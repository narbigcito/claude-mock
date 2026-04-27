# CI/CD - GitHub Actions

Este proyecto tiene dos workflows:

| Workflow | Cuándo corre | Qué hace |
|----------|--------------|----------|
| `ci.yml` | Push a `main` y cada Pull Request hacia `main` | Lint (`mix format --check-formatted`), compila con `--warnings-as-errors`, y corre la suite de tests con un servicio Postgres |
| `deploy.yml` | Cuando se crea un **tag** que empieza con `v` (ej: `v1.0.0`) | Verifica que el tag esté en `main`, conecta al servidor vía Cloudflare Tunnel, hace `git checkout` al tag y reconstruye los contenedores |

## 🚢 Cómo hacer un release

```bash
# 1. Asegúrate de estar en main y actualizado
git checkout main
git pull

# 2. Crea un tag siguiendo SemVer
git tag -a v1.0.0 -m "Release v1.0.0"

# 3. Empuja el tag — esto dispara el deploy
git push origin v1.0.0
```

> El deploy se aborta si el tag no es alcanzable desde `main` (`git merge-base --is-ancestor`). Eso evita publicar código que vive solo en una rama de feature.

## ⚙️ Configuración

### 1. Secrets necesarios en GitHub

Ve a tu repositorio en GitHub → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Agrega los siguientes secrets:

| Secret | Descripción | Ejemplo |
|--------|-------------|---------|
| `SSH_KEY` | Clave SSH privada (PEM format) | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `SSH_USER` | Usuario SSH del servidor | `narbigcito` |
| `DEPLOY_PATH` | Ruta absoluta donde está el proyecto en el servidor | `/srv/claude-mock` |
| `CLOUDFLARE_SERVICE_TOKEN_ID` | Token ID de Cloudflare Access | Desde el dashboard de Cloudflare |
| `CLOUDFLARE_SERVICE_TOKEN_SECRET` | Token Secret de Cloudflare Access | Desde el dashboard de Cloudflare |

### 2. Configuración de Cloudflare (ya está hecha)

El dominio `claude-mock.narbigcito.com` ya está configurado en el túnel de Cloudflare:

```yaml
- hostname: claude-mock.narbigcito.com
  service: http://localhost:4004
```

Para obtener los Service Tokens de Cloudflare:
1. Ve a [dash.teams.cloudflare.com](https://dash.teams.cloudflare.com)
2. Navega a: **Access** → **Service Auth** → **Service Tokens**
3. Copia el **Client ID** → `CLOUDFLARE_SERVICE_TOKEN_ID`
4. Copia el **Client Secret** → `CLOUDFLARE_SERVICE_TOKEN_SECRET`

### 3. Preparar el servidor para el deploy

En tu servidor de producción:

```bash
# Crear directorio del proyecto
sudo mkdir -p /srv/claude-mock
sudo chown $USER:$USER /srv/claude-mock

# Clonar el repositorio (solo la primera vez)
cd /srv/claude-mock
git clone git@github.com:tU-USUARIO/claude-mock.git .

# Crear archivo de variables de entorno
cp .env.example .env
# Editar .env con los valores de producción
nano .env

# Asegurar que existe el directorio de conversaciones
mkdir -p priv/conversations

# Asegurar que Docker está instalado y funcionando
docker --version
docker compose version
```

### 4. Variables de entorno requeridas

Crea un archivo `.env` en el servidor con:

```bash
# Base de datos
POSTGRES_USER=claude_mock
POSTGRES_PASSWORD=tu_password_seguro_aqui
POSTGRES_DB=claude_mock_prod

# Phoenix
SECRET_KEY_BASE=genera_con_mix_phx_gen_secret
PHX_HOST=claude-mock.narbigcito.com
PHX_SERVER=true
PORT=4004

# Opcional: LLM integration
PANOPTIKON_API_KEY=tu_api_key
PANOPTIKON_BASE_URL=https://panoptikon.narbigcito.com/v1
PANOPTIKON_MODEL=kimi-k2-turbo-preview

# Seeding
SEED_ON_BOOT=true
```

Para generar `SECRET_KEY_BASE`:
```bash
# En cualquier máquina con Elixir instalado:
mix phx.gen.secret
```

### 5. Permisos de Docker (opcional)

Si el usuario SSH no es root, asegúrate de que esté en el grupo docker:

```bash
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar para aplicar cambios
```

## 🚀 Cómo funciona el deploy

Cuando empujas un tag `v*`:

1. GitHub Actions verifica que el commit del tag exista en `main`
2. Se conecta al servidor vía Cloudflare Tunnel
3. Ejecuta `git fetch --tags --force` y `git checkout` al tag exacto
4. Ejecuta `docker compose -f docker-compose.prod.yml up -d --build`
5. Limpia imágenes antiguas de Docker
6. Verifica que el contenedor está corriendo

La aplicación usa Traefik (ya corriendo en el servidor) para:
- SSL automático con Let's Encrypt
- Redirección HTTP → HTTPS
- Routing basado en hostname

## 📊 Ver logs del deploy

En GitHub:
- Ve a **Actions** → selecciona el workflow más reciente → **Deploy to Production Server**

En el servidor:
```bash
# Ver logs de los contenedores
docker compose -f docker-compose.prod.yml logs -f

# Ver estado
docker ps

# Ver logs solo de la app
docker logs -f claude-mock
```

## 🔄 Deploy manual (si es necesario)

Si necesitas hacer deploy manualmente:

```bash
ssh usuario@ssh.narbigcito.com
cd /srv/claude-mock
git pull origin main
docker compose -f docker-compose.prod.yml up -d --build
```

## 🛠️ Troubleshooting

### Error: "Permission denied (publickey)"
- Verifica que el secret `SSH_KEY` esté correctamente configurado
- Asegúrate de que la clave pública está en `~/.ssh/authorized_keys` en el servidor
- Verifica que el usuario en `SSH_USER` tiene permisos

### Error: "docker: command not found"
- Asegúrate de que Docker está instalado en el servidor
- Si el usuario no es root, verifica que esté en el grupo `docker`

### Error: "No such file or directory" en DEPLOY_PATH
- Verifica que la ruta en `DEPLOY_PATH` existe en el servidor
- Asegúrate de que el usuario tiene permisos para acceder a esa ruta

### Error: "network panoptikon_panoptikon-net not found"
- Asegúrate de que Traefik está corriendo (viene de panoptikon)
```bash
docker network ls | grep panoptikon
docker ps | grep traefik
```

### Error: "failed to verify certificate"
- Verifica que los secrets `CLOUDFLARE_SERVICE_TOKEN_ID` y `CLOUDFLARE_SERVICE_TOKEN_SECRET` son correctos

## 📝 Notas

- El workflow de deploy usa **concurrency** (`cancel-in-progress: false`): si llegan dos tags casi simultáneos se ejecutan en orden, no se cancelan entre sí
- El workflow de CI sí cancela ejecuciones anteriores del mismo branch/PR cuando llega un commit nuevo
- El deploy hace `git checkout` al tag exacto, así el servidor siempre corre una versión nombrada (no un commit suelto)
- Las imágenes antiguas de Docker se limpian automáticamente después del deploy
- La base de datos persiste en un volumen Docker llamado `db_data`
- Las conversaciones se leen desde `./priv/conversations` (montado como volumen read-only)
