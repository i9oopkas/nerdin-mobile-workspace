plugins {
    id("nerdin.nerdin-android-application")
}

android {
    namespace = "app.nerdin"
    defaultConfig {
        applicationId = "app.nerdin.mobile"
        versionCode = 1
        versionName = "0.1.0"
    }
    buildFeatures {
        compose = true
    }
}

// ─── Plugin DEX assets ──────────────────────────────────────────

val pluginModules = listOf(
    ":plugins:llm:openai",
    ":plugins:termux",
    ":plugins:agent:react",
    ":plugins:agent:permissions",
    ":plugins:tools:local",
    ":plugins:tools:termux"
)

androidComponents.onVariants { variant ->
    // Declare the output directory as a DirectoryProperty so it can be
    // used both as the task's output and as the asset source registration.
    val outputDir = project.objects.directoryProperty()
    outputDir.set(layout.buildDirectory.dir("generated/plugin-assets/${variant.name}"))

    val collectTask = tasks.register("collectPluginDex${variant.name}") {
        description = "Collect plugin .dex files for ${variant.name}"
        group = "plugin"

        dependsOn(pluginModules.map { "$it:packagePluginDex" })

        // Declare the output directory so AGP can track it
        outputs.dir(outputDir)

        doLast {
            val pluginsDir = outputDir.get().asFile.resolve("plugins")
            pluginsDir.mkdirs()

            pluginModules.forEach { modulePath ->
                val moduleDexName = modulePath.replace(":", "-").removePrefix("-")
                val dexFile = rootProject.project(modulePath)
                    .layout.buildDirectory
                    .file("plugin-dex/${moduleDexName}.dex")
                    .get().asFile

                if (dexFile.exists()) {
                    val target = File(pluginsDir, dexFile.name)
                    dexFile.copyTo(target, overwrite = true)
                    logger.lifecycle("✅ Plugin dex: ${dexFile.name} → ${target.length()} bytes")
                } else {
                    logger.warn("⚠️ No dex at ${dexFile.absolutePath} for $modulePath")
                }

                val metaFile = rootProject.project(modulePath)
                    .layout.buildDirectory
                    .file("plugin-dex/${moduleDexName}.pluginmeta")
                    .get().asFile

                if (metaFile.exists()) {
                    val target = File(pluginsDir, metaFile.name)
                    metaFile.copyTo(target, overwrite = true)
                    logger.lifecycle("✅ Plugin meta: ${metaFile.name} → ${target.length()} bytes")
                } else {
                    logger.warn("⚠️ No pluginmeta at ${metaFile.absolutePath} for $modulePath")
                }
            }
        }
    }

    // Register the generated directory as an asset source for AGP 9.x.
    // This tells the Android asset pipeline to include files from this
    // directory (produced by collectTask) in the APK assets.
    variant.sources.assets!!.addGeneratedSourceDirectory(collectTask) {
        outputDir
    }
}

// ─── Dependencies ───────────────────────────────────────────────

dependencies {
    implementation(project(":core:api"))
    implementation(project(":core:runtime"))
    implementation(project(":ui:api"))
    implementation(project(":ui:core"))
    implementation(project(":ui:agent"))
    implementation(project(":ui:settings"))

    // Compose
    implementation(platform("androidx.compose:compose-bom:2025.01.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    debugImplementation("androidx.compose.ui:ui-tooling")
}
