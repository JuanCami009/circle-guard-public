# OWASP ZAP — Pruebas de Seguridad (punto 5)

Escaneo pasivo automático de los 8 microservicios CircleGuard usando
[OWASP ZAP Baseline](https://www.zaproxy.org/docs/docker/baseline-scan/).

## Qué hace

- Ejecuta `zap-baseline.py` (modo pasivo, sin ataques activos) contra cada servicio.
- Genera un reporte HTML y JSON por servicio en `zap/reports/`.
- Falla el pipeline solo en alertas de nivel **High** (configurable).
- Aplica `zap/rules.tsv` para suprimir falsos positivos de API REST.

## Ejecución local

Requiere Docker y los servicios accesibles (prod: NodePorts 300xx en host.docker.internal).

```bash
# Con los NodePorts de prod activos:
bash zap/run_zap.sh

# Cambiar host o nivel de fallo:
ZAP_HOST=localhost ZAP_FAIL_ON=Medium bash zap/run_zap.sh
```

Los reportes se generan en `zap/reports/`:

```
zap/reports/
  zap-auth-service.html
  zap-promotion-service.html
  ...
```

## CI/CD

Stage `Security Tests (OWASP ZAP)` en `Jenkinsfile.master`:
- Se ejecuta **después del despliegue** a prod (post-deploy).
- Los reportes HTML se archivan como artefactos Jenkins.
- `ZAP_FAIL_ON=High` por defecto; advertencias menores no bloquean.

## Ajustar reglas

`zap/rules.tsv` contiene exclusiones justificadas para falsos positivos de API REST
(CSP, cookie flags, CORS abierto para app móvil). Para agregar exclusiones:

```
<ruleId>    IGNORE    <justificación>
```

IDs de reglas: https://www.zaproxy.org/docs/alerts/

## Interpretación de resultados

| Exit code ZAP | Significado | Acción |
|---|---|---|
| 0 | Sin alertas del nivel configurado | ✅ OK |
| 1 | Advertencias menores (por debajo del nivel) | ⚠️ Revisar reporte |
| 2 | Alertas del nivel configurado encontradas | ❌ Corregir o agregar a rules.tsv con justificación |
