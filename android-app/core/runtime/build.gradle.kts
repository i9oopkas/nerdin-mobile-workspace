plugins {
    id("nerdin.nerdin-android-library")
}

android {
    namespace = "app.nerdin.core.runtime"
}

dependencies {
    implementation(project(":core:api"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.core.ktx)
}
