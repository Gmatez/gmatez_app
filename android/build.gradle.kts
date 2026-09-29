allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// agora_rtc_engine (and similar plugins) use safeExtGet('compileSdkVersion', 31).
// AndroidX 1.13+ requires compileSdk >= 34.
extra["compileSdkVersion"] = 35
extra["targetSdkVersion"] = 35
extra["minSdkVersion"] = 24

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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
