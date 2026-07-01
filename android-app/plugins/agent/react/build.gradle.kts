plugins {
    id("nerdin.nerdin-android-library")
    id("nerdin.nerdin-plugin-dex")
}

android {
    namespace = "app.nerdin.plugins.agent.react"
}

pluginDex {
    pluginClass = "app.nerdin.plugins.agent.react.ReactAgentPlugin"
}

dependencies {
    implementation(project(":core:api"))
    implementation(project(":plugins:agent:api"))
    implementation(project(":plugins:llm:api"))
    implementation(project(":plugins:tool:api"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.json)
}
