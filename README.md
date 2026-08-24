<a id="top"></a>

# 🎮 Game Dev Studio Installer (Ubuntu)

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%2B-orange)
![Linux Mint](https://img.shields.io/badge/Linux%20Mint-22%2B-green)
![Zorin OS](https://img.shields.io/badge/Zorin%20OS-18%2B-blue)
![Pop!_OS](https://img.shields.io/badge/Pop!_OS-24.04%2B-cyan)
![Xubuntu](https://img.shields.io/badge/Xubuntu-24.04%2B-silver)
![Lubuntu](https://img.shields.io/badge/Lubuntu-24.04%2B-blue)
![Kubuntu](https://img.shields.io/badge/Kubuntu-24.04%2B-lightblue)
![Ubuntu Studio](https://img.shields.io/badge/Ubuntu%20Studio-24.04%2B-purple)
![Ubuntu-Based](https://img.shields.io/badge/Ubuntu-22.04%2B-orange)
![Shell Script](https://img.shields.io/badge/Shell-Bash-blue)
![Status](https://img.shields.io/badge/Status-Active%20Project-brightgreen)

---

## 📑 Table of Contents

- [🚀 Overview](#-overview)
- [⚡ One-Line Install](#-one-line-install)
  - [🟢 Essential Install](#-essential-install)
  - [🟢 Standard Install (Recommended)](#-standard-install-recommended)
  - [🟢 Only Download Script (To run it later)](#-only-download-script-to-run-it-later)
  - [🟢 Clone from git](#-clone-from-git)
  - [🔁 Install + System Upgrade](#-install--system-upgrade)
  - [💥 Force Reinstall (Overwrite Everything)](#-force-reinstall-overwrite-everything)
  - [⚡ Force + Upgrade (Full System Refresh)](#-force--upgrade-full-system-refresh)
  - [⬆️ Update a single package](#️-update-a-single-package)
    - [Examples](#examples)
  - [📦 List available packages](#-list-available-packages)
  - [⏭️ Skip packages](#️-skip-packages)
    - [Example](#example)
- [🧱 What Gets Installed](#-what-gets-installed)
  - [🎮 Game Engines](#-game-engines)
    - [Python / Python-like](#python--python-like)
    - [Lua](#lua)
    - [No-Code / Low-Code / Multi-Language / Custom](#no-code--low-code--multi-language--custom)
    - [.NET/C#/Mono](#netcmono)
    - [JavaScript / TypeScript](#javascript--typescript)
    - [Clients/Modding/Console](#clientsmoddingconsole)
  - [🌐 Web App Stack](#-web-app-stack)
  - [🎨 Art & Design Tools](#-art--design-tools)
  - [🎧 Audio / Video Suite](#-audio--video-suite)
    - [Plugins](#plugins)
  - [💻 Development Tools](#-development-tools)
  - [🧩 Level Design Tools](#-level-design-tools)
  - [🔧 Environment Tools](#-environment-tools)
  - [🧠 Productivity Tools](#-productivity-tools)
  - [📦 Publishing Tools](#-publishing-tools)
- [⚙️ CLI OPTIONS](#️-cli-options)
- [🧠 Behavior Modes](#-behavior-modes)
  - [🟢 Safe Mode (Default)](#-safe-mode-default)
  - [🔁 Upgrade Mode](#-upgrade-mode)
  - [💥 Force Mode](#-force-mode)
- [🧪 Recommended Usage](#-recommended-usage)
- [🧠 Design Philosophy](#-design-philosophy)

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
- 🧩 Game dev pipeline utilities and environment/runtime/build tools

Built for speed, reproducibility, and zero manual setup.

[↑ Back to top](#top)

---

## ⚡ One-Line Install

### 🟢 Essential Install (Recommended for Beginners)

This option only installes a few select essential software from the whole list. Good for beginner to intermediate Game Dev and Sound Engineers, who want tools that work.

```bash
wget -qO ~/gamedev-studio.sh https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh && chmod +x ~/gamedev-studio.sh && ~/gamedev-studio.sh -e
```

OR

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && ~/gamedev-studio.sh -e
```

It is equivalent to 
```bash
~/gamedev-studio.sh -u apt,deps,code-setup,code,godot,godot-templates,gdevelop,ctjs,renpy,microstudio,whimtale,gimp,krita,pixelorama,libresprite,tiled,ldtk,audacity,lmms,kdenlive,obs,famistudio
```

### 🟢 Standard Install (Recommended)

This option installs everything. Good for Game Dev enthusiasts who would like to explore all the available options.

```bash
wget -qO ~/gamedev-studio.sh https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh && chmod +x ~/gamedev-studio.sh && ~/gamedev-studio.sh
```

OR

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && ~/gamedev-studio.sh
```

[↑ Back to top](#top)

### 🟢 Only Download Script (To run it later)

If you just want to download and run it later

```bash
wget -qO ~/gamedev-studio.sh https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh && chmod +x ~/gamedev-studio.sh
```

OR

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh
```

You can run the command whenever you want. You can re-run the command if it breaks in between. You can run it with different options mentioned below in the CLI Options section.

```bash
~/gamedev-studio.sh
```

Make sure not to run this as sudo because it already uses sudo at appropriate times.

[↑ Back to top](#top)

### 🟢 Clone from git

If you just want to clone it from github

```bash
git clone https://github.com/geekypedia/gamedev-studio.git && cd gamedev-studio && chmod +x install.sh && ./install.sh
```

[↑ Back to top](#top)

---

### 🔁 Install + System Upgrade

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && ~/gamedev-studio.sh --upgrade
```

[↑ Back to top](#top)

---

### 💥 Force Reinstall (Overwrite Everything)

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && ~/gamedev-studio.sh --force
```

[↑ Back to top](#top)

---

### ⚡ Force + Upgrade (Full System Refresh)

```bash
curl -fsSL https://raw.githubusercontent.com/geekypedia/gamedev-studio/main/install.sh -o ~/gamedev-studio.sh && chmod +x ~/gamedev-studio.sh && ~/gamedev-studio.sh --force --upgrade
```

[↑ Back to top](#top)

---

### ⬆️ Update a single package

```bash
~/gamedev-studio.sh --update your-package
```

OR

```bash
~/gamedev-studio.sh -u your-package
```

##### More usable with -f option

```bash
~/gamedev-studio.sh --update your-package --force
```

OR

```bash
~/gamedev-studio.sh -u your-package -f
```

##### If you want to update all packages with the name partially matching the one you supplied

```bash
~/gamedev-studio.sh --update your-package --like
```

OR

```bash
~/gamedev-studio.sh -u your-package -lk
```

##### If package is already downloaded in tmp folder and you just need to trigger re-installation

```bash
~/gamedev-studio.sh --update your-package --force --skip-downloads
```

OR

```bash
~/gamedev-studio.sh -u your-package -f -sd
```

#### Examples

```bash
~/gamedev-studio.sh -f -u godot
```

```bash
~/gamedev-studio.sh -f -sd -u defold
```

```bash
~/gamedev-studio.sh -f -sd -u godot,gdevelop
```

```bash
~/gamedev-studio.sh -f -u godot -lk
```

[↑ Back to top](#top)

---

### 📦 List available packages

```bash
~/gamedev-studio.sh --list
```

OR

```bash
~/gamedev-studio.sh -l
```

[↑ Back to top](#top)

---

### ⏭️ Skip packages

```bash
~/gamedev-studio.sh --skip package1,package2
```

OR

```bash
~/gamedev-studio.sh -s package1,package2
```

#### Example

```bash
~/gamedev-studio.sh --skip code,gideros,solar2d
```

OR

```bash
~/gamedev-studio.sh -s code,gideros,solar2d
```

[↑ Back to top](#top)

---

## 🧱 What Gets Installed

### 🎮 Game Engines

#### Python / Python-like

- Godot Engine (Python-like GDScript)
- Ren’Py (Python)
- Pygame (Python)
- Pyxel (Python)
- Raylib (Python)
- Panda3D (Python)
- Ursina (Python)
- Eldiron (Python)

#### Lua

- LÖVE2D (Lua)
- Defold (Lua)
- Solarus (Lua)
- Solar2D (Lua)
- Gideros Studio (Lua)

#### No-Code / Low-Code / Multi-Language / Custom

- GDevelop (No-code, JavaScript supported)
- Ct.js (Block-based, JavaScript, CoffeeScript)
- microStudio (Lua, JavaScript, Python)
- Whimtale (No-code)
- GB Studio (No-code)
- Twine (No-code)
- TuesdayJS (No-code, JavaScript)
- Inky (No-code)
- GameMaker (GML/JavaScript/TypeScript)

#### .NET/C#/Mono

- Godot Engine .NET (C#)

#### JavaScript / TypeScript

- Phaser
- ExcaliburJS
- Babylon.JS

#### Clients/Modding/Console

- Flare
- Intersect Engine Client and Server (Free MMO RPG Maker)
- TIC-80

[↑ Back to top](#top)

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

[↑ Back to top](#top)

---

### 🎨 Art & Design Tools

- Blender
- GIMP
- Krita
- Inkscape
- Piko Pixel
- Pixelorama
- LibreSprite
- Ogmo Editor
- Effekseer
- FreeTexturePacker
- Synfig Studio
- Pencil2D
- OpenToonz
- ArmorPaint
- MakeHuman

[↑ Back to top](#top)

---

### 🎧 Audio / Video Suite

- VLC Media Player
- Kdenlive
- OBS Studio
- LMMS
- Audacity
- Ardour
- Fami Studio
- yadaw
- Plugins
  - Hydrogen Drum Machine
  - Revisto Drum Machine
  - Geonkick
  - Helm
  - Sitala
  - SurgeXT
  - Dexed
  - TAL-NoiseMaker
  - Odin 2
- rFXGen
- Natron

[↑ Back to top](#top)

---

### 💻 Development Tools

- Git
- Curl / Wget / jq / unzip
- VS Code
- code-server
- Chromium/Chrome

[↑ Back to top](#top)

---

### 🧩 Level Design Tools

- Tiled Map Editor
- LDtk

[↑ Back to top](#top)

---

### 🔧 Environment Tools

- LDtk Sync Tool
- Godot Export Templates for iOS, Android and Desktop
- Adventure Game Studio Runtime
- love.js

[↑ Back to top](#top)

---

### 🧠 Productivity Tools

- Obsidian

[↑ Back to top](#top)

---

### 📦 Publishing Tools

- itch.io Butler

[↑ Back to top](#top)

---

## ⚙️ CLI OPTIONS

| Flag | Description |
|------|-------------|
| `--essential` / `-e` | Only install essential tools. This is an exclusive option and doesn't combine with other options below |
| `--force` / `-f` | Reinstall and overwrite all tools |
| `--skip-downloads` / `-sd` | Skip downloading zip files to temp directory if it already exists (useful in combination with --force/-f |
| `--upgrade` | Runs system upgrade (`apt upgrade`) before installation |
| `--update <package>` / `-u <package>` | Runs specific installation package(s) (e.g. `godot,electron`) |
| `--skip <package(s)>` / `-s <package(s)>` | Skips specific installation package(s) (e.g. `gideros,solar2d`) |
| `--like` / `-lk` | While updating targeted packages, it matches partial keyword. for example `godot` matches godot, godot3, godot.net |
| `--list` / `-l` | Lists available packages |
| *(none)* | Safe mode (skip existing installs) |

[↑ Back to top](#top)

---

## 🧠 Behavior Modes

### 🟢 Safe Mode (Default)

- Skips already installed tools
- Installs missing components only
- No overwriting

[↑ Back to top](#top)

---

### 🔁 Upgrade Mode

```bash
sudo apt upgrade -y
```

- System-level upgrade only
- No tool reinstall

[↑ Back to top](#top)

---

### 💥 Force Mode

- Reinstalls everything
- Overwrites binaries and AppImages
- Useful for broken setups or full resets

[↑ Back to top](#top)

---

## 🧪 Recommended Usage

| Scenario | Command |
|----------|--------|
| First setup | Default |
| Weekly maintenance | `--upgrade` |
| Broken system | `--force` |
| Fresh rebuild | `--force --upgrade` |

[↑ Back to top](#top)

---

## 🧠 Design Philosophy

This project follows a Workstation-as-Code approach:

- Re-runnable without breaking system
- Explicit destructive actions only via flags
- Modular installation by category
- Minimal user input required
- Optimized for indie game developers

[↑ Back to top](#top)
