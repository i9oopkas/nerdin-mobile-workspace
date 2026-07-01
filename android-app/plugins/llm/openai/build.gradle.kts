plugins {
    id("nerdin.nerdin-android-library")
    id("nerdin.nerdin-plugin-dex")
}

android {
    namespace = "app.nerdin.plugins.llm.openai"
}

pluginDex {
    pluginClass = "app.nerdin.plugins.llm.openai.OpenAiPlugin"
}

dependencies {
    implementation(project(":core:api"))
    implementation(project(":plugins:llm:api"))
    implementation(libs.okhttp)
    implementation(libs.okhttp.sse)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.json)
}
