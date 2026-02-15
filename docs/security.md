# Security Notes

- **Never** commit `~/.openclaw/openclaw.json` or any token/API key.
- Keep Gateway **loopback-only** on VPS.
- Relay is loopback-only on local machine (127.0.0.1:18792).
- Use a dedicated Chrome profile for control to reduce extension cross-talk.
- If you expose relay to LAN, you must add additional auth and firewall rules.
