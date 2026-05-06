package com.circleguard.promotion.service;

import com.circleguard.promotion.model.AccessPoint;
import com.circleguard.promotion.model.Building;
import com.circleguard.promotion.model.Floor;
import com.circleguard.promotion.repository.jpa.AccessPointRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.kafka.core.KafkaTemplate;

import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LocationResolutionServiceTest {

    @Mock
    private AccessPointRepository accessPointRepository;

    @Mock
    private MacSessionRegistry sessionRegistry;

    @Mock
    private GraphService graphService;

    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Mock
    private StringRedisTemplate redisTemplate;

    @InjectMocks
    private LocationResolutionService locationResolutionService;

    @Test
    void shouldEmitProximityEventForKnownDeviceAtKnownAp() {
        Building building = Building.builder().id(UUID.randomUUID()).name("Edificio A").code("A").build();
        Floor floor = Floor.builder().id(UUID.randomUUID()).building(building).floorNumber(1).build();
        AccessPoint ap = AccessPoint.builder()
            .id(UUID.randomUUID()).macAddress("aa:bb:cc:dd:ee:ff")
            .floor(floor).coordinateX(10.0).coordinateY(20.0).name("AP-1").build();

        when(accessPointRepository.findByMacAddress("aa:bb:cc:dd:ee:ff")).thenReturn(Optional.of(ap));
        when(sessionRegistry.getAnonymousId("11:22:33:44:55:66")).thenReturn("anon-user-001");

        @SuppressWarnings("unchecked")
        SetOperations<String, String> setOps = mock(SetOperations.class);
        when(redisTemplate.opsForSet()).thenReturn(setOps);
        when(setOps.members(anyString())).thenReturn(Set.of());

        locationResolutionService.processSignal("aa:bb:cc:dd:ee:ff", "11:22:33:44:55:66", -65.0);

        verify(kafkaTemplate).send(eq("proximity.detected"), eq("anon-user-001"), any());
    }

    @Test
    void shouldIgnoreSignalFromUnknownAccessPoint() {
        when(accessPointRepository.findByMacAddress("ff:ee:dd:cc:bb:aa")).thenReturn(Optional.empty());

        locationResolutionService.processSignal("ff:ee:dd:cc:bb:aa", "11:22:33:44:55:66", -70.0);

        verifyNoInteractions(kafkaTemplate);
        verifyNoInteractions(sessionRegistry);
    }

    @Test
    void shouldIgnoreSignalFromUnmappedDevice() {
        Building building = Building.builder().id(UUID.randomUUID()).name("Edificio B").code("B").build();
        Floor floor = Floor.builder().id(UUID.randomUUID()).building(building).floorNumber(2).build();
        AccessPoint ap = AccessPoint.builder()
            .id(UUID.randomUUID()).macAddress("aa:bb:cc:dd:ee:ff")
            .floor(floor).coordinateX(5.0).coordinateY(5.0).name("AP-2").build();

        when(accessPointRepository.findByMacAddress("aa:bb:cc:dd:ee:ff")).thenReturn(Optional.of(ap));
        when(sessionRegistry.getAnonymousId("00:11:22:33:44:55")).thenReturn(null);

        locationResolutionService.processSignal("aa:bb:cc:dd:ee:ff", "00:11:22:33:44:55", -80.0);

        verifyNoInteractions(kafkaTemplate);
        verifyNoInteractions(graphService);
    }
}
