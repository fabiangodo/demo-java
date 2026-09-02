# Demo Spring Boot: AWS EC2, GitHub Actions & Microsoft Entra ID Security

Proyecto de demostración de una API REST en **Spring Boot 3 (Java 21)** como **OAuth2 Resource Server** protegido con **Microsoft Entra ID**, desplegado de forma automatizada en **AWS EC2** mediante **GitHub Actions**.

---

## 🛠️ Tecnologías y Stack

* **Java 21** (Amazon Corretto)
* **Spring Boot 3.3.4** (Gradle como gestor de dependencias y construcción)
* **Spring Security OAuth2 Resource Server** (Validación nativa de tokens JWT sin librerías de Azure de terceros)
* **Microsoft Entra ID** (Proveedor de identidad y emisor de tokens OAuth2)
* **AWS EC2** (Instancia `t3.micro` con Amazon Linux 2023)
* **GitHub Actions** (Pipeline CI/CD mediante OpenSSH y SCP)

---

## 📦 1. Dependencias en Gradle (`build.gradle`)

Para evitar conflictos de compatibilidad de clases (`ClassNotFoundException` o `IllegalArgumentException`), **no se utilizan starters de Azure**. Se usa el validador nativo de Spring Security:

```groovy
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.3.4'
    id 'io.spring.dependency-management' version '1.1.6'
}

group = 'com.rojas'
version = '0.0.1-SNAPSHOT'

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    
    // Validador nativo de JWT / OAuth2 Resource Server para Spring Boot 3
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'

    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
}

tasks.named('test') {
    useJUnitPlatform()
}

```

---

## 🔐 2. Variables de Entorno y `application.properties`

La aplicación descarga las claves públicas de Microsoft desde el puerto HTTPS configurado en `issuer-uri` para verificar automáticamente los tokens JWT recibidos:

```properties
spring.application.name=demo

# Configuración estándar de Spring Security OAuth2 Resource Server
spring.security.oauth2.resourceserver.jwt.issuer-uri=https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0
spring.security.oauth2.resourceserver.jwt.audiences=${AZURE_APP_ID_URI}

```

---

## 🔒 3. Configuración de Seguridad y Controlador

### `SecurityConfig.java`

Habilita la protección en todas las rutas y delega la validación del encabezado `Authorization: Bearer <token>` a Spring Security:

```java
package com.rojas.holamundo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
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
            .oauth2ResourceServer(oauth2 -> oauth2.jwt());

        return http.build();
    }
}

```

### `HelloController.java`

```java
package com.rojas.holamundo.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HelloController {

    @GetMapping("/hello")
    @PreAuthorize("hasAuthority('SCOPE_OT.Read')")
    public Map<String, String> hello() {
        return Map.of("message", "Hello, World!");
    }
}

```

---

## ☁️ 4. Guía Detallada: Configuración y Acceso a AWS EC2

### A. Creación y Seguridad del Servidor

1. **AMI Recomendada:** Amazon Linux 2023.
2. **Grupo de Seguridad (Security Group) - Reglas de Entrada (Inbound Rules):**
* **SSH (Puerto 22):** `Custom TCP` / `0.0.0.0/0` (o la IP local del desarrollador).
* **Aplicación (Puerto 8080):** `Custom TCP` / Port Range: `8080` / Source: `0.0.0.0/0` (*Obligatorio para recibir peticiones externas*).



---

### B. Solución a Problemas Frecuentes de Conexión por SSH

Si los estudiantes no pueden conectarse a la EC2, revisa los siguientes puntos críticos:

#### 1. Ubicación del archivo de clave (.pem)

Git Bash lanzará el error `Warning: Identity file key.pem not accessible` si la terminal no está posicionada en el directorio donde existe el archivo `.pem`.

* Navegar a la carpeta donde está la llave (ej. Descargas):
```bash
cd ~/Downloads

```


* O especificar la ruta absoluta al conectar:
```bash
ssh -i ~/Downloads/key.pem ec2-user@<IP_PUBLICA_EC2>

```



#### 2. Permisos restrictivos de la llave (`Permission denied`)

SSH rechaza conexiones si los permisos del archivo `.pem` son demasiado abiertos:

```bash
chmod 400 key.pem

```

#### 3. Nombre de usuario incorrecto según la AMI

El usuario predeterminado de SSH varía según la imagen del sistema operativo elegida en AWS:

* **Amazon Linux 2023 / Amazon Linux 2:** `ec2-user`
* **Ubuntu Server:** `ubuntu`
* **Debian:** `admin`

*Comando de acceso correcto:*

```bash
ssh -i key.pem ec2-user@<IP_PUBLICA_EC2>

```

#### 4. Cambio de IP Pública al reiniciar la instancia

Si la instancia EC2 se apaga y se vuelve a encender, AWS asigna una **IP pública IPv4 diferente**. Si el comando da error de tiempo de espera (`timeout`), verifica la IP actual en la consola de AWS.

