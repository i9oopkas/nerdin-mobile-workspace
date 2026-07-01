plugins {
    id("nerdin.nerdin-android-library")
}

android {
    namespace = "app.nerdin.plugins.tool.api"
}

dependencies {
    implementation(project(":core:api"))
    implementation(libs.kotlinx.coroutines.core)
}
