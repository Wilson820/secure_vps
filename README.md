# secure_vps
VPS initial config and install secure. - docker environment

### 1. Ejecute install.sh
```
chmod +x install.sh && ./install.sh
```

### 2. Ejecute secure_ssh.sh
Asegure el acceso **antes** de exponer servicios en el servidor.

```
chmod +x secure_ssh.sh && ./secure_ssh.sh
```

> **Ejecútelo en una terminal interactiva.** El script crea el usuario y le pide una
> confirmación a mitad de la ejecución, así que no funciona con `curl | bash` ni con la
> entrada redirigida.

Puede cambiar el puerto y el usuario sin editar el fichero:

```
SSH_PORT=2222 SSH_USER=wilson ./secure_ssh.sh
```

**Cómo funciona (dos fases, para que sea imposible quedarse fuera):**

1. **Fase 1** — crea el usuario `admon` con sudo, comprueba que tiene una contraseña
   utilizable y pone a sshd a escuchar en el **22 y en el 2287 a la vez**. El puerto 22
   sigue abierto y root sigue pudiendo entrar: todo es reversible.
2. El script **se detiene** y le pide que abra otra terminal y verifique:
   ```
   ssh -p 2287 admon@<IP_DEL_VPS>
   sudo -v
   ```
3. **Fase 2** — solo si escribe `CONFIRMO`, cierra el puerto 22 y aplica
   `PermitRootLogin no`. Cualquier otra respuesta revierte el servidor a su estado original.

Si algo falla en cualquier punto, el script restaura la configuración anterior, reactiva
`ssh.socket` si lo había desactivado y deja el puerto 22 operativo.

### 3. Ejecute setup_npm.sh
```
chmod +x setup_npm.sh && ./setup_npm.sh
```

### 4. Instale InsForge
Siga el resumen de la sección de abajo. *(No existe un `install_insForge.sh` en este
repositorio; la instalación es manual.)*

---

## Si pierdo el acceso al VPS

El script está diseñado para que esto no ocurra, pero si se queda fuera por cualquier otro
motivo, entre por la **consola web / VNC** del panel de su proveedor y ejecute:

```bash
# 1. Ver en qué puerto escucha sshd realmente (resuelve los ficheros incluidos)
sudo sshd -T | grep -E '^(port|permitrootlogin|passwordauthentication) '

# 2. Volver a abrir el puerto 22
sudo rm -f /etc/ssh/sshd_config.d/00-secure-vps.conf
sudo cp /etc/ssh/sshd_config.<FECHA>.bak /etc/ssh/sshd_config   # ls /etc/ssh/*.bak
sudo ufw allow 22/tcp

# 3. Devolver el control a ssh.socket si estaba enmascarado (Ubuntu 24.04)
sudo systemctl unmask ssh.socket
sudo systemctl daemon-reload
sudo systemctl restart ssh

# 4. Si el problema es la cuenta admon, reponga su contraseña
sudo passwd admon
sudo passwd -S admon    # el segundo campo debe ser "P"
```

**Causa habitual del bloqueo:** en Ubuntu ≥20.04, `/etc/ssh/sshd_config` empieza con
`Include /etc/ssh/sshd_config.d/*.conf` y **gana el primer valor encontrado**, así que un
`50-cloud-init.conf` puede anular lo que se escriba al final del fichero principal. Por eso
`secure_ssh.sh` escribe en `00-secure-vps.conf` y verifica el resultado con `sshd -T` en
lugar de fiarse de `sshd -t`.

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
