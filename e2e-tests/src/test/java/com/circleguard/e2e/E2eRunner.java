package com.circleguard.e2e;

import com.intuit.karate.junit5.Karate;
import org.junit.jupiter.api.Tag;

/**
 * Runner principal para la suite E2E de CircleGuard (Karate + JUnit 5).
 *
 * Ejecutar: ./gradlew :e2e-tests:e2eTest
 *
 * Variables de entorno requeridas (ver karate-config.js):
 *   E2E_HOST           — host con los NodePorts accesibles (default: host.docker.internal)
 *   E2E_PORT_AUTH      — NodePort de auth-service (default: 30180/31180 según entorno)
 *   E2E_PORT_FORM      — NodePort de form-service
 *   E2E_PORT_PROMOTION — NodePort de promotion-service
 *   E2E_PORT_GATEWAY   — NodePort de gateway-service
 *   ... (ver karate-config.js para la lista completa)
 *
 *   TEST_JWT / TEST_ANON_ID — JWT + anonId pre-autenticados (fallback si no hay creds de login)
 */
@Tag("e2e")
public class E2eRunner {

    @Karate.Test
    Karate runAllE2e() {
        return Karate.run("classpath:e2e").relativeTo(getClass());
    }
}
