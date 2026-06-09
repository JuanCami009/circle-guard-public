package com.circleguard.dashboard.controller;

import com.circleguard.dashboard.service.AnalyticsService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/v1/analytics")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class AnalyticsController {
    private final AnalyticsService analyticsService;
    private final MeterRegistry meterRegistry;

    // ── Métricas de negocio: consultas al dashboard por endpoint (Punto 7) ──
    private Counter queriesTrends;
    private Counter queriesHealthBoard;
    private Counter queriesSummary;
    private Counter queriesDepartment;
    private Counter queriesTimeSeries;

    @PostConstruct
    void initMetrics() {
        queriesTrends      = dashboardCounter("trends");
        queriesHealthBoard = dashboardCounter("health-board");
        queriesSummary     = dashboardCounter("summary");
        queriesDepartment  = dashboardCounter("department");
        queriesTimeSeries  = dashboardCounter("time-series");
    }

    private Counter dashboardCounter(String endpoint) {
        return Counter.builder("circleguard_dashboard_queries_total")
                      .description("Total de consultas al dashboard-service")
                      .tag("endpoint", endpoint)
                      .register(meterRegistry);
    }

    @GetMapping("/trends/{locationId}")
    public ResponseEntity<List<Map<String, Object>>> getTrends(@PathVariable UUID locationId) {
        queriesTrends.increment();
        return ResponseEntity.ok(analyticsService.getEntryTrends(locationId));
    }

    @GetMapping("/health-board")
    public ResponseEntity<Map<String, Object>> getHealthBoardStats() {
        queriesHealthBoard.increment();
        return ResponseEntity.ok(analyticsService.getGlobalHealthStats());
    }

    @GetMapping("/summary")
    public ResponseEntity<Map<String, Object>> getSummary() {
        queriesSummary.increment();
        return ResponseEntity.ok(analyticsService.getCampusSummary());
    }

    @GetMapping("/department/{department}")
    public ResponseEntity<Map<String, Object>> getDepartmentStats(@PathVariable String department) {
        queriesDepartment.increment();
        return ResponseEntity.ok(analyticsService.getDepartmentStats(department));
    }

    @GetMapping("/time-series")
    public ResponseEntity<List<Map<String, Object>>> getTimeSeries(
            @RequestParam(defaultValue = "hourly") String period,
            @RequestParam(defaultValue = "24") int limit) {
        queriesTimeSeries.increment();
        return ResponseEntity.ok(analyticsService.getTimeSeries(period, limit));
    }
}
