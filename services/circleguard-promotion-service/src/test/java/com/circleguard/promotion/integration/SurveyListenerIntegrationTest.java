package com.circleguard.promotion.integration;

import com.circleguard.promotion.listener.SurveyListener;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.Neo4jContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Prueba de integración: SurveyListener → HealthStatusService → Neo4j.
 * Valida que un evento de encuesta con síntomas actualiza el nodo del usuario a SUSPECT.
 */
@SpringBootTest
@Testcontainers
@Tag("integration")
class SurveyListenerIntegrationTest {

    @Container
    static Neo4jContainer<?> neo4j = new Neo4jContainer<>("neo4j:5.12")
            .withAdminPassword("password");

    @DynamicPropertySource
    static void neo4jProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.neo4j.uri", neo4j::getBoltUrl);
        registry.add("spring.neo4j.authentication.username", () -> "neo4j");
        registry.add("spring.neo4j.authentication.password", () -> "password");
    }

    @Autowired
    private SurveyListener surveyListener;

    @Autowired
    private Neo4jClient neo4jClient;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @BeforeEach
    void cleanGraph() {
        neo4jClient.query("MATCH (n) DETACH DELETE n").run();
    }

    @Test
    void shouldPromoteUserToSuspectWhenSurveyHasSymptoms() {
        neo4jClient.query("CREATE (:User {anonymousId: 'survey-user-001', status: 'ACTIVE'})").run();

        surveyListener.onSurveySubmitted(Map.of("anonymousId", "survey-user-001", "hasSymptoms", true));

        String status = neo4jClient
                .query("MATCH (u:User {anonymousId: 'survey-user-001'}) RETURN u.status AS status")
                .fetchAs(String.class).one().orElse("NOT_FOUND");

        assertThat(status).isEqualTo("SUSPECT");
    }

    @Test
    void shouldLeaveUserUnchangedWhenSurveyHasNoSymptoms() {
        neo4jClient.query("CREATE (:User {anonymousId: 'survey-user-002', status: 'ACTIVE'})").run();

        surveyListener.onSurveySubmitted(Map.of("anonymousId", "survey-user-002", "hasSymptoms", false));

        String status = neo4jClient
                .query("MATCH (u:User {anonymousId: 'survey-user-002'}) RETURN u.status AS status")
                .fetchAs(String.class).one().orElse("NOT_FOUND");

        assertThat(status).isEqualTo("ACTIVE");
    }
}
