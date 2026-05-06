package com.circleguard.notification.integration;

import com.circleguard.notification.service.ExposureNotificationListener;
import com.circleguard.notification.service.LmsService;
import com.circleguard.notification.service.NotificationDispatcher;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/**
 * Prueba de integración: ExposureNotificationListener → NotificationDispatcher.
 * Valida que un evento de cambio de estado activa el despacho multi-canal.
 */
@SpringBootTest
@Tag("integration")
class ExposureNotificationIntegrationTest {

    @Autowired
    private ExposureNotificationListener listener;

    @MockBean
    private NotificationDispatcher dispatcher;

    @MockBean
    private LmsService lmsService;

    @Test
    void shouldTriggerDispatchForSuspectStatusChange() throws Exception {
        String eventJson = "{\"anonymousId\":\"user-exp-001\",\"status\":\"SUSPECT\"}";

        listener.handleStatusChange(eventJson);

        verify(dispatcher).dispatch(eq("user-exp-001"), eq("SUSPECT"));
        verify(lmsService).syncRemoteAttendance(eq("user-exp-001"), eq("SUSPECT"));
    }

    @Test
    void shouldNotDispatchForActiveStatus() throws Exception {
        String eventJson = "{\"anonymousId\":\"user-exp-002\",\"status\":\"ACTIVE\"}";

        listener.handleStatusChange(eventJson);

        verifyNoInteractions(dispatcher);
        verifyNoInteractions(lmsService);
    }

    @Test
    void shouldTriggerDispatchForConfirmedStatusChange() throws Exception {
        String eventJson = "{\"anonymousId\":\"user-exp-003\",\"status\":\"CONFIRMED\"}";

        listener.handleStatusChange(eventJson);

        verify(dispatcher).dispatch(eq("user-exp-003"), eq("CONFIRMED"));
    }
}
