plugins {
    id("nerdin.nerdin-android-library")
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "app.nerdin.ui.settings"
}

dependencies {
    implementation(project(":ui:api"))
    implementation(project(":ui:core"))
    implementation(project(":core:api"))
    implementation(libs.compose.material3)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.kotlinx.coroutines.core)
}
