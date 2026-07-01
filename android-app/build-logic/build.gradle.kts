plugins {
    `kotlin-dsl`
}

repositories {
    google()
    mavenCentral()
}

gradlePlugin {
    plugins {
        register("nerdin-android-library") {
            id = "nerdin.nerdin-android-library"
            implementationClass = "nerdin.NerdinAndroidLibrary"
        }
        register("nerdin-android-application") {
            id = "nerdin.nerdin-android-application"
            implementationClass = "nerdin.NerdinAndroidApplication"
        }
        register("nerdin-plugin-dex") {
            id = "nerdin.nerdin-plugin-dex"
            implementationClass = "nerdin.NerdinPluginDex"
        }
    }
}

dependencies {
    implementation("com.android.tools.build:gradle:9.1.1")
    implementation("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
}
