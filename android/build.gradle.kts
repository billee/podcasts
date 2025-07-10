// Top-level build file where you can add configuration options common to all sub-projects/modules.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // This is the Android Gradle Plugin (AGP) - ESSENTIAL
        classpath("com.android.tools.build:gradle:8.3.0") // Ensure this version is compatible with your Flutter/Gradle setup
        // Kotlin Gradle Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0") // Ensure this version matches your app-level kotlin_version
        // Google Services plugin for Firebase
        classpath("com.google.gms:google-services:4.4.2") // Ensure this is the correct version for your Firebase setup
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory configuration (as per your previous file)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
