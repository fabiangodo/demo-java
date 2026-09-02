# 3. Actualizar el pipeline y desplegar los cambios

La app ahora necesita `AZURE_TENANT_ID` y `AZURE_APP_ID_URI` como variables de entorno **en el proceso que corre en EC2** (no solo en tu `.env` local). Esto significa dos cambios sobre lo que dejamos en el [Paso 1](../paso1/03-desplegar-con-github-actions.md): nuevos secrets en GitHub, y exportar esas variables antes de arrancar el `.jar` remoto.

## 3.1. Agregar los nuevos Secrets en GitHub

**Settings → Secrets and variables → Actions**, agrega (además de `EC2_HOST` y `EC2_SSH_KEY` del paso 1):

| Secret | Valor |
|---|---|
| `AZURE_CLIENT_ID` | Application (client) ID de Entra ID |
| `AZURE_TENANT_ID` | Directory (tenant) ID de Entra ID |
| `AZURE_APP_ID_URI` | El App ID URI que configuraste en "Expose an API" |

> `AZURE_CLIENT_SECRET` **no** se necesita como secret de GitHub — la API (Resource Server) solo valida tokens, no los emite. El client secret únicamente lo usa quien *consume* la API para pedir el token (ver [paso 4](04-pruebas-y-troubleshooting.md)).

## 3.2. Modificar `.github/workflows/deploy.yml`

Agrega el bloque de `export` **antes** de arrancar el jar, dentro del step "Restart Spring Boot App via SSH":

```yaml
    - name: Restart Spring Boot App via SSH
      run: |
        ssh -i ~/.ssh/deploy_key ec2-user@${{ secrets.EC2_HOST }} '
          set -e
          mkdir -p /home/ec2-user/app

          command -v java >/dev/null 2>&1 || sudo dnf install -y java-21-amazon-corretto

          fuser -k 8080/tcp || true
          pkill -x java || true
          sleep 2

          # Variables de entorno de Microsoft Entra ID para el Resource Server
          export AZURE_CLIENT_ID="${{ secrets.AZURE_CLIENT_ID }}"
          export AZURE_TENANT_ID="${{ secrets.AZURE_TENANT_ID }}"
          export AZURE_APP_ID_URI="${{ secrets.AZURE_APP_ID_URI }}"

          setsid java -jar /home/ec2-user/app/*.jar > /home/ec2-user/app/app.log 2>&1 < /dev/null &
          disown || true

          sleep 3
          exit 0
        '
```

> ⚠️ **Por qué el `export` tiene que ir en el mismo bloque `ssh '...'` y antes del `setsid`:** las variables exportadas en una sesión SSH no persisten a la siguiente conexión ni se heredan automáticamente por el proceso backgroundeado si se exportan en otro paso/conexión. Tienen que estar en el mismo shell que hace `setsid java -jar ...`, para que el proceso hijo las herede vía entorno.

## 3.3. Desplegar

```bash
git add .github/workflows/deploy.yml src/main/resources/application.properties \
        src/main/java/com/rojas/holamundo/config/SecurityConfig.java \
        src/main/java/com/rojas/holamundo/HelloController.java build.gradle
git commit -m "feat: agregar seguridad OAuth2 con Microsoft Entra ID"
git push
```

Sigue el run en la pestaña **Actions** hasta que quede verde, y continúa con [4. Pruebas y troubleshooting](04-pruebas-y-troubleshooting.md) para confirmar que la protección realmente funciona (no solo que el deploy no falló).
