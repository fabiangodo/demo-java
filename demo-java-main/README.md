# Demo Spring Boot - AWS EC2 & GitHub Actions Deployment

Proyecto de demostración de una API REST desarrollada en **Spring Boot (Java)** con un pipeline de integración y despliegue continuo (CI/CD) automatizado hacia una instancia **Amazon EC2** utilizando **GitHub Actions**.

---

## 🛠️ Tecnologías y Stack

- **Java 21** (Amazon Corretto)
- **Spring Boot** (Gradle como gestor de dependencias y construcción)
- **AWS EC2** (Instancia `t3.micro` con Amazon Linux)
- **GitHub Actions** (CI/CD nativo mediante OpenSSH y SCP)

---

## 🚀 Endpoints de la API

- **Base URL:** `http://<IP_PUBLICA>:8080`
- **Endpoint de prueba:** `GET /api/hello`
  - **Respuesta esperada:**
    ```json
    { "message": "Hello, World!" }
    ```

---

## ⚙️ Arquitectura del Despliegue Automatizado (CI/CD)

Cada vez que se realiza un `push` a la rama principal (`main` / `master`), el workflow de GitHub Actions (`.github/workflows/deploy.yml`) ejecuta los siguientes pasos de forma completamente autónoma:

1. **Compilación:** Utiliza el runner de GitHub para compilar el proyecto y empaquetarlo en un archivo `.jar` ejecutable mediante Gradle (`./gradlew bootJar -x test`).
2. **Transferencia:** Copia de forma segura el archivo `.jar` generado directamente a la instancia EC2 utilizando `scp` nativo.
3. **Provisionamiento y Aprovisionamiento Remoto (SSH):**
   - **Idempotencia de Java:** Comprueba e instala automáticamente el runtime `java-21-amazon-corretto` en la instancia si no se encuentra presente.
   - **Limpieza de procesos:** Detiene cualquier instancia previa de la aplicación escuchando en el puerto `8080` (`fuser -k 8080/tcp`) o procesos `java` residuales (`pkill -x java`).
   - **Ejecución en segundo plano:** Inicia la aplicación con `setsid` para asegurar que el proceso corra de manera independiente y persista tras finalizar la sesión SSH del pipeline.
4. **Concurrencia Controlada:** Configurado con `cancel-in-progress: true` para evitar conflictos si se realizan múltiples commits seguidos.

---

## 🔧 Configuración Requerida en AWS EC2

Para que la conexión y el despliegue funcionen correctamente, se configuraron los siguientes parámetros en la infraestructura de AWS:

- **Par de Claves (Key Pair):** Tipo RSA con formato `.pem`.
- **Grupo de Seguridad (Security Group):**
  - **Puerto 22 (SSH):** Acceso para administración y despliegue.
  - **Puerto 80 (HTTP) y 443 (HTTPS):** Tráfico web general.
  - **Puerto 8080 (TCP Personalizado):** Abierto a `0.0.0.0/0` para la recepción de peticiones de la API de Spring Boot.

---

## 🔐 Configuração de Secrets en GitHub

Para permitir el acceso seguro desde GitHub Actions hacia tu servidor AWS, configura los siguientes Secrets en tu repositorio (`Settings` > `Secrets and variables` > `Actions`):

- `EC2_HOST`: Dirección IP pública (IPv4) de tu instancia EC2.
- `EC2_SSH_KEY`: Contenido completo de tu archivo de clave privada `.pem`.

---

## 🔍 Notas de Troubleshooting y Lecciones Aprendidas

- **Gestión de procesos Java (`pkill`):** Se evita el uso de flags genéricas como `pkill -f "java -jar"` ya que afectan al propio comando del intérprete del shell en ejecución. Se utiliza estrictamente `pkill -x java` para apuntar únicamente al nombre exacto del proceso.
- **Permisos de la Clave Privada:** Si realizas conexiones manuales por SSH y obtienes un error de `Permission denied (publickey)`, asegúrate de restringir los permisos locales del archivo de llave con:
  ```bash
  chmod 600 tu-llave.pem
  ```

# Bitácora Completa de Implementación y Despliegue

## API Spring Boot 3 + Microsoft Entra ID (OAuth2 M2M) + AWS EC2 + GitHub Actions

---

### 📋 1. Resumen de Arquitectura y Stack

