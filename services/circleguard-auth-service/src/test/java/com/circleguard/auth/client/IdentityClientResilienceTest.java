package com.circleguard.auth.client;

import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.RetryConfig;
import io.github.resilience4j.retry.RetryRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Supplier;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

// Programmatic Resilience4j unit test — no Spring context required.
// Verifies circuit breaker state transitions without needing LDAP/DB/Flyway setup.
class IdentityClientResilienceTest {

    private CircuitBreakerRegistry cbRegistry;

    @BeforeEach
    void setUp() {
        CircuitBreakerConfig config = CircuitBreakerConfig.custom()
                .slidingWindowSize(5)
                .failureRateThreshold(60f)
                .waitDurationInOpenState(Duration.ofSeconds(5))
                .permittedNumberOfCallsInHalfOpenState(3)
                .build();
        cbRegistry = CircuitBreakerRegistry.of(config);
    }

    @Test
    void circuitBreakerStartsInClosedState() {
        CircuitBreaker cb = cbRegistry.circuitBreaker("identity");
        assertThat(cb.getState()).isEqualTo(CircuitBreaker.State.CLOSED);
    }

    @Test
    void circuitBreakerOpensAfterFailureThresholdExceeded() {
        CircuitBreaker cb = cbRegistry.circuitBreaker("identity");
        Supplier<UUID> alwaysFails = CircuitBreaker.decorateSupplier(cb,
                () -> { throw new RuntimeException("connection refused"); });

        // 5 calls × 100% failure rate > 60% threshold → OPEN
        for (int i = 0; i < 5; i++) {
            try { alwaysFails.get(); } catch (Exception ignored) {}
        }

        assertThat(cb.getState()).isEqualTo(CircuitBreaker.State.OPEN);
    }

    @Test
    void openCircuitRejectsCallsWithoutCallingBackend() {
        CircuitBreaker cb = cbRegistry.circuitBreaker("identity");
        cb.transitionToOpenState();

        AtomicBoolean backendWasCalled = new AtomicBoolean(false);
        Supplier<UUID> supplier = CircuitBreaker.decorateSupplier(cb, () -> {
            backendWasCalled.set(true);
            return UUID.randomUUID();
        });

        assertThatThrownBy(supplier::get).isInstanceOf(CallNotPermittedException.class);
        assertThat(backendWasCalled.get()).isFalse();
    }

    @Test
    void retryDecoratorRetriesOnFailureBeforeGivingUp() {
        RetryConfig retryConfig = RetryConfig.custom()
                .maxAttempts(3)
                .waitDuration(Duration.ofMillis(10))
                .build();
        RetryRegistry retryRegistry = RetryRegistry.of(retryConfig);

        var retry = retryRegistry.retry("identity");
        int[] callCount = {0};

        Supplier<UUID> supplier = io.github.resilience4j.retry.Retry.decorateSupplier(retry, () -> {
            callCount[0]++;
            throw new RuntimeException("transient failure");
        });

        try { supplier.get(); } catch (Exception ignored) {}

        // maxAttempts=3 means 1 initial + 2 retries = 3 total calls
        assertThat(callCount[0]).isEqualTo(3);
    }
}
