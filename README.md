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

## 🧱 What Gets Installed

### 🎮 Game Engines
- Godot Engine
- GDevelop
- ct.js
- Ren’Py
- LÖVE2D

---

### 🌐 Web Game Stack
- Node.js (via NVM LTS)
- Vite
- React
- Phaser
- ExcaliburJS
- create-react-app

---

### 🎨 Art & Design Tools
- GIMP
- Krita
- Inkscape
- Pixelorama
- LibreSprite
- Piskel

---

### 🎧 Audio / Video Suite
- VLC Media Player
- Kdenlive
- OBS Studio
- LMMS
- Audacity
- Ardour
- Hydrogen Drum Machine
- Geonkick

---

### 💻 Development Tools
- Git
- Curl / Wget / jq / unzip
- VS Code
- code-server
- Google Chrome

---

### 🧠 Productivity Tools
- Obsidian

---

### 📦 Publishing Tools
- itch.io Butler

---

### 🧩 Pipeline Tools
- LDtk
- LDtk Sync Tool

---

## ⚙️ CLI OPTIONS

| Flag | Description |
|------|-------------|
| `--force` / `-f` | Reinstall and overwrite all tools |
| `--upgrade` | Runs only system upgrade (`apt upgrade`) |
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
