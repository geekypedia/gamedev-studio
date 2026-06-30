# 🎮 Game Dev Studio Installer (Ubuntu)

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%2B-orange)
![Shell Script](https://img.shields.io/badge/Shell-Bash-blue)
![Status](https://img.shields.io/badge/Status-Active%20Project-brightgreen)

---

## 🚀 Overview

Game Dev Studio Installer is a one-command setup script that transforms a fresh Ubuntu system into a complete **indie game development and creative production workstation**.

It installs a full ecosystem of:

- 🎮 Game engines  
- 🌐 Web game development stack  
- 🎨 Art & design tools  
- 🎧 Audio / video production suite  
- 💻 Development environment  
- 📦 Publishing tools  
- 🧩 Game dev pipeline utilities  

Built for speed, reproducibility, and zero manual setup.

---

## ⚡ One-Line Install

### 🟢 Standard Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && sudo ~/gamedev-studio.sh
```
---

### 🔁 Install + System Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && sudo ~/gamedev-studio.sh --upgrade
```
---

### 💥 Force Reinstall (Overwrite Everything)

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && sudo ~/gamedev-studio.sh --force
```
---

### ⚡ Force + Upgrade (Full System Refresh)

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && sudo ~/gamedev-studio.sh --force --upgrade
```
---

### 🎯 Update a single package

```bash
~/gamedev-studio.sh --update your-package
```

##### More usable with -f option

```bash
~/gamedev-studio.sh --update your-package -f
```

##### If package is already downloaded in tmp folder and you just need to trigger re-installation

```bash
~/gamedev-studio.sh --update your-package -f --skip-downloads
```

OR

```bash
~/gamedev-studio.sh -u your-package -f -sd
```


#### Example

```bash
~/gamedev-studio.sh --update godot -f
```
---

### 🎯 List available packages

```bash
~/gamedev-studio.sh --list
```

---

### 🎯 Skip packages

```bash
~/gamedev-studio.sh --skip package1,package2
```
#### Example

```bash
~/gamedev-studio.sh --skip code,gideros,solar2d
```

---


## 🧱 What Gets Installed

### 🎮 Game Engines

#### Python / Python-like
- Godot Engine (Python-like GDScript)
- Ren’Py (Python)
- Pygame (Python)
- Pyxel (Python)
- Panda3D (Python)
- Ursina (Python)
- Eldiron (Python)

#### Lua
- LÖVE2D (Lua)
- Defold (Lua)
- Solarus (Lua)
- Solar2D (Lua)
- Gideros Studio (Lua)

#### No-Code / Low-Code / Multi-Language
- GDevelop (No-code, JavaScript supported)
- Ct.js (Block-based, JavaScript, CoffeeScript)
- microStudio (Lua, JavaScript, Python)
- GB Studio (No-code)
- GameMaker (GML/JavaScript/TypeScript)

#### JavaScript / TypeScript
- Phaser
- ExcaliburJS

---

### 🌐 Web App Stack 
- Node.js (via NVM LTS)
- Vite
- React
- create-react-app
- NW
- Electron
- http-server
- serve
- SQLite Browser

---

### 🎨 Art & Design Tools
- Blender
- GIMP
- Krita
- Inkscape
- Pixelorama
- LibreSprite

---

### 🎧 Audio / Video Suite
- VLC Media Player
- Kdenlive
- OBS Studio
- LMMS
- Audacity
- Ardour
- Hydrogen Drum Machine
- Revisto Drum Machine
- Geonkick

---

### 💻 Development Tools
- Git
- Curl / Wget / jq / unzip
- VS Code
- code-server
- Google Chrome

---

### 🧩 Level Design Tools
- Tiled Map Editor
- LDtk

---

### 🧩 Pipeline Tools
- LDtk Sync Tool
- Godot Export Templates for iOS, Android and Desktop

---

### 🧠 Productivity Tools
- Obsidian

---

### 📦 Publishing Tools
- itch.io Butler

---

## ⚙️ CLI OPTIONS

| Flag | Description |
|------|-------------|
| `--force` / `-f` | Reinstall and overwrite all tools |
| `--skip-downloads` / `-sd` | Skip downloading zip files to temp directory if it already exists (useful in combination with --force/-f |
| `--upgrade` | Runs system upgrade (`apt upgrade`) before installation |
| `--update <package>` / `-u <package>` | Runs only a specific installation package (e.g. `godot`, `electron`) |
| `--skip <package(s)>` / `-s <package(s)>` | Skips specific installation package(s) (e.g. `gideros,solar2d`) |
| `--list` / `-l` | Lists available packages |
| *(none)* | Safe mode (skip existing installs) |

---

## 🧠 Behavior Modes

### 🟢 Safe Mode (Default)
- Skips already installed tools
- Installs missing components only
- No overwriting

---

### 🔁 Upgrade Mode
sudo apt upgrade -y

- System-level upgrade only
- No tool reinstall

---

### 💥 Force Mode
- Reinstalls everything
- Overwrites binaries and AppImages
- Useful for broken setups or full resets

---

## 🧪 Recommended Usage

| Scenario | Command |
|----------|--------|
| First setup | Default |
| Weekly maintenance | `--upgrade` |
| Broken system | `--force` |
| Fresh rebuild | `--force --upgrade` |

---

## 🧠 Design Philosophy

This project follows a Workstation-as-Code approach:

- Re-runnable without breaking system
- Explicit destructive actions only via flags
- Modular installation by category
- Minimal user input required
- Optimized for indie game developers
