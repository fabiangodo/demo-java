# 1. Crear el proyecto con Spring Initializr

## 1.1. Generar el proyecto

Ve a [https://start.spring.io](https://start.spring.io) y configura:

| Campo | Valor |
|---|---|
| Project | Gradle - Groovy |
| Language | Java |
| Spring Boot | 3.3.x (última versión estable) |
| Group | `com.rojas` (o el paquete que prefieras) |
| Artifact | `demo` |
| Packaging | Jar |
| Java | 21 |

**Dependencias** (buscar y agregar):
- **Spring Web** (`spring-boot-starter-web`)

Presiona **Generate**, descomprime el `.zip` y abre el proyecto.

## 1.2. Estructura resultante

```
demo/
├── build.gradle
├── settings.gradle
├── gradlew / gradlew.bat        # wrapper de Gradle, no lo edites
├── src/main/java/com/rojas/demo/DemoApplication.java
└── src/main/resources/application.properties
```

El `build.gradle` que genera Spring Initializr ya trae el toolchain de Java correcto:

```groovy
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.3.4'
    id 'io.spring.dependency-management' version '1.1.6'
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
}
```

> ⚠️ **Importante:** la versión de `languageVersion` acá **debe coincidir** con la versión de JDK que uses en el step "Set up JDK" del workflow de GitHub Actions (paso 3). Si no coinciden, el build falla en CI con un error de tipo `Cannot find a Java installation... matching {languageVersion=XX}`.

## 1.3. Crear el endpoint de prueba

Crea `src/main/java/com/rojas/demo/HelloController.java`:

```java
package com.rojas.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HelloController {

    @GetMapping("/hello")
    public Map<String, String> hello() {
        return Map.of("message", "Hello, World!");
    }
}
```

## 1.4. Probar localmente

```bash
./gradlew bootRun
```

Y en otra terminal:

```bash
curl http://localhost:8080/api/hello
# {"message":"Hello, World!"}
```

Si eso responde bien, ya tienes la base lista para desplegar. Sube el proyecto a un repositorio de GitHub (necesitarás la URL en el paso siguiente) y continúa con [2. Configurar la instancia EC2](02-configurar-instancia-ec2.md).
