plugins {
    id("nerdin.nerdin-android-library")
}

android {
    namespace = "app.nerdin.plugins.agent.api"
}

dependencies {
    implementation(project(":core:api"))
    implementation(project(":plugins:llm:api"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.json)
}
