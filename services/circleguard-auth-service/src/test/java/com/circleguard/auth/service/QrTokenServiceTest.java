package com.circleguard.auth.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.security.Key;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

class QrTokenServiceTest {

    private static final String TEST_QR_SECRET = "qr-secret-test-key-must-be-32bytes-ok";
    private static final long SHORT_EXPIRATION_MS = 1_000L;
    private static final long LONG_EXPIRATION_MS = 60_000L;

    private Key verificationKey;

    @BeforeEach
    void setUp() {
        verificationKey = Keys.hmacShaKeyFor(TEST_QR_SECRET.getBytes());
    }

    @Test
    void shouldGenerateTokenWithAnonymousIdAsSubject() {
        QrTokenService service = new QrTokenService(TEST_QR_SECRET, LONG_EXPIRATION_MS);
        UUID anonymousId = UUID.randomUUID();

        String token = service.generateQrToken(anonymousId);

        Claims claims = Jwts.parserBuilder()
            .setSigningKey(verificationKey)
            .build()
            .parseClaimsJws(token)
            .getBody();

        assertThat(claims.getSubject()).isEqualTo(anonymousId.toString());
    }

    @Test
    void shouldGenerateANonNullNonEmptyToken() {
        QrTokenService service = new QrTokenService(TEST_QR_SECRET, LONG_EXPIRATION_MS);
        UUID anonymousId = UUID.randomUUID();

        String token = service.generateQrToken(anonymousId);

        assertThat(token).isNotNull().isNotEmpty();
    }

    @Test
    void shouldGenerateExpiredTokenWhenExpirationIsVeryShort() throws InterruptedException {
        QrTokenService service = new QrTokenService(TEST_QR_SECRET, SHORT_EXPIRATION_MS);
        UUID anonymousId = UUID.randomUUID();

        String token = service.generateQrToken(anonymousId);
        Thread.sleep(SHORT_EXPIRATION_MS + 100);

        assertThrows(ExpiredJwtException.class, () ->
            Jwts.parserBuilder()
                .setSigningKey(verificationKey)
                .build()
                .parseClaimsJws(token)
        );
    }

    @Test
    void shouldGenerateDifferentTokensForDifferentUsers() {
        QrTokenService service = new QrTokenService(TEST_QR_SECRET, LONG_EXPIRATION_MS);

        String token1 = service.generateQrToken(UUID.randomUUID());
        String token2 = service.generateQrToken(UUID.randomUUID());

        // Tokens signed for different subjects must differ
        assertThat(token1).isNotEqualTo(token2);
    }
}
