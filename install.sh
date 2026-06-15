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

# -----------------------------
# FLAGS
# -----------------------------

FORCE_UPDATE=0
RUN_UPGRADE_STEP=0

for arg in "$@"; do
    case "$arg" in
        --force|-f)
            FORCE_UPDATE=1
            ;;
        --upgrade)
            RUN_UPGRADE_STEP=1
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--force|-f] [--upgrade]"
            exit 1
            ;;
    esac
done

# -----------------------------
# SAFE HELPERS
# -----------------------------

safe_wget() {
    local url="$1"
    local out="$2"

    if [ -z "$url" ] || [ "$url" = "null" ]; then
        return 1
    fi

    wget -q -O "$out" "$url"
    [ -s "$out" ]
}

safe_find_exec() {
    find "$1" -type f -executable 2>/dev/null | head -n 1
}

is_installed() {
    command -v "$1" >/dev/null 2>&1
}

run_step() {
    local NAME="$1"
    local CHECK_CMD="$2"
    shift 2

    echo
    echo "--------------------------------------------------"
    echo "Installing: $NAME"
    echo "--------------------------------------------------"

    if [[ "$FORCE_UPDATE" -eq 0 ]] && eval "$CHECK_CMD"; then
        echo "✓ $NAME already installed (skipping)"
        INSTALLED+=("$NAME (already present)")
        return 0
    fi

    if [[ "$FORCE_UPDATE" -eq 1 ]]; then
        echo "⚠ Force mode: reinstalling $NAME"
    fi

    if eval "$*"; then
        success "$NAME"
    else
        failure "$NAME"
    fi
}

# -----------------------------
# BINARY REGISTRY (FIX)
# -----------------------------

register_bin() {
    local name="$1"
    local target="$2"

    if [ -z "$target" ] || [ ! -f "$target" ]; then
        echo "⚠ Cannot register $name (missing binary: $target)"
        return 1
    fi

    chmod +x "$target"
    sudo ln -sf "$target" /usr/local/bin/"$name"
}

echo "========================================="
echo "🎮 Game Dev Studio Installer (Ubuntu)"
echo "========================================="

BASE="/opt/gamedev"
BIN="/usr/local/bin"

sudo mkdir -p "$BASE"/{engines,tools,art,web,audio,dev,pipelines}
sudo mkdir -p "$BIN"

# -----------------------------
# SYSTEM FLOW
# -----------------------------

run_step "APT Update" "true" '
sudo apt update -y
'

if [[ "$RUN_UPGRADE_STEP" -eq 1 ]]; then
run_step "APT Upgrade" "true" '
sudo apt upgrade -y
'
fi

run_step "System Dependencies Install" \
"is_installed git && is_installed curl && is_installed wget && is_installed unzip && is_installed jq" '
sudo apt install -y \
git curl wget unzip jq zenity inotify-tools \
build-essential software-properties-common \
libfuse2 flatpak python3 python3-pip
'

# -----------------------------
# GPU DRIVERS
# -----------------------------

run_step "GPU Drivers" "false" '
sudo ubuntu-drivers autoinstall
'

# -----------------------------
# FLATPAK
# -----------------------------

run_step "Flatpak + Bottles" "is_installed flatpak" '
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &&
flatpak install -y flathub com.usebottles.bottles || true
'

# -----------------------------
# NODE / NVM
# -----------------------------

run_step "Node.js (NVM + LTS)" "is_installed node" '
if [ ! -d "$HOME/.nvm" ]; then
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts

npm install -g vite create-react-app react phaser excalibur
'

# -----------------------------
# CODE EDITORS
# -----------------------------

sudo rm -f /etc/apt/sources.list.d/vscode.list
sudo rm -f /usr/share/keyrings/ms.gpg

run_step "VS Code Repo Setup" "false" '
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor |
sudo tee /usr/share/keyrings/ms.gpg >/dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms.gpg] https://packages.microsoft.com/repos/code stable main" |
sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
'

run_step "VS Code Install" "is_installed code" '
sudo apt update &&
sudo apt install -y code
'

run_step "Code Server" "is_installed code-server" '
curl -fsSL https://code-server.dev/install.sh | sudo bash
'

# -----------------------------
# WEB BROWSER
# -----------------------------

