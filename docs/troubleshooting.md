# Troubleshooting

## Attach fails with chrome-extension:// URL
**Error**: `Cannot access a chrome-extension:// URL of different extension`

**Fix**: Use a dedicated Chrome profile with only the OpenClaw extension enabled.

## VPS shows 0 tabs
**Symptoms**: `openclaw browser profiles` shows `chrome running (0 tabs)`.

**Fix**: Attach a tab via the extension icon. Re-attach if you restarted node host.

## Relay not reachable (Timeout)
**Error**: `Relay server not reachable at http://127.0.0.1:18792`

**Fix**:
- Re-attach the tab
- If still failing, run stop/start scripts

## EADDRINUSE 18792
**Cause**: A previous node host is still running.

**Fix**: Stop old node host or run `openclaw-stop.ps1`.

## 401 Unauthorized on /json/list
Expected: Relay uses token auth; direct curl/iwr will be denied.

## SSH tunnel fails to listen
Check SSH key auth and that `moltbook-vps` is reachable.
