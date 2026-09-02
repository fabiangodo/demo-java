# 3. Desplegar con GitHub Actions

## 3.1. Configurar los Secrets del repositorio

En GitHub: **Settings → Secrets and variables → Actions → New repository secret**. Crea:

| Secret | Valor |
|---|---|
| `EC2_HOST` | La IP pública de tu instancia (ej. `3.15.232.215`) |
| `EC2_SSH_KEY` | El contenido **completo** del archivo `.pem` (incluyendo las líneas `-----BEGIN...` y `-----END...`) |

## 3.2. Crear el workflow

Crea el archivo `.github/workflows/deploy.yml`:

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

          # Instala el JRE en la instancia si no esta presente (idempotente:
          # no hace nada si ya esta instalado)
          command -v java >/dev/null 2>&1 || sudo dnf install -y java-21-amazon-corretto

          # Mata cualquier proceso previo en el puerto 8080 o proceso java residual
          fuser -k 8080/tcp || true
          pkill -x java || true
          sleep 2

          # setsid + stdin cerrado para desligar completamente la app del canal SSH
          setsid java -jar /home/ec2-user/app/*.jar > /home/ec2-user/app/app.log 2>&1 < /dev/null &
          disown || true

          sleep 3
          exit 0
        '
```

### ¿Por qué SSH/SCP nativo y no una acción de terceros (`appleboy/ssh-action`)?

En la práctica se probó primero con `appleboy/ssh-action` / `appleboy/scp-action`, pero la razón real de fallos intermitentes **no** era esa acción — ver la nota del `pkill` más abajo. Se migró a `ssh`/`scp` nativos (ya incluidos en `ubuntu-latest`) simplemente porque es más simple, transparente y sin dependencias externas que puedan cambiar de comportamiento.

### ¿Por qué `concurrency` con `cancel-in-progress`?

Si haces varios `push` seguidos, sin esto cada uno dispara un deploy que compite por el mismo servidor. Con este bloque, un push nuevo cancela limpiamente el deploy anterior en vez de correr en paralelo.

## 3.3. Probar el despliegue

Haz `git push` a `main` y observa la pestaña **Actions** del repositorio. Cuando termine en verde, prueba:

```bash
curl http://<IP_PUBLICA_EC2>:8080/api/hello
```

## 3.4. Troubleshooting — lecciones aprendidas

| Síntoma | Causa real | Solución |
|---|---|---|
| El step de SSH muere casi instantáneo con `signal TERM` (exit 143), sin ningún log de conexión, **sin importar la acción o versión usada** | El script remoto tenía `pkill -f "java -jar"`. Con `-f`, `pkill` compara contra la **línea de comandos completa** de cada proceso. Como el script se ejecuta como `sh -c "<todo el texto del script>"`, la propia cadena `"java -jar"` aparece en el comando del shell que está corriendo el script — **se mataba a sí mismo al instante**. | Usar `pkill -x java` (compara solo el nombre exacto del proceso, no la línea de comandos). |
| `setsid: failed to execute java: No such file or directory` en el log, aunque `java -version` funciona al conectarte manualmente por SSH | `ssh host 'comando'` (no interactivo) no carga `.bash_profile`/`.bashrc`; si java no está en una ruta básica del sistema, no lo encuentra. En este caso además el JRE **no estaba instalado en absoluto** en la instancia — el JDK del step "Set up JDK" es solo para compilar en el runner, no llega a la EC2. | Instalar el JRE en la instancia (`sudo dnf install -y java-21-amazon-corretto`) y automatizarlo en el propio script de despliegue con el chequeo `command -v java || ...` de arriba. |
| `curl` a la IP pública da `ERR_CONNECTION_REFUSED` aunque el pipeline esté verde | El pipeline verde solo confirma que el script SSH corrió sin errores de shell — no garantiza que el `.jar` realmente haya arrancado. | Diagnosticar por SSH: `ps aux \| grep java`, `cat /home/ec2-user/app/app.log`. |
| Llave `.pem` da `Permission denied (publickey...)` al conectar manualmente | Permisos del archivo demasiado abiertos (`0644`). SSH ignora llaves privadas legibles por otros usuarios. | `chmod 600 tu-llave.pem` |

Con esto ya tienes el flujo base funcionando. El siguiente paso es agregar autenticación con Microsoft Entra ID — ver [Paso 2](../paso2/README.md).
