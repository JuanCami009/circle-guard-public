package com.circleguard.form.service;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.model.Questionnaire;
import com.circleguard.form.model.ValidationStatus;
import com.circleguard.form.repository.HealthSurveyRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class HealthSurveyService {
    private final HealthSurveyRepository repository;
    private final QuestionnaireService questionnaireService;
    private final SymptomMapper symptomMapper;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    // ── Métrica de negocio: encuestas de salud enviadas (Punto 7) ─────────
    private final Counter surveysSubmitted;

    private static final String TOPIC_SURVEY_SUBMITTED = "survey.submitted";
    private static final String TOPIC_CERTIFICATE_VALIDATED = "certificate.validated";

    public HealthSurveyService(HealthSurveyRepository repository,
                               QuestionnaireService questionnaireService,
                               SymptomMapper symptomMapper,
                               KafkaTemplate<String, Object> kafkaTemplate,
                               MeterRegistry meterRegistry) {
        this.repository           = repository;
        this.questionnaireService = questionnaireService;
        this.symptomMapper        = symptomMapper;
        this.kafkaTemplate        = kafkaTemplate;
        this.surveysSubmitted = Counter.builder("circleguard_surveys_submitted_total")
                                       .description("Total de encuestas de salud enviadas por usuarios")
                                       .register(meterRegistry);
    }

    @Transactional
    public HealthSurvey submitSurvey(HealthSurvey survey) {
        Optional<Questionnaire> activeQuestionnaire = questionnaireService.getActiveQuestionnaire();

        boolean hasSymptoms = activeQuestionnaire
                .map(q -> symptomMapper.hasSymptoms(survey, q))
                .orElse(false);

        // Compatibility: update the legacy fields if they are missing in request but present in responses
        if (survey.getHasFever() == null) survey.setHasFever(hasSymptoms);
        if (survey.getHasCough() == null) survey.setHasCough(hasSymptoms);

        // Set initial validation status if attachment is present
        if (survey.getAttachmentPath() != null) {
            survey.setValidationStatus(ValidationStatus.PENDING);
        }

        HealthSurvey saved = repository.save(survey);
        surveysSubmitted.increment(); // ── métrica de negocio

        // Emit Event for Promotion Service
        Map<String, Object> event = Map.of(
            "anonymousId", saved.getAnonymousId(),
            "hasSymptoms", hasSymptoms,
            "timestamp", System.currentTimeMillis()
        );
        kafkaTemplate.send(TOPIC_SURVEY_SUBMITTED, saved.getAnonymousId().toString(), event);

        return saved;
    }

    public List<HealthSurvey> getPendingSurveys() {
        return repository.findByAttachmentPathIsNotNullAndValidationStatus(ValidationStatus.PENDING);
    }

    @Transactional
    public void validateSurvey(UUID surveyId, ValidationStatus status, UUID adminId) {
        HealthSurvey survey = repository.findById(surveyId)
                .orElseThrow(() -> new RuntimeException("Survey not found: " + surveyId));

        survey.setValidationStatus(status);
        survey.setValidatedBy(adminId);
        repository.save(survey);

        // Emit event so promotion-service can restore access if approved
        if (status == ValidationStatus.APPROVED) {
            Map<String, Object> event = Map.of(
                "anonymousId", survey.getAnonymousId(),
                "status", "APPROVED",
                "adminId", adminId,
                "timestamp", System.currentTimeMillis()
            );
            kafkaTemplate.send(TOPIC_CERTIFICATE_VALIDATED, survey.getAnonymousId().toString(), event);
        }
    }
}
