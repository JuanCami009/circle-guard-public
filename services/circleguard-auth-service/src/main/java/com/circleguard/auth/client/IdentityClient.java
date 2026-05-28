package com.circleguard.auth.client;

import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.util.*;

@Component
@Slf4j
public class IdentityClient {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${identity.service.url:http://localhost:8083}")
    private String identityServiceUrl;

    @CircuitBreaker(name = "identity", fallbackMethod = "fallbackGetAnonymousId")
    @Retry(name = "identity")
    public UUID getAnonymousId(String realIdentity) {
        String url = identityServiceUrl + "/api/v1/identities/map";
        Map<String, String> request = Map.of("realIdentity", realIdentity);
        @SuppressWarnings("unchecked")
        Map<String, Object> response = restTemplate.postForObject(url, request, Map.class);
        return UUID.fromString(response.get("anonymousId").toString());
    }

    @SuppressWarnings("unused")
    private UUID fallbackGetAnonymousId(String realIdentity, Exception e) {
        log.warn("Identity service unavailable for '{}' (circuit open or retries exhausted): {}", realIdentity, e.getMessage());
        throw new RuntimeException("Identity service temporarily unavailable", e);
    }
}
