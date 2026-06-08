package com.circleguard.dashboard.integration;

import com.circleguard.dashboard.client.PromotionClient;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Prueba de integración: AnalyticsController → AnalyticsService → KAnonymityFilter.
 * PromotionClient y JdbcTemplate se mockean para evitar dependencias de red/BD real.
 * Verifica el pipeline completo HTTP → lógica de privacidad → respuesta JSON.
 */
@SpringBootTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:dashtest;DB_CLOSE_DELAY=-1",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
    "spring.jpa.hibernate.ddl-auto=create-drop",
    "circleguard.promotion-service.url=http://localhost:9999"
})
@AutoConfigureMockMvc
@Tag("integration")
class AnalyticsControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PromotionClient promotionClient;

    @MockBean
    private JdbcTemplate jdbcTemplate;

    // ── GET /api/v1/analytics/summary ─────────────────────────────────

    @Test
    void summaryEndpointShouldReturnPromotionStats() throws Exception {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 1200L);
        stats.put("suspectCount", 30L);
        stats.put("confirmedCount", 5L);

        when(promotionClient.getHealthStats()).thenReturn(stats);

        mockMvc.perform(get("/api/v1/analytics/summary")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.totalUsers").value(1200))
            .andExpect(jsonPath("$.suspectCount").value(30));
    }

    // ── GET /api/v1/analytics/health-board ────────────────────────────

    @Test
    void healthBoardEndpointShouldReturnGlobalStats() throws Exception {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("campusStatus", "SAFE");
        stats.put("totalActive", 980L);

        when(promotionClient.getHealthStats()).thenReturn(stats);

        mockMvc.perform(get("/api/v1/analytics/health-board")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.campusStatus").value("SAFE"));
    }

    // ── GET /api/v1/analytics/department/{dept} ───────────────────────

    @Test
    void departmentEndpointShouldApplyKAnonymityMasking() throws Exception {
        // Departamento pequeño: 3 usuarios → totalUsers < K=5 → enmascarar todo
        Map<String, Object> raw = new LinkedHashMap<>();
        raw.put("totalUsers", 3L);
        raw.put("suspectCount", 1L);
        raw.put("department", "TestDept");

        when(promotionClient.getHealthStatsByDepartment("TestDept")).thenReturn(raw);

        mockMvc.perform(get("/api/v1/analytics/department/TestDept")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            // k-anonymity debe enmascarar: totalUsers < 5
            .andExpect(jsonPath("$.totalUsers").value("<5"))
            .andExpect(jsonPath("$.note").value("Insufficient data for privacy"));
    }

    @Test
    void departmentEndpointShouldExposeCountsWhenPopulationSufficient() throws Exception {
        Map<String, Object> raw = new LinkedHashMap<>();
        raw.put("totalUsers", 200L);
        raw.put("suspectCount", 8L);   // >= K=5 → visible
        raw.put("confirmedCount", 2L); // < K=5 → enmascarado
        raw.put("department", "Engineering");

        when(promotionClient.getHealthStatsByDepartment("Engineering")).thenReturn(raw);

        mockMvc.perform(get("/api/v1/analytics/department/Engineering")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.suspectCount").value(8))
            .andExpect(jsonPath("$.confirmedCount").value("<5"));
    }

    // ── GET /api/v1/analytics/time-series ────────────────────────────

    @Test
    void timeSeriesEndpointShouldReturnDataPoints() throws Exception {
        when(jdbcTemplate.queryForList(anyString(), (Object) org.mockito.ArgumentMatchers.any()))
            .thenThrow(new RuntimeException("Table not found")); // fuerza mock data

        mockMvc.perform(get("/api/v1/analytics/time-series")
                .param("period", "hourly")
                .param("limit", "5")
                .accept(MediaType.APPLICATION_JSON))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$").isArray());
    }
}
