package com.circleguard.file.service;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.*;

/**
 * Pruebas unitarias de FileStorageService.
 * Usa un directorio temporal (@TempDir) para evitar efectos sobre el sistema de archivos real.
 */
class FileStorageServiceTest {

    @TempDir
    Path tempDir;

    private FileStorageService service;

    @BeforeEach
    void setUp() throws Exception {
        service = new FileStorageService();
        // Redirigir el campo 'root' al directorio temporal
        ReflectionTestUtils.setField(service, "root", tempDir);
    }

    // ── saveFile ───────────────────────────────────────────────────────

    @Test
    void saveFileShouldReturnGeneratedFilename() throws IOException {
        MockMultipartFile file = new MockMultipartFile(
            "file", "report.pdf", "application/pdf", "pdf-content".getBytes());

        String filename = service.saveFile(file);

        assertThat(filename).isNotBlank();
        assertThat(filename).endsWith("_report.pdf");
    }

    @Test
    void saveFileShouldPersistFileToStorage() throws IOException {
        MockMultipartFile file = new MockMultipartFile(
            "file", "cert.pdf", "application/pdf", "cert-data".getBytes());

        String filename = service.saveFile(file);

        Path savedPath = tempDir.resolve(filename);
        assertThat(Files.exists(savedPath)).isTrue();
        assertThat(Files.readAllBytes(savedPath)).isEqualTo("cert-data".getBytes());
    }

    @Test
    void saveFileShouldGenerateUniqueFilenamesForSameName() throws IOException {
        MockMultipartFile file1 = new MockMultipartFile(
            "file", "document.pdf", "application/pdf", "content1".getBytes());
        MockMultipartFile file2 = new MockMultipartFile(
            "file", "document.pdf", "application/pdf", "content2".getBytes());

        String name1 = service.saveFile(file1);
        String name2 = service.saveFile(file2);

        assertThat(name1).isNotEqualTo(name2);
    }

    @Test
    void saveFileShouldHandleFileWithNoOriginalName() {
        MockMultipartFile file = new MockMultipartFile(
            "file", (String) null, "application/octet-stream", "data".getBytes());

        // No debe lanzar NullPointerException
        assertThatCode(() -> service.saveFile(file)).doesNotThrowAnyException();
    }
}
