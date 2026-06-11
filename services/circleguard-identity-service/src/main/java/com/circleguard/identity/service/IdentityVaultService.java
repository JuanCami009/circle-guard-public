package com.circleguard.identity.service;

import com.circleguard.identity.model.IdentityMapping;
import com.circleguard.identity.repository.IdentityMappingRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.keygen.KeyGenerators;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.security.MessageDigest;
import java.util.UUID;
import java.util.HexFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
@RequiredArgsConstructor
public class IdentityVaultService {
    private final IdentityMappingRepository repository;
    private final MeterRegistry meterRegistry;

    @Value("${vault.hash-salt:circleguard-default-salt}")
    private String hashSalt;

    // ── Métricas de negocio: mapeos de identidad nuevos creados (Punto 7) ───
    private Counter identityMappingsCreated;

    @PostConstruct
    void initMetrics() {
        identityMappingsCreated = Counter.builder("circleguard_identity_mappings_total")
                                         .description("Total de nuevos mapeos de identidad creados en identity-service")
                                         .register(meterRegistry);
    }

    /**
     * Maps a real identity to a secure, encrypted anonymous ID.
     */
    @Transactional
    public UUID getOrCreateAnonymousId(String realIdentity) {
        String hash = computeHash(realIdentity);

        return repository.findByIdentityHash(hash)
                .map(IdentityMapping::getAnonymousId)
                .orElseGet(() -> {
                    String salt = KeyGenerators.string().generateKey();
                    IdentityMapping mapping = IdentityMapping.builder()
                            .realIdentity(realIdentity)
                            .identityHash(hash)
                            .salt(salt)
                            .build();
                    UUID newId = repository.save(mapping).getAnonymousId();
                    identityMappingsCreated.increment();
                    return newId;
                });
    }

    private String computeHash(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest((input + hashSalt).getBytes());
            return HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new RuntimeException("Hash computation failed", e);
        }
    }

    public String resolveRealIdentity(UUID anonymousId) {
        return repository.findById(anonymousId)
                .map(IdentityMapping::getRealIdentity)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Identity not found"));
    }
}
