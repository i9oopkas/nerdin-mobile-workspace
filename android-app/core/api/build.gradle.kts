plugins {
    id("nerdin.nerdin-android-library")
}

android {
    namespace = "app.nerdin.core.api"
}

dependencies {
    implementation(libs.kotlinx.coroutines.core)
}
