// ── E2E Tests — Karate (Punto 5: Pruebas E2E cross-service)
// Framework: Karate DSL sobre JUnit 5. Los journeys prueban flujos reales
// encadenando auth → form → promotion (Kafka) → gateway.
//
// Correr: ./gradlew :e2e-tests:e2eTest
// El task "test" estándar está deshabilitado para no ejecutar E2E en cada build.
// Requiere entorno desplegado (NodePorts accesibles). Ver karate-config.js.

plugins {
    java
}

// No aplicar Spring Boot ni Kotlin a este módulo (solo Java + Karate)
configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "org.springframework.boot") {
            useVersion("3.2.4")
        }
    }
}

dependencies {
    testImplementation("com.intuit.karate:karate-junit5:1.4.1")
    testImplementation("net.masterthought:cucumber-reporting:5.8.1")
}

// Task dedicada para E2E (no corre en el ciclo normal de test)
val e2eTest by tasks.registering(Test::class) {
    description = "Ejecuta pruebas E2E Karate contra el entorno desplegado"
    group = "verification"
    useJUnitPlatform()
    testClassesDirs = sourceSets["test"].output.classesDirs
    classpath = sourceSets["test"].runtimeClasspath

    // Pasar todas las variables de entorno al proceso de test
    environment(System.getenv())

    // Directorio de reportes Karate
    systemProperty("karate.output.dir", "${project.buildDir}/karate-reports")

    reports {
        html.outputLocation.set(file("${project.buildDir}/karate-reports"))
        junitXml.outputLocation.set(file("${project.buildDir}/test-results/e2eTest"))
    }
}

// El task "test" estándar no corre nada (E2E requiere entorno live)
tasks.named<Test>("test") {
    enabled = false
}

// JaCoCo no tiene sentido en E2E (cobertura se mide en los servicios individuales)
tasks.withType<org.gradle.testing.jacoco.tasks.JacocoReport> {
    enabled = false
}
