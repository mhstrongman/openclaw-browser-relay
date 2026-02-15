# Quickstart

## Prereqs
- VPS with OpenClaw Gateway running
- Local Windows machine with OpenClaw CLI installed
- SSH key auth from local to VPS (no password prompt)
- Google Chrome installed locally

## One-time setup (VPS)

```bash
openclaw config set gateway.nodes.browser.mode auto
openclaw gateway restart
```

## One-time setup (Local)

Install the extension files:

```bash
openclaw browser extension install
openclaw browser extension path
```

Load extension in Chrome:
- Open `chrome://extensions`
- Enable Developer mode
- Click `Load unpacked` and select the printed path

## Daily use

Start tunnel + node host + Chrome:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\openclaw-start.ps1
```

Attach a tab:
- Use the **dedicated Chrome profile**
- Open any page
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
