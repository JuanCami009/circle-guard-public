package com.circleguard.notification.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class ExposureNotificationListener {

    private final NotificationDispatcher dispatcher;
    private final ObjectMapper objectMapper;
    private final LmsService lmsService;

    // ── Métrica de negocio: notificaciones despachadas por canal (Punto 7) ─
    private final Counter notificationsSent;
    private final Counter notificationsFailed;

    public ExposureNotificationListener(NotificationDispatcher dispatcher,
                                        ObjectMapper objectMapper,
                                        LmsService lmsService,
                                        MeterRegistry meterRegistry) {
        this.dispatcher    = dispatcher;
        this.objectMapper  = objectMapper;
        this.lmsService    = lmsService;
        this.notificationsSent = Counter.builder("circleguard_notifications_sent_total")
                                        .description("Notificaciones de estado de salud despachadas")
                                        .tag("channel", "status_change")
                                        .tag("result", "success")
                                        .register(meterRegistry);
        this.notificationsFailed = Counter.builder("circleguard_notifications_sent_total")
                                          .description("Notificaciones de estado de salud despachadas")
                                          .tag("channel", "status_change")
                                          .tag("result", "failure")
                                          .register(meterRegistry);
    }

    /**
     * Listens for status changes and exposure events.
     */
    @KafkaListener(topics = "promotion.status.changed", groupId = "notification-group")
    public void handleStatusChange(String eventJson) {
        log.info("Received health status change event: {}", eventJson);
        try {
            JsonNode node = objectMapper.readTree(eventJson);
            String userId = node.path("anonymousId").asText("unknown");
            String status = node.path("status").asText("UNKNOWN");

            if (!"ACTIVE".equals(status) && !"UNKNOWN".equals(status)) {
                dispatcher.dispatch(userId, status);
                lmsService.syncRemoteAttendance(userId, status);
                notificationsSent.increment(); // ── métrica de negocio
            }
        } catch (Exception e) {
            log.error("Failed to parse health status change event: {}", e.getMessage());
            notificationsFailed.increment(); // ── métrica de negocio
        }
    }
}
