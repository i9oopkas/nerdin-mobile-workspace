plugins {
    id("nerdin.nerdin-android-library")
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "app.nerdin.ui.core"
}

dependencies {
    implementation(project(":ui:api"))
    implementation(project(":core:api"))
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.material3)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.tooling.preview)
    implementation("androidx.compose.material:material-icons-extended")
    implementation(libs.androidx.core.ktx)
    implementation(libs.hilt.core)
    implementation(libs.kotlinx.coroutines.core)
    implementation("androidx.activity:activity-compose:1.9.3")
}