run_step "Google Chrome" "is_installed google-chrome || is_installed google-chrome-stable" '
safe_wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb /tmp/chrome.deb &&
sudo apt install -y /tmp/chrome.deb
'

# -----------------------------
# GAME ENGINES
# -----------------------------

rrun_step "Godot" "is_installed godot" '
GODOT_URL=$(curl -s https://api.github.com/repos/godotengine/godot/releases/latest |
jq -r ".assets[] | select(.name|test(\"linux.*x86_64.*zip\")) | .browser_download_url" | head -n 1)

safe_wget "$GODOT_URL" /tmp/godot.zip || exit 1

rm -rf /tmp/godot
unzip -o /tmp/godot.zip -d /tmp/godot

GODOT_BIN=$(find /tmp/godot -type f -executable -name "*x86_64*" | head -n 1)

if [ -z "$GODOT_BIN" ]; then
    echo "Godot binary not found"
    exit 1
fi

sudo install -Dm755 "$GODOT_BIN" /opt/gamedev/engines/godot

register_bin godot /opt/gamedev/engines/godot
'

run_step "Godot Export Templates" "false" '
TEMPLATE_URL=$(curl -s https://api.github.com/repos/godotengine/godot/releases/latest |
jq -r ".assets[] | select(.name|test(\"export_templates.*zip\")) | .browser_download_url" | head -n 1)

safe_wget "$TEMPLATE_URL" /tmp/godot_templates.zip || exit 1

mkdir -p ~/.local/share/godot/export_templates
unzip -o /tmp/godot_templates.zip -d ~/.local/share/godot/export_templates
'

run_step "GDevelop" "is_installed gdevelop" '
GDEV_URL=$(curl -s https://api.github.com/repos/4ian/GDevelop/releases/latest |
jq -r ".assets[] | select(.name|test(\"linux.*AppImage\")) | .browser_download_url" | head -n 1)

safe_wget "$GDEV_URL" /opt/gamedev/engines/gdevelop.AppImage || exit 1
chmod +x /opt/gamedev/engines/gdevelop.AppImage
sudo ln -sf /opt/gamedev/engines/gdevelop.AppImage /usr/local/bin/gdevelop
'

run_step "ct.js" "is_installed ctjs" '
CT_URL=$(curl -s https://api.github.com/repos/ct-js/ct-js/releases/latest |
jq -r ".assets[] | select(.name|test(\"AppImage\")) | .browser_download_url" | head -n 1)

safe_wget "$CT_URL" /opt/gamedev/engines/ctjs.AppImage || exit 1
chmod +x /opt/gamedev/engines/ctjs.AppImage
sudo ln -sf /opt/gamedev/engines/ctjs.AppImage /usr/local/bin/ctjs
'

run_step "RenPy" "is_installed renpy" '
safe_wget https://www.renpy.org/dl/latest/renpy.zip /tmp/renpy.zip || exit 1

rm -rf /opt/gamedev/engines/renpy
mkdir -p /opt/gamedev/engines/renpy

unzip -o /tmp/renpy.zip -d /opt/gamedev/engines/renpy

RENPY_LAUNCHER=$(find /opt/gamedev/engines/renpy -type f -name "renpy.sh" | head -n 1)

if [ -z "$RENPY_LAUNCHER" ]; then
    echo "RenPy launcher not found"
    exit 1
fi

register_bin renpy "$RENPY_LAUNCHER"
'

run_step "LOVE2D" "is_installed love" '
sudo apt install -y love
'

# -----------------------------
# CREATIVE TOOLS
# -----------------------------

run_step "GIMP/Krita/Inkscape" "is_installed gimp && is_installed krita && is_installed inkscape" '
sudo apt install -y gimp krita inkscape
'

run_step "Piskel" "false" '
PISKEL_URL=$(curl -s https://api.github.com/repos/piskelapp/piskel/releases/latest |
jq -r ".assets[] | select(.name|test(\"linux.*64\")) | .browser_download_url" | head -n 1)

safe_wget "$PISKEL_URL" /tmp/piskel.zip || exit 1
mkdir -p /opt/gamedev/art/piskel
unzip -o /tmp/piskel.zip -d /opt/gamedev/art/piskel

