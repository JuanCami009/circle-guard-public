package com.circleguard.gateway.integration;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.security.Key;
import java.util.Date;
import java.util.UUID;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Prueba de integración: GateController → QrValidationService → Redis.
 * Verifica el flujo completo de validación de QR incluyendo JWT parsing real y consulta de estado en Redis.
 */
@SpringBootTest(properties = {
    "qr.secret=my-qr-secret-key-for-dev-1234567890",
    "qr.expiration=60000",
    "spring.data.redis.host=localhost",
    "spring.data.redis.port=6379"
})
@AutoConfigureMockMvc
@Tag("integration")
class GatewayValidationIntegrationTest {

    private static final String QR_SECRET = "my-qr-secret-key-for-dev-1234567890";

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private StringRedisTemplate redisTemplate;

    @Test
    void shouldAllowAccessForHealthyUser() throws Exception {
        String anonymousId = UUID.randomUUID().toString();
        String token = buildValidQrToken(anonymousId);

        ValueOperations<String, String> valueOps = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        when(valueOps.get("user:status:" + anonymousId)).thenReturn("CLEAR");

        mockMvc.perform(post("/api/v1/gate/validate")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"" + token + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(true))
                .andExpect(jsonPath("$.status").value("GREEN"));
    }

    @Test
    void shouldDenyAccessForContagiousUser() throws Exception {
        String anonymousId = UUID.randomUUID().toString();
        String token = buildValidQrToken(anonymousId);

        ValueOperations<String, String> valueOps = mock(ValueOperations.class);
        when(redisTemplate.opsForValue()).thenReturn(valueOps);
        when(valueOps.get("user:status:" + anonymousId)).thenReturn("CONTAGIED");

        mockMvc.perform(post("/api/v1/gate/validate")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"" + token + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.status").value("RED"));
    }

    @Test
    void shouldRejectExpiredToken() throws Exception {
        String anonymousId = UUID.randomUUID().toString();
        Key key = Keys.hmacShaKeyFor(QR_SECRET.getBytes());
        String expiredToken = Jwts.builder()
                .setSubject(anonymousId)
                .setExpiration(new Date(System.currentTimeMillis() - 1000))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();

        mockMvc.perform(post("/api/v1/gate/validate")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"token\":\"" + expiredToken + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.valid").value(false))
                .andExpect(jsonPath("$.status").value("RED"));
    }

    private String buildValidQrToken(String anonymousId) {
        Key key = Keys.hmacShaKeyFor(QR_SECRET.getBytes());
        return Jwts.builder()
                .setSubject(anonymousId)
                .setExpiration(new Date(System.currentTimeMillis() + 60_000L))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }
}
