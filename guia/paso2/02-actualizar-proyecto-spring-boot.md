# 2. Actualizar el proyecto Spring Boot

## 2.1. Dependencia (`build.gradle`)

Agrega el starter estándar de Spring Security para validar JWT como *Resource Server*:

```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-oauth2-resource-server'

    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
}
```

> ⚠️ **Qué NO usar:** se probó primero con `com.azure.spring:spring-cloud-azure-starter-active-directory`, pensando que sería más "nativo" para Entra ID. En la práctica introdujo conflictos de versiones (`ClassNotFoundException` / `IllegalArgumentException` al levantar el contexto de Spring). Se removió por completo a favor del starter estándar `spring-boot-starter-oauth2-resource-server`, que es agnóstico del proveedor y funciona perfecto validando los JWT de Entra ID por su `issuer-uri`. Menos dependencias, menos sorpresas.

## 2.2. Propiedades (`src/main/resources/application.properties`)

```properties
spring.application.name=demo

# Configuración estándar de Spring Security OAuth2 Resource Server
spring.security.oauth2.resourceserver.jwt.issuer-uri=https://login.microsoftonline.com/${AZURE_TENANT_ID}/v2.0
spring.security.oauth2.resourceserver.jwt.audiences=${AZURE_APP_ID_URI}
```

`${AZURE_TENANT_ID}` y `${AZURE_APP_ID_URI}` se resuelven desde variables de entorno del proceso — no se hardcodean acá. Cómo llegan esas variables al proceso en EC2 se explica en el [paso 3](03-actualizar-pipeline-y-desplegar.md).

## 2.3. Configuración de seguridad (`src/main/java/.../config/SecurityConfig.java`)

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
@EnableMethodSecurity // habilita @PreAuthorize en los controladores
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

    // Mapea el claim "roles" (App Roles de Entra ID) a authorities "ROLE_*"
    // de Spring Security, para poder usar hasRole("OT.Read").
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

> 💡 **Nota de compatibilidad:** en algunas versiones de Spring Security, `oauth2.jwt()` **sin argumentos** no compila (`method jwt in class OAuth2ResourceServerConfigurer<H> cannot be applied to given types`). Siempre pásale un `Customizer`, aunque sea vacío (`jwt -> {}`) si no necesitas el converter de roles.

### ¿Por qué `roles` y no `scp`/scopes?

Como se explicó en el [paso 1 de esta sección](01-configurar-azure-entra-id.md#concepto-clave), el flujo `client_credentials` entrega App Roles en el claim `roles`, no scopes delegados. Por eso el converter de arriba lee específicamente `"roles"` y no el claim `"scp"` que usarías en un flujo de usuario delegado.

## 2.4. Proteger el endpoint (`HelloController.java`)

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

`hasRole('OT.Read')` en Spring Security busca automáticamente la authority `ROLE_OT.Read` — que es justo lo que produce el converter del paso 2.3 a partir del App Role `OT.Read` de Entra ID.

## 2.5. Manejo local de secretos (`.env`, no lo subas al repo)

Para probar localmente sin hardcodear credenciales:

1. Agrega `.env` a `.gitignore` (si no está ya).
2. Crea `.env.example` como plantilla de referencia (este sí se sube al repo, sin valores reales):

```env
AZURE_TENANT_ID=tu_tenant_id_aqui
AZURE_CLIENT_ID=tu_client_id_aqui
AZURE_CLIENT_SECRET=tu_client_secret_aqui
API_URL=http://<EC2_PUBLIC_IP>:8080/api/hello
```

3. Crea tu propio `.env` (sin subir) con los valores reales del [paso 1](01-configurar-azure-entra-id.md).

> ⚠️ **Si accidentalmente commiteas un secret real:** GitHub bloqueará el push con **GH013: Push Protection**. La solución es `.gitignore` con `.env`, sacarlo del staging/historial con `git rm --cached .env` (y si ya llegó a un commit, reescribir esa parte del historial) **antes** de reintentar el push — nunca ignorar la advertencia y forzar el push con el secret real adentro.

Continúa con [3. Actualizar el pipeline y desplegar](03-actualizar-pipeline-y-desplegar.md).
