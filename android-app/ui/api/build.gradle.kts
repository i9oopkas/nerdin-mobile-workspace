plugins {
    id("nerdin.nerdin-android-library")
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "app.nerdin.ui.api"
}

dependencies {
    implementation(project(":core:api"))
    implementation(libs.compose.runtime)
    implementation(libs.compose.ui)
    implementation("androidx.compose.foundation:foundation:1.7.6")
    implementation(libs.hilt.core)
    implementation(libs.kotlinx.coroutines.core)
}
