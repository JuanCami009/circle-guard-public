package com.circleguard.promotion.task;

import com.circleguard.promotion.repository.graph.UserNodeRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GraphCleanupTaskTest {

    private static final long FOURTEEN_DAYS_MS = 14L * 24 * 60 * 60 * 1000;

    @Mock
    private UserNodeRepository userNodeRepository;

    @InjectMocks
    private GraphCleanupTask graphCleanupTask;

    @Test
    void shouldPurgeEncountersOlderThan14Days() {
        when(userNodeRepository.purgeStaleEncounters(anyLong())).thenReturn(5L);
        long before = System.currentTimeMillis();

        graphCleanupTask.purgeStaleEncounters();

        long after = System.currentTimeMillis();
        ArgumentCaptor<Long> thresholdCaptor = ArgumentCaptor.forClass(Long.class);
        verify(userNodeRepository).purgeStaleEncounters(thresholdCaptor.capture());

        long capturedThreshold = thresholdCaptor.getValue();
        long expectedThresholdMin = before - FOURTEEN_DAYS_MS;
        long expectedThresholdMax = after - FOURTEEN_DAYS_MS;

        assertThat(capturedThreshold)
            .isGreaterThanOrEqualTo(expectedThresholdMin)
            .isLessThanOrEqualTo(expectedThresholdMax);
    }

    @Test
    void shouldNotThrowWhenRepositoryReturnsNull() {
        when(userNodeRepository.purgeStaleEncounters(anyLong())).thenReturn(null);

        assertDoesNotThrow(() -> graphCleanupTask.purgeStaleEncounters());

        verify(userNodeRepository).purgeStaleEncounters(anyLong());
    }

    @Test
    void shouldHandleRepositoryExceptionGracefully() {
        when(userNodeRepository.purgeStaleEncounters(anyLong()))
            .thenThrow(new RuntimeException("Neo4j connection lost"));

        assertDoesNotThrow(() -> graphCleanupTask.purgeStaleEncounters(),
            "purgeStaleEncounters should catch exceptions to avoid breaking the scheduler");
    }
}
