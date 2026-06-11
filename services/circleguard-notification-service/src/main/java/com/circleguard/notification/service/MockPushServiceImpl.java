package com.circleguard.notification.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import jakarta.annotation.Resource;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

@Service
@Slf4j
@ConditionalOnProperty(name = "features.push.real-delivery", havingValue = "false", matchIfMissing = true)
public class MockPushServiceImpl implements PushService {

    @Resource
    private AuditLogService auditLogService;

    @Override
    @Async
    public CompletableFuture<Void> sendAsync(String userId, String message) {
        return sendAsync(userId, message, Map.of());
    }

    @Override
    @Async
    public CompletableFuture<Void> sendAsync(String userId, String message, Map<String, String> metadata) {
        String correlationId = UUID.randomUUID().toString();
        log.info("[MOCK PUSH] To: {}, Content: {}, Metadata: {}", userId, message, metadata);
        auditLogService.logDelivery(userId, "PUSH", "SUCCESS", correlationId);
        return CompletableFuture.completedFuture(null);
    }
}
