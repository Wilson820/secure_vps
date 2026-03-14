# secure_vps
VPS initial config and install secure. - docker environment

Arquitectura de Conexión Segura
Al cambiar el puerto y usar Nginx Proxy Manager, tu servidor ahora se verá así desde el exterior:

¿Cómo conectar ahora?
A partir de ahora, para entrar a tu servidor por terminal, deberás especificar el puerto con el parámetro -p:

```
ssh -p 2287 tu_usuario@tu_ip_del_servidor
```
