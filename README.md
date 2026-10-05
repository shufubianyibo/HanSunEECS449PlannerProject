# Course Compass ↗

A calmer coursework planner, built in **Jac 0.37.11**. Capture assignments, see your course workload, and turn a long task list into a realistic daily study plan. Web, native mobile, and terminal all use the same Jac API and SQLite database.

**Name:** Han Sun 
**UMID:** 01001584

## Quick start

Prerequisite: install the **Jac 0.37.11** standalone distribution from the [official Jac installation documentation](https://jaclang.org/docs/latest). Check `jac --version`. First launch may download Jac’s managed Postgres runtime for its internal serving infrastructure; planning records themselves use SQLite. Its bundled JavaScript runtime installs frontend dependencies; Python packages and AI API keys are not needed for this app.

From the repository root:

```sh
jac install
jac run
```

Open **http://127.0.0.1:8000**. The default app serves both the web interface and the API. Jac uses HMR by default (frontend 8000, proxied API 8001); `jac run --no-dev` serves both on port 8000. Stop with Ctrl+C. The first launch is an empty workspace; no fake assignments are inserted into your data.

## What you can do

- Add, edit, complete, reopen, delete, and search assignments; filter by course and status.
- Record deadline, priority (1 high / 2 medium / 3 low), and 5–600 estimated minutes.
- See open/completed/overdue counts and remaining course workload.
- Set a daily budget (5–720 minutes) to get a deadline-first focus plan. Ties use priority, creation time, then ID. Long tasks receive partial sessions; finished tasks are excluded.
- Use native mobile for quick capture and completion, or the CLI for fast terminal entry.
- Refresh any interface to see changes from the others. Explicit refresh bypasses the client reader cache.

The focus plan is a suggestion across **all unfinished assignments**, including upcoming ones. It does not create calendar events or deduct time automatically. Mark a task complete only when the assignment is actually finished. Dates are date-only values; “today” is the server's local date. CLI `--day` overrides the reference date for overdue reporting, not the scheduling order.

## CLI

Start `jac run` in one terminal, then in another:

```sh
jac run cli -- add "Finish Jac planner" --course "EECS 449" --due 2026-10-05 --priority 1 --minutes 90
jac run cli -- list
jac run cli -- list --all --course "EECS 449"
jac run cli -- today --budget 60
jac run cli -- done TASK_UUID
jac run cli -- reopen TASK_UUID
jac run cli -- delete TASK_UUID --yes
jac run cli -- --json list --all
jac run cli -- --help
```

Replace `TASK_UUID` with the full ID printed by `list`. Set `COMPASS_URL` or put `--server http://HOST:8000` **before** the subcommand to use another backend. `--json` is also a global option before the subcommand. Deletion requires `--yes`. Exit codes: 0 success, 1 validation/protocol failure, 2 usage, 3 connection failure.

## Mobile (React Native, not a responsive-web substitute)

`mobile/main.jac` uses Jac's `@jac/mobui` primitives (`View`, `Text`, `TextInput`, `Pressable`, `ScrollView`) and compiles to React Native through Expo. It supports a daily focus budget, listing and completing assignments, and quick capture. Full editing, reopening, and deletion live on the web/CLI.

Browser validation of the **same mobile source**:

```sh
jac run
# In a second terminal:
jac run scripts/mobile_preview.jac
```

Open **http://127.0.0.1:8012**. The helper builds the real mobile source and serves its static files and proxies API calls to the existing backend on port 8000. It does not create a second database or duplicate planning logic. Set `COMPASS_URL` before launching the preview if your backend uses another address; keep the browser preview’s Backend URL field blank (same-origin proxy). This small adapter avoids a sibling-static-asset routing problem observed in Jac 0.37.11.

Native prerequisites: Android emulator or device plus JDK 21/Android SDK (Jac setup can provision these), or macOS with Xcode and an iOS simulator. For development:

```sh
jac setup mobile
jac run --dev mobile
```

Press `a` / `i` in Expo, or use the offered Expo Go QR code. Jac 0.37.11 may also trigger a platform build while starting the development backend, so complete the platform prerequisites first. The Jac mobile development command injects a device-visible API host. For a physical phone, use a trusted Wi-Fi network; `127.0.0.1` on your phone means the phone, not your laptop. Override host discovery with `JAC_RN_DEV_HOST=YOUR_LAN_IP` when needed. Keep your existing web server running (`jac run --host 0.0.0.0` for a physical phone). In the mobile app, set **Your backend** to `http://YOUR_LAN_IP:8000` and tap **Connect to backend**; this explicitly targets the same API as web/CLI. Android emulator can use `http://10.0.2.2:8000`; iOS simulator can use `http://127.0.0.1:8000`. The manual address is session-local. See `jac guide jac-mobile-app` for current platform setup and host configuration.

Native builds (requires accepting the platform SDK licenses yourself):

```sh
jac build mobile --platform android
# macOS with Xcode:
jac build mobile --platform ios
```

Native device execution needs the platform tools and a running reachable backend; browser preview is not evidence of a successful APK/iOS build. Tested and untested paths are explicitly listed in `agent_notes/04_TEST.md`.

## Architecture and persistence

```text
Web (Jac + React) ─────────┐
Mobile (Jac + React Native)├── Jac function API ── core/planner.jac ── SQLite
CLI (Jac + HTTP) ──────────┘                         │
                                  core/task.jac + core/course.jac
```

`jac.toml` declares three apps; the default `web-app` owns and serves the shared backend. Each endpoint is explicitly imported in `web/main.jac`. Mobile calls compile to RPC; CLI calls the same HTTP endpoints. All business logic is written in Jac. SQLite and HTTP use Python's standard library through Jac interoperability.

- `POST /function/dashboard`: tasks, course statistics, focus plan.
- `POST /function/save_task`: create or update (optional `task_id`).
- `POST /function/set_done`: idempotent completion/reopening.
- `POST /function/delete_task`: deletion with missing-ID handling.
- Interactive API docs: `/docs`; transport wraps results in `data.result`. All parameters are explicit on the wire (Jac 0.37.11 has a default-parameter coercion issue). Example dashboard body: `{"day":"","budget":120,"refresh":"manual"}`. For new tasks, pass `task_id: ""` plus title/course/due/priority/minutes.

Data lives in **`data/planner.sqlite3`**, anchored to the source root. Set `COMPASS_DB=/absolute/path/planner.sqlite3` on the **server** to choose another location. SQL uses bound parameters, transactions, constraints, and a busy timeout. No client opens the database. Restarting preserves tasks; deleting source/build caches is unnecessary. Back up the data directory with the server stopped (include WAL files if present).

This is intentionally a **single-user local planner**, with public API endpoints and no account system. Default binding is `127.0.0.1`. For phone access on a trusted LAN use `jac run --host 0.0.0.0`; anyone who can reach that server can change tasks. It is not configured for public Internet hosting.

## Verification and submission

```sh
jac check
jac test -d tests
jac build web --as client
jac build mobile --platform web
# With the server running, optional Python 3 black-box integration suite:
python3 tests/integration.py
```

The `agent_notes` directory records PLAN → IMPLEMENT → AUDIT → TEST in order, including actual commands, repairs and platform limitations. Before submission, fill your name/UMID, verify your phone/emulator workflow, push the source to your own GitHub repository and submit its URL on Canvas. Build artifacts, dependencies, and personal data are ignored by `.gitignore`.

## References

Project organization and native UI conventions were learned from the official `jac create --awesome` workspace and bundled `jac guide` documentation. The coursework workflow, SQLite domain model, focus allocator, and interface are original to this project. See the [assignment](prompt/extra-credit-1.md) and [Jac documentation](https://jaclang.org/docs/latest).
