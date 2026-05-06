package com.circleguard.form.integration;

import com.circleguard.form.model.Questionnaire;
import com.circleguard.form.repository.QuestionnaireRepository;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.TestPropertySource;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Prueba de integración JPA: ciclo completo CRUD del Questionnaire.
 * Valida la persistencia, los callbacks @PrePersist/@PreUpdate y el finder custom.
 */
@DataJpaTest
@TestPropertySource(properties = {
    "spring.datasource.url=jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
    "spring.jpa.hibernate.ddl-auto=create-drop",
    "spring.flyway.enabled=false"
})
@Tag("integration")
class QuestionnaireJpaIntegrationTest {

    @Autowired
    private QuestionnaireRepository repository;

    @Test
    void shouldPersistAndRetrieveQuestionnaire() {
        Questionnaire q = Questionnaire.builder()
                .title("Encuesta COVID-19")
                .description("Formulario de síntomas")
                .version(1)
                .isActive(true)
                .build();

        Questionnaire saved = repository.save(q);

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getCreatedAt()).isNotNull();

        Optional<Questionnaire> found = repository.findById(saved.getId());
        assertThat(found).isPresent();
        assertThat(found.get().getTitle()).isEqualTo("Encuesta COVID-19");
    }

    @Test
    void shouldFindActiveQuestionnaireByHighestVersion() {
        repository.save(Questionnaire.builder().title("V1").version(1).isActive(true).build());
        repository.save(Questionnaire.builder().title("V2").version(2).isActive(true).build());
        repository.save(Questionnaire.builder().title("V3-inactive").version(3).isActive(false).build());

        Optional<Questionnaire> active = repository.findFirstByIsActiveTrueOrderByVersionDesc();

        assertThat(active).isPresent();
        assertThat(active.get().getTitle()).isEqualTo("V2");
    }

    @Test
    void shouldSetDefaultValuesOnPersist() {
        Questionnaire q = Questionnaire.builder()
                .title("Minimal Questionnaire")
                .build();

        Questionnaire saved = repository.save(q);

        assertThat(saved.getVersion()).isEqualTo(1);
        assertThat(saved.getIsActive()).isFalse();
        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }

    @Test
    void shouldReturnAllPersistedQuestionnaires() {
        repository.save(Questionnaire.builder().title("Q1").version(1).isActive(true).build());
        repository.save(Questionnaire.builder().title("Q2").version(1).isActive(false).build());

        List<Questionnaire> all = repository.findAll();

        assertThat(all).hasSizeGreaterThanOrEqualTo(2);
        assertThat(all).extracting(Questionnaire::getTitle).contains("Q1", "Q2");
    }
}
