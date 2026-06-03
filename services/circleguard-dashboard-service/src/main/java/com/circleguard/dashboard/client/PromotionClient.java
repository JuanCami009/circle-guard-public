package com.circleguard.dashboard.client;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@Component
@Slf4j
public class PromotionClient {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${circleguard.promotion-service.url:http://localhost:8088}")
    private String promotionServiceUrl;

    @CircuitBreaker(name = "promotion", fallbackMethod = "fallbackGetHealthStats")
    @SuppressWarnings("unchecked")
    public Map<String, Object> getHealthStats() {
        return restTemplate.getForObject(
                promotionServiceUrl + "/api/v1/health-status/stats",
                Map.class
        );
    }

    @CircuitBreaker(name = "promotion", fallbackMethod = "fallbackGetHealthStatsByDepartment")
    @SuppressWarnings("unchecked")
    public Map<String, Object> getHealthStatsByDepartment(String department) {
        return restTemplate.getForObject(
                promotionServiceUrl + "/api/v1/health-status/stats/department/" + department,
                Map.class
        );
    }

    @SuppressWarnings("unused")
    private Map<String, Object> fallbackGetHealthStats(Exception e) {
        log.error("Circuit open for promotion-service health stats: {}", e.getMessage());
        return Map.of("error", "Service unavailable", "timestamp", new Date());
    }

    @SuppressWarnings("unused")
    private Map<String, Object> fallbackGetHealthStatsByDepartment(String department, Exception e) {
        log.error("Circuit open for promotion-service department stats [{}]: {}", department, e.getMessage());
        return Map.of("error", "Service unavailable", "department", department, "timestamp", new Date());
    }
}
