plugins {
    id("nerdin.nerdin-android-library")
    id("nerdin.nerdin-plugin-dex")
}

android {
    namespace = "app.nerdin.plugins.termux"
}

pluginDex {
    pluginClass = "app.nerdin.plugins.termux.TermuxPlugin"
}

dependencies {
    implementation(project(":core:api"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.json)
}
