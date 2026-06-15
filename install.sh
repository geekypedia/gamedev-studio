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
# GLOBAL VARIABLES
# -----------------------------

APPLICATION_ID="5ddd20fa-76f4-40a2-8fc1-9599cac0924e"
TMP_DIR="/tmp/$APPLICATION_ID"

# -----------------------------
# SAFE HELPERS
# -----------------------------

safe_wget() {
    local url="$1"
    local out="$2"

    if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo "⚠️ safe_wget: empty URL"
        return 1
    fi

    echo "⬇️ Downloading: $url"

    # Create isolated temp directory per run
    #local TMP_DIR="/tmp/5ddd20fa-76f4-40a2-8fc1-9599cac0924e"
    mkdir -p "$TMP_DIR"

    download() {
        if command -v curl >/dev/null 2>&1; then
            curl -L --fail --progress-bar "$url" -o "$1"
        elif command -v wget >/dev/null 2>&1; then
            wget --show-progress -O "$1" "$url"
        else
            echo "❌ Neither curl nor wget is installed"
            return 1
        fi
    }

    # Try requested location first
    if download "$out"; then
        [ -s "$out" ] && return 0
    fi

    echo "⚠️ Primary download path failed, retrying in isolated tmp..."

    local tmpfile="$TMP_DIR/$(basename "$out")"

    if download "$tmpfile"; then
        if [ -s "$tmpfile" ]; then
            mv "$tmpfile" "$out" 2>/dev/null || {
                echo "⚠️ Cannot move to target, keeping in sandbox: $tmpfile"
                return 0
            }
            return 0
        fi
    fi

    echo "⚠️ Download failed"
    return 1
}

safe_wget_silent() {
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

is_ok() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
    return 0
}

# -----------------------------
# BINARY REGISTRY (FIX)
# -----------------------------
create_desktop_entry() {
    local app="$1"
    local display_name="${2:-$1}"

    local bin
    bin=$(command -v "$app" 2>/dev/null)

    if [ -z "$bin" ]; then
        echo "⚠️ Cannot create desktop entry: $app not found"
        return 1
    fi

    local real_bin
    real_bin=$(readlink -f "$bin")

    local icon=""

    icon=$(find "$(dirname "$real_bin")" \
        -type f \
        \( -iname "*.png" -o -iname "*.svg" -o -iname "*.xpm" \) \
        | head -n1)

    [ -z "$icon" ] && icon="$app"

    sudo tee "/usr/share/applications/${app}.desktop" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$display_name
Exec=$bin
Icon=$icon
Terminal=false
Categories=Development;
StartupNotify=true
EOF

    sudo chmod 644 "/usr/share/applications/${app}.desktop"

    command -v update-desktop-database >/dev/null 2>&1 &&
        sudo update-desktop-database /usr/share/applications >/dev/null 2>&1 || true

    echo "🖥️ Desktop launcher created: $display_name"
}

register_bin() {
    local name="$1"
    local target="$2"
    local display_name="${3:-$name}"

    if [ -z "$target" ] || [ ! -f "$target" ]; then
        echo "⚠ Cannot register $name (missing binary: $target)"
        return 1
    fi

    chmod +x "$target"
    sudo ln -sf "$target" /usr/local/bin/"$name"

    create_desktop_entry "$name" "$display_name"
}


# -----------------------------
# APT REPO
# -----------------------------

apt_cleanup_repo() {
  local pattern="$1"

  echo "🧹 Searching APT configs for: $pattern"

  # Find all repo files containing the pattern
  grep -Rsl "$pattern" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | while read -r file; do
    echo "🔍 Found in: $file"

    # Show current entries (debug-safe)
    grep -n "$pattern" "$file" || true
  done
}

