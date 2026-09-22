# TV Remote as a Voice Keyboard

Turn a cheap Xiaomi TV Bluetooth voice remote into a **wireless voice keyboard**
for Windows: hold the mic key and your dictation engine wakes up *and* hears the
remote's microphone. Every other button is remappable (single / double / long
press).

> **In short:** hold 【mic】 → the input method opens and records from the remote → release → text appears.

```text
  [Xiaomi BLE voice remote]
        │  BLE
        ├── HID  (buttons)  ──► bridge app ──► your own key mapping / shortcuts
        └── ATVV (voice)    ──► bridge app ──► VB-CABLE ──► Windows default mic ──► dictation
                                                    ▲
   the remote's mic key also has to look like a REAL Right Alt to the IME  ◄── driver-level remap
```

## Why this repo exists

The same use case is sold commercially as small "keyboard/microphone" or
"voice-remote" gadgets. Those are fine products — but if you already own (or can
buy for a few dollars) a Xiaomi TV voice remote, you can get the same workflow,
and you get something the gadgets don't: **every button is scriptable**.

This repository is the **field-tested recipe** (setup steps, config files, helper
scripts and the pitfalls) — the actual bridge software is a separate
open-source project (see [THIRD_PARTY.md](THIRD_PARTY.md)).

## What it is

* A documented, reproducible Windows setup: pairing, bridge app, virtual audio
  cable, and per-button mapping.
* Two small helper scripts: a prerequisite checker and a **reversible**
  keyboard-remap tool.