- **Backend**: Java 21, Spring Boot 3.3.4, Gradle.
- **Seguridad / OAuth2**: Microsoft Entra ID (Resource Server mediante `spring-boot-starter-oauth2-resource-server`).
- **Tipo de Autenticación**: Flujo de aplicación a aplicación Machine-to-Machine (M2M) con `grant_type=client_credentials`.
- **Autorización**: Roles de Aplicación (`roles` claim) con evaluación granular mediante `@PreAuthorize("hasRole('OT.Read')")`.
- **Infraestructura**: Instancia AWS EC2 (Amazon Linux 2023).
- **CI/CD**: GitHub Actions (Build con Gradle, despliegue por SCP y reinicio de servicio por SSH).

---

### ⚙️ 2. Configuración en Microsoft Entra ID (Azure Portal)

#### 2.1. Identificador de la Aplicación

- **App ID URI**: Configurado en **Exponer una API** (_Expose an API_) como `api://<CLIENT_ID>`.

#### 2.2. Creación del Rol de Aplicación (App Role)

> **Concepto Clave**: En el flujo `client_credentials`, Entra ID **no emite scopes delegados (`scp`)**, sino **App Roles (`roles`)**.

1. En **Roles de aplicación** (_App roles_) > **Crear rol de aplicación**:

- **Nombre de pantalla**: `OT.Read`
- **Tipos de miembros permitidos**: **Aplicaciones** (_Applications_) —_imprescindible para llamadas M2M_—.
- **Valor**: `OT.Read`
- **Descripción**: Permiso de lectura para órdenes de trabajo.

#### 2.3. Asignación de Permisos y Concesión de Consentimiento

1. En **Permisos de la API** (_API permissions_) > **Agregar un permiso**.
2. Seleccionar **API usadas en mi organización** (o **Mis API**) > buscar la aplicación (`demo-java-api`).
3. Seleccionar **Permisos de aplicación** (_Application permissions_).
4. Seleccionar el rol **`OT.Read`** y presionar **Agregar permisos**.
5. Presionar **Conceder consentimiento de administrador para [Organización]** (_Grant admin consent_) y confirmar (debe visualizarse el check verde ✅ en la columna de Estado).

---

### 💻 3. Configuración del Proyecto Spring Boot 3

#### 3.1. Dependencias (`build.gradle`)

Se utiliza el starter estándar de Spring Security, evitando bibliotecas con conflictos de versiones:

```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

```

#### 3.2. Propiedades de la Aplicación (`src/main/resources/application.properties`)

```properties
spring.application.name=demo

# Configuración de Spring Security OAuth2 Resource Server
spring.security.oauth2.resourceserver.jwt.issuer-uri=https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0
spring.security.oauth2.resourceserver.jwt.audiences=${AZURE_APP_ID_URI}

```

#### 3.3. Configuración de Seguridad (`SecurityConfig.java`)

Mapea el claim `"roles"` emitido en el JWT por Entra ID a autoridades con el prefijo `ROLE_`:

```java
package com.rojas.holamundo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter()))
            );

        return http.build();
    }

    private JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter authoritiesConverter = new JwtGrantedAuthoritiesConverter();
        authoritiesConverter.setAuthoritiesClaimName("roles");
        authoritiesConverter.setAuthorityPrefix("ROLE_");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
        return converter;
    }
}

```

#### 3.4. Controlador Protegido (`HelloController.java`)

```java
package com.rojas.holamundo;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HelloController {

    @GetMapping("/hello")
    @PreAuthorize("hasRole('OT.Read')")
    public Map<String, String> hello() {
        return Map.of("message", "Hello, World!");
    }
}

```

---

### 🚀 4. Pipeline CI/CD (.github/workflows/deploy.yml)

El flujo construye el binario Jar con Java 21/Gradle, lo transfiere a la instancia EC2 mediante SCP y reinicia la aplicación exportando las variables necesarias.

