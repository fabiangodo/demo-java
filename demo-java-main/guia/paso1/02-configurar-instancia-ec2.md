# 2. Configurar la instancia EC2 en AWS

## 2.1. Acceder a la consola de AWS

Ingresa a la [consola de AWS](https://console.aws.amazon.com/) con tu cuenta (portal educativo/institucional o cuenta propia con capa gratuita).

## 2.2. Crear el par de claves (Key Pair)

En **EC2 → Network & Security → Key Pairs → Create key pair**:

| Campo | Valor |
|---|---|
| Name | el que prefieras (ej. `demo-java-key`) |
| Key pair type | **RSA** |
| Private key file format | **.pem** |

Descarga el archivo `.pem` y guárdalo en un lugar seguro — **no lo subas nunca al repositorio**. Lo necesitarás para:
- Conectarte manualmente por SSH cuando quieras depurar algo.
- Configurarlo como secret en GitHub (paso 3) para que el pipeline pueda desplegar.

En tu máquina, asegúrate de que tenga los permisos correctos o SSH lo rechazará:

```bash
chmod 600 demo-java-key.pem
```

## 2.3. Lanzar la instancia EC2

En **EC2 → Instances → Launch instance**:

| Campo | Valor |
|---|---|
| Name | ej. `demo-java-server` |
| AMI | Amazon Linux 2023 |
| Instance type | `t3.micro` (capa gratuita) |
| Key pair | la que creaste en el paso anterior |

## 2.4. Configurar el Security Group (reglas de entrada)

En la configuración de red de la instancia (o en un Security Group nuevo/existente), agrega estas reglas de entrada (**Inbound rules**):

| Puerto | Protocolo | Origen | Para qué |
|---|---|---|---|
| 22 | TCP | `0.0.0.0/0` | SSH — administración y despliegue desde GitHub Actions |
| 80 | TCP | `0.0.0.0/0` | HTTP (tráfico web general, opcional en esta demo) |
| 443 | TCP | `0.0.0.0/0` | HTTPS (opcional en esta demo) |
| 8080 | TCP | `0.0.0.0/0` | Puerto donde escucha la API de Spring Boot |

> ⚠️ **Por qué el puerto 22 debe estar abierto a `0.0.0.0/0` y no solo a "mi IP":** GitHub Actions se conecta desde IPs dinámicas de sus runners (no la tuya), así que restringir el origen a tu IP fija rompe el despliegue automático. Como ya usas autenticación por llave privada, abrir el puerto a cualquier origen es la práctica estándar para este tipo de pipelines — nadie puede entrar sin la llave `.pem`.

## 2.5. Anota la IP pública

Una vez que la instancia esté **"Running"**, copia su **IPv4 pública** (ej. `3.15.232.215`) desde el resumen de la instancia. La necesitarás en el paso siguiente.

Continúa con [3. Desplegar con GitHub Actions](03-desplegar-con-github-actions.md).
