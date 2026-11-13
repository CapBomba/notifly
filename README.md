# NotiFly

A real-time notification platform built with Flutter, Supabase, Riverpod, and Drift.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter + Dart |
| State management | Riverpod (hand-written providers) |
| Authentication | Supabase Auth |
| Database | Supabase PostgreSQL |
| Real-time events | Supabase Realtime |
| Async job processing | Transactional outbox pattern |
| Offline persistence | Drift + SQLite (`drift_flutter`) |
| Local notifications | flutter_local_notifications |

## Project Structure

```
lib/
├── main.dart                        # App entry point
├── core/
│   ├── config/app_config.dart       # Supabase URL + key
│   ├── database/                    # Drift database, tables, DAOs
│   ├── notifications/               # NotificationService + payload model
│   ├── router/app_router.dart       # Declarative Navigator 2.0 router
│   ├── sync/                        # OutboxSyncService + provider
│   └── theme/app_theme.dart         # Material 3 light/dark themes
└── features/
    ├── auth/                        # Login, register, auth providers
    ├── inbox/                       # Notification list, detail, repository
    └── preferences/                 # Notification preference toggles
```

## Getting Started

### 1. Apply the database schema

Open the [Supabase SQL Editor](https://supabase.com/dashboard/project/oigwtrrjlgetxqqkwunc/sql/new)
and run the contents of:

```
supabase/migrations/001_initial_schema.sql
```

This creates:
- `profiles` — mirrors `auth.users`
- `notifications` — the main notification table
- `notification_outbox` — server-side durable event queue
- `notification_preferences` — per-user settings
- `announcements` — admin broadcast messages
- Row Level Security policies for all tables
- Realtime publication for `notifications`

### 2. Enable Realtime in the Supabase dashboard

Go to **Database → Replication** and ensure `notifications` is in the
`supabase_realtime` publication (the migration does this, but verify it's active).

### 3. Run the app

```bash
flutter run
```

Or with explicit credentials via `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://oigwtrrjlgetxqqkwunc.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_Wj88x3PZg0uGsuLHQ88G0g_UaCsqwAW
```

### 4. Code generation (Drift)

If you modify any Drift table or DAO, regenerate the `.g.dart` files:

```bash
dart run build_runner build
```

## How Notifications Work

1. **An event occurs** — a message, task update, or announcement is saved to Supabase.
2. **PostgreSQL records it** — the `notifications` row is inserted.
3. **Supabase Realtime publishes** — connected clients receive the `INSERT` event.
4. **Flutter updates the inbox** — the local Drift cache is updated; a system notification is shown if the app is foregrounded.
5. **Outbox syncs reads/deletes** — user actions are written locally first, then replayed to Supabase when connectivity is available.

### Delivery limitations (no FCM)

| App state | Delivery |
|---|---|
| Foreground | ✅ Instant via Realtime + local notification |
| Background | ⚠️ Depends on OS keeping the connection alive |
| Terminated / force-stopped | ❌ Not delivered until next app open |

This is an intentional architecture choice — no Firebase dependency.
See the Supabase connection for guaranteed background delivery if needed later.

## Supabase Project

- **URL**: `https://oigwtrrjlgetxqqkwunc.supabase.co`
- **Dashboard**: [supabase.com/dashboard/project/oigwtrrjlgetxqqkwunc](https://supabase.com/dashboard/project/oigwtrrjlgetxqqkwunc)
