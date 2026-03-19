# secure_vps
VPS initial config and install secure. - docker environment

### 1. Ejecute install.sh
```
chmod +x install.sh && ./install.sh
```

### 2. Ejecute setup_npm.sh
```
chmod +x setup_npm.sh && ./setup_npm.sh
```

### 3. Ejecute secure_ssh.sh
```
chmod +x secure_ssh.sh && ./secure_ssh.sh
```

### 4. Ejecute install_insForge.sh
```
chmod +x install_insForge.sh && ./install_insForge.sh
```

### Resumen de Instalación de InsForge (Vía [Blog Edu Navajas](https://edunavajas.com/blog/insforge-self-host))

InsForge es una alternativa open-source potente a Supabase que puedes auto-alojar para tener control total de tus datos.

**Puntos Clave del Tutorial:**
*   **Requisitos del Sistema:** Se recomienda un VPS con al menos **2GB de RAM**.
*   **Configuración Crítica (.env):**
    *   **Seguridad:** Es Vital cambiar los valores por defecto de `POSTGRES_USER` y `POSTGRES_PASSWORD`.
    *   **Claves API:** La variable `ACCESS_API_KEY` **debe** comenzar con el prefijo `ik_` (ej. `ik_hash_generado`).
    *   **Secretos:** Generar hashes largos y únicos para `JWT_SECRET` y `ENCRYPTION_KEY` usando `openssl rand -base64 64`.
*   **Almacenamiento (Storage):** El blog recomienda usar **Cloudflare R2** por su compatibilidad con S3 y su excelente capa gratuita (10GB de almacenamiento sin costo).
*   **Despliegue:** 
    *   Para producción, ejecutar: `docker compose -f docker-compose.prod.yml up -d`.
    *   **Coolify:** Se menciona como la forma más sencilla de desplegarlo con interfaz visual y HTTPS automático.
*   **Dominio y SSL:** Si no usas Coolify, se recomienda **Caddy** como reverse proxy para gestionar certificados SSL de forma automática y sencilla.

    **Despliegue con Nginx Proxy Manager**
    Configura un Hosts Proxy con los siguientes datos:
    *   **Domain Name:** tu_dominio.com o IP del servidor 
    *   **Scheme:** http
    *   **Forward Hostname / IP:** [IP_ADDRESS]
    *   **Forward Port:** 7130 Puerto configurado para insForge
    *   **SSL:** Activa el certificado SSL de Let's Encrypt. / Solo aplica si tienes dominio


# Arquitectura de Conexión Segura
Al usar Nginx Proxy Manager, tu servidor ahora se verá así desde el exterior:

¿Cómo conectar ahora?
A partir de ahora, para entrar a tu servidor por terminal, deberás especificar el puerto con el parámetro -p:

```
ssh -p 2287 tu_usuario@tu_ip_del_servidor
```
