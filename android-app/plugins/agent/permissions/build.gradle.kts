plugins {
    id("nerdin.nerdin-android-library")
    id("nerdin.nerdin-plugin-dex")
}

android {
    namespace = "app.nerdin.plugins.agent.permissions"
}

pluginDex {
    pluginClass = "app.nerdin.plugins.agent.permissions.AgentPermissionsPlugin"
}

dependencies {
    implementation(project(":core:api"))
    implementation(project(":plugins:agent:api"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.json)
}
