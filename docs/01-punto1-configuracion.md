# Punto 1: Configuración de Jenkins, Docker y Kubernetes (10%)

## Resumen

Este documento describe la configuración del entorno de desarrollo para el proyecto CircleGuard, que incluye:

- **Jenkins**: servidor de CI/CD para orquestar pipelines de construcción y despliegue.
- **Docker**: containerización de los 8 microservicios mediante Dockerfiles multi-stage.
- **Kubernetes**: clúster de Docker Desktop para el despliegue de los servicios e infraestructura.

Los 8 microservicios del proyecto son:

| Servicio | Puerto | Dependencias clave |
|---|---|---|
| `circleguard-file-service` | 8085 | Ninguna |
| `circleguard-gateway-service` | 8087 | Redis, JWT |
| `circleguard-dashboard-service` | 8084 | PostgreSQL |
| `circleguard-form-service` | 8086 | PostgreSQL, Kafka |
| `circleguard-notification-service` | 8082 | Kafka, SMTP |
| `circleguard-promotion-service` | 8088 | PostgreSQL, Neo4j, Redis, Kafka |
| `circleguard-auth-service` | 8180 | PostgreSQL, OpenLDAP, JWT |
| `circleguard-identity-service` | 8083 | PostgreSQL |

---

## 1. Configuración de Jenkins

Jenkins se ejecuta como un contenedor Docker standalone fuera del clúster de Kubernetes, lo que le permite construir imágenes Docker usando el daemon del host y desplegar en Kubernetes usando el kubeconfig del host.

### 1.1 Arrancar Jenkins

La imagen oficial `jenkins/jenkins:lts` no incluye los binarios de `docker` ni `kubectl`, por lo que se usa un Dockerfile personalizado (`jenkins/Dockerfile`) que los instala sobre la imagen base.

**Construir la imagen personalizada** (desde la raíz del repositorio):

```bash
docker build -t circleguard/jenkins:latest jenkins/
```

**Levantar el contenedor:**

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add 0 \
  --add-host=kubernetes.docker.internal:host-gateway \
  -v ~/.kube/config:/var/jenkins_home/.kube/config:ro \
  -v ~/.gradle:/var/jenkins_home/.gradle \
  circleguard/jenkins:latest
```

| Volumen / flag | Propósito |
|---|---|
| `jenkins_home` | Persistencia de configuración, jobs y plugins |
| `/var/run/docker.sock` | Acceso al Docker daemon del host para construir imágenes |
| `--group-add 0` | Agrega al usuario `jenkins` el grupo root (GID 0), requerido porque Docker Desktop Mac expone el socket con ese GID dentro del contenedor |
| `--add-host=kubernetes.docker.internal:host-gateway` | Resuelve `kubernetes.docker.internal` a la IP del host desde dentro del contenedor, permitiendo que `kubectl` alcance el API server de Docker Desktop sin modificar el kubeconfig |
| `~/.kube/config` | Kubeconfig estándar del host montado directamente |
| `~/.gradle` | Cache de Gradle del host - evita descargar `gradle-8.14-bin.zip` en cada build |

### 1.2 Configuración inicial

1. Abrir `http://localhost:8080`.
2. Obtener la contraseña inicial: `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
3. Seleccionar **Install suggested plugins**.
4. Crear el usuario administrador y confirmar la URL.

### 1.3 Instalar plugins adicionales

Ir a **Manage Jenkins -> Plugins -> Available plugins** e instalar:

| Plugin | Función |
|---|---|
| `Docker Pipeline` | Permite construir y publicar imágenes Docker desde un Jenkinsfile |
| `Kubernetes CLI` | Proporciona acceso a `kubectl` en los pipelines |

> **Nota:** Git, Pipeline, Pipeline Stage View y sus dependencias se instalan automáticamente al seleccionar "Install suggested plugins".

![Instalación de plugins Docker Pipeline y Kubernetes CLI](../screenshots/install-kubernetes-docker-plugins.png)

---

## 2. Dockerfiles - Containerización de los microservicios

### 2.1 Estrategia multi-stage

Cada microservicio tiene su propio `Dockerfile` en `services/<nombre>/Dockerfile`. Todos siguen la misma estrategia multi-stage:

**Etapa 1 - builder** (`eclipse-temurin:21-jdk-alpine`):
- Copia el monorepo completo (necesario porque Gradle necesita ver todos los subproyectos).
- Ejecuta `./gradlew :services:<nombre>:bootJar -x test --no-daemon` para producir el JAR ejecutable.

**Etapa 2 - runtime** (`eclipse-temurin:21-jre-alpine`):
- Imagen final mínima (~200 MB vs ~600 MB con Debian).
- Copia únicamente el JAR generado.
- Ejecuta como usuario no-root (`appuser`) por seguridad.
- Expone el puerto del servicio.

El **contexto de build siempre es la raíz del repositorio** porque `settings.gradle.kts` y `build.gradle.kts` residen ahí y Gradle debe poder ver todos los módulos del monorepo.

### 2.2 Construir las imágenes

Desde la raíz del repositorio (el punto es importante - indica el contexto de build):

```bash
docker build -t circleguard/file-service:latest \
  -f services/circleguard-file-service/Dockerfile .

