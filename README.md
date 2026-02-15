# OpenClaw Browser Relay (VPS -> Local Chrome)

Remote OpenClaw on a VPS controlling **your local Google Chrome tabs** via the OpenClaw Browser Relay extension.

This repo packages a repeatable, secure-ish workflow with one-click start/stop scripts and a dedicated Chrome profile strategy.

## What this does

- VPS runs OpenClaw Gateway (loopback-only)
- Local Windows node host connects via SSH tunnel
- Local relay listens on `127.0.0.1:18792`
- Chrome extension attaches to a tab and exposes CDP to OpenClaw

## Security warning

- Keep the Gateway **loopback-only** on the VPS.
- Never commit `~/.openclaw/openclaw.json` or any tokens/API keys.
- Relay is **loopback-only** (`127.0.0.1:18792`); do not expose it to LAN/WAN.

## Why a dedicated Chrome profile

Other extensions inject `chrome-extension://` iframes/scripts, which breaks attach. Use a dedicated profile **with only OpenClaw Browser Relay enabled**.

## Quick Start

See `docs/quickstart.md` for the full step-by-step.

### 1) VPS (one-time)

```bash
openclaw config set gateway.nodes.browser.mode auto
openclaw gateway restart
```

### 2) Local (one-time)

Install the extension path (official OpenClaw extension):

```bash
openclaw browser extension install
openclaw browser extension path
```

Then in Chrome:
- `chrome://extensions`
- Developer mode ON
- Load unpacked -> extension path above

### 3) Daily use

Start everything:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\openclaw-start.ps1
```

Attach manually:
- Open a tab in the **dedicated profile**
- Click the OpenClaw Browser Relay icon (badge ON)

Verify from VPS:

```bash
openclaw browser tabs
openclaw browser snapshot
```

Stop everything:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\openclaw-stop.ps1
```

## Script parameters

`openclaw-start.ps1` parameters (optional):
- `-VpcHost` (default: `moltbook-vps`)
- `-GatewayPort` (default: `18789`)
- `-LocalGatewayPort` (default: `18790`)
- `-NodeDisplayName` (default: `win10`)
- `-ChromeProfileDir` (default: `openclaw\chrome-profile-openclaw`)
- `-ChromeUrl` (default: `https://example.com`)
- `-WarmupRelay` (default: `$true`)

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\openclaw-start.ps1 -VpcHost my-vps -NodeDisplayName my-laptop -ChromeUrl https://x.com
```

## Docs

- `docs/quickstart.md`
- `docs/architecture.md`
- `docs/troubleshooting.md`
- `docs/security.md`

## License

MIT. See `LICENSE`.
