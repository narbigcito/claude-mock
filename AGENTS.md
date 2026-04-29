# AGENTS.md — ClaudeMock

## Project Overview

Elixir/Phoenix 1.7 application for browsing read-only Claude conversations. Conversations are seeded from JSON files in `priv/conversations/` and edited via an admin panel. Port 4004 (not the default 4000).

## Quick Start

**Todo se ejecuta a través de Docker.** Asegúrate de tener Docker y Docker Compose instalados.

```bash
# Iniciar servicios (app + PostgreSQL)
make docker-up

# Ver logs
make docker-logs

# App disponible en http://localhost:4004
```

O manualmente con docker compose:
```bash
docker compose up -d
docker compose logs -f app
```

## Database

PostgreSQL corre dentro de Docker. No necesitas instalarlo localmente.

Configuración por defecto:
- Puerto: `5436` (mapeado desde el contenedor)
- User: `claude_mock`
- Password: `claude_mock`
- DB: `claude_mock_prod`

```bash
# Iniciar solo la base de datos (normalmente no necesario, 'make docker-up' lo hace todo)
docker compose up -d db

# Ejecutar migraciones
make migrate

# Resetear base de datos (¡cuidado, borra todo!)
make reset-db
```

## Test

**⚠️ IMPORTANTE: Siempre corre los tests localmente antes de hacer push al CI.**

```bash
# Primero asegúrate de tener la DB de test corriendo
docker compose up -d db

# Ejecutar todos los tests (recomendado antes de cada push)
mix test

# Ejecutar tests específicos
mix test test/claude_mock/accounts_test.exs
mix test test/claude_mock/accounts_test.exs:42
```

Tests run on port 4002 with `Ecto.Adapters.SQL.Sandbox`.

## Code Quality

```bash
mix format           # Format all .ex/.exs/.heex files
mix compile --warnings-as-errors
```

Formatter config: `.formatter.exs` (includes Phoenix.LiveView.HTMLFormatter).

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `lib/claude_mock/` | Core contexts: `Chats`, `Accounts`, `LLM` |
| `lib/claude_mock_web/` | Web layer: LiveViews, controllers, components |
| `lib/claude_mock_web/live/admin_live/` | Admin panel LiveViews |
| `priv/conversations/` | JSON conversation sources (seed files) |
| `priv/repo/migrations/` | Ecto migrations |

## Key Contexts

- `ClaudeMock.Chats` — Read-only conversation access, import/update via JSON
- `ClaudeMock.Accounts` — User auth with `is_admin` flag
- `ClaudeMock.LLM` — OpenAI-compatible API client (Panoptikon)

## Routes

| Path | Purpose |
|------|---------|
| `/` | Chat list (public) |
| `/c/:id` | View conversation (public) |
| `/admin` | Admin dashboard (requires auth + admin) |
| `/admin/new` | Create conversation manually |
| `/admin/from-image` | Generate conversation from image via LLM |
| `/embed/:id` | Embeddable conversation view |
| `/export/:id` | JSON export |
| `/dev/dashboard` | LiveDashboard (dev only) |

## Conversation Seeding

JSON files in `priv/conversations/` are imported on boot if `SEED_ON_BOOT=true`:

```json
{
  "title": "My Conversation",
  "model": "claude-opus-4-6",
  "messages": [
    {"role": "user", "content": "...", "position": 0},
    {"role": "assistant", "content": "...", "position": 1}
  ]
}
```

Safe to re-run: skips existing titles. Run manually:
```bash
# Development
mix run -e 'ClaudeMock.Release.seed_conversations()'

# Production release
bin/seed
```

## Makefile Commands

**Todos los comandos se ejecutan dentro de Docker.** No necesitas tener Elixir instalado localmente.

Ejecuta `make` o `make help` para ver todos los comandos disponibles.

| Comando | Descripción |
|---------|-------------|
| `make docker-up` | Inicia todos los servicios (app + PostgreSQL) |
| `make docker-down` | Detiene los servicios de Docker |
| `make docker-build` | Reconstruye la imagen Docker |
| `make docker-logs` | Muestra logs de la aplicación |
| `make docker-shell` | Abre una shell dentro del contenedor |
| `make server` | Muestra logs del servidor en http://localhost:4004 |
| `make seed` | Importa conversaciones desde `priv/conversations/` |
| `make admin` | Crea un usuario admin de forma interactiva |
| `make migrate` | Ejecuta migraciones pendientes |
| `make reset-db` | **Cuidado**: Resetea la base de datos completamente |
| `make status` | Muestra el estado de los servicios |

## Creating an Admin

**Via Makefile (interactivo - recomendado):**
```bash
make admin
# Te pedirá email y password interactivamente
# La contraseña debe tener al menos 12 caracteres
```

**Via Admin Panel:**
Once logged in as an admin, go to `/admin/users` to create new admin users.

**Via CLI manual (dentro del contenedor Docker):**
```bash
docker compose exec app /app/bin/claude_mock eval 'ClaudeMock.Release.create_admin("admin@example.com", "password123456")'
```

**Access Requirements:**
- URL: `/admin`
- Requires authentication AND `is_admin: true` flag on the user
- Non-admins are redirected to `/` with error message

## Production Release

Docker-based. Required env vars in `.env`:
- `SECRET_KEY_BASE` — Run `mix phx.gen.secret` to generate
- `DATABASE_URL` — `ecto://USER:PASS@HOST/DB`
- `PHX_HOST` — Hostname for URL generation

Optional:
- `PANOPTIKON_API_KEY` — For LLM features in admin panel
- `SEED_ON_BOOT=true` — Auto-import conversations on start

```bash
docker-compose up --build
```

Release commands available at `/app/bin/`:
- `server` — Start application
- `migrate` — Run Ecto migrations
- `seed` — Import conversations

## Mix Aliases

Defined in `mix.exs`:
- `mix setup` — Full dev setup
- `mix test` — Run tests (includes DB setup)
- `mix assets.setup` — Install Tailwind/esbuild
- `mix assets.build` — Compile assets
- `mix assets.deploy` — Minified assets for prod
- `mix ecto.setup` — Create DB, migrate, seed
- `mix ecto.reset` — Drop and re-setup DB

## Environment-Specific Notes

**Dev:**
- Live reload enabled for `.ex`, `.heex`, `.css`, `.js` files
- Email previews at `/dev/mailbox`
- Stacktraces and debug errors enabled

**Test:**
- Logger level `:warning` (quieter)
- Password hashing uses `log_rounds: 1` (faster)

**Prod:**
- Bandit server only starts with `PHX_SERVER=true`
- IPv6 binding on `{0,0,0,0,0,0,0,0}`
- Static assets are digested with `phx.digest`

## LLM Integration

Admin panel uses Panoptikon API for image-to-conversation generation:
- Config in `runtime.exs` via `PANOPTIKON_BASE_URL`, `PANOPTIKON_API_KEY`, `PANOPTIKON_MODEL`
- See `ClaudeMock.LLM` module for implementation

## Constraints

- Conversations are read-only in public UI; edits only via admin
- Embeds use a separate pipeline (no CSRF/session required)
- Admin routes require both authentication AND `is_admin: true`