* A record of what actually works (and what silently doesn't) when you inject
  keystrokes into modern IMEs and Electron-style desktop apps.

## What it is not

* It does **not** redistribute the bridge app, the virtual audio cable driver, or
  any IME. You download those from their official sources.
* It is **not** affiliated with, sponsored by, or endorsed by any vendor
  mentioned here (Xiaomi, ByteDance/Doubao, Ulanzi, VB-Audio, Microsoft…). See
  [THIRD_PARTY.md](THIRD_PARTY.md) for the legal notes and trademarks.
* It does not replace the remote as a TV remote — a BLE remote pairs with one
  host at a time, so re-pair it with the TV if you still need that.

## Requirements

| | |
|---|---|
| Remote | Xiaomi Bluetooth **voice** remote. Verified: 12-key standard model and 2 Pro / RC003 (VID `0x2717`, PID `0x32B8`). **BLE only — no USB receiver exists**, a charging cable does not expose it. |
| Remote must expose voice | The device tree must contain the ATVV service `AB5E0001-5A21-4F05-BC7D-AF01F617B664` (Android-TV Voice-over-BLE). No ATVV = no microphone, no matter what else you do. |
| PC | Windows 10 1809+ / Windows 11 with a working Bluetooth radio |
| Dictation engine | Any IME/typing tool with a hold-to-talk hotkey (Doubao IME, Windows `Win+H`, …). Cloud engines send your audio to their vendor. |
| Admin once | Installing the virtual audio driver and writing the keyboard remap need elevation. |

## Quick start

### 1. Pair the remote

Hold **【Home】+【Menu】for 3–5 s**, then *Settings → Bluetooth & devices → Add
device → Bluetooth* on Windows and pick `小米蓝牙语音遥控器`.

Verify (PowerShell):

```powershell
Get-PnpDevice | Where-Object { $_.InstanceId -match 'VID_2717' -or $_.FriendlyName -match '遥控|MI RC' } |
  Select-Object Status, Class, FriendlyName, InstanceId
```

You want to see `VID&012717_PID&32B8` and the ATVV service UUID in the same
device tree. `scripts/check-prereqs.ps1` does this check for you.

### 2. Install the bridge app (Remote Mic · RC003)

Download the **official release** and, before running it, verify the SHA-256
against the release's `SHA256SUMS.txt`:

```
55660a5c514ef851ffb39a97b6711758ab7ff7882e1a1b455267be95a7322293  RemoteMicRC003Setup-0.1.0-candidate-unsigned.exe
```

```powershell
RemoteMicRC003Setup.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

It installs per-user to `%LOCALAPPDATA%\RemoteMic\RC003`. It is **unsigned**, so
Defender may flag it as a PUA heuristic — see Troubleshooting.

### 3. Install a virtual audio cable (VB-CABLE)

Install VB-Audio's official package as administrator (the Remote Mic bundle
contains the unmodified official ZIP, hash below), then reboot when convenient:

```
b950e39f01af1d04ea623c8f6d8eb9b6ea5c477c637295fabf20631c85116bfb  VBCABLE_Driver_Pack45.zip
VBCABLE_Setup_x64.exe -i -h     :: silent install
```

You should now have `CABLE Input` (playback side) and `CABLE Output` (recording
side).

### 4. Configure the bridge

Copy `config/config.example.json` to `%LOCALAPPDATA%\RemoteMic\RC003\config.json`
and `config/key_bindings.example.json` to `…\RC003\key_bindings.json`.

Then set **Windows' default recording device to `CABLE Output`** (most IMEs
follow the system default). Keep the IME's own hold-to-talk hotkey aligned with
`voice_hotkey` (`ralt` for hold-to-talk, `ralt+space` for the toggle variant).

### 5. Remap the mic key at the driver level (the actual trick)

The bridge can already turn the mic key into a synthetic Right Alt. **Almost every
modern IME ignores synthetic keys** (`LLKHF_INJECTED`), so that alone gets you
nothing. A driver-level scancode remap produces a keystroke the IME accepts as
physical:

```powershell
# elevated PowerShell — backs up the key first, prints the rollback command
powershell -ExecutionPolicy Bypass -File scripts/apply-scancode-map.ps1
# reboot to take effect
```

What it writes (20 bytes, `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout`,
value `Scancode Map`):

```
00 00 00 00 | 00 00 00 00 | 02 00 00 00 | 38 E0 3F 00 | 00 00 00 00
 version      flags         entries       F5 → RightAlt   terminator
                                        (new E0 38, old 3F 00)
```

So: remote's mic key (scan code `0x3F`) → real **Right Alt** (extended `0x38`).
Trade-off: your keyboard's F5 becomes Right Alt too — use `Ctrl+R` to refresh in
browsers. Rollback: `…apply-scancode-map.ps1 -Rollback`, then reboot.

### 6. Run it

```powershell
# start the bridge (detached, no console window)
cmd /c start "" "$env:LOCALAPPDATA\RemoteMic\RC003\RemoteMicRC003.exe" --bridge
```

Autostart: put a shortcut to `…\RemoteMicRC003.exe` with the argument `--bridge`
in `shell:startup`.

### 7. Verify

Hold the mic key and say something. Evidence that it really worked (not just
"the UI looked fine"):

```
%LOCALAPPDATA%\RemoteMic\RC003\logs\app.log
  startup: exactly one RC003 candidate resolved
  voice capabilities received: version=0x0100 sample_rate=16000.0 frame_size=120
  voice PCM summary: … result=signal
```

## Button mapping and gestures

`key_bindings.json`:

```json
{
  "schema_version": 1,
  "bindings":            { "left": { "kind": "arrow_left",  "keys": [] },
                           "menu": { "kind": "key_combo",   "keys": ["ctrl", "k"] } },
  "secondary_bindings":  { "left": { "long_press": { "kind": "key_combo", "keys": ["ctrl", "k"] } },
                           "back": { "long_press": { "kind": "key_combo", "keys": ["escape"] } } },
  "physical_bindings":   {}
}
```

* Button ids: `mic power up down left right ok back volume_up volume_down home menu tv`
* Actions: `voice escape return arrow_up/down/left/right delete_backward
  show_desktop context_menu app_switcher system_volume_up/down`, or any chord via
  `key_combo` + `keys`
* Key tokens: `ctrl shift alt win lctrl ralt pageup pagedown comma slash f1..f24 a-z 0-9 vk_xx`
* **Gesture cost (measured):** binding a *double click* delays the single click by
  **300 ms**; a *long press* fires at **0.55 s** and does not slow single clicks.
  If you want a snappy single click, use long press instead of double click.
* The mapping file is **hot-reloaded** — no bridge restart needed.

## Desktop-app shortcuts: measured, not guessed

Injecting keystrokes into an Electron/Chromium app works (a synthetic `Ctrl+K`
opens a command palette), but not every chord behaves the way the app's docs
suggest:

| Chord | Result when injected |
|---|---|
| `Ctrl+K` (command palette / search) | ✅ works, and the palette is navigable with ↑/↓ + Enter — the most reliable "switch conversation / search" entry point |
| `Ctrl+Tab`, `Ctrl+PageUp/Down` (next/previous conversation) | ❌ no effect in the app tested (hijacked by its own tab-cycling logic) |
| `Ctrl+1..9` (jump to Nth conversation) | ❌ no effect |
| `Ctrl+Shift+F` (sidebar search) | ⚠️ opens, but the result list ignores ↑/↓ |
| `Esc` | ⚠️ closes overlays **and** interrupts whatever the agent/app is running — never bind it to a single click |

A layout that works well in practice:

```
single ←/→  = arrow left/right        (cursor movement, instant)
long   ←/→  = Ctrl+K  (open palette)  → ↑/↓ to choose → OK to open
single  ↑/↓ = arrow up/down
single  Menu = Ctrl+K        long Menu = Ctrl+Shift+F
single  Back = Backspace     long  Back = Esc (close overlay)
OK = Enter   Volume ± = system volume   Home = show desktop   Power = Esc
```

## Troubleshooting

| Symptom | Real cause | Fix |
|---|---|---|
| Works, then after a reboot the input method wakes up but **no audio** | Windows Defender quarantined the unsigned bridge exe as a PUA | `Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\RemoteMic"` + `-ExclusionProcess RemoteMicRC003.exe`, reinstall from the verified installer |
| Log stops, process gone | the bridge was started inside a short-lived shell/session | start it detached (`cmd /c start "" … --bridge`) or from `shell:startup` |
| Mic key does nothing at all | remote not connected / bridge not running / `output_endpoint_name` empty (fails closed) | check the log for a fresh `startup:` line; confirm the endpoint name matches the MME truncated name exactly |
| IME shows "recording failed" | after a show-desktop round-trip the app has no editable focus | click into the text field first |
| A USB mic disappeared from the device list | some USB audio devices don't re-enumerate after a reboot | unplug/replug the USB receiver |
| Text appears but is garbled | wrong mic routing (IME still on the headset mic) | set the dictation engine's input (or the system default) to `CABLE Output` |

## Legal

See [THIRD_PARTY.md](THIRD_PARTY.md). Short version: no third-party software is
bundled; trademarks belong to their owners; this project is independent and
merely interoperates with them. Read the safety notes before applying the
registry remap.

## License

MIT — see [LICENSE](LICENSE). Contributions welcome, especially device reports
(other remotes, other IMEs, other desktop apps).

---

## 中文说明

把几十块的小米电视蓝牙语音遥控器，变成电脑上的**无线语音键盘**：按住话筒键
→ 输入法被唤醒 **并且** 听到的是遥控器的麦克风 → 松手出字。其余按键全部可自定义
（单击 / 双击 / 长按三档）。

### 为什么会有这个仓库

同样的使用场景，市面上有厂商做成了小硬件（"键盘麦克风 / 语音遥控器"形态）。
它们是不错的产品；但如果你手边有（或几块钱能买到）小米电视的语音遥控器，就能
得到同样的体验，而且多一样它们没有的东西：**每个按键都能脚本化**。

本仓库是**真机踩过的完整配方**：安装步骤、配置模板、辅助脚本和坑清单。桥接程序
本身是另一个开源项目（见 [THIRD_PARTY.md](THIRD_PARTY.md)），不在本仓库内分发。

### 三步走

1. **配对**：同时长按【主页】+【菜单】3~5 秒 → Windows 蓝牙里添加
   「小米蓝牙语音遥控器」。用 `scripts/check-prereqs.ps1` 确认设备树里有
   `VID&012717_PID&32B8` 和 ATVV 服务 `AB5E0001-…`（**没有 ATVV 就没有麦克风**）。
2. **装两样东西**：桥接程序 Remote Mic（官方 Release，先核对 SHA-256）+
   虚拟声卡 VB-CABLE（官方包，静默安装 `VBCABLE_Setup_x64.exe -i -h`）。
   然后把 **Windows 默认录音设备设为 `CABLE Output`**。
3. **驱动层改键**（关键一步）：运行 `scripts/apply-scancode-map.ps1`（需管理员，
   会自动备份），把话筒键的扫描码 `F5` 映射成**真正的右 Alt**，**重启生效**。

### 为什么非要"驱动层改键"

桥接程序本来就能把话筒键转成"模拟的右 Alt"，但**现代输入法普遍按
`LLKHF_INJECTED` 忽略模拟按键**（实测：注入右 Alt / 右 Alt+空格 各 3 轮，输入法
进程的麦克风使用时间与 CPU 零变化）。注册表 `Scancode Map` 由键盘类驱动在最底层
改键，做出来的按键在输入法眼里就是"真键盘按的"，这就是整件事的关键。

代价：键盘上的 `F5` 也会变成右 Alt（浏览器刷新改用 `Ctrl+R`）；回滚：
`scripts/apply-scancode-map.ps1 -Rollback` 后重启。

### 按键映射

用法见 `config/key_bindings.example.json`。注意实测过的两条规律：

* **配"双击"会让单击延迟 300 毫秒**（程序要先等你是不是要点第二下）——想要"跟手"
  就别用双击，改用**长按**（0.55 秒触发，不拖慢单击）；
* 映射文件是**热加载**的，改完立即生效。

### 桌面应用里的快捷键（实测，不是猜的）

`Ctrl+K`（命令面板）注入可用且面板内 ↑/↓ + 回车可导航，最适合做"换对话 / 搜索"；
`Ctrl+Tab`、`Ctrl+PageUp/Down`、`Ctrl+1..9` 实测**无反应**；`Esc` 会连带打断正在
运行的任务，**不要绑到单击键**。推荐布局见上文英文版的表格。

### 排障要点

* **重启后"能唤输入法但没声音"**：多半是 Windows Defender 把未签名的桥接程序当
  PUA 删了（误报）→ 加定向排除后重装；
* **程序静默消失**：它是在短命会话里启动的 → 改成脱离会话启动或放启动文件夹；
* **提示"录音失败"**：从 Win+D 回来没有可编辑焦点 → 先点一下输入框。

完整坑清单见英文版 Troubleshooting 表格与 `THIRD_PARTY.md` 的安全提示。

### 许可

MIT（见 [LICENSE](LICENSE)）。欢迎补充设备适配报告（其它遥控器、输入法、桌面应用）。
