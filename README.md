# Androidex

Androidex is a self-hosted, multi-client interface for a shared Codex runtime.
It lets you start a coding session in the React web app, continue it from the
Flutter app, and join the same live conversation from the official Codex TUI.

The Go bridge keeps every client attached to one Codex `app-server`, so messages,
streaming output, tool activity, approvals, authentication, and turn state stay
synchronized in real time. Codex itself remains on the workstation or development
server; clients connect over a trusted LAN, VPN, or SSH tunnel.

## Clients

| Client | Best for | Highlights |
| --- | --- | --- |
| React web app | Desktops and any device with a browser | Responsive chat UI, URL-addressable sessions, workspace selection, approvals, and device sign-in |
| Flutter app | Phones and tablets | Swipeable sessions, searchable and reorderable session picker, keyboard-safe composer, split landscape layout, and Android background connectivity |
| Codex TUI | Terminal workflows | Connects directly to the shared app-server through `codex --remote` or the installed shell wrapper |

All three clients can participate in the same active conversation. Thread history
continues to be stored and owned by Codex rather than Androidex.

## Features

### Shared Codex experience

- Create, discover, rename, and resume sessions across multiple workspaces.
- Stream assistant responses, reasoning summaries, command output, tool activity,
  file changes, interruptions, and turn status as they happen.
- Keep active turns and pending approvals available after a client reconnects.
- Interrupt a running turn from the web app, Flutter app, or connected terminal.
- Respond to command approvals, file-change approvals, permission requests, user
  questions, and MCP elicitations away from the host machine.
- Complete OpenAI device authentication from a connected client when the shared
  Codex login is missing or expired.
- Select new-conversation workspaces with server-backed path completion.

### Web app

- React 19 and Vite interface served directly by the Go service in production.
- Explicit session URLs that restore the selected thread on refresh or sharing.
- Session picker with active-state indicators and rename controls.
- Markdown messages, copyable code blocks, and expandable command output.
- Responsive layouts for desktop, tablet, and mobile browsers.
- Real-time recovery of active turns and unresolved approval prompts without
  interval polling.

### Flutter app

The Android-first Flutter client lives in [`mobile/`](mobile/). It uses the same
bridge API and live protocol as the web app.

- Swipe horizontally between full-screen sessions across all workspaces.
- Search, rename, and drag to reorder sessions; custom ordering is persisted on
  the device.
- Keep separate message drafts per session while moving between conversations.
- Use a fixed, safe-area-aware composer that stays above the Android keyboard and
  becomes an interrupt control while Codex is working.
- View Markdown responses, command results, live activity, and approval cards.
- Use two independent conversation panes on wide landscape and tablet layouts.
- Configure and persist the bridge URL from inside the app.
- Optionally keep live WebSocket sessions connected in the Android background
  through a foreground-service notification.

## Architecture

```text
 React web app ───── HTTP + SSE + WebSocket ─┐
                                             │
 Flutter app ─────── HTTP + SSE + WebSocket ─┼──> Go bridge
                                             │        │
                                             │        ├── serves the built React app
                                             │        │
                                             │        └── WebSocket RPC ──> Codex app-server
                                             │                                  ▲
 Codex TUI ──────────────────────────────────┴──── codex --remote ───────────────┘
```

The Go bridge starts a Codex app-server when none is available, or reconnects to
an already-running compatible process. It translates client actions into the
app-server protocol and broadcasts notifications and runtime snapshots to every
subscribed client.

Stored thread history is supplemented with live command and tool events that are
not always present in the app-server's thread projection. This preserves the
event order clients saw while a turn was running and allows state to be rebuilt
after a reconnect.

## Repository layout

| Path | Responsibility |
| --- | --- |
| `src/` | React web interface, transcript rendering, session and workspace selection, and approval controls |
| `mobile/` | Flutter client, shared API models, Android integration, and Flutter tests |
| `server/` | Go HTTP/SSE/WebSocket bridge and Codex app-server protocol client |
| `scripts/install.sh` | Linux systemd-user and macOS LaunchAgent installation |
| `scripts/install-shell-wrapper.sh` | Idempotent zsh, bash, and fish integration for shared terminal sessions |
| `INSTALL.md` | Production installation, configuration, security, updates, and troubleshooting |

## Development

### Web app and bridge

Install the Node dependencies, then start the Go bridge and Vite in separate
terminals:

```bash
npm ci
npm run dev:server
```

```bash
npm run dev
```

Open `http://localhost:40000`. Vite proxies API and WebSocket traffic to the Go
bridge on port `40001`; the shared Codex app-server uses loopback port `40002` by
default.

| Command | Purpose |
| --- | --- |
| `npm run dev` | Start the Vite development server |
| `npm run dev:server` | Run the Go bridge from source |
| `npm run build` | Build the production React assets |
| `npm run server` | Run the bridge with the built web app |

### Flutter app

Start the Go bridge first. The default Flutter configuration connects an Android
emulator to the host at `http://10.0.2.2:40001`:

```bash
cd mobile
flutter pub get
flutter run
```

For a physical device, provide a bridge address reachable from that device:

```bash
flutter run --dart-define=CODEX_SERVER_URL=http://SERVER:40001
```

The address can also be changed later in the app's settings. Verify the Flutter
client with:

```bash
flutter analyze
flutter test
```

See [`mobile/README.md`](mobile/README.md) for Android networking and release
build notes.

## Shared terminal sessions

All clients must connect to the same app-server process to share live state.
Browser and Flutter clients do this through the Go bridge. Terminal clients use
Codex's `--remote` option or the shell wrapper installed by Androidex.

The wrapper sends the invoking shell's current directory as the remote Codex
working directory unless `-C` or `--cd` is supplied. Administrative commands
such as `codex login`, `codex logout`, `codex auth`, `codex app-server`, and
`codex exec` continue to use the local CLI path.

Resuming a stored thread with an independent Codex process does not join the
shared runtime. That process will not receive Androidex messages, approvals, or
live turn updates.

## Installation

See [`INSTALL.md`](INSTALL.md) for the complete deployment runbook. A production
installation builds the React assets, installs the Go bridge as a user service,
starts the loopback-only Codex app-server, and optionally adds the shared-runtime
shell wrapper.

## Security

Androidex does not provide application-level access control. OpenAI device
authentication authorizes the Codex account; it does not protect access to the
Androidex web, API, or WebSocket endpoints.

Anyone who can reach the Go bridge can interact with Codex using the service
user's permissions and configured workspaces. Expose port `40001` only on a
trusted LAN or private VPN, or place an authenticated HTTPS reverse proxy in
front of it. Keep the Codex app-server on loopback and never expose port `40002`
directly. Remote terminal clients should reach it through an SSH tunnel.

## Project status

Codex app-server's TCP WebSocket transport and remote terminal mode are
experimental. Protocol changes in new Codex CLI releases may require bridge
updates. The Go bridge is the only component intended to be reachable from other
machines.
