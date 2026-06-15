#!/usr/bin/env bash

################################################################################
# COPYRIGHT NOTICE
#
# This script has been authored by:
#     Om Girish Talsania
#
# It is released freely for use, modification, redistribution, and integration
# into personal, educational, or commercial projects.
#
# You are permitted to adapt, extend, and improve this script without restriction,
# provided that its original intent of open and accessible development tooling
# is preserved.
################################################################################

set +e

INSTALLED=()
FAILED=()
MANUAL=()

success() {
    INSTALLED+=("$1")
    echo "✓ $1"
}

failure() {
    FAILED+=("$1")
    MANUAL+=("$1")
    echo "✗ $1"
}

run_step() {
    local NAME="$1"
    shift

    echo
    echo "--------------------------------------------------"
    echo "Installing: $NAME"
    echo "--------------------------------------------------"

    "$@"

    if [ $? -eq 0 ]; then
        success "$NAME"
    else
        failure "$NAME"
    fi
}

echo "========================================="
echo "🎮 Game Dev Studio Installer (Ubuntu)"
echo "========================================="

BASE="/opt/gamedev"
BIN="/usr/local/bin"

sudo mkdir -p "$BASE"/{engines,tools,art,web,audio,dev,pipelines}
sudo mkdir -p "$BIN"

# ----------------------------------------
# SYSTEM SETUP
# ----------------------------------------
echo "[1] Installing system dependencies..."

sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  git curl wget unzip jq zenity inotify-tools \
  build-essential software-properties-common \
  libfuse2 flatpak python3 python3-pip

# ----------------------------------------
# GPU DRIVERS
# ----------------------------------------
echo "[2] Configuring graphics drivers..."

sudo ubuntu-drivers autoinstall || true

# ----------------------------------------
# FLATPAK SUPPORT
# ----------------------------------------
echo "[3] Installing Flatpak support..."

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
flatpak install -y flathub com.usebottles.bottles || true

# ----------------------------------------
# NODE.JS ENVIRONMENT
# ----------------------------------------
echo "[4] Installing Node.js environment..."

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh" || true

nvm install --lts || true
nvm use --lts || true

npm install -g \
  vite create-react-app react \
  phaser excalibur

# ----------------------------------------
# CODE EDITORS
# ----------------------------------------
echo "[5] Installing code editors..."

echo "[5] Installing code editors..."

sudo rm -f /etc/apt/sources.list.d/vscode.list
sudo rm -f /usr/share/keyrings/ms.gpg
sudo rm -f /usr/share/keyrings/packages.microsoft.gpg

run_step "VS Code Repository" bash -c '
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
| gpg --dearmor \
| sudo tee /usr/share/keyrings/ms.gpg >/dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms.gpg] https://packages.microsoft.com/repos/code stable main" \
| sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
'

run_step "VS Code" bash -c '
sudo apt update &&
sudo apt install -y code
'

run_step "Code Server" bash -c '
curl -fsSL https://code-server.dev/install.sh | sudo bash
'

# ----------------------------------------
# WEB BROWSER
# ----------------------------------------
echo "[6] Installing web browser..."

wget -O /tmp/chrome.deb \
  https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

sudo apt install -y /tmp/chrome.deb

# ----------------------------------------
# GAME ENGINES
# ----------------------------------------
echo "[7] Installing game engines..."

GODOT_URL=$(curl -s https://api.github.com/repos/godotengine/godot/releases/latest \
| jq -r '.assets[] | select(.name|test("linux.*x86_64.*zip")) | .browser_download_url' | head -n 1)

wget -O /tmp/godot.zip "$GODOT_URL"
unzip -o /tmp/godot.zip -d /tmp/godot

GODOT_BIN=$(find /tmp/godot -type f -executable | head -n 1)
sudo cp "$GODOT_BIN" "$BASE/engines/godot"
sudo chmod +x "$BASE/engines/godot"
sudo ln -sf "$BASE/engines/godot" "$BIN/godot"

GDEV_URL=$(curl -s https://api.github.com/repos/4ian/GDevelop/releases/latest \
| jq -r '.assets[] | select(.name|test("linux.*AppImage")) | .browser_download_url' | head -n 1)

wget -O "$BASE/engines/gdevelop.AppImage" "$GDEV_URL"
chmod +x "$BASE/engines/gdevelop.AppImage"
sudo ln -sf "$BASE/engines/gdevelop.AppImage" "$BIN/gdevelop"

CT_URL=$(curl -s https://api.github.com/repos/ct-js/ct-js/releases/latest \
| jq -r '.assets[] | select(.name|test("AppImage")) | .browser_download_url' | head -n 1)

wget -O "$BASE/engines/ctjs.AppImage" "$CT_URL"
chmod +x "$BASE/engines/ctjs.AppImage"
sudo ln -sf "$BASE/engines/ctjs.AppImage" "$BIN/ctjs"

wget -O /tmp/renpy.zip https://www.renpy.org/dl/latest/renpy.zip
mkdir -p "$BASE/engines/renpy"
unzip -o /tmp/renpy.zip -d "$BASE/engines/renpy"

sudo apt install -y love

MICRO_URL=$(curl -s https://api.github.com/repos/pmgl/microstudio/releases/latest \
| jq -r '.assets[] | select(.name|test("linux")) | .browser_download_url' | head -n 1)

wget -O /tmp/microstudio.zip "$MICRO_URL"
mkdir -p "$BASE/web/microstudio"
unzip -o /tmp/microstudio.zip -d "$BASE/web/microstudio"

