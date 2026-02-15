# Architecture

## Components
- **VPS**: OpenClaw Gateway (loopback-only)
- **Local**: OpenClaw Node Host + Browser Relay
- **Chrome**: OpenClaw Browser Relay extension attached to a tab

## Ports
- Gateway: `18789` (VPS loopback)
- SSH tunnel: `127.0.0.1:18790` -> VPS `127.0.0.1:18789`
- Relay: `127.0.0.1:18792`

## Flow
1. Local opens SSH tunnel to VPS (port forward).
2. Node host connects to Gateway via tunnel.
3. Node host spins up relay on 18792.
4. Extension connects to relay and attaches a tab.
5. VPS OpenClaw calls `openclaw browser ...` which routes to the node.

## Profiles (OpenClaw side)
- `openclaw`: OpenClaw managed browser
- `chrome`: extension relay profile (your existing Chrome tabs)
