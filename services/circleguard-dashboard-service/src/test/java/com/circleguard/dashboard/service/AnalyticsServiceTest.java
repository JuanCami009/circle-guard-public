package com.circleguard.dashboard.service;

import com.circleguard.dashboard.client.PromotionClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

/**
 * Pruebas unitarias de AnalyticsService.
 * PromotionClient y JdbcTemplate se mockean — sin BD ni red real.
 */
@ExtendWith(MockitoExtension.class)
class AnalyticsServiceTest {

    @Mock
    private JdbcTemplate jdbc;

    @Mock
    private PromotionClient promotionClient;

    @Mock
    private KAnonymityFilter kAnonymityFilter;

    @InjectMocks
    private AnalyticsService service;

    private Map<String, Object> sampleStats;

    @BeforeEach
    void setUp() {
        sampleStats = new LinkedHashMap<>();
        sampleStats.put("totalUsers", 500L);
        sampleStats.put("suspectCount", 12L);
        sampleStats.put("confirmedCount", 3L);
    }

    // ── getCampusSummary ───────────────────────────────────────────────

    @Test
    void getCampusSummaryShouldDelegateToPromotionClient() {
        when(promotionClient.getHealthStats()).thenReturn(sampleStats);

        Map<String, Object> result = service.getCampusSummary();

        assertThat(result).isEqualTo(sampleStats);
        verify(promotionClient, times(1)).getHealthStats();
    }

    // ── getDepartmentStats ─────────────────────────────────────────────

    @Test
    void getDepartmentStatsShouldApplyKAnonymityFilter() {
        String dept = "Ingenieria";
        Map<String, Object> raw = new LinkedHashMap<>(sampleStats);
        Map<String, Object> filtered = Map.of("totalUsers", 500L, "suspectCount", "<5");

        when(promotionClient.getHealthStatsByDepartment(dept)).thenReturn(raw);
        when(kAnonymityFilter.apply(raw)).thenReturn(filtered);

        Map<String, Object> result = service.getDepartmentStats(dept);

        assertThat(result).isEqualTo(filtered);
        verify(promotionClient).getHealthStatsByDepartment(dept);
        verify(kAnonymityFilter).apply(raw);
    }

    // ── getGlobalHealthStats ───────────────────────────────────────────

    @Test
    void getGlobalHealthStatsShouldDelegateToCampusSummary() {
        when(promotionClient.getHealthStats()).thenReturn(sampleStats);

        Map<String, Object> result = service.getGlobalHealthStats();

        assertThat(result).isEqualTo(sampleStats);
        verify(promotionClient, times(1)).getHealthStats();
    }

    // ── getTimeSeries (fallback mock data) ────────────────────────────

    @Test
    void getTimeSeriesShouldReturnMockDataWhenTableDoesNotExist() {
        when(jdbc.queryForList(anyString(), (Object) any()))
            .thenThrow(new RuntimeException("Table not found"));

        List<Map<String, Object>> result = service.getTimeSeries("hourly", 24);

        // Fallback genera hasta 24 buckets × 4 statuses
        assertThat(result).isNotEmpty();
        assertThat(result.size()).isLessThanOrEqualTo(24 * 4);
    }

    @Test
    void getTimeSeriesShouldLimitResults() {
        when(jdbc.queryForList(anyString(), (Object) any()))
            .thenThrow(new RuntimeException("Table not found"));

        // limit=5 → max 5 × 4 statuses = 20 puntos (pero min(5,24) * 4)
        List<Map<String, Object>> result = service.getTimeSeries("daily", 5);

        assertThat(result.size()).isLessThanOrEqualTo(5 * 4);
    }
}