MICRO_BIN=$(find "$BASE/web/microstudio" -type f -executable | head -n 1)
sudo ln -sf "$MICRO_BIN" "$BIN/microstudio"

# ----------------------------------------
# CREATIVE TOOLS
# ----------------------------------------
echo "[8] Installing creative tools..."

sudo apt install -y \
  gimp krita inkscape

wget -O "$BASE/art/pixelorama.AppImage" \
https://github.com/Orama-Interactive/Pixelorama/releases/latest/download/Pixelorama.x86_64.AppImage || true

chmod +x "$BASE/art/pixelorama.AppImage"
sudo ln -sf "$BASE/art/pixelorama.AppImage" "$BIN/pixelorama"

wget -O "$BASE/art/libresprite.AppImage" \
https://github.com/LibreSprite/LibreSprite/releases/latest/download/LibreSprite-x86_64.AppImage || true

chmod +x "$BASE/art/libresprite.AppImage"
sudo ln -sf "$BASE/art/libresprite.AppImage" "$BIN/libresprite"

# ----------------------------------------
# Piskel
# ----------------------------------------

PISKEL_URL=$(curl -s https://api.github.com/repos/piskelapp/piskel/releases/latest \
| jq -r '.assets[] | select(.name|test("linux.*64")) | .browser_download_url' | head -n 1)

wget -O /tmp/piskel.zip "$PISKEL_URL"

mkdir -p "$BASE/art/piskel"

unzip -o /tmp/piskel.zip -d "$BASE/art/piskel"

PISKEL_BIN=$(find "$BASE/art/piskel" -type f -executable | head -n 1)

chmod +x "$PISKEL_BIN"

sudo ln -sf "$PISKEL_BIN" "$BIN/piskel"


# ----------------------------------------
# AUDIO-VIDEO STACK
# ----------------------------------------
echo "[9] Installing audio and video tools..."

sudo apt install -y \
  vlc kdenlive obs-studio \
  lmms audacity ardour hydrogen \
  drumkv1 synthv1 samplv1 geonkick

# ----------------------------------------
# LDtk
# ----------------------------------------
echo "[10] Setting up Level Editors..."

sudo apt install -y \
  tiled

LDTK_URL=$(curl -s https://api.github.com/repos/deepnight/ldtk/releases/latest \
| jq -r '.assets[] | select(.name|test("Linux.*zip")) | .browser_download_url' | head -n 1)

wget -O /tmp/ldtk.zip "$LDTK_URL"
mkdir -p "$BASE/tools/ldtk"

unzip -o /tmp/ldtk.zip -d "$BASE/tools/ldtk"

LDTK_BIN=$(find "$BASE/tools/ldtk" -type f -executable | head -n 1)

chmod +x "$LDTK_BIN"
sudo ln -sf "$LDTK_BIN" "$BIN/ldtk"

# ----------------------------------------
# LDtk SYNC TOOL
# ----------------------------------------
echo "[11] Setting up LDtk sync..."

cat > "$BIN/ldtk-sync" <<'EOF'
#!/usr/bin/env bash

WATCH=${1:-$PWD}

echo "Watching LDtk files in: $WATCH"

inotifywait -m "$WATCH" -e close_write |
while read path action file; do
  [[ "$file" == *.ldtk ]] && cp "$path$file" "$WATCH/export_$file.json"
done
EOF

chmod +x "$BIN/ldtk-sync"

# ----------------------------------------
# ITCH.IO UPLOADER
# ----------------------------------------

echo "[12] Installing productivity tools..."
OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
| jq -r '.assets[] | select(.name|test("AppImage")) | .browser_download_url' | head -n 1)

wget -O "$BASE/tools/obsidian.AppImage" "$OBSIDIAN_URL"

chmod +x "$BASE/tools/obsidian.AppImage"

sudo ln -sf "$BASE/tools/obsidian.AppImage" "$BIN/obsidian"

# ----------------------------------------
# ITCH.IO UPLOADER
# ----------------------------------------
echo "[13] Installing deployment tools..."

curl -L -o /tmp/butler.zip https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default
unzip /tmp/butler.zip -d /tmp
sudo mv /tmp/butler /usr/local/bin/
sudo chmod +x /usr/local/bin/butler

# ----------------------------------------
# GAMDEV COMMAND
# ----------------------------------------
echo "[14] Creating gamedev command..."

cat > "$BIN/gamedev" <<'EOF'
#!/usr/bin/env bash

case "$1" in
  list)
    ls /usr/local/bin | grep -E "godot|gdevelop|ctjs|ldtk|microstudio|pixelorama|libresprite|obs"
    ;;
  audio)
    ardour & hydrogen & geonkick & obs &
    ;;
  sync)
    ldtk-sync "$2"
    ;;
  fps)
    mkdir -p "$2"/{scenes,scripts,assets}
    echo "Created Godot FPS project: $2"
    ;;
  web)
    mkdir -p "$2"
    echo "Created Phaser project: $2"
    ;;
  *)
    echo "Usage:"
    echo " gamedev list"
    echo " gamedev audio"
    echo " gamedev sync <folder>"
    echo " gamedev fps <name>"
    echo " gamedev web <name>"
    ;;
esac
EOF

chmod +x "$BIN/gamedev"

# ----------------------------------------
# COMPLETION
# ----------------------------------------
echo "========================================="
echo "Installation complete."
echo "Use: gamedev list"
echo "Use: gamedev audio"
echo "========================================="
