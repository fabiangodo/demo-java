Para conectarte a la instancia EC2 desde **Git Bash** y validar que la aplicación esté corriendo, sigue estos pasos:

---

### Paso 1: Cambiar permisos a la llave privada y conectar por SSH

1. Abre Git Bash en tu equipo.
2. Asegúrate de restringir los permisos de tu archivo de llave (ej. `mi-llave.pem`), de lo contrario SSH rechazará la conexión por seguridad:

```bash
chmod 400 /ruta/a/tu-llave.pem

```

3. Conéctate a la EC2 usando el usuario `ec2-user` y la IP pública:

```bash
ssh -i /ruta/a/tu-llave.pem ec2-user@3.15.232.215

```

---

### Paso 2: Verificar el estado dentro de la EC2

Una vez dentro de la consola del servidor (verás el prompt `[ec2-user@... ]$`):

1. **Verificar que el proceso Java está ejecutándose:**
```bash
ps aux | grep java

```


*Deberías ver la línea de comando ejecutando tu archivo `.jar`.*
2. **Revisar los logs de la aplicación:**
```bash
tail -n 50 /home/ec2-user/app/app.log

```


*Busca el mensaje típico de inicio de Spring Boot: `Started DemoApplication in X seconds`.*
3. **Hacer una prueba interna en el puerto 8080:**
```bash
curl -i http://localhost:8080/api/hello

```


*Debe responder `HTTP/1.1 401 Unauthorized` (lo cual confirma que Spring Security ya está activo).*

---

### Paso 3: Probar desde tu máquina (fuera de la EC2)

Abre otra ventana de Git Bash en tu computador (sin iniciar sesión por SSH) y ejecuta:

```bash
curl -i http://3.15.232.215:8080/api/hello

```

* **Si responde `HTTP/1.1 401 Unauthorized`:** El despliegue fue un éxito completo. La aplicación está arriba, expuesta a internet y protegida por Spring Security.
* **Si se queda pegado/hace timeout:** Revisa en la consola de AWS que el **Security Group** de la EC2 tenga abierta una regla de entrada (Inbound rule) para el puerto `8080` (TCP) desde `0.0.0.0/0`.
