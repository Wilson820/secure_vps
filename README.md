# secure_vps
VPS initial config and install secure. - docker environment

### 1. Ejecute install.sh
```
chmod +x install.sh & ./install.sh
```

### 2. Ejecute setup_npm.sh
```
chmod +x setup_npm.sh & ./setup_npm.sh
```

### 3. Ejecute secure_ssh.sh
```
chmod +x secure_ssh.sh & ./secure_ssh.sh
```

# Arquitectura de Conexión Segura
Al usar Nginx Proxy Manager, tu servidor ahora se verá así desde el exterior:

¿Cómo conectar ahora?
A partir de ahora, para entrar a tu servidor por terminal, deberás especificar el puerto con el parámetro -p:

```
ssh -p 2287 tu_usuario@tu_ip_del_servidor
```
