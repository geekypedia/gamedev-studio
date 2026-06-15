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
# SAFE HELPERS (IMPORTANT FIX)
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
    local path="$1"
    find "$path" -type f -executable 2>/dev/null | head -n 1
}

run_step() {
    local NAME="$1"
    shift

    echo
    echo "--------------------------------------------------"
    echo "Installing: $NAME"
    echo "--------------------------------------------------"

    bash -c "$*"
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
run_step "System Dependencies" '
sudo apt update -y &&
sudo apt install -y \
git curl wget unzip jq zenity inotify-tools \
build-essential software-properties-common \
libfuse2 flatpak python3 python3-pip
'

# ----------------------------------------
# GPU DRIVERS
# ----------------------------------------
run_step "GPU Drivers" sudo ubuntu-drivers autoinstall

# ----------------------------------------
# FLATPAK
# ----------------------------------------
run_step "Flatpak + Bottles" '
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &&
flatpak install -y flathub com.usebottles.bottles || true
'

# ----------------------------------------
# NODE / NVM
# ----------------------------------------
run_step "Node.js (NVM + LTS)" '
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts &&
nvm use --lts &&

npm install -g vite create-react-app react phaser excalibur
'

# ----------------------------------------
# CODE EDITORS (FIXED VS CODE)
# ----------------------------------------
echo "[5] Installing code editors..."

sudo rm -f /etc/apt/sources.list.d/vscode.list
sudo rm -f /usr/share/keyrings/ms.gpg
sudo rm -f /usr/share/keyrings/packages.microsoft.gpg

run_step "VS Code Repo Setup" '
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor |
sudo tee /usr/share/keyrings/ms.gpg >/dev/null

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms.gpg] https://packages.microsoft.com/repos/code stable main" |
sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
'

run_step "VS Code Install" '
sudo apt update &&
sudo apt install -y code
'

run_step "Code Server" '
curl -fsSL https://code-server.dev/install.sh | sudo bash
'

# ----------------------------------------
# WEB BROWSER
# ----------------------------------------
run_step "Google Chrome" '
safe_wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb /tmp/chrome.deb &&
sudo apt install -y /tmp/chrome.deb
'

# ----------------------------------------
# GAME ENGINES (PART 1)
# ----------------------------------------

run_step "Godot" '
GODOT_URL=$(curl -s https://api.github.com/repos/godotengine/godot/releases/latest |
jq -r ".assets[] | select(.name|test(\"linux.*x86_64.*zip\")) | .browser_download_url" |
head -n 1)

safe_wget "$GODOT_URL" /tmp/godot.zip &&
unzip -o /tmp/godot.zip -d /tmp/godot

GODOT_BIN=$(safe_find_exec /tmp/godot)
[ -n "$GODOT_BIN" ] || exit 1

sudo cp "$GODOT_BIN" "'"$BASE"'/engines/godot" &&
sudo chmod +x "'"$BASE"'/engines/godot" &&
sudo ln -sf "'"$BASE"'/engines/godot" "'"$BIN"'/godot
'

run_step "GDevelop" '
GDEV_URL=$(curl -s https://api.github.com/repos/4ian/GDevelop/releases/latest |
jq -r ".assets[] | select(.name|test(\"linux.*AppImage\")) | .browser_download_url" |
head -n 1)

safe_wget "$GDEV_URL" "'"$BASE"'/engines/gdevelop.AppImage" &&
chmod +x "'"$BASE"'/engines/gdevelop.AppImage" &&
sudo ln -sf "'"$BASE"'/engines/gdevelop.AppImage" "'"$BIN"'/gdevelop
'

run_step "ct.js" '
CT_URL=$(curl -s https://api.github.com/repos/ct-js/ct-js/releases/latest |
jq -r ".assets[] | select(.name|test(\"AppImage\")) | .browser_download_url" |
head -n 1)

safe_wget "$CT_URL" "'"$BASE"'/engines/ctjs.AppImage" &&
chmod +x "'"$BASE"'/engines/ctjs.AppImage" &&
sudo ln -sf "'"$BASE"'/engines/ctjs.AppImage" "'"$BIN"'/ctjs
'

run_step "RenPy" '
safe_wget https://www.renpy.org/dl/latest/renpy.zip /tmp/renpy.zip &&
mkdir -p "'"$BASE"'/engines/renpy" &&
unzip -o /tmp/renpy.zip -d "'"$BASE"'/engines/renpy
'

run_step "LOVE2D" sudo apt install -y love

run_step "MicroStudio" '
MICRO_URL=$(curl -s https://api.github.com/repos/pmgl/microstudio/releases/latest |
jq -r ".assets[] | select(.name|test(\"linux\")) | .browser_download_url" |
head -n 1)

safe_wget "$MICRO_URL" /tmp/microstudio.zip &&
mkdir -p "'"$BASE"'/web/microstudio" &&
unzip -o /tmp/microstudio.zip -d "'"$BASE"'/web/microstudio

