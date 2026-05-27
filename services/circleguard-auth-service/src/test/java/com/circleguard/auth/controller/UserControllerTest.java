package com.circleguard.auth.controller;

import com.circleguard.auth.model.LocalUser;
import com.circleguard.auth.repository.LocalUserRepository;
import com.circleguard.auth.service.CustomUserDetailsService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Collections;
import java.util.List;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(UserController.class)
public class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private LocalUserRepository localUserRepository;

    @MockBean
    private CustomUserDetailsService customUserDetailsService;

    @Test
    @WithMockUser
    void getUsersByPermission_NoMatchingUsers_ReturnsEmptyList() throws Exception {
        Mockito.when(localUserRepository.findUsersByPermissionName("NOTIFY_ALERTS"))
                .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/v1/users/permissions/NOTIFY_ALERTS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$").isEmpty());
    }

    @Test
    @WithMockUser
    void getUsersByPermission_UsersExist_ReturnsUsernameAndEmail() throws Exception {
        LocalUser user = LocalUser.builder()
                .id(UUID.randomUUID())
                .username("admin.user")
                .password("hashed")
                .email("admin@circleguard.edu")
                .isActive(true)
                .build();

        Mockito.when(localUserRepository.findUsersByPermissionName("ADMIN_ACCESS"))
                .thenReturn(List.of(user));

        mockMvc.perform(get("/api/v1/users/permissions/ADMIN_ACCESS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].username").value("admin.user"))
                .andExpect(jsonPath("$[0].email").value("admin@circleguard.edu"));
    }

    @Test
    @WithMockUser
    void getUsersByPermission_UserWithNullEmail_ReturnsEmptyStringForEmail() throws Exception {
        LocalUser user = LocalUser.builder()
                .id(UUID.randomUUID())
                .username("no.email.user")
                .password("hashed")
                .email(null)
                .isActive(true)
                .build();

        Mockito.when(localUserRepository.findUsersByPermissionName("SOME_PERM"))
                .thenReturn(List.of(user));

        mockMvc.perform(get("/api/v1/users/permissions/SOME_PERM"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].username").value("no.email.user"))
                .andExpect(jsonPath("$[0].email").value(""));
    }
}
