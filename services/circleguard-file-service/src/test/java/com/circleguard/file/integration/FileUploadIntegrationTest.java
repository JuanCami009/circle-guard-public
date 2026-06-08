package com.circleguard.file.integration;

import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Prueba de integración: FileUploadController → FileStorageService → filesystem.
 * Levanta el contexto completo de Spring Boot y verifica el flujo HTTP real de upload.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Tag("integration")
class FileUploadIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void uploadEndpointShouldReturn200WithFilenameForValidPdf() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
            "file", "health-cert.pdf", "application/pdf", "pdf-bytes".getBytes());

        mockMvc.perform(multipart("/api/v1/files/upload").file(file))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.filename").isNotEmpty())
            .andExpect(jsonPath("$.filename").value(org.hamcrest.Matchers.endsWith("_health-cert.pdf")));
    }

    @Test
    void uploadEndpointShouldAcceptImageFiles() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
            "file", "foto.png", "image/png", "img-bytes".getBytes());

        mockMvc.perform(multipart("/api/v1/files/upload").file(file))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.filename").isNotEmpty());
    }

    @Test
    void uploadEndpointShouldReturn400WhenNoFileProvided() throws Exception {
        // Sin el parámetro "file", Spring MVC debe retornar 400
        mockMvc.perform(multipart("/api/v1/files/upload"))
            .andExpect(status().is4xxClientError());
    }
}
