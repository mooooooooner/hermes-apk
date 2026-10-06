pluginManagement {
    repositories {
        // Local pre-fetched mirror (Clash/proxy occasionally drops Gradle's TLS handshakes).
        maven { url = uri("file:///D:/downloaded/m2local") }
        // Prefer a domestic mirror first (more reliable on this network), fall back to upstream.
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven { url = uri("file:///D:/downloaded/m2local") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        google()
        mavenCentral()
    }
}

rootProject.name = "Hermes"
include(":app")
