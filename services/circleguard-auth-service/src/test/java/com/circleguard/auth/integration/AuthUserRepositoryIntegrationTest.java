package com.circleguard.auth.integration;

import com.circleguard.auth.model.LocalUser;
import com.circleguard.auth.model.Permission;
import com.circleguard.auth.model.Role;
import com.circleguard.auth.repository.LocalUserRepository;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.test.autoconfigure.orm.jpa.TestEntityManager;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Integration tests for LocalUserRepository.
 * Validates JPA mappings (User → Role → Permission) and custom JPQL query
 * findUsersByPermissionName against H2 in-memory database.
 */
@DataJpaTest
@ActiveProfiles("test")
@Tag("integration")
class AuthUserRepositoryIntegrationTest {

    @Autowired
    private TestEntityManager entityManager;

    @Autowired
    private LocalUserRepository userRepository;

    @Test
    void findUsersByPermissionName_UserHasPermission_ReturnsUser() {
        Permission perm = entityManager.persist(Permission.builder()
                .name("NOTIFY_PRIORITY_ALERTS")
                .description("Send priority alerts")
                .build());

        Role role = entityManager.persist(Role.builder()
                .name("HEALTH_OFFICER")
                .description("Health department officer")
                .permissions(Set.of(perm))
                .build());

        LocalUser user = entityManager.persist(LocalUser.builder()
                .username("officer.rodriguez")
                .password("$2a$10$hashedpassword")
                .email("officer@circleguard.edu")
                .isActive(true)
                .roles(Set.of(role))
                .build());

        entityManager.flush();

        List<LocalUser> result = userRepository.findUsersByPermissionName("NOTIFY_PRIORITY_ALERTS");

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getUsername()).isEqualTo("officer.rodriguez");
    }

    @Test
    void findUsersByPermissionName_NoUserHasPermission_ReturnsEmptyList() {
        entityManager.flush();

        List<LocalUser> result = userRepository.findUsersByPermissionName("NON_EXISTENT_PERMISSION");

        assertThat(result).isEmpty();
    }

    @Test
    void findUsersByPermissionName_OnlyUsersWithPermissionReturned() {
        Permission permA = entityManager.persist(Permission.builder()
                .name("PERM_A").build());
        Permission permB = entityManager.persist(Permission.builder()
                .name("PERM_B").build());

        Role roleA = entityManager.persist(Role.builder()
                .name("ROLE_A").permissions(Set.of(permA)).build());
        Role roleB = entityManager.persist(Role.builder()
                .name("ROLE_B").permissions(Set.of(permB)).build());

        entityManager.persist(LocalUser.builder()
                .username("user.a").password("hash").isActive(true).roles(Set.of(roleA)).build());
        entityManager.persist(LocalUser.builder()
                .username("user.b").password("hash").isActive(true).roles(Set.of(roleB)).build());

        entityManager.flush();

        List<LocalUser> result = userRepository.findUsersByPermissionName("PERM_A");

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getUsername()).isEqualTo("user.a");
    }

    @Test
    void findByUsername_ExistingUser_ReturnsUser() {
        entityManager.persist(LocalUser.builder()
                .username("john.doe")
                .password("$2a$10$hashedpassword")
                .email("john@circleguard.edu")
                .isActive(true)
                .build());
        entityManager.flush();

        Optional<LocalUser> result = userRepository.findByUsername("john.doe");

        assertThat(result).isPresent();
        assertThat(result.get().getEmail()).isEqualTo("john@circleguard.edu");
    }

    @Test
    void findByUsername_NonExistentUser_ReturnsEmpty() {
        Optional<LocalUser> result = userRepository.findByUsername("ghost.user");

        assertThat(result).isEmpty();
    }
}
