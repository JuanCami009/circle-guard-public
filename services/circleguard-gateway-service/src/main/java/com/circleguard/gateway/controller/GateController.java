package com.circleguard.gateway.controller;

import com.circleguard.gateway.service.QrValidationService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/gate")
@RequiredArgsConstructor
public class GateController {
    private final QrValidationService validationService;
    private final MeterRegistry meterRegistry;

    // ── Métricas de negocio: validaciones de acceso por resultado (Punto 7) ─
    private Counter gateGranted;
    private Counter gateDenied;

    @PostConstruct
    void initMetrics() {
        gateGranted = Counter.builder("circleguard_gate_validations_total")
                             .description("Total de validaciones de acceso en gateway-service")
                             .tag("result", "granted")
                             .register(meterRegistry);
        gateDenied  = Counter.builder("circleguard_gate_validations_total")
                             .description("Total de validaciones de acceso en gateway-service")
                             .tag("result", "denied")
                             .register(meterRegistry);
    }

    @PostMapping("/validate")
    public ResponseEntity<QrValidationService.ValidationResult> validate(@RequestBody Map<String, String> request) {
        String token = request.get("token");
        QrValidationService.ValidationResult result = validationService.validateToken(token);
        if (result.valid()) {
            gateGranted.increment();
        } else {
            gateDenied.increment();
        }
        return ResponseEntity.ok(result);
    }
}