MICRO_BIN=$(safe_find_exec "'"$BASE"'/web/microstudio")
[ -n "$MICRO_BIN" ] || exit 1

sudo ln -sf "$MICRO_BIN" "'"$BIN"'/microstudio
'

# ----------------------------------------
# CREATIVE TOOLS
# ----------------------------------------

run_step "GIMP/Krita/Inkscape" \
sudo apt install -y gimp krita inkscape

run_step "Pixelorama" '
safe_wget https://github.com/Orama-Interactive/Pixelorama/releases/latest/download/Pixelorama.x86_64.AppImage "'"$BASE"'/art/pixelorama.AppImage" &&
chmod +x "'"$BASE"'/art/pixelorama.AppImage" &&
sudo ln -sf "'"$BASE"'/art/pixelorama.AppImage" "'"$BIN"'/pixelorama
'

run_step "LibreSprite" '
safe_wget https://github.com/LibreSprite/LibreSprite/releases/latest/download/LibreSprite-x86_64.AppImage "'"$BASE"'/art/libresprite.AppImage" || true
chmod +x "'"$BASE"'/art/libresprite.AppImage" || true
sudo ln -sf "'"$BASE"'/art/libresprite.AppImage" "'"$BIN"'/libresprite || true
'

run_step "Piskel" '
PISKEL_URL=$(curl -s https://api.github.com/repos/piskelapp/piskel/releases/latest |
jq -r ".assets[] | select(.name|test(\"linux.*64\")) | .browser_download_url" |
head -n 1)

safe_wget "$PISKEL_URL" /tmp/piskel.zip &&
mkdir -p "'"$BASE"'/art/piskel" &&
unzip -o /tmp/piskel.zip -d "'"$BASE"'/art/piskel

PISKEL_BIN=$(safe_find_exec "'"$BASE"'/art/piskel")
[ -n "$PISKEL_BIN" ] || exit 1

chmod +x "$PISKEL_BIN"
sudo ln -sf "$PISKEL_BIN" "'"$BIN"'/piskel
'

# ----------------------------------------
# AUDIO / VIDEO
# ----------------------------------------

run_step "Audio & Video Suite" \
sudo apt install -y vlc kdenlive obs-studio lmms audacity ardour hydrogen drumkv1 synthv1 samplv1 geonkick

# ----------------------------------------
# LDtk
# ----------------------------------------

run_step "Tiled" sudo apt install -y tiled

run_step "LDtk" '
LDTK_URL=$(curl -s https://api.github.com/repos/deepnight/ldtk/releases/latest |
jq -r ".assets[] | select(.name|test(\"Linux.*zip\")) | .browser_download_url" |
head -n 1)

safe_wget "$LDTK_URL" /tmp/ldtk.zip &&
mkdir -p "'"$BASE"'/tools/ldtk" &&
unzip -o /tmp/ldtk.zip -d "'"$BASE"'/tools/ldtk

LDTK_BIN=$(safe_find_exec "'"$BASE"'/tools/ldtk")
[ -n "$LDTK_BIN" ] || exit 1

chmod +x "$LDTK_BIN"
sudo ln -sf "$LDTK_BIN" "'"$BIN"'/ldtk
'

# ----------------------------------------
# LDtk Sync Tool
# ----------------------------------------

run_step "LDtk Sync Tool" '
cat > "'"$BIN"'/ldtk-sync" <<'"'"'EOF'"'"'
#!/usr/bin/env bash
WATCH=${1:-$PWD}
echo "Watching LDtk files in: $WATCH"
inotifywait -m "$WATCH" -e close_write |
while read path action file; do
  [[ "$file" == *.ldtk ]] && cp "$path$file" "$WATCH/export_$file.json"
done
EOF

chmod +x "'"$BIN"'/ldtk-sync
'

# ----------------------------------------
# OBSIDIAN
# ----------------------------------------

run_step "Obsidian" '
OBSIDIAN_URL=$(curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
jq -r ".assets[] | select(.name|test(\"AppImage\")) | .browser_download_url" |
head -n 1)

safe_wget "$OBSIDIAN_URL" "'"$BASE"'/tools/obsidian.AppImage" &&
chmod +x "'"$BASE"'/tools/obsidian.AppImage" &&
sudo ln -sf "'"$BASE"'/tools/obsidian.AppImage" "'"$BIN"'/obsidian
'

# ----------------------------------------
# BUTLER
# ----------------------------------------

run_step "itch.io Butler" '
safe_wget https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default /tmp/butler.zip &&
unzip /tmp/butler.zip -d /tmp &&
[ -f /tmp/butler ] &&
sudo mv /tmp/butler /usr/local/bin/ &&
sudo chmod +x /usr/local/bin/butler
'

# ----------------------------------------
# GAMDEV COMMAND
# ----------------------------------------

run_step "Gamedev Command" '
cat > "'"$BIN"'/gamedev" <<'"'"'EOF'"'"'
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

chmod +x "'"$BIN"'/gamedev
'

# ----------------------------------------
# SUMMARY
# ----------------------------------------

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
