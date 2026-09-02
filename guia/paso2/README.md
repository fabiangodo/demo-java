# Paso 2 — Seguridad con Microsoft Entra ID (OAuth2 M2M)

Parte desde donde termina el [Paso 1](../paso1/README.md): una API desplegada en EC2 sin protección alguna. Acá se agrega autenticación **machine-to-machine (M2M)** con **Microsoft Entra ID** (antes Azure AD), usando el flujo `client_credentials` y validación de JWT como *OAuth2 Resource Server*.

## Índice

1. [Configurar la aplicación en Microsoft Entra ID (Azure Portal)](01-configurar-azure-entra-id.md)
2. [Actualizar el proyecto Spring Boot](02-actualizar-proyecto-spring-boot.md)
3. [Actualizar el pipeline y desplegar los cambios](03-actualizar-pipeline-y-desplegar.md)
4. [Pruebas y troubleshooting](04-pruebas-y-troubleshooting.md)

## Concepto clave antes de empezar

En un flujo `client_credentials` (app llamando a app, sin usuario humano de por medio), Entra ID **no emite scopes delegados** (`scp`) — emite **App Roles** (claim `roles`). Si intentas validar con `hasAuthority('SCOPE_...')` como en los tutoriales típicos de "usuario inicia sesión", vas a obtener `403 Forbidden` siempre. Este paso está diseñado around eso desde el principio.

## Resultado esperado al final de este paso

```bash
curl -i -X GET http://<IP_PUBLICA_EC2>:8080/api/hello \
  -H "Authorization: Bearer $ACCESS_TOKEN"

HTTP/1.1 200 OK
Content-Type: application/json

{"message":"Hello, World!"}
```

Y sin el header `Authorization`, la misma petición debe responder `401 Unauthorized`.
