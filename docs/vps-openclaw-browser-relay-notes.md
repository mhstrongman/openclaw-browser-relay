# VPS OpenClaw 控制本地 Chrome（Browser Relay）全程梳理

**用途**
用于在 VPS 上运行的 OpenClaw 主代理，通过本地 Chrome 扩展（OpenClaw Browser Relay）控制本地 Chrome 标签页，便于远程任务操作与自动化。

**核心诉求**
- 使用本机已安装的 Google Chrome（不使用 Chrome for Testing）。
- 日常化、规范化，尽量一键启动；实际控制时由用户手动点击扩展 attach。

## 架构与数据流（官方 Gateway + Node Host 模式）

VPS 端：
- OpenClaw Gateway（默认 18789），配置 `bind=loopback`。

本地端：
- OpenClaw Node Host 连接到 VPS Gateway（通过 SSH 隧道）。
- Node Host 在本机启动 Browser Relay（默认 18792）。
- Chrome 扩展连接到 `127.0.0.1:18792`，转发 CDP 到 OpenClaw。

**数据流**
- VPS OpenClaw -> Gateway（18789）
- 本地 SSH 隧道 -> 127.0.0.1:18790（转发到 VPS 18789）
- Node Host 通过 18790 连接 Gateway
- Relay 在本地 18792 监听，扩展 attach 后转发 CDP

## 端口与关键配置

- VPS Gateway：`18789`（loopback，仅 VPS 本机可达）
- 本地 SSH 隧道：`127.0.0.1:18790` -> VPS `127.0.0.1:18789`
- 本地 Relay：`127.0.0.1:18792`

**OpenClaw 内部规则**
- Browser control 的默认 `controlPort` 基于 gateway 端口派生。
- Chrome 扩展 relay 的默认端口 = `controlPort + 1`。
- 默认存在内置 profile：
  - `openclaw`（OpenClaw 自管浏览器）
  - `chrome`（Browser Relay 方式，控制用户 Chrome 标签）

## VPS 一次性设置

```bash
openclaw config set gateway.nodes.browser.mode auto
openclaw gateway restart
```

说明：允许 gateway 自动路由到具备 browser 能力的节点。

## 本地一次性准备

**安装扩展**
```bash
openclaw browser extension install
openclaw browser extension path
```

然后在 Chrome：
- 打开 `chrome://extensions`
- 开启开发者模式
- Load unpacked 指向扩展目录

**强烈推荐：专用 Chrome Profile**
原因：其他扩展会注入 `chrome-extension://` iframe/script，导致 attach 失败。

常见报错：
- `[attach] Cannot access a chrome-extension:// URL of different extension URL`

解决方案：
- 使用专用 profile，仅启用 OpenClaw 扩展（禁用其他扩展）

## 一键脚本

路径：`openclaw/scripts/openclaw-start.ps1`

功能：
- 自动建立 SSH 隧道
- 读取 VPS token
- 启动 node host
- 打开专用 Chrome profile

核心逻辑（已实现）：
- 自动读取 `~/.openclaw/openclaw.json` 中 gateway token
- 设置 `OPENCLAW_GATEWAY_TOKEN`
- 清理代理环境变量
- 识别并清理旧的 node host 进程
- SSH 连接使用：
  - `ExitOnForwardFailure=yes`
  - `BatchMode=yes`
  - `ConnectTimeout=5`
- 自动打开专用 profile（默认目录 `openclaw/chrome-profile-openclaw`）
- 若扩展未安装，会自动打开 `chrome://extensions`

**停止脚本**
路径：`openclaw/scripts/openclaw-stop.ps1`

功能：
- 关闭 SSH 隧道
- 关闭 node host

## 日常使用流程（最短路径）

1. 运行一键启动脚本
```powershell
powershell -ExecutionPolicy Bypass -File .\openclaw\scripts\openclaw-start.ps1
```

2. 在专用 profile 中打开任意页面

3. 点击扩展图标 attach（徽标变为 ON）

4. 在 VPS 端检查 tab
```bash
openclaw browser tabs
```

5. 进行控制/截图
```bash
openclaw browser snapshot
```

## 常见问题与排查

**1. attach 失败（扩展报错）**
- 报错：`Cannot access a chrome-extension:// URL of different extension`
- 原因：其他扩展注入 `chrome-extension://` iframe
- 解决：专用 profile，只保留 OpenClaw 扩展

**2. VPS 显示 0 tabs**
- 表现：`openclaw browser profiles` 显示 `chrome running (0 tabs)`
- 说明：relay 正常，但没有 attach 的 tab
- 解决：确认扩展已 attach；必要时重新 attach

**3. Relay 无法访问 / 超时**
- 报错：`[relay] Relay server not reachable at http://127.0.0.1:18792 (TimeoutError)`
- 常见原因：
  - node host 短暂卡住
  - SSH 隧道不稳定
- 快速恢复：
  - 重新 attach
  - 或运行 stop/start 脚本重启

**4. EADDRINUSE：端口冲突**
- 报错：`listen EADDRINUSE 127.0.0.1:18792`
- 原因：旧 relay 未清理
- 解决：kill 旧 node host 或执行 stop 脚本

**5. 401 Unauthorized**
- 访问 `http://127.0.0.1:18792/json/list` 返回 401
- 原因：relay 有 token 认证，属于正常现象

**6. SSH 隧道失败**
- 报错：`SSH tunnel failed to listen` 或 `ssh exited`
- 解决：确认本地 SSH key 已免密登录 `moltbook-vps`

## 验证成功标志

在 VPS 执行：
```bash
openclaw browser tabs
```
返回格式示例（表示成功）：
- `1. X ...`
- 显示 tab 标题、URL、id

## 已做的扩展小改动（本地调试增强）

- 扩展 Options 页增加 `Last attach error` 显示
- background.js 增加 attach 兼容逻辑（避免部分页面 attach 失败）

## 最终达成效果

- VPS 能看到本地 Chrome tab
- `openclaw browser snapshot` 能抓取页面 DOM
- 日常使用只需：一键启动 + 手动 attach

---

**官方参考（放入 X 长文可引用）**
```text
https://docs.openclaw.ai/cli/browser
```
