# WinDebloat

WinDebloat is a configuration-driven Windows debloating framework designed to run
**during Windows installation** using `autounattend.xml`.

It provides full, explicit control over what is removed or disabled in Windows,
using a single global configuration file with clear toggles and explanations of
consequences.

This project is intended for advanced users who want deterministic, reproducible,
and transparent system configuration.

---

## Features

- Runs during Windows installation (no post-install hacks)
- Single global configuration file (`debloat.config.psd1`)
- Toggle-based control over every debloat action
- Human-readable explanations of consequences
- Explicit safety gate (`IAgreeAndUnderstand = true`)
- No hardcoded removals — everything is opt-in
- Full logging of all actions

---

## Philosophy

WinDebloat follows three core principles:

1. Nothing is removed implicitly  
2. The user must explicitly accept responsibility  
3. Configuration over automation  

This is **not** a one-click debloater.  
It is a **deterministic Windows configuration system**.

---

## What Can Be Managed

Depending on configuration, WinDebloat can manage:

- Built-in Appx and provisioned applications
- Consumer features and recommendations
- Widgets and Windows Copilot
- OneDrive (disable or uninstall)
- Selected Windows services
- Selected Windows capabilities (DISM-based)
- Privacy-related system policies (best-effort)

All actions are optional and explicitly controlled.

---

## Repository Structure
```
WinDebloat:
├── autounattend.xml
└── sources/
    └── $OEM$
        └── $1
            └── Setup
                └── Debloat
                    ├── debloat.ps1
                    └── debloat.config.psd1
```
    
## Final Installation Media Structure
```
WindowsInstallationMediaDrive:
├── autounattend.xml
├── Some of the Installation Source Files (don't touch)...
└── sources/
    ├── $OEM$
    │   └── $1
    │       └── Setup
    │           └── Debloat
    │               ├── debloat.ps1
    │               └── debloat.config.psd1
    │
    └── Lots of Installation Source Files (don't touch)...
```

---

## ⚠️ Disclaimer

WinDebloat modifies Windows system components, policies, and bundled software.

Misconfiguration **can lead to loss of functionality**, including but not limited to:
- Microsoft Store features
- Xbox / Game Pass integration
- Widgets, Copilot, or cloud features
- Diagnostics and telemetry

You are solely responsible for the effects of using this project.

---

## 📜 License Summary (Human-readable)

- ✔ Free to use
- ✔ Free to modify
- ✔ Free to share
- ❌ Selling or commercial redistribution is **not allowed**

See `LICENSE` for full terms.

---

## 🚧 Project Status

WinDebloat is intentionally conservative by default.  
Future extensions may include:
- Inventory / discovery mode
- Config auto-generation based on ISO contents
- Preset profiles (conservative / balanced / aggressive)

---

## 🧩 Target Audience

- Advanced Windows users
- Developers
- System administrators
- Homelab / workstation builders
- Anyone who wants **full control over Windows, not guesses**

