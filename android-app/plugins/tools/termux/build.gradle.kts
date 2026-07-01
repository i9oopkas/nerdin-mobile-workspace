plugins {
    id("nerdin.nerdin-android-library")
    id("nerdin.nerdin-plugin-dex")
}

android {
    namespace = "app.nerdin.plugins.tools.termux"
}

pluginDex {
    pluginClass = "app.nerdin.plugins.tools.termux.TermuxToolsPlugin"
}

dependencies {
    implementation(project(":core:api"))
    implementation(project(":plugins:tool:api"))
    implementation(libs.kotlinx.coroutines.core)
}
