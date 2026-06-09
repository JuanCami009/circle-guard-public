package com.circleguard.file.controller;

import com.circleguard.file.service.FileStorageService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/files")
@CrossOrigin(origins = "*")
@RequiredArgsConstructor
public class FileUploadController {
    private final FileStorageService storageService;
    private final MeterRegistry meterRegistry;

    // ── Métricas de negocio: subidas de archivos por resultado (Punto 7) ────
    private Counter uploadsSuccess;
    private Counter uploadsFailure;

    @PostConstruct
    void initMetrics() {
        uploadsSuccess = Counter.builder("circleguard_file_uploads_total")
                                .description("Total de subidas de archivos en file-service")
                                .tag("result", "success")
                                .register(meterRegistry);
        uploadsFailure = Counter.builder("circleguard_file_uploads_total")
                                .description("Total de subidas de archivos en file-service")
                                .tag("result", "failure")
                                .register(meterRegistry);
    }

    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> upload(@RequestParam("file") MultipartFile file) {
        try {
            String filename = storageService.saveFile(file);
            uploadsSuccess.increment();
            return ResponseEntity.ok(Map.of("filename", filename));
        } catch (Exception e) {
            uploadsFailure.increment();
            throw e;
        }
    }
}