PISKEL_BIN=$(safe_find_exec /opt/gamedev/art/piskel)
chmod +x "$PISKEL_BIN"
sudo ln -sf "$PISKEL_BIN" /usr/local/bin/piskel
'

run_step "Pixelorama" "is_installed pixelorama" '
safe_wget https://github.com/Orama-Interactive/Pixelorama/releases/latest/download/Pixelorama.x86_64.AppImage /opt/gamedev/art/pixelorama.AppImage &&
chmod +x /opt/gamedev/art/pixelorama.AppImage &&
sudo ln -sf /opt/gamedev/art/pixelorama.AppImage /usr/local/bin/pixelorama
'

run_step "LibreSprite" "false" '
safe_wget https://github.com/LibreSprite/LibreSprite/releases/latest/download/LibreSprite-x86_64.AppImage /opt/gamedev/art/libresprite.AppImage || true
chmod +x /opt/gamedev/art/libresprite.AppImage || true
sudo ln -sf /opt/gamedev/art/libresprite.AppImage /usr/local/bin/libresprite || true
'

# -----------------------------
# AUDIO / VIDEO
# -----------------------------

run_step "Audio & Video Suite" "is_installed vlc && is_installed kdenlive" '
sudo apt install -y vlc kdenlive obs-studio lmms audacity ardour hydrogen
'

# -----------------------------
# LEVEL EDITORS
# -----------------------------

run_step "Tiled Map Editor" "is_installed tiled" '
sudo apt install -y tiled
'

run_step "LDtk" "false" '
LDTK_URL=$(curl -s https://api.github.com/repos/deepnight/ldtk/releases/latest |
jq -r ".assets[] | select(.name|test(\"Linux.*zip\")) | .browser_download_url" | head -n 1)

safe_wget "$LDTK_URL" /tmp/ldtk.zip || exit 1
mkdir -p /opt/gamedev/tools/ldtk
unzip -o /tmp/ldtk.zip -d /opt/gamedev/tools/ldtk

LDTK_BIN=$(safe_find_exec /opt/gamedev/tools/ldtk)
chmod +x "$LDTK_BIN"
sudo ln -sf "$LDTK_BIN" /usr/local/bin/ldtk
'

run_step "LDtk Sync Pipeline" "is_installed ldtk-sync" '
cat > /usr/local/bin/ldtk-sync <<EOF
#!/usr/bin/env bash
WATCH_DIR=\${1:-\$PWD}

echo "👀 Watching LDtk files in: \$WATCH_DIR"

inotifywait -m "\$WATCH_DIR" -e close_write |
while read path action file; do
    if [[ "\$file" == *.ldtk ]]; then
        echo "Exporting: \$file"
        cp "\$path\$file" "\$WATCH_DIR/export_\$file.json"
    fi
done
EOF

chmod +x /usr/local/bin/ldtk-sync
'

# -----------------------------
# PRODUCTIVITY
# -----------------------------

run_step "Obsidian" "is_installed obsidian" '
OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
jq -r ".assets[] | select(.name|test(\"AppImage\")) | .browser_download_url" | head -n 1)

safe_wget "$OBSIDIAN_URL" /opt/gamedev/tools/obsidian.AppImage || exit 1
chmod +x /opt/gamedev/tools/obsidian.AppImage
sudo ln -sf /opt/gamedev/tools/obsidian.AppImage /usr/local/bin/obsidian
'

# -----------------------------
# DEPLOYMENT
# -----------------------------

run_step "itch.io Butler" "is_installed butler" '
safe_wget https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default /tmp/butler.zip
unzip /tmp/butler.zip -d /tmp
sudo mv /tmp/butler /usr/local/bin/
sudo chmod +x /usr/local/bin/butler
'

# -----------------------------
# SUMMARY
# -----------------------------

echo
echo "========================================="
echo "INSTALLATION SUMMARY"
echo "========================================="

echo
echo "INSTALLED:"
printf '  ✓ %s\n' "${INSTALLED[@]}"

echo
echo "FAILED:"
printf '  ✗ %s\n' "${FAILED[@]}"

echo
echo "MANUAL INSTALL REQUIRED:"
printf '  • %s\n' "${MANUAL[@]}"

echo
echo "========================================="
echo "Done."
echo "========================================="