docker build -t circleguard/gateway-service:latest \
  -f services/circleguard-gateway-service/Dockerfile .

docker build -t circleguard/dashboard-service:latest \
  -f services/circleguard-dashboard-service/Dockerfile .

docker build -t circleguard/form-service:latest \
  -f services/circleguard-form-service/Dockerfile .

docker build -t circleguard/notification-service:latest \
  -f services/circleguard-notification-service/Dockerfile .

docker build -t circleguard/promotion-service:latest \
  -f services/circleguard-promotion-service/Dockerfile .

docker build -t circleguard/auth-service:latest \
  -f services/circleguard-auth-service/Dockerfile .

docker build -t circleguard/identity-service:latest \
  -f services/circleguard-identity-service/Dockerfile .
```

---

## 3. Kubernetes - Despliegue en el clúster de Docker Desktop

### 3.1 Estructura de los manifests

Los manifests de Kubernetes están organizados en `k8s/`:

```
k8s/
├── 00-namespace.yml              # Namespace "circleguard"
├── infra/
│   ├── 01-configmap.yml          # Variables de entorno no-secretas
│   ├── 02-secrets.yml            # Contraseñas y claves (base64)
│   ├── 03-postgres.yml           # PostgreSQL 16 + init-db.sql
│   ├── 04-neo4j.yml              # Neo4j 5.26 con plugin APOC
│   ├── 05-zookeeper.yml          # Zookeeper (requerido por Kafka)
│   ├── 06-kafka.yml              # Apache Kafka 7.6
│   ├── 07-redis.yml              # Redis 7.2
│   ├── 08-mailhog.yml            # MailHog (SMTP de desarrollo)
│   └── 09-openldap.yml           # OpenLDAP (requerido por auth-service)
└── services/
    ├── 09-file-service.yml
    ├── 10-gateway-service.yml
    ├── 11-dashboard-service.yml
    ├── 12-form-service.yml
    ├── 13-notification-service.yml
    ├── 14-promotion-service.yml
    ├── 15-auth-service.yml
    └── 16-identity-service.yml
```

### 3.2 Aplicar los manifests al clúster

```bash
# Asegurarse de usar el contexto de Docker Desktop
kubectl config use-context docker-desktop

# Crear el namespace primero
kubectl apply -f k8s/00-namespace.yml

# Desplegar la infraestructura (en orden numérico)
kubectl apply -f k8s/infra/

# Esperar a que la infraestructura esté lista antes de desplegar servicios
kubectl wait --for=condition=ready pod -l app=postgres -n circleguard --timeout=120s
kubectl wait --for=condition=ready pod -l app=neo4j -n circleguard --timeout=120s

# Desplegar los 8 microservicios
kubectl apply -f k8s/services/
```

![Pods de Kubernetes en estado Running](../screenshots/kubectl-get-pods.png)

![Services de Kubernetes con NodePorts asignados](../screenshots/kubectl-get-svc.png)
