# 1. Configurar la aplicación en Microsoft Entra ID (Azure Portal)

## 1.1. Registrar la aplicación

En el [Azure Portal](https://portal.azure.com) → **Microsoft Entra ID → App registrations → New registration**. Registra tu API (ej. `demo-java-api`). Anota estos tres valores, los necesitarás luego como secrets:

- **Application (client) ID** → será `AZURE_CLIENT_ID`
- **Directory (tenant) ID** → será `AZURE_TENANT_ID`

## 1.2. Exponer la API y definir el App ID URI

En **Expose an API** (Exponer una API):
- Configura el **Application ID URI** (por defecto algo como `api://<CLIENT_ID>`, puedes dejarlo así). Este valor será `AZURE_APP_ID_URI`.

## 1.3. Crear el App Role

> **Por qué un App Role y no un Scope:** los *scopes* delegados son para cuando un usuario humano inicia sesión y delega permisos. En `client_credentials` (app-a-app) no hay usuario, así que Entra ID usa **App Roles** en su lugar, entregados en el claim `roles` del JWT.

En **App roles → Create app role**:

| Campo | Valor |
|---|---|
| Display name | `OT.Read` |
| Allowed member types | **Applications** ← imprescindible para M2M |
| Value | `OT.Read` |
| Description | Permiso de lectura para órdenes de trabajo |

## 1.4. Asignar el permiso y otorgar consentimiento de administrador

1. **API permissions → Add a permission → APIs my organization uses** (o **My APIs**) → busca tu app (`demo-java-api`).
2. Selecciona **Application permissions** (no *Delegated*).
3. Marca el rol **`OT.Read`** → **Add permissions**.
4. Presiona **Grant admin consent for [tu organización]** y confirma.
5. Verifica que la columna **Status** quede con el check verde ✅ — sin esto, el token se emite pero sin el rol, y todo dará `403`.

## 1.5. Crear un Client Secret (solo para pruebas M2M)

En **Certificates & secrets → New client secret**. Copia el **Value** inmediatamente (no se vuelve a mostrar) — este es tu `AZURE_CLIENT_SECRET`, usado únicamente para las pruebas locales del [paso 4](04-pruebas-y-troubleshooting.md), **no** se despliega al servidor.

Con estos 4 valores en mano (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_APP_ID_URI`, `AZURE_CLIENT_SECRET`), continúa con [2. Actualizar el proyecto Spring Boot](02-actualizar-proyecto-spring-boot.md).
