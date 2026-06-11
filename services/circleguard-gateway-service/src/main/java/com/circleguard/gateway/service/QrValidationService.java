package com.circleguard.gateway.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import java.security.Key;

@Service
@RequiredArgsConstructor
@Slf4j
public class QrValidationService {
    private final StringRedisTemplate redisTemplate;

    @Value("${qr.secret}")
    private String qrSecret;

    private static final String STATUS_KEY_PREFIX = "user:status:";

    /**
     * Cache-Aside: valid GREEN results are cached for 30s (see CacheConfig).
     * RED results bypass cache so status changes are reflected immediately.
     */
    @Cacheable(value = "qrTokens", key = "#token", unless = "!#result.valid")
    public ValidationResult validateToken(String token) {
        Claims claims;
        try {
            Key key = Keys.hmacShaKeyFor(qrSecret.getBytes());
            claims = Jwts.parserBuilder()
                    .setSigningKey(key)
                    .build()
                    .parseClaimsJws(token)
                    .getBody();
        } catch (Exception e) {
            return new ValidationResult(false, "RED", "Invalid or Expired Token");
        }

        String anonymousId = claims.getSubject();
        String status = getStatusFromRedis(anonymousId);

        if ("CONTAGIED".equals(status) || "POTENTIAL".equals(status)) {
            return new ValidationResult(false, "RED", "Access Denied: Health Risk Detected");
        }
        return new ValidationResult(true, "GREEN", "Welcome to Campus");
    }

    private String getStatusFromRedis(String anonymousId) {
        try {
            return redisTemplate.opsForValue().get(STATUS_KEY_PREFIX + anonymousId);
        } catch (Exception e) {
            log.warn("Redis unavailable for status check of {}; defaulting to no restriction", anonymousId);
            return null;
        }
    }

    public record ValidationResult(boolean valid, String status, String message) {}
}
