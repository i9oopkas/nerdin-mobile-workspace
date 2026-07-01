pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "nerdin-mobile-workspace"

includeBuild("build-logic")

// Core
include(":core:api")
include(":core:runtime")

// Plugin API modules (service provider interfaces + data types)
include(":plugins:llm:api")
include(":plugins:memory:api")
include(":plugins:agent:api")
include(":plugins:tool:api")
include(":plugins:search:api")
include(":plugins:prompt:api")
include(":plugins:auth:api")

// Plugin implementations
include(":plugins:llm:openai")
include(":plugins:termux")
include(":plugins:agent:react")
include(":plugins:agent:permissions")
include(":plugins:tools:local")
include(":plugins:tools:termux")

// UI modules
include(":ui:api")
include(":ui:core")
include(":ui:agent")
include(":ui:settings")

// App shell
include(":app")
