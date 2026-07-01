plugins {
    id("nerdin.nerdin-android-library")
    id("nerdin.nerdin-plugin-dex")
}

android {
    namespace = "app.nerdin.plugins.tools.local"
}

pluginDex {
    pluginClass = "app.nerdin.plugins.tools.local.LocalToolsPlugin"
}

dependencies {
    implementation(project(":core:api"))
    implementation(project(":plugins:tool:api"))
    implementation(libs.kotlinx.coroutines.core)
}
