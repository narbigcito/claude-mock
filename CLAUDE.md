# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Elixir/Phoenix 1.7 app that displays read-only Claude conversations. Runs on port **4004** via Docker. Full project context is in `AGENTS.md`.

## Commands

All commands run inside Docker — Elixir does not need to be installed locally.

```bash
make docker-up        # Start app + PostgreSQL
make docker-logs      # Tail application logs
make docker-shell     # Shell inside container
make migrate          # Run pending migrations
make seed             # Import JSON conversations
make admin            # Create admin user (interactive)
make reset-db         # Drop and recreate DB (destructive)
```

Code quality (run inside container or locally if Elixir is available):
```bash
mix format                          # Format .ex/.exs/.heex
mix compile --warnings-as-errors    # Strict compilation check
mix test                            # Run all tests (auto-creates/migrates test DB)
mix test path/to/file_test.exs:42   # Run single test by line
```

## Architecture

Two OTP applications under `lib/`:

- **`claude_mock/`** — business logic contexts:
  - `Chats` — conversation CRUD + JSON import/export; public UI is read-only, writes go through admin
  - `Accounts` — phx.gen.auth users with an `is_admin` boolean
  - `LLM` — thin Req client for an OpenAI-compatible provider (Panoptikon); converts screenshot → conversation JSON

- **`claude_mock_web/`** — Phoenix web layer:
  - `live/` — LiveViews for public chat browsing (`ChatLive`) and admin panel (`admin_live/`)
  - `controllers/` — `EmbedController` handles `/embed/:id` and `/export/:id` (no CSRF/session pipeline)
  - `components/` — shared HEEx components including `chat_components.ex` for message rendering

## Key Patterns

- **Conversation import**: `Chats.import_conversation/1` accepts the same JSON shape stored in `priv/conversations/*.json`. `update_conversation/2` replaces title + all messages atomically via `Ecto.Multi`.
- **Admin auth**: `UserAuth.ensure_admin` on_mount plug checks `current_user.is_admin`; non-admins are redirected to `/`.
- **Embed pipeline**: `/embed` and `/export` scopes use a separate `:embed` pipeline (no CSRF), so those routes work in iframes.
- **Markdown**: `ClaudeMockWeb.Markdown` wraps Earmark; used in chat components to render assistant messages.
- **Seeding**: `SEED_ON_BOOT=true` in env triggers `ClaudeMock.Release.seed_conversations/0` on startup; safe to re-run (skips existing titles).

## Environment Variables

Required in production (`.env`):
- `SECRET_KEY_BASE` — generate with `mix phx.gen.secret`
- `DATABASE_URL` — `ecto://USER:PASS@HOST/DB`
- `PHX_HOST` — hostname for URL generation

Optional:
- `PANOPTIKON_BASE_URL`, `PANOPTIKON_API_KEY`, `PANOPTIKON_MODEL` — enables LLM image-to-conversation feature
- `SEED_ON_BOOT=true` — auto-import conversations on start
