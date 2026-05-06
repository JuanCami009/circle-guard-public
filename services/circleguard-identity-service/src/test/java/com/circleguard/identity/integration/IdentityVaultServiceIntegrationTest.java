package com.circleguard.identity.integration;

import com.circleguard.identity.model.IdentityMapping;
import com.circleguard.identity.repository.IdentityMappingRepository;
import com.circleguard.identity.service.IdentityVaultService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Prueba de integración: IdentityVaultService → IdentityMappingRepository → IdentityEncryptionConverter.
 * Valida el ciclo completo: identidad real → hash → cifrado → almacenamiento → recuperación.
 * Usa @DataJpaTest con H2 in-memory (mismo patrón que IdentityMappingRepositoryTest existente).
 */
@DataJpaTest
@ActiveProfiles("test")
@Transactional
@Tag("integration")
class IdentityVaultServiceIntegrationTest {

    @Autowired
    private IdentityMappingRepository repository;

    private IdentityVaultService identityVaultService;

    @BeforeEach
    void setUp() {
        identityVaultService = new IdentityVaultService(repository);
        ReflectionTestUtils.setField(identityVaultService, "hashSalt", "12345678");
    }

    @Test
    void shouldCreateAnonymousIdForNewIdentity() {
        UUID anonymousId = identityVaultService.getOrCreateAnonymousId("juan.perez@universidad.edu");

        assertThat(anonymousId).isNotNull();
    }

    @Test
    void shouldReturnSameAnonymousIdForSameIdentity() {
        UUID first  = identityVaultService.getOrCreateAnonymousId("maria.garcia@universidad.edu");
        UUID second = identityVaultService.getOrCreateAnonymousId("maria.garcia@universidad.edu");

        assertThat(first).isEqualTo(second);
    }

    @Test
    void shouldReturnDifferentAnonymousIdsForDifferentIdentities() {
        UUID id1 = identityVaultService.getOrCreateAnonymousId("user.one@universidad.edu");
        UUID id2 = identityVaultService.getOrCreateAnonymousId("user.two@universidad.edu");

        assertThat(id1).isNotEqualTo(id2);
    }

    @Test
    void shouldResolveRealIdentityFromAnonymousId() {
        String realIdentity = "carlos.lopez@universidad.edu";
        UUID anonymousId = identityVaultService.getOrCreateAnonymousId(realIdentity);
        repository.flush();

        String resolved = identityVaultService.resolveRealIdentity(anonymousId);

        assertThat(resolved).isEqualTo(realIdentity);
    }

    @Test
    void shouldThrowNotFoundForUnknownAnonymousId() {
        UUID nonExistentId = UUID.randomUUID();

        assertThrows(ResponseStatusException.class,
            () -> identityVaultService.resolveRealIdentity(nonExistentId));
    }
}
