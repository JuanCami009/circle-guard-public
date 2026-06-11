# OWASP ZAP  - Pruebas de Seguridad (punto 5)

Escaneo pasivo automático de los 8 microservicios CircleGuard usando
[OWASP ZAP Baseline](https://www.zaproxy.org/docs/docker/baseline-scan/).

## Qué hace

- Ejecuta `zap-baseline.py` (modo pasivo, sin ataques activos) contra cada servicio.
- Genera un reporte HTML y JSON por servicio en `zap/reports/`.
- Falla el pipeline solo en alertas de nivel **High** (configurable).
- Aplica `zap/rules.tsv` para suprimir falsos positivos de API REST.

## Ejecución local

Requiere Docker y los servicios accesibles.

```bash
# Prod (NodePorts 300xx  - defaults):
bash zap/run_zap.sh

# Stage (NodePorts 320xx):
ZAP_PORT_NOTIFICATION=32082 ZAP_PORT_DASHBOARD=32084 ZAP_PORT_FILE=32085 \
ZAP_PORT_FORM=32086 ZAP_PORT_GATEWAY=32087 ZAP_PORT_PROMOTION=32088 \
ZAP_PORT_IDENTITY=32083 ZAP_PORT_AUTH=32180 bash zap/run_zap.sh

# Cambiar host o nivel de fallo:
ZAP_HOST=localhost ZAP_FAIL_ON=Medium bash zap/run_zap.sh
```

### Variables de entorno

| Variable | Default (prod) | Descripción |
|---|---|---|
| `ZAP_HOST` | `host.docker.internal` | Host donde los NodePorts son accesibles |
| `ZAP_FAIL_ON` | `High` | Nivel mínimo de alerta que aborta: `Low`, `Medium`, `High` |
| `ZAP_TIMEOUT` | `120` | Timeout en segundos por servicio |
| `ZAP_PORT_NOTIFICATION` | `30082` | NodePort de notification-service |
| `ZAP_PORT_IDENTITY` | `30083` | NodePort de identity-service |
| `ZAP_PORT_DASHBOARD` | `30084` | NodePort de dashboard-service |
| `ZAP_PORT_FILE` | `30085` | NodePort de file-service |
| `ZAP_PORT_FORM` | `30086` | NodePort de form-service |
| `ZAP_PORT_GATEWAY` | `30087` | NodePort de gateway-service |
| `ZAP_PORT_PROMOTION` | `30088` | NodePort de promotion-service |
| `ZAP_PORT_AUTH` | `30180` | NodePort de auth-service |

Los reportes se generan en `zap/reports/`:

```
zap/reports/
  zap-auth-service.html
  zap-promotion-service.html
  ...
```

## CI/CD

Stage `Security Tests (OWASP ZAP)` corre en dos pipelines:

| Pipeline | NodePorts | `ZAP_FAIL_ON` | Momento |
|---|---|---|---|
| `Jenkinsfile.stage` | 320xx (namespace `circleguard-stage`) | `High` | Post-deploy a stage, antes de promover a prod |
| `Jenkinsfile.master` | 300xx (namespace `circleguard-prod`) | `High` | Post-deploy a prod |

- Los reportes HTML y JSON se archivan como artefactos Jenkins en ambos pipelines.
- `ZAP_FAIL_ON=High`: bloquea el pipeline solo si hay alertas de severidad High.
- Advertencias menores (Medium/Low) se reportan sin bloquear.

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
| 0 | Sin alertas del nivel configurado | OK |
| 1 | Advertencias menores (por debajo del nivel) | Revisar reporte |
| 2 | Alertas del nivel configurado encontradas | Corregir o agregar a rules.tsv con justificación |