---

## ⚙️ 5. Pipeline de CI/CD en GitHub Actions (`.github/workflows/deploy.yml`)

### Secrets Requeridos en GitHub (`Settings` > `Secrets and variables` > `Actions`):

| Secret Name | Descripción |
| --- | --- |
| `EC2_HOST` | Dirección IP Pública IPv4 de la instancia EC2 |
| `EC2_SSH_KEY` | Contenido de la clave privada `.pem` |
| `AZURE_CLIENT_ID` | Application (client) ID de Microsoft Entra ID |
| `AZURE_TENANT_ID` | Directory (tenant) ID de Microsoft Entra ID |
| `AZURE_APP_ID_URI` | Application ID URI de la API (ej. `api://426120e7-...`) |

### Workflow Completo:

```yaml
name: Deploy Spring Boot to EC2

on:
  push:
    branches: [ "main", "master" ]

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
        distribution: 'temurin'
        java-version: '21'

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

          # Instala el JRE de Java 21 si no esta presente en la EC2
          command -v java >/dev/null 2>&1 || sudo dnf install -y java-21-amazon-corretto

          # Cierra cualquier proceso previo en el puerto 8080 o java
          fuser -k 8080/tcp || true
          pkill -x java || true
          sleep 2

          # Inyeccion de variables de entorno desde Secrets de GitHub
          export AZURE_CLIENT_ID="${{ secrets.AZURE_CLIENT_ID }}"
          export AZURE_TENANT_ID="${{ secrets.AZURE_TENANT_ID }}"
          export AZURE_APP_ID_URI="${{ secrets.AZURE_APP_ID_URI }}"

          # Desliga el proceso Java del canal SSH para ejecucion persistente
          setsid java -jar /home/ec2-user/app/*.jar > /home/ec2-user/app/app.log 2>&1 < /dev/null &
          disown || true

          sleep 3
          exit 0
        '

```

---

## 🧪 6. Guía de Pruebas y Validación con `curl`

### Paso 1: Validar rechazo de acceso anónimo (401 Unauthorized)

Ejecuta desde cualquier terminal local:

```bash
curl -i http://<IP_EC2>:8080/api/hello

```

**Respuesta esperada:** `HTTP/1.1 401 Unauthorized`.

---

### Paso 2: Obtener Access Token de Microsoft Entra ID (`Client Credentials`)

Genera un secreto de cliente en Entra ID (*Certificados y secretos*) y solicita un token por consola:

```bash
curl -X POST "https://login.microsoftonline.com/<AZURE_TENANT_ID>/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=<AZURE_CLIENT_ID>" \
  -d "scope=api://<AZURE_CLIENT_ID>/.default" \
  -d "client_secret=<CLIENT_SECRET_VALUE>" \
  -d "grant_type=client_credentials"

```

*Copia el token JWT que viene dentro de `"access_token": "eyJ0eXAi..."`.*

---

### Paso 3: Probar la llamada a la API autenticada

Envia la petición adjuntando el token en la cabecera `Authorization`:

```bash
curl -i -X GET http://<IP_EC2>:8080/api/hello \
  -H "Authorization: Bearer <TU_ACCESS_TOKEN>"

```

#### Respuestas esperadas:

* **`HTTP/1.1 200 OK`**: Si el token contiene los permisos de scope adecuados o la anotación `@PreAuthorize` fue removida temporalmente para validar conectividad.
* **`HTTP/1.1 403 Forbidden`**: Indica que el token fue **validado exitosamente por Spring Security**, pero fue rechazado por no contar con la autoridad `SCOPE_OT.Read` requerida por `@PreAuthorize` (los flujos de `client_credentials` generan tokens de aplicación y no delegated scopes de usuario).

---

## 🔍 Tabla Resumen de Diagnóstico (Troubleshooting)

| Error Observado | Causa Raíz | Solución |
| --- | --- | --- |
| `curl: (7) Failed to connect` | Puerto 8080 bloqueado en AWS o la app no inició. | Agregar la regla TCP 8080 en el **Security Group** de la EC2 y revisar `/home/ec2-user/app/app.log`. |
| `Permission denied (publickey)` | Archivo `.pem` con permisos incorrectos o usuario SSH equivocado. | Aplicar `chmod 400 key.pem` y usar `ec2-user@<IP>` (Amazon Linux) o `ubuntu@<IP>` (Ubuntu). |
| `No qualifying bean of type 'JwtDecoder'` | No se especificó el `issuer-uri` en `application.properties`. | Verificar que `spring.security.oauth2.resourceserver.jwt.issuer-uri` esté definido correctamente. |
| `ClassNotFoundException: ConfigurableBootstrapContext` | Incompatibilidad con las dependencias `spring-cloud-azure`. | Eliminar dependencias de Azure del `build.gradle` y usar únicamente `spring-boot-starter-oauth2-resource-server`. |