package com.circleguard.notification.service;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class AuditLogServiceTest {

    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;

    @InjectMocks
    private AuditLogService auditLogService;

    @Test
    void shouldPublishAuditEventToCorrectTopic() {
        auditLogService.logDelivery("user-123", "EMAIL", "DELIVERED", "corr-abc");

        verify(kafkaTemplate).send(eq("notification.audit"), eq("user-123"), any());
    }

    @Test
    @SuppressWarnings("unchecked")
    void shouldIncludeAllFieldsInAuditEvent() {
        ArgumentCaptor<Object> payloadCaptor = ArgumentCaptor.forClass(Object.class);

        auditLogService.logDelivery("user-456", "SMS", "FAILED", "corr-xyz");

        verify(kafkaTemplate).send(eq("notification.audit"), eq("user-456"), payloadCaptor.capture());

        Map<String, Object> event = (Map<String, Object>) payloadCaptor.getValue();
        assertThat(event).containsKeys("eventId", "timestamp", "userId", "channel", "status", "correlationId");
        assertThat(event.get("userId")).isEqualTo("user-456");
        assertThat(event.get("channel")).isEqualTo("SMS");
        assertThat(event.get("status")).isEqualTo("FAILED");
        assertThat(event.get("correlationId")).isEqualTo("corr-xyz");
    }

    @Test
    @SuppressWarnings("unchecked")
    void shouldGenerateCorrelationIdWhenNullProvided() {
        ArgumentCaptor<Object> payloadCaptor = ArgumentCaptor.forClass(Object.class);

        auditLogService.logDelivery("user-789", "PUSH", "DELIVERED", null);

        verify(kafkaTemplate).send(anyString(), anyString(), (Object) payloadCaptor.capture());

        Map<String, Object> event = (Map<String, Object>) payloadCaptor.getValue();
        assertThat(event.get("correlationId")).isNotNull().isInstanceOf(String.class);
        assertThat((String) event.get("correlationId")).isNotEmpty();
    }
}
