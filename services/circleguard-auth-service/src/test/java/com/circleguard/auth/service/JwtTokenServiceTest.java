package com.circleguard.auth.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;

import java.security.Key;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class JwtTokenServiceTest {

    private static final String TEST_SECRET = "my-super-secret-test-key-32-chars-long";
    private static final long EXPIRATION_MS = 3_600_000L;

    private JwtTokenService jwtTokenService;
    private Key verificationKey;

    @BeforeEach
    void setUp() {
        jwtTokenService = new JwtTokenService(TEST_SECRET, EXPIRATION_MS);
        verificationKey = Keys.hmacShaKeyFor(TEST_SECRET.getBytes());
    }

    @Test
    void shouldGenerateTokenWithAnonymousIdAsSubject() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = mock(Authentication.class);
        when(auth.getAuthorities()).thenAnswer(inv -> Collections.emptyList());

        String token = jwtTokenService.generateToken(anonymousId, auth);

        Claims claims = Jwts.parserBuilder()
            .setSigningKey(verificationKey)
            .build()
            .parseClaimsJws(token)
            .getBody();

        assertThat(claims.getSubject()).isEqualTo(anonymousId.toString());
    }

    @Test
    void shouldIncludePermissionsInToken() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = mock(Authentication.class);
        GrantedAuthority authority = () -> "ROLE_STUDENT";
        when(auth.getAuthorities()).thenAnswer(inv -> List.of(authority));

        String token = jwtTokenService.generateToken(anonymousId, auth);

        Claims claims = Jwts.parserBuilder()
            .setSigningKey(verificationKey)
            .build()
            .parseClaimsJws(token)
            .getBody();

        @SuppressWarnings("unchecked")
        List<String> permissions = (List<String>) claims.get("permissions");
        assertThat(permissions).containsExactly("ROLE_STUDENT");
    }

    @Test
    void shouldSetExpirationApproximatelyOneHourFromNow() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = mock(Authentication.class);
        when(auth.getAuthorities()).thenAnswer(inv -> Collections.emptyList());

        long before = System.currentTimeMillis();
        String token = jwtTokenService.generateToken(anonymousId, auth);
        long after = System.currentTimeMillis();

        Claims claims = Jwts.parserBuilder()
            .setSigningKey(verificationKey)
            .build()
            .parseClaimsJws(token)
            .getBody();

        long expMs = claims.getExpiration().getTime();
        // JWT stores exp in seconds; allow ±1000 ms tolerance for the second-precision truncation
        assertThat(expMs).isBetween(before + EXPIRATION_MS - 1000, after + EXPIRATION_MS + 1000);
    }
}
