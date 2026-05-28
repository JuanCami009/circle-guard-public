package com.circleguard.gateway.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.cache.CacheManager;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.test.context.TestPropertySource;

import java.security.Key;
import java.util.Date;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@SpringBootTest
@TestPropertySource(properties = {
    "qr.secret=qr-secret-test-key-must-be-32bytes-ok",
    "spring.data.redis.host=localhost",
    "spring.data.redis.port=6379"
})
class QrValidationCacheTest {

    private static final String QR_SECRET = "qr-secret-test-key-must-be-32bytes-ok";

    @Autowired
    private QrValidationService validationService;

    @MockBean
    private StringRedisTemplate redisTemplate;

    @Autowired
    private CacheManager cacheManager;

    private String validToken;

    @BeforeEach
    void setUp() {
        cacheManager.getCache("qrTokens").clear();

        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(ops);
        when(ops.get(anyString())).thenReturn(null);

        Key key = Keys.hmacShaKeyFor(QR_SECRET.getBytes());
        validToken = Jwts.builder()
                .setSubject("550e8400-e29b-41d4-a716-446655440000")
                .setExpiration(new Date(System.currentTimeMillis() + 60_000))
                .signWith(key)
                .compact();
    }

    @Test
    void redisIsCalledOnlyOnceForRepeatedValidations() {
        validationService.validateToken(validToken);
        validationService.validateToken(validToken);
        validationService.validateToken(validToken);

        // Redis queried exactly once; subsequent calls served from Caffeine cache
        verify(redisTemplate.opsForValue(), times(1)).get(anyString());
    }

    @Test
    void resultIsGreenForTokenWithNoRiskStatus() {
        QrValidationService.ValidationResult result = validationService.validateToken(validToken);

        assertThat(result.valid()).isTrue();
        assertThat(result.status()).isEqualTo("GREEN");
    }

    @Test
    void redisFailureDefaultsToGreenWithoutException() {
        when(redisTemplate.opsForValue().get(anyString()))
                .thenThrow(new RuntimeException("Redis connection refused"));

        QrValidationService.ValidationResult result = validationService.validateToken(validToken);

        // Service degrades gracefully: gate stays open when Redis is unavailable
        assertThat(result.valid()).isTrue();
        assertThat(result.status()).isEqualTo("GREEN");
    }
}
