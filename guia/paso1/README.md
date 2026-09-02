# Paso 1 — API Spring Boot en EC2 con despliegue automático (GitHub Actions)

Esta primera parte cubre desde cero hasta tener una API REST simple, corriendo en una instancia EC2 de AWS, y que se **despliega solita** cada vez que haces `push` a `main`.

No incluye seguridad (eso es [Paso 2](../paso2/README.md)) — el objetivo aquí es tener el flujo completo de CI/CD funcionando primero, sin complejidad adicional.

## Índice

1. [Crear el proyecto con Spring Initializr](01-crear-proyecto-spring-boot.md)
2. [Configurar la instancia EC2 en AWS](02-configurar-instancia-ec2.md)
3. [Desplegar con GitHub Actions](03-desplegar-con-github-actions.md)

## Resultado esperado al final de este paso

```
GET http://<IP_PUBLICA_EC2>:8080/api/hello

200 OK
{"message":"Hello, World!"}
```

Y cada `git push` a `main` reconstruye y redespliega automáticamente, sin que tengas que tocar la instancia a mano.