fix_microsoft_repo() {
  echo "🧹 Cleaning ONLY Microsoft VS Code repo entries..."

  local TARGET="packages.microsoft.com/repos/code"

  # Remove from all .list files in sources.list.d
  for f in /etc/apt/sources.list.d/*.list; do
    [ -e "$f" ] || continue

    if grep -q "$TARGET" "$f"; then
      echo "🗑 Cleaning file: $f"
      sudo sed -i "\|$TARGET|d" "$f"

      # If file becomes empty, remove it
      if [ ! -s "$f" ]; then
        sudo rm -f "$f"
      fi
    fi
  done

  # Remove from main sources.list only those lines
  if grep -q "$TARGET" /etc/apt/sources.list 2>/dev/null; then
    echo "🧹 Cleaning /etc/apt/sources.list"
    sudo sed -i "\|$TARGET|d" /etc/apt/sources.list
  fi

  # Remove ONLY Microsoft keyrings (not everything APT-related)
  sudo rm -f /usr/share/keyrings/ms.gpg
  sudo rm -f /usr/share/keyrings/microsoft.gpg
  sudo rm -f /etc/apt/keyrings/microsoft.gpg

  sudo mkdir -p /etc/apt/keyrings

  echo "✅ Microsoft repo cleaned safely"
}

setup_microsoft_repo() {
  echo "🔑 Adding clean Microsoft VS Code repo..."

  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null

  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

  sudo apt-get update -y || true
  echo "✅ VS Code repo ready"
}

check_apt_conflicts() {
  echo "🔎 Checking for Signed-By conflicts..."

  grep -R "signed-by" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null |
  awk -F: '{print $2}' |
  sort |
  uniq -c |
  awk '$1 > 1 {print "⚠️ Duplicate entry:", $0}'
}


# -----------------------------
# INSTALLER ENGINE
# -----------------------------

gh_asset() {
    local repo="$1"
    local match1="$2"
    local match2="$3"
    local ext="$4"

    curl -s "https://api.github.com/repos/$repo/releases/latest" |
    jq -r --arg m1 "$match1" --arg m2 "$match2" --arg ext "$ext" '
        .assets[]
        | select(.name | test($m1; "i"))
        | select(.name | test($m2; "i"))
        | select(.name | endswith($ext))
        | .browser_download_url
    ' | head -n1
}

gdrive_download() {
    local file_id="$1"
    local out="$2"

    echo "⬇️ Google Drive download: $file_id"

    # first request (may return confirm page)
    curl -L -c /tmp/gcookie -s \
      "https://drive.google.com/uc?export=download&id=$file_id" \
      > /tmp/gpage.html

    # extract confirm token if present
    CONFIRM=$(grep -o 'confirm=[^&"]*' /tmp/gpage.html | head -n1 | cut -d= -f2)

    if [ -n "$CONFIRM" ]; then
        curl -L -b /tmp/gcookie \
          "https://drive.google.com/uc?export=download&confirm=$CONFIRM&id=$file_id" \
          -o "$out"
    else
        curl -L \
          "https://drive.google.com/uc?export=download&id=$file_id" \
          -o "$out"
    fi

    [ -s "$out" ]
}

install_engine() {
    local name="$1"
    shift
    local url="$1"
    local type="$2"
    local dest="$3"

    echo "⬇️ Installing $name"

    mkdir -p "$dest"

    case "$type" in
        appimage)
            safe_wget "$url" "$dest/$name.AppImage" || return 0
            chmod +x "$dest/$name.AppImage"
            register_bin "$name" "$dest/$name.AppImage"
        ;;

        zip)
            safe_wget "$url" "$TMP_DIR/$name.zip" || return 0
            unzip -o "$TMP_DIR/$name.zip" -d "$dest" || return 0
        ;;

        tar.gz)
            safe_wget "$url" "$TMP_DIR/$name.tar.gz" || return 0
            tar -xzf "$TMP_DIR/$name.tar.gz" -C "$dest" || return 0
        ;;

        tar.bz2)
            safe_wget "$url" "$TMP_DIR/$name.tar.bz2" || return 0
            tar -xjf "$TMP_DIR/$name.tar.bz2" -C "$dest" || return 0
        ;;
    esac
}

echo "========================================="
echo "🎮 Game Dev Studio Installer (Ubuntu)"
echo "========================================="

BASE="/opt/gamedev"
BIN="/usr/local/bin"

# Create base directories as root
sudo mkdir -p "$BASE"
sudo mkdir -p "$BIN"

# Take ownership of the whole gamedev tree
sudo chown -R "$USER:$USER" "$BASE"

# Now create subfolders as normal user (no sudo needed)
mkdir -p "$BASE"/{engines,tools,art}

# Create and Take ownership of the tmp too
sudo mkdir -p "$TMP_DIR"
sudo chown -R "$USER:$USER" "$TMP_DIR"

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
"is_ok git curl wget unzip jq" '
sudo apt install -y \
git curl wget unzip jq zenity inotify-tools \
build-essential software-properties-common \
libfuse2 flatpak python3 python3-pip
'

# -----------------------------
# GPU DRIVERS
# -----------------------------

if [[ "$RUN_UPGRADE_STEP" -eq 1 ]]; then
run_step "GPU Drivers" "nvidia-smi >/dev/null 2>&1 || lspci | grep -i nvidia" '
sudo ubuntu-drivers autoinstall
'
fi

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

npm install -g typescript --progress=true --verbose
npm install -g vite --progress=true --verbose
npm install -g react --progress=true --verbose
npm install -g create-react-app --progress=true --verbose
npm install -g phaser --progress=true --verbose
npm install -g excalibur --progress=true --verbose
npm install -g nw --progress=true --verbose
npm install -g electron --progress=true --verbose
'

# -----------------------------
# CODE EDITORS
# -----------------------------

run_step "VS Code Repo Setup" "false" '
echo "🧹 Cleaning old VS Code / Microsoft repository definitions..."

# Remove all known VS Code / Microsoft repo definitions
sudo rm -f /etc/apt/sources.list.d/vscode.list
sudo rm -f /etc/apt/sources.list.d/vscode.sources

sudo rm -f /etc/apt/sources.list.d/*vscode*.list
sudo rm -f /etc/apt/sources.list.d/*vscode*.sources

sudo rm -f /etc/apt/sources.list.d/*microsoft*.list
sudo rm -f /etc/apt/sources.list.d/*microsoft*.sources

# Remove any inline VS Code entries from main sources.list
sudo sed -i "\|packages.microsoft.com/repos/code|d" /etc/apt/sources.list 2>/dev/null || true

# Remove old keyrings
sudo rm -f /usr/share/keyrings/ms.gpg
sudo rm -f /usr/share/keyrings/microsoft.gpg
sudo rm -f /etc/apt/keyrings/microsoft.gpg

# Create keyring directory
sudo mkdir -p /etc/apt/keyrings

echo "🔑 Installing Microsoft signing key..."

curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg

echo "📦 Adding VS Code repository..."

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

echo "🔍 Active VS Code repo definitions:"
grep -R "packages.microsoft.com/repos/code" /etc/apt 2>/dev/null || true

echo "🔄 Updating package cache..."
sudo apt-get update -y || {
    echo "⚠️ apt update failed"
    return 0
}

echo "✅ VS Code repository configured"
'

run_step "VS Code Install" "is_installed code" '
sudo apt-get install -y code || {
    echo "⚠️ VS Code installation failed"
    return 0
}
'

run_step "Code Server" "is_installed code-server" '
curl -fsSL https://code-server.dev/install.sh | sudo bash || {
  echo "⚠️ code-server install failed"
  return 0
}
'

# -----------------------------
# WEB BROWSER
# -----------------------------

run_step "Google Chrome" "is_ok google-chrome google-chrome-stable chromium" '
mkdir -p "$TMP_DIR"

CHROME_DEB="$TMP_DIR/chrome.deb"

safe_wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb "$CHROME_DEB" || {
  echo "⚠️ Download failed"
  return 0
}

sudo dpkg -i "$CHROME_DEB" || {
  echo "⚠️ dpkg install had dependency issues, fixing..."
}

sudo apt-get install -f -y || {
  echo "⚠️ apt fix failed"
  return 0
}
'

# -----------------------------
# GAME ENGINES
# -----------------------------

run_step "Godot" "is_installed godot" '
mkdir -p "$TMP_DIR"

GODOT_URL=$(
  curl -s https://api.github.com/repos/godotengine/godot/releases/latest |
  jq -r ".assets[] | select(.name|test(\"linux.*x86_64.*zip\")) | .browser_download_url" |
  head -n 1
)

if [ -z "$GODOT_URL" ]; then
    echo "⚠️ Godot download URL not found"
    return 0
fi

GODOT_ZIP="$TMP_DIR/godot.zip"

safe_wget "$GODOT_URL" "$GODOT_ZIP" || {
    echo "⚠️ Godot download failed"
    return 0
}

rm -rf "$TMP_DIR/godot"
mkdir -p "$TMP_DIR/godot"

unzip -o "$GODOT_ZIP" -d "$TMP_DIR/godot" || {
    echo "⚠️ Godot unzip failed"
    return 0
}

GODOT_BIN=$(find "$TMP_DIR/godot" -type f -executable -name "*x86_64*" | head -n 1)

if [ -z "$GODOT_BIN" ]; then
    echo "⚠️ Godot binary not found"
    return 0
fi

sudo install -Dm755 "$GODOT_BIN" /opt/gamedev/engines/godot

register_bin godot /opt/gamedev/engines/godot "Godot"
'

run_step "Godot Export Templates" "false" '
mkdir -p "$TMP_DIR"

API="https://api.github.com/repos/godotengine/godot/releases/latest"

TEMPLATE_URL=$(
  curl -s "$API" |
  jq -r "
    .assets[]
    | select(.name != null)
    | select(.name | test(\"export_templates\"))
    | .browser_download_url
  " | head -n 1
)

if [ -z "$TEMPLATE_URL" ]; then
    echo "⚠️ Could not find export templates URL"
    curl -s "$API" | jq -r ".assets[].name"
    return 0
fi

echo "⬇️ Downloading templates: $TEMPLATE_URL"

TEMPLATE_FILE="$TMP_DIR/godot_templates.tpz"

safe_wget "$TEMPLATE_URL" "$TEMPLATE_FILE" || {
    echo "⚠️ Template download failed"
    return 0
}

VERSION=$(curl -s "$API" | jq -r ".tag_name")

TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/$VERSION"

mkdir -p "$TEMPLATE_DIR" || {
    echo "⚠️ Failed to create template directory"
    return 0
}

unzip -o "$TEMPLATE_FILE" -d "$TEMPLATE_DIR" || {
    echo "⚠️ Template unzip failed"
    return 0
}
'

run_step "GDevelop" "is_installed gdevelop" '
GDEV_URL=$(
  curl -s https://api.github.com/repos/4ian/GDevelop/releases/latest |
  jq -r "
    .assets[]
    | select(.name | endswith(\".AppImage\"))
    | select(.name | contains(\"arm64\") | not)
    | .browser_download_url
  " | head -n1
)

if [ -z "$GDEV_URL" ]; then
    echo "⚠️ Could not find x86_64 AppImage"
    return 0
fi

safe_wget "$GDEV_URL" /opt/gamedev/engines/gdevelop.AppImage || {
    echo "⚠️ GDevelop download failed"
    return 0
}

register_bin gdevelop /opt/gamedev/engines/gdevelop.AppImage "GDevelop"
'

run_step "ct.js" "is_installed ctjs" '
mkdir -p "$TMP_DIR"
mkdir -p /opt/gamedev/engines/ctjs

CT_URL=$(
  curl -s https://api.github.com/repos/ct-js/ct-js/releases/latest |
  jq -r "
    .assets[]
    | select(.name | test(\"linux.*64.*zip$\"; \"i\"))
    | .browser_download_url
  " | head -n1
)

if [ -z "$CT_URL" ]; then
  echo "⚠️ Could not find ct.js Linux x64 ZIP"
  return 0
fi

CT_ZIP="$TMP_DIR/ctjs.zip"
CT_TMP="$TMP_DIR/ctjs"
CT_INSTALL="/opt/gamedev/engines/ctjs"

safe_wget "$CT_URL" "$CT_ZIP" || {
  echo "⚠️ ct.js download failed"
  return 0
}

rm -rf "$CT_TMP"
mkdir -p "$CT_TMP"

unzip -o "$CT_ZIP" -d "$CT_TMP" || {
  echo "⚠️ Failed to extract ct.js"
  return 0
}

# Find binary in temp
CT_BIN=$(find "$CT_TMP" -type f -name "ctjs" -executable | head -n 1)

if [ -z "$CT_BIN" ]; then
  echo "⚠️ ct.js executable not found"
  return 0
fi

# Move full extracted folder into /opt
rm -rf "$CT_INSTALL"
mv "$CT_TMP" "$CT_INSTALL"

# Update binary path after move
CT_BIN_FINAL=$(find "$CT_INSTALL" -type f -name "ctjs" -executable | head -n 1)

if [ -z "$CT_BIN_FINAL" ]; then
  echo "⚠️ ct.js binary missing after install move"
  return 0
fi

register_bin ctjs "$CT_BIN_FINAL" "Ct.js"
'

run_step "RenPy" "is_installed renpy" '

mkdir -p "$TMP_DIR"

API="https://api.github.com/repos/renpy/renpy/releases/latest"

DATA=$(curl -s "$API")

# Prefer SDK tar.bz2
RENPY_URL=$(echo "$DATA" | jq -r "
  .assets[]
  | select(.name | endswith(\"sdk.tar.bz2\"))
  | .browser_download_url
" | head -n1)

EXT="tar.bz2"

# Fallback to zip if tar.bz2 not found
if [ -z "$RENPY_URL" ]; then
    RENPY_URL=$(echo "$DATA" | jq -r "
      .assets[]
      | select(.name | endswith(\"sdk.zip\"))
      | .browser_download_url
    " | head -n1)

    EXT="zip"
fi

if [ -z "$RENPY_URL" ]; then
    echo "⚠️ Could not find RenPy SDK"
    return 0
fi

echo "⬇️ RenPy URL: $RENPY_URL"

OUT="$TMP_DIR/renpy.$EXT"

safe_wget "$RENPY_URL" "$OUT" || {
    echo "⚠️ RenPy download failed"
    return 0
}

rm -rf /opt/gamedev/engines/renpy
mkdir -p /opt/gamedev/engines/renpy

if [ "$EXT" = "tar.bz2" ]; then
    tar -xjf "$OUT" -C /opt/gamedev/engines/renpy || {
        echo "⚠️ Extraction failed (tar.bz2)"
        return 0
    }
else
    unzip -o "$OUT" -d /opt/gamedev/engines/renpy || {
        echo "⚠️ Extraction failed (zip)"
        return 0
    }
fi

RENPY_LAUNCHER=$(find /opt/gamedev/engines/renpy -type f -name "renpy.sh" | head -n 1)

if [ -z "$RENPY_LAUNCHER" ]; then
    echo "⚠️ renpy.sh not found"
    return 0
fi

register_bin renpy "$RENPY_LAUNCHER" "Ren'Py"
'

run_step "LOVE2D" "is_installed love" '
sudo apt install -y love
'

# -----------------------------
# CREATIVE TOOLS
# -----------------------------

run_step "Blender" "is_installed blender" '
sudo apt install -y blender
'

run_step "GIMP/Krita/Inkscape" "is_installed gimp && is_installed krita && is_installed inkscape" '
sudo apt install -y gimp krita inkscape
'

run_step "Pixelorama" "is_installed pixelorama" '
API="https://api.github.com/repos/Orama-Interactive/Pixelorama/releases/latest"

PIXEL_URL=$(
  curl -s "$API" |
  jq -r "
    .assets[]
    | select(.name | test(\"Linux\"; \"i\"))
    | select(.name | test(\"64bit\"; \"i\"))
    | select(.name | endswith(\".tar.gz\"))
    | .browser_download_url
  " | head -n1
)

if [ -z "$PIXEL_URL" ]; then
    echo "⚠️ Could not find Pixelorama Linux 64bit tar.gz"
    return 0
fi

echo "⬇️ Pixelorama URL: $PIXEL_URL"

PIXEL_ARCHIVE="$TMP_DIR/pixelorama.tar.gz"
PIXEL_DIR="/opt/gamedev/art/pixelorama"

safe_wget "$PIXEL_URL" "$PIXEL_ARCHIVE" || {
    echo "⚠️ Pixelorama download failed"
    return 0
}

rm -rf "$PIXEL_DIR"
mkdir -p "$PIXEL_DIR"

tar -xzf "$PIXEL_ARCHIVE" -C "$PIXEL_DIR" || {
    echo "⚠️ Extraction failed"
    return 0
}

PIXEL_BIN=$(find "$PIXEL_DIR" -type f -name "Pixelorama*" -executable | head -n1)

if [ -z "$PIXEL_BIN" ]; then
    echo "⚠️ Pixelorama binary not found"
    return 0
fi

register_bin pixelorama "$PIXEL_BIN" "Pixelorama"
'

run_step "LibreSprite" "is_installed libresprite" '
API="https://api.github.com/repos/LibreSprite/LibreSprite/releases/latest"

ZIP_URL=$(
  curl -s "$API" |
  jq -r "
    .assets[]
    | select(.name | test(\"linux.*x86_64.*zip$\"; \"i\"))
    | .browser_download_url
  " | head -n1
)

if [ -z "$ZIP_URL" ]; then
    echo "⚠️ Could not find LibreSprite Linux x86_64 zip"
    return 0
fi

echo "⬇️ LibreSprite URL: $ZIP_URL"

LIBRE_ZIP="$TMP_DIR/libresprite.zip"
LIBRE_DIR="/opt/gamedev/art/libresprite"

safe_wget "$ZIP_URL" "$LIBRE_ZIP" || {
    echo "⚠️ LibreSprite download failed"
    return 0
}

rm -rf "$LIBRE_DIR"
mkdir -p "$LIBRE_DIR"

unzip -o "$LIBRE_ZIP" -d "$LIBRE_DIR" || {
    echo "⚠️ Extraction failed"
    return 0
}

# Find actual AppImage inside extracted folder
LS_BIN=$(find "$LIBRE_DIR" -type f -name "*.AppImage" | head -n 1)

if [ -z "$LS_BIN" ]; then
    echo "⚠️ LibreSprite AppImage not found after extraction"
    return 0
fi

register_bin libresprite "$LS_BIN" "LibreSprite"
'

# -----------------------------
# AUDIO / VIDEO
# -----------------------------

run_step "Audio & Video Suite" "is_installed vlc && is_installed kdenlive" '
sudo apt install -y vlc kdenlive obs-studio lmms audacity ardour
sudo apt install -y hydrogen hydrogen-drumkits geonkick

'

# -----------------------------
# LEVEL EDITORS
# -----------------------------

run_step "LDtk" "false" '
API="https://api.github.com/repos/deepnight/ldtk/releases/latest"

LDTK_URL=$(
  curl -s "$API" |
  jq -r "
    .assets[]
    | select(.name == \"ubuntu-distribution.zip\")
    | .browser_download_url
  " | head -n1
)

if [ -z "$LDTK_URL" ]; then
  echo "⚠️ Could not find LDtk Linux build"
  return 0
fi

echo "⬇️ LDtk URL: $LDTK_URL"

LDTK_ZIP="$TMP_DIR/ldtk.zip"
LDTK_DIR="/opt/gamedev/tools/ldtk"

safe_wget "$LDTK_URL" "$LDTK_ZIP" || {
  echo "⚠️ LDtk download failed"
  return 0
}

rm -rf "$LDTK_DIR"
mkdir -p "$LDTK_DIR"

unzip -o "$LDTK_ZIP" -d "$LDTK_DIR" || {
  echo "⚠️ LDtk unzip failed"
  return 0
}

# First try obvious executable names
LDTK_BIN=$(find "$LDTK_DIR" -type f \( -name "ldtk*" -o -name "LDtk*" \) -executable | head -n1)

# If not found, look for any AppImage
if [ -z "$LDTK_BIN" ]; then
  LDTK_BIN=$(find "$LDTK_DIR" -type f -name "*.AppImage" | head -n1)

  if [ -n "$LDTK_BIN" ]; then
    echo "🔧 Found AppImage without executable bit: $LDTK_BIN"
    chmod +x "$LDTK_BIN"
  fi
fi

if [ -z "$LDTK_BIN" ]; then
  echo "⚠️ Could not locate LDtk executable"
  echo "Contents of extracted folder:"
  find "$LDTK_DIR" -type f | head -50
  return 0
fi

register_bin ldtk "$LDTK_BIN" "LDtk"
'


run_step "LDtk Sync Pipeline" "is_installed ldtk-sync" '
sudo tee /usr/local/bin/ldtk-sync >/dev/null <<EOF
#!/usr/bin/env bash

WATCH_DIR="\${1:-\$PWD}"

echo "👀 Watching LDtk files in: \$WATCH_DIR"

inotifywait -m "\$WATCH_DIR" -e close_write |
while read path action file; do
    if [[ "\$file" == *.ldtk ]]; then
        echo "Exporting: \$file"
        cp "\$path\$file" "\$WATCH_DIR/export_\$file.json"
    fi
done
EOF

sudo chmod +x /usr/local/bin/ldtk-sync
'

# -----------------------------
# PRODUCTIVITY
# -----------------------------

run_step "Obsidian" "is_installed obsidian" '
mkdir -p /opt/gamedev/tools

OBSIDIAN_URL=$(
  curl -s https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest |
  jq -r "
    .assets[]
    | select(.name | endswith(\".AppImage\"))
    | select(.name | ascii_downcase | contains(\"arm64\") | not)
    | .browser_download_url
  " | head -n1
)

if [ -z "$OBSIDIAN_URL" ]; then
  echo "⚠️ Could not find Obsidian AppImage"
  return 0
fi

safe_wget "$OBSIDIAN_URL" /opt/gamedev/tools/obsidian.AppImage || {
  echo "⚠️ Obsidian download failed"
  return 0
}

register_bin obsidian /opt/gamedev/tools/obsidian.AppImage "Obsidian"
'

# -----------------------------
# DEPLOYMENT
# -----------------------------

run_step "itch.io Butler" "is_installed butler" '
mkdir -p "$TMP_DIR"

BUTLER_URLS=(
  "https://broth.itch.ovh/butler/linux-amd64/LATEST/archive/default"
  "https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default"
)

BUTLER_ZIP="$TMP_DIR/butler.zip"
BUTLER_TMP="$TMP_DIR/butler_unpack"
INSTALL_DIR="/opt/gamedev/tools/butler"

BUTLER_SOURCE=""

for url in "${BUTLER_URLS[@]}"; do
  echo "⬇️ Trying: $url"
  if safe_wget "$url" "$BUTLER_ZIP"; then
    BUTLER_SOURCE="$url"
    break
  fi
done

if [ -z "$BUTLER_SOURCE" ]; then
  echo "⚠️ Failed to download Butler from all mirrors"
  return 0
fi

rm -rf "$BUTLER_TMP"
mkdir -p "$BUTLER_TMP"

unzip -o "$BUTLER_ZIP" -d "$BUTLER_TMP" || {
  echo "⚠️ Failed to extract Butler"
  return 0
}

BUTLER_BIN=$(find "$BUTLER_TMP" -type f -name "butler" -executable | head -n1)

if [ -z "$BUTLER_BIN" ]; then
  echo "⚠️ Could not locate Butler executable"
  return 0
fi

mkdir -p "$INSTALL_DIR"
cp "$BUTLER_BIN" "$INSTALL_DIR/butler"
chmod +x "$INSTALL_DIR/butler"

register_bin butler "$INSTALL_DIR/butler" "Butler"
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
