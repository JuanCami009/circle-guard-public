# Taller 2: Pruebas y Lanzamiento

## Descripción

Para este ejercicio, se deben configurar los pipelines necesarios para al menos seis microservicios del código disponible en:

```
https://github.com/jcmunozf/circle-guard-public
```

Al escoger los microservicios, se debe considerar que estos se comuniquen entre sí, para permitir la implementación de pruebas que los involucren.

---

## Actividades

### 1. (10%)

Configurar:

* Jenkins
* Docker
* Kubernetes

para su utilización.

---

### 2. (15%)

Para los microservicios escogidos, definir pipelines que permitan la utilización de la aplicación en un entorno de desarrollo (dev environment), incluyendo:

* Construcción
* Pruebas a diferentes niveles
* Deployment

---

### 3. (30%)

Definir pruebas en algunos microservicios:

* Pruebas unitarias
* Pruebas de integración
* Pruebas E2E
* Pruebas de rendimiento

#### Requisitos mínimos:

a. Al menos cinco nuevas pruebas unitarias que validen componentes individuales

b. Al menos cinco nuevas pruebas de integración que validen la comunicación entre servicios

c. Al menos cinco nuevas pruebas E2E que validen flujos completos de usuario

d. Pruebas de rendimiento y estrés utilizando Locust que simulen casos de uso reales del sistema

Todas las pruebas deben:

* Ser relevantes sobre funcionalidades existentes, ajustadas o agregadas
* Incluir análisis de resultados

---

### 4. (15%)

Para los microservicios escogidos, definir pipelines que permitan la construcción incluyendo pruebas de la aplicación desplegada en Kubernetes (stage environment).

---

### 5. (15%)

Ejecutar un pipeline de despliegue que:

* Realice la construcción
* Ejecute pruebas unitarias
* Valide pruebas de sistema
* Despliegue la aplicación en Kubernetes (master environment)

Debe incluir:

* Definición de todas las fases necesarias
* Generación automática de Release Notes siguiendo buenas prácticas de Change Management

---

### 6. (15%)

Documentación adecuada del proceso realizado y un video que evidencie todos los puntos anteriores.

---

## Reporte de Resultados

Se debe entregar:

* Un documento
* Un video corto (máximo 8 minutos)

### El reporte debe incluir:

#### Configuración

* Texto de configuración de los pipelines
* Capturas de pantalla relevantes

#### Resultado

* Capturas de ejecución exitosa de los pipelines
* Detalles y resultados relevantes

#### Análisis

* Interpretación de resultados de las pruebas
* Especial énfasis en pruebas de rendimiento

Métricas clave a incluir:

* Tiempo de respuesta
* Throughput
* Tasa de errores

---

## Entregables Adicionales

* Archivo .zip con:

  * Pipelines
  * Pruebas implementadas
  * Proyecto (si fue modificado)