```yaml
name: Deploy Spring Boot to EC2

on:
  push:
    branches: ["main", "master"]

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK
        uses: actions/setup-java@v5
        with:
          distribution: "temurin"
          java-version: "21"

      - name: Build with Gradle
        run: ./gradlew bootJar -x test

      - name: Set up SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.EC2_SSH_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H "${{ secrets.EC2_HOST }}" >> ~/.ssh/known_hosts 2>/dev/null

      - name: Copy JAR to EC2 via SCP
        run: |
          ssh -i ~/.ssh/deploy_key ec2-user@${{ secrets.EC2_HOST }} 'mkdir -p /home/ec2-user/app'
          scp -i ~/.ssh/deploy_key build/libs/*.jar ec2-user@${{ secrets.EC2_HOST }}:/home/ec2-user/app/

      - name: Restart Spring Boot App via SSH
        run: |
          ssh -i ~/.ssh/deploy_key ec2-user@${{ secrets.EC2_HOST }} '
            set -e
            mkdir -p /home/ec2-user/app

            command -v java >/dev/null 2>&1 || sudo dnf install -y java-21-amazon-corretto

            fuser -k 8080/tcp || true
            pkill -x java || true
            sleep 2

            export AZURE_CLIENT_ID="${{ secrets.AZURE_CLIENT_ID }}"
            export AZURE_TENANT_ID="${{ secrets.AZURE_TENANT_ID }}"
            export AZURE_APP_ID_URI="${{ secrets.AZURE_APP_ID_URI }}"

            setsid java -jar /home/ec2-user/app/*.jar > /home/ec2-user/app/app.log 2>&1 < /dev/null &
            disown || true

            sleep 3
            exit 0
          '
```

---

### 🧪 5. Pruebas Locales y Manejo de Secretos

#### 5.1. Archivo `.gitignore` y `.env.example`

Para cumplir con la política de GitHub Push Protection:

1. `.env` agregado a `.gitignore`.
2. Plantilla de referencia `.env.example`:

```env
AZURE_TENANT_ID=tu_tenant_id_aqui
AZURE_CLIENT_ID=tu_client_id_aqui
AZURE_CLIENT_SECRET=tu_client_secret_aqui
API_URL=http://<EC2_PUBLIC_IP>:8080/api/hello

```

#### 5.2. Script de Validación (`test.sh`)

```bash
#!/bin/bash

if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo "❌ Error: No se encontró el archivo .env"
  exit 1
fi

echo "🔑 Solicitando Access Token a Microsoft Entra ID..."

TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${AZURE_CLIENT_ID}" \
  -d "scope=${AZURE_CLIENT_ID}/.default" \
  -d "client_secret=${AZURE_CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "None" ]; then
  echo "❌ Error al obtener el token:"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Token obtenido exitosamente."
echo "🚀 Enviando petición a $API_URL..."
echo ""

curl -i -X GET "$API_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

```

---

### 🛠️ 6. Matriz de Resolución de Problemas (Troubleshooting)

| Error Encontrado                                      | Causa Raíz                                                                                                               | Solución Aplicada                                                                                                            |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `ClassNotFoundException` / `IllegalArgumentException` | Incompatibilidad al importar paquetes de `spring-cloud-azure`.                                                           | Se eliminaron dependencias de `spring-cloud-azure` y se usó la solución nativa `spring-boot-starter-oauth2-resource-server`. |
| `401 Unauthorized`                                    | Configuración incorrecta del `issuer-uri` o del `audience` esperados por el filtro JWT.                                  | Se mapearon explícitamente `issuer-uri` (`/v2.0`) y `audiences` (`AZURE_APP_ID_URI`) en `application.properties`.            |
| `403 Forbidden` (`insufficient_scope`)                | El flujo `client_credentials` emite App Roles (`roles`), pero la API buscaba Scopes delegados (`scp` / `SCOPE_OT.Read`). | 1. Se creó el **App Role** `OT.Read` para Aplicaciones y se otorgó **Admin Consent** en Azure.<br>                           |

<br>2. Se agregó `JwtAuthenticationConverter` en Spring Security para leer `roles` y se cambió la anotación a `hasRole('OT.Read')`. |
| `GH013: Push Protection` | El archivo `.env` con el secret de Azure fue incluido por error en los commits de Git. | Se agregó `.env` a `.gitignore`, se removió de la caché (`git rm --cached .env`) y se reestructuró la historia limpia de commits antes de enviar el push. |

---

### ✅ Resultado de la Ejecución Final

```http
HTTP/1.1 200 OK
X-Content-Type-Options: nosniff
X-XSS-Protection: 0
Cache-Control: no-cache, no-store, max-age=0, must-revalidate
Content-Type: application/json

{"message":"Hello, World!"}

```
