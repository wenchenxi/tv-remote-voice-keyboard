# Third-party components, trademarks and legal notes

This repository contains **documentation, configuration templates and small
helper scripts only**. It does **not** bundle or redistribute any third-party
software, binary, driver or asset.

## Software you install yourself (not distributed here)

| Component | Role | Where to get it | License / terms |
|---|---|---|---|
| **Remote Mic · RC003** (`miaomiaozii/windows-remote-mic-app`) | BLE/ATVV bridge: turns the remote's mic audio and buttons into Windows input | Its own GitHub Releases | GPL-3.0, **unsigned** build. This repo only *links* to it and documents its config files. |
| **VB-CABLE Virtual Audio Device** (VB-Audio) | Virtual audio cable (`CABLE Input` → `CABLE Output`) | <https://vb-audio.com/Cable/> | Free **Donationware**, redistribution restricted. Install from VB-Audio's official package (the Remote Mic bundle ships the unmodified official ZIP). |
| **Doubao IME** (if you use it as the dictation engine) | Speech-to-text | Official site | Proprietary, ByteDance. |
| Windows' built-in voice typing (`Win+H`) | Alternative dictation engine | Part of Windows | Microsoft EULA. |

## Trademarks

Xiaomi, Mi, 小爱 (Xiao Ai), Doubao/豆包, Ulanzi/优篮子, VB-Audio, Windows and any
other names or marks mentioned here are the property of their respective
owners.

This project is **not affiliated with, sponsored by, or endorsed by** any of
them. Names are used only to describe devices, software or use cases that the
project interoperates with or is inspired by — that is, in a descriptive
(nominative) sense. No third-party logo, product photo, firmware or
proprietary code is included in this repository.

## Safety notes for the documented procedures

1. **Registry keyboard remap (`Scancode Map`)** — this is a system-wide change
   that takes effect after a reboot and affects *all* keyboards using the mapped
   scan code. Back up the key first (`scripts/apply-scancode-map.ps1` does this
   automatically) and keep the documented rollback command.
2. **Unsigned third-party binary** — Windows Defender (or other AV) may
   quarantine the Remote Mic executable as a heuristic false positive. Only
   install it after verifying the published SHA-256. If you add an antivirus
   exclusion, keep it scoped to that one folder/process, and remember to remove
   it when you uninstall.
3. **Virtual audio device** — while the default recording device is set to
   `CABLE Output`, other applications (calls, recorders) will also hear whatever
   is fed into the cable. Switch your default input back when you are done.
4. **Voice privacy** — with a cloud dictation engine, whatever you say goes to
   that vendor. Read the vendor's privacy terms before using it for anything
   sensitive.
