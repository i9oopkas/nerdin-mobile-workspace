package nerdin

import org.gradle.api.GradleException
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.*
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.jar.JarEntry
import java.util.jar.JarInputStream
import java.util.jar.JarOutputStream
import java.util.zip.ZipInputStream

class NerdinPluginDex : Plugin<Project> {
    override fun apply(target: Project) {
        val ext = target.extensions.create("pluginDex", PluginDexExtension::class.java)

        target.tasks.register("packagePluginDex") {
            description = "Packages the plugin implementation class as a standalone .dex file with META-INF/services for ServiceLoader discovery."
            group = "plugin"

            dependsOn("assembleDebug")

            doLast {
                val project = target
                val sdkDir = findSdkDir(project)
                val buildToolsDir = File(sdkDir, "build-tools")
                val latestBt = buildToolsDir.listFiles()
                    ?.filter { it.isDirectory }
                    ?.maxByOrNull { it.name }
                    ?: throw GradleException("No build-tools directory found in $buildToolsDir")

                val androidJar = File(sdkDir, "platforms/android-36/android.jar")
                val d8Jar = File(latestBt, "lib/d8.jar")

                if (!androidJar.exists()) throw GradleException("android.jar not found: $androidJar")
                if (!d8Jar.exists()) throw GradleException("d8.jar not found: $d8Jar")

                // 1. Find AAR output
                val aarDir = project.layout.buildDirectory.dir("outputs/aar").get().asFile
                val aarFile = aarDir.listFiles()?.find { it.name.endsWith("-debug.aar") }
                    ?: throw GradleException("No debug AAR found in $aarDir. Run assembleDebug first.")

                // 2. Extract classes.jar from AAR
                val tempDir = project.layout.buildDirectory.dir("tmp/plugin-dex").get().asFile.also { it.mkdirs() }
                val classesJar = File(tempDir, "classes.jar")
                ZipInputStream(FileInputStream(aarFile)).use { zis ->
                    var entry = zis.nextEntry
                    while (entry != null) {
                        if (entry.name == "classes.jar") {
                            FileOutputStream(classesJar).use { zis.copyTo(it) }
                            break
                        }
                        zis.closeEntry()
                        entry = zis.nextEntry
                    }
                }

                if (!classesJar.exists()) {
                    throw GradleException("classes.jar not found inside AAR: $aarFile")
                }

                // 3. Create merged JAR with META-INF/services
                val mergedJar = File(tempDir, "merged.jar")
                JarOutputStream(FileOutputStream(mergedJar)).use { jos ->
                    JarInputStream(FileInputStream(classesJar)).use { jis ->
                        var entry = jis.nextJarEntry
                        while (entry != null) {
                            jos.putNextEntry(JarEntry(entry.name))
                            if (!entry.isDirectory) jis.copyTo(jos)
                            jos.closeEntry()
                            entry = jis.nextJarEntry
                        }
                    }
                    // Add ServiceLoader manifest file
                    jos.putNextEntry(JarEntry("META-INF/services/app.nerdin.core.api.Plugin"))
                    jos.write(ext.pluginClass.toByteArray())
                    jos.closeEntry()
                }

                // 4. Run d8 to convert JAR to DEX
                val process = ProcessBuilder(
                    "java", "-cp", d8Jar.absolutePath,
                    "com.android.tools.r8.D8",
                    "--lib", androidJar.absolutePath,
                    "--release",
                    "--output", tempDir.absolutePath,
                    mergedJar.absolutePath
                )
                    .directory(tempDir)
                    .inheritIO()
                    .start()
                val exitCode = process.waitFor()
                if (exitCode != 0) {
                    throw GradleException("d8 process exited with code $exitCode")
                }

                // 5. Copy output .dex
                val generatedDex = File(tempDir, "classes.dex")
                if (!generatedDex.exists()) {
                    throw GradleException("d8 did not produce classes.dex in $tempDir")
                }
                val outputDir = project.layout.buildDirectory.dir("plugin-dex").get().asFile.also { it.mkdirs() }
                val modulePath = project.path.replace(":", "-").removePrefix("-")
                generatedDex.copyTo(File(outputDir, "${modulePath}.dex"), overwrite = true)

                // Write .pluginmeta file alongside the .dex for runtime discovery
                // (ServiceLoader doesn't work with DEX because d8 strips META-INF/services/)
                val metaFile = outputDir.resolve("$modulePath.pluginmeta")
                metaFile.writeText(ext.pluginClass)
                println("Plugin metadata written: ${metaFile.absolutePath}")

                println("✅ Plugin DEX created: ${outputDir}/${modulePath}.dex (${generatedDex.length()} bytes)")
            }
        }
    }

    private fun findSdkDir(project: Project): String {
        // Try local.properties first
        var dir = project.projectDir.resolve("local.properties")
        if (!dir.exists()) dir = project.rootProject.rootDir.resolve("local.properties")
        if (dir.exists()) {
            dir.readLines().forEach { line ->
                if (line.startsWith("sdk.dir")) {
                    return line.substringAfter("=").trim().replace("\\", "/")
                }
            }
        }
        return System.getenv("ANDROID_SDK_ROOT")
            ?: System.getenv("ANDROID_HOME")
            ?: "${System.getProperty("user.home")}/Android/Sdk"
    }
}

open class PluginDexExtension {
    /** Fully qualified class name of the Plugin implementation, e.g. "app.nerdin.plugins.llm.openai.OpenAiPlugin" */
    var pluginClass: String = ""
}
