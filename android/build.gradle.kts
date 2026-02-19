allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

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

// AGP 8+ requires a namespace on every Android module.
// Some third-party plugins still omit it, so we derive one automatically.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val getNamespace = androidExt.javaClass.methods.firstOrNull {
            it.name == "getNamespace" && it.parameterCount == 0
        } ?: return@withPlugin
        val current = runCatching { getNamespace.invoke(androidExt) as? String }.getOrNull()
        if (!current.isNullOrBlank()) return@withPlugin

        val setNamespace = androidExt.javaClass.methods.firstOrNull {
            it.name == "setNamespace" && it.parameterCount == 1
        } ?: return@withPlugin

        val safeProjectName = project.name.replace(Regex("[^A-Za-z0-9_]"), "_")
        val fallbackNamespace = "com.hbp.$safeProjectName"
        runCatching { setNamespace.invoke(androidExt, fallbackNamespace) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
