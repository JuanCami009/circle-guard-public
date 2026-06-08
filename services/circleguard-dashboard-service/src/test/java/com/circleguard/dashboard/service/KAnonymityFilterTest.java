package com.circleguard.dashboard.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pruebas unitarias del motor de privacidad k-anonimidad (Story 7.5, FR-23).
 * Verifica que ningún grupo de tamaño < K exponga datos individuales.
 */
class KAnonymityFilterTest {

    private KAnonymityFilter filter;

    @BeforeEach
    void setUp() {
        filter = new KAnonymityFilter();
    }

    // ── apply(null) ────────────────────────────────────────────────────

    @Test
    void shouldReturnEmptyMapWhenStatsIsNull() {
        Map<String, Object> result = filter.apply(null);
        assertThat(result).isEmpty();
    }

    // ── totalUsers por debajo de K ─────────────────────────────────────

    @Test
    void shouldMaskEntireResultWhenTotalUsersBelowDefaultK() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 3L);
        stats.put("suspectCount", 1L);
        stats.put("department", "Engineering");

        Map<String, Object> result = filter.apply(stats);

        assertThat(result).containsKey("note");
        assertThat(result.get("note")).isEqualTo("Insufficient data for privacy");
        assertThat(result.get("totalUsers")).isEqualTo("<5");
        // department debe preservarse para identificar el grupo
        assertThat(result.get("department")).isEqualTo("Engineering");
        // datos individuales no deben aparecer
        assertThat(result).doesNotContainKey("suspectCount");
    }

    @Test
    void shouldMaskEntireResultWhenTotalUsersBelowCustomK() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 8L);
        stats.put("confirmedCount", 2L);

        Map<String, Object> result = filter.apply(stats, 10);

        assertThat(result.get("totalUsers")).isEqualTo("<10");
        assertThat(result).containsKey("note");
    }

    // ── totalUsers >= K pero conteos individuales por debajo de K ──────

    @Test
    void shouldMaskIndividualCountsBelowKWhenTotalSufficient() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 100L);
        stats.put("suspectCount", 2L);    // < 5 → debe enmascararse
        stats.put("confirmedCount", 10L); // >= 5 → debe mostrarse

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("suspectCount")).isEqualTo("<5");
        assertThat(result.get("confirmedCount")).isEqualTo(10L);
        assertThat(result.get("totalUsers")).isEqualTo(100L); // total no se enmascara
    }

    @Test
    void shouldNotMaskCountsAtExactlyK() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 50L);
        stats.put("probableCount", 5L); // exactamente K, no debe enmascararse

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("probableCount")).isEqualTo(5L);
    }

    @Test
    void shouldNotMaskZeroCounts() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 50L);
        stats.put("confirmedCount", 0L); // cero no implica riesgo de re-identificación

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("confirmedCount")).isEqualTo(0L);
    }

    // ── Campos que no terminan en "Count" no se tocan ─────────────────

    @Test
    void shouldNotMaskNonCountFields() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 50L);
        stats.put("riskScore", 3L);    // < K pero no termina en "Count"
        stats.put("department", "CS");

        Map<String, Object> result = filter.apply(stats);

        // riskScore no debe enmascararse — solo campos "...Count"
        assertThat(result.get("riskScore")).isEqualTo(3L);
        assertThat(result.get("department")).isEqualTo("CS");
    }

    // ── Mapa vacío ─────────────────────────────────────────────────────

    @Test
    void shouldReturnEmptyMapWhenStatsIsEmpty() {
        Map<String, Object> result = filter.apply(Map.of());
        assertThat(result).isEmpty();
    }

    // ── Timestamp se preserva en enmascaramiento total ─────────────────

    @Test
    void shouldPreserveTimestampWhenMaskingEntireResult() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 2L);
        stats.put("timestamp", "2025-01-01T00:00:00Z");
        stats.put("suspectCount", 1L);

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("timestamp")).isEqualTo("2025-01-01T00:00:00Z");
    }
}
