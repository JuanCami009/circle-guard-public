package com.circleguard.gateway.controller;

import com.circleguard.gateway.service.QrValidationService;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(GateController.class)
@Import(GateControllerTest.TestMeterConfig.class)
public class GateControllerTest {

    // Provee un MeterRegistry real (in-memory) para que @PostConstruct pueda crear los Counters
    static class TestMeterConfig {
        @Bean
        MeterRegistry meterRegistry() {
            return new SimpleMeterRegistry();
        }
    }

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private QrValidationService validationService;

    @Test
    void shouldReturnValidationResult() throws Exception {
        String token = "mock-token";
        QrValidationService.ValidationResult mockResult =
            new QrValidationService.ValidationResult(true, "GREEN", "Welcome");

        Mockito.when(validationService.validateToken(token)).thenReturn(mockResult);

        mockMvc.perform(post("/api/v1/gate/validate")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\": \"mock-token\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(true))
                .andExpect(jsonPath("$.status").value("GREEN"));
    }
}
