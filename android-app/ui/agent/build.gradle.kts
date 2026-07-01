plugins {
    id("nerdin.nerdin-android-library")
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "app.nerdin.ui.agent"
}

dependencies {
    implementation(project(":ui:api"))
    implementation(project(":ui:core"))
    implementation(project(":core:api"))
    implementation(project(":plugins:agent:api"))
    implementation(project(":plugins:llm:api"))
    implementation(libs.compose.material3)
    implementation(libs.compose.ui)
    implementation(libs.hilt.core)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.kotlinx.coroutines.core)
}
