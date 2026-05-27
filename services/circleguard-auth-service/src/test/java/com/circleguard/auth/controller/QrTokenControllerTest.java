package com.circleguard.auth.controller;

import com.circleguard.auth.security.DualChainAuthenticationProvider;
import com.circleguard.auth.security.JwtAuthenticationFilter;
import com.circleguard.auth.security.SecurityConfig;
import com.circleguard.auth.service.CustomUserDetailsService;
import com.circleguard.auth.service.QrTokenService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(QrTokenController.class)
@Import(SecurityConfig.class)
public class QrTokenControllerTest {

    private static final String TEST_UUID = "550e8400-e29b-41d4-a716-446655440000";

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private QrTokenService qrService;

    @MockBean
    private CustomUserDetailsService customUserDetailsService;

    @MockBean
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @MockBean
    private DualChainAuthenticationProvider dualChainAuthenticationProvider;

    @Test
    @WithMockUser(username = TEST_UUID)
    void generateToken_Authenticated_ReturnsQrTokenAndExpiresIn() throws Exception {
        UUID anonymousId = UUID.fromString(TEST_UUID);
        String mockToken = "mock-qr-jwt-token";
        Mockito.when(qrService.generateQrToken(anonymousId)).thenReturn(mockToken);

        mockMvc.perform(get("/api/v1/auth/qr/generate"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.qrToken").value(mockToken))
                .andExpect(jsonPath("$.expiresIn").value("60"));
    }

    @Test
    void generateToken_Unauthenticated_Returns4xx() throws Exception {
        mockMvc.perform(get("/api/v1/auth/qr/generate"))
                .andExpect(status().is4xxClientError());
    }
}
