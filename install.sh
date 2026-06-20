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

    if [[ "$FORCE_UPDATE" -eq 0 ]]; then
        eval "$CHECK_CMD"
        local CHECK_STATUS=$?

        if [[ $CHECK_STATUS -eq 0 ]]; then
            echo "✓ $NAME already installed (skipping)"
            INSTALLED+=("$NAME (already present)")
            return 0
        fi
    else
        echo "⚠ Force mode: reinstalling $NAME"
    fi

    eval "$*"
    local RUN_STATUS=$?

    if [[ $RUN_STATUS -eq 0 ]]; then
        success "$NAME"
    else
        failure "$NAME"
    fi

    return $RUN_STATUS
}

run_step_legacy() {
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

is_pip_installed() {
    python3 -c "import $1" 2>/dev/null
}

# -----------------------------
# BINARY REGISTRY (FIX)
# -----------------------------

copy_ctjs_icon() {
    local CT_INSTALL="$1"

    if [ -z "$CT_INSTALL" ] || [ ! -d "$CT_INSTALL" ]; then
        echo "⚠️ Invalid ct.js install path"
        return 1
    fi

    local SRC="$CT_INSTALL/linux64/package.nw/ct_ide.png"
    local DEST="$CT_INSTALL/linux64/icon.png"

    if [ ! -f "$SRC" ]; then
        echo "⚠️ ct.js icon not found at expected path: $SRC"
        return 1
    fi

    cp "$SRC" "$DEST"

    echo "🖼️ ct.js icon set: $DEST"
}

copy_ctjs_icon_rec() {
    local CT_INSTALL="$1"

    if [ -z "$CT_INSTALL" ] || [ ! -d "$CT_INSTALL" ]; then
        echo "⚠️ Invalid CTJS install path"
        return 1
    fi

    echo "🎯 Searching ct.js icon in $CT_INSTALL..."

    # Prefer common Electron / ct.js icon locations
    local ICON
    ICON=$(find "$CT_INSTALL" \
        -type f \( \
            -iname "ct_ide.png" \
            -o -iname "icon.png" \
            -o -iname "ctjs.png" \
            -o -iname "icon.ico" \
            -o -iname "*.png" \
        \) \
        | grep -Ei "(icon|ctjs)" \
        | head -n 1)

    # fallback: any reasonably sized png (avoid random assets if possible)
    if [ -z "$ICON" ]; then
        ICON=$(find "$CT_INSTALL" -type f -iname "*.png" | head -n 1)
    fi

    if [ -z "$ICON" ]; then
        echo "⚠️ No icon found for ct.js"
        return 1
    fi

    local DEST="$CT_INSTALL/icon.png"

    cp "$ICON" "$DEST"

    echo "🖼️ ct.js icon copied to: $DEST"
}

extract_appimage_icon() {
    local appimage="$1"

    if [ -z "$appimage" ] || [ ! -f "$appimage" ]; then
        echo "⚠️ Invalid AppImage path"
        return 1
    fi

    if [[ "$appimage" != *.AppImage ]]; then
        echo "⚠️ Not an AppImage: $appimage"
        return 1
    fi

    local dir icon_path tmpdir

    dir=$(dirname "$appimage")
    icon_path="$dir/icon.png"
    tmpdir="/tmp/appimage_extract_$$"

    # skip if already exists
    if [ -f "$icon_path" ]; then
        echo "✅ Icon already exists: $icon_path"
        return 0
    fi

    echo "🎯 Extracting icon from AppImage: $appimage"

    mkdir -p "$tmpdir"

    # extract AppImage filesystem
    if "$appimage" --appimage-extract >/dev/null 2>&1; then

        # 1. Best case: .DirIcon (most AppImages)
        if [ -f squashfs-root/.DirIcon ]; then
            cp squashfs-root/.DirIcon "$icon_path"

        # 2. Common Linux icon locations
        else
            ICON=$(find squashfs-root \
                -type f \
                \( -iname "*.png" -o -iname "*.svg" -o -iname "*.xpm" \) \
                | grep -Ei "(icon|logo|app)" \
                | head -n 1)

            if [ -n "$ICON" ]; then
                cp "$ICON" "$icon_path"
            fi
        fi

        rm -rf squashfs-root
    else
        echo "⚠️ AppImage extraction failed"
        return 1
    fi

    if [ -f "$icon_path" ]; then
        echo "🖼️ Icon saved: $icon_path"
    else
        echo "⚠️ No icon found inside AppImage"
        return 1
    fi
}

extract_appimage_icon_from_symlnk() {
    local app="$1"

    local bin
    bin=$(command -v "$app" 2>/dev/null)

    if [ -z "$bin" ]; then
        echo "⚠️ $app not found"
        return 1
    fi

    local appimage
    appimage=$(readlink -f "$bin")

    if [ -z "$appimage" ] || [[ "$appimage" != *.AppImage ]]; then
        echo "⚠️ $app does not point to an AppImage"
        return 1
    fi

    local dir
    dir=$(dirname "$appimage")

    local icon_path="$dir/icon.png"

    # skip if already extracted
    if [ -f "$icon_path" ]; then
        echo "✅ Icon already exists for $app"
        return 0
    fi

    echo "🎯 Extracting icon for $app from AppImage..."

    # AppImage extract mode (no execution required)
    if "$appimage" --appimage-extract >/dev/null 2>&1; then
        if [ -f squashfs-root/.DirIcon ]; then
            cp squashfs-root/.DirIcon "$icon_path"
        elif [ -f squashfs-root/usr/share/icons/hicolor/256x256/apps/*.png ]; then
            cp squashfs-root/usr/share/icons/hicolor/256x256/apps/*.png "$icon_path" 2>/dev/null || true
        fi

        rm -rf squashfs-root
    else
        echo "⚠️ Failed to extract AppImage for $app"
        return 1
    fi

    if [ -f "$icon_path" ]; then
        echo "🖼️ Icon saved: $icon_path"
    else
        echo "⚠️ Icon not found inside AppImage"
    fi
}

create_desktop_entry() {
    local app="$1"
    local display_name="${2:-$1}"
    local base_path="$3"

    local bin
    bin=$(command -v "$app" 2>/dev/null)

    if [ -z "$bin" ]; then
        echo "⚠️ Cannot create desktop entry: $app not found"
        return 1
    fi

    local real_bin
    real_bin=$(readlink -f "$bin")

    local base_dir
    if [ -n "$base_path" ]; then
        base_dir="$base_path"
    else
        base_dir=$(dirname "$real_bin")
    fi

    local icon=""

    echo "🎯 Resolving icon for $app..."

    # -------------------------------------------------------
    # 1. Try system theme icons first (BEST OPTION)
    # -------------------------------------------------------
    for i in "$app" "$(echo "$app" | tr '[:lower:]' '[:upper:]')" "$(echo "$app" | tr '[:upper:]' '[:lower:]')"; do
        if gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null; then
            :
        fi

        if [ -n "$(find /usr/share/icons /usr/share/pixmaps -iname "$i.*" 2>/dev/null | head -n1)" ]; then
            icon=$(find /usr/share/icons /usr/share/pixmaps -iname "$i.*" 2>/dev/null | head -n1)
            break
        fi
    done

    # -------------------------------------------------------
    # 2. Try icon next to executable (same folder only)
    # -------------------------------------------------------
    if [ -z "$icon" ]; then
        icon=$(find "$base_dir" -maxdepth 1 -type f \
            \( -iname "*.png" -o -iname "*.svg" -o -iname "*.xpm" \) \
            | grep -Ei "(icon|logo|app|$app)" \
            | head -n1)
    fi

    # -------------------------------------------------------
    # 3. Try ONE level deep ONLY (avoid random deep assets)
    # -------------------------------------------------------
    if [ -z "$icon" ]; then
        icon=$(find "$base_dir" -mindepth 2 -maxdepth 2 -type f \
            \( -iname "*.png" -o -iname "*.svg" \) \
            | grep -Ei "(icon|logo|$app)" \
            | head -n1)
    fi

    # -------------------------------------------------------
    # 4. Fallback: system icon name
    # -------------------------------------------------------
    if [ -z "$icon" ]; then
        icon="$app"
    fi

    sudo tee "/usr/share/applications/${app}.desktop" >/dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$display_name
Exec=$bin
Icon=$icon
Terminal=false
Categories=Development;GameDev;
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

  sudo apt update -y || true
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

is_npm_installed() {
    npm list -g --depth=0 "$1" >/dev/null 2>&1
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
"is_ok git curl wget unzip jq pv" '
sudo apt install -y \
git curl wget unzip jq pv zenity inotify-tools \
build-essential software-properties-common \
libfuse2 flatpak python3 python3-pip python3-venv
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

run_step "Node.js (NVM + LTS)" '
NVM_PATH="$(eval echo ~${SUDO_USER:-$USER})/.nvm/nvm.sh"
[ ! -s "$NVM_PATH" ]
' '
set -e

NVM_DIR="$(eval echo ~${SUDO_USER:-$USER})/.nvm"

if [ ! -d "$NVM_DIR" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$NVM_DIR"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts
nvm alias default "lts/*"

echo "✅ NVM + LTS Node installed"
'

run_step "TSC" "is_installed tsc" '
sudo apt install node-typescript -y || echo "⚠️ TypeScript install failed"
'

run_step "TypeScript" "is_npm_installed typescript" '
npm install -g typescript --progress=true --verbose || echo "⚠️ TypeScript install failed"
'

run_step "Vite" "is_installed vite" '
npm install -g vite --progress=true --verbose || echo "⚠️ Vite install failed"
'

run_step "Create Vite" "is_installed create-vite" '
npm install -g create-vite --progress=true --verbose || echo "⚠️ create-vite install failed"
'

run_step "React CLI" "is_installed create-react-app" '
npm install -g create-react-app --progress=true --verbose || echo "⚠️ create-react-app install failed"
'

run_step "Phaser CLI" "is_npm_installed phaser" '
npm install -g phaser --progress=true --verbose || echo "⚠️ Phaser install failed"
'

run_step "Excalibur CLI" "is_npm_installed excalibur" '
npm install -g excalibur --progress=true --verbose || echo "⚠️ Excalibur install failed"
'

run_step "NW.js CLI" "is_npm_installed nw" '
npm install -g nw --progress=true --verbose || echo "⚠️ NW.js install failed"
'

run_step "Electron CLI" "is_npm_installed electron" '
npm install -g electron --progress=true --verbose || echo "⚠️ Electron install failed"
'

# -----------------------------
# CODE EDITORS
# -----------------------------

run_step "VS Code Repo Setup" "is_installed code" '
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
sudo apt update -y || {
    echo "⚠️ apt update failed"
    return 0
}

echo "✅ VS Code repository configured"
'

run_step "VS Code Install" "is_installed code" '
sudo apt install -y code || {
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

run_step "HTTP Server" "is_installed http-server" '
npm install -g http-server || echo "⚠️ http-server install failed"
'

run_step "Serve" "is_installed serve" '
npm install -g serve || echo "⚠️ serve install failed"
'

run_step "SQLite (CLI)" "is_installed sqlite3" '
sudo apt install -y sqlite3 sqlite3-tools || echo "⚠️ SQLite install failed"
'

run_step "SQLite Browser" "is_installed sqlitebrowser" '
echo "📦 Installing DB Browser for SQLite..."

sudo apt install -y sqlitebrowser || {
    echo "⚠️ Failed to install sqlitebrowser"
    return 0
}

echo "🧭 Verifying installation..."
if command -v sqlitebrowser >/dev/null 2>&1; then
    echo "✅ SQLite Browser installed successfully"
else
    echo "⚠️ Installation completed but binary not found"
fi
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

sudo apt install -f -y || {
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

rm -rf /opt/gamedev/engines/godot
mkdir -p /opt/gamedev/engines/godot

sudo install -Dm755 "$GODOT_BIN" /opt/gamedev/engines/godot/godot

register_bin godot /opt/gamedev/engines/godot/godot "Godot"
'

run_step "Godot Export Templates" "false" '
mkdir -p "$TMP_DIR"

API="https://api.github.com/repos/godotengine/godot/releases"

echo "🌐 Fetching Godot export templates..."

RELEASE_JSON=$(curl -s "$API")

# get latest version tag (first release in list)
LATEST_VERSION=$(echo "$RELEASE_JSON" | jq -r ".[0].tag_name // empty")

# detect installed Godot version
INSTALLED_VERSION_RAW=$(godot --version 2>/dev/null || true)

# normalize: 4.6.3.stable.official.xxxxx → 4.6.3-stable
if [ -n "$INSTALLED_VERSION_RAW" ]; then
    BASE_VERSION=$(echo "$INSTALLED_VERSION_RAW" | cut -d. -f1-3)

    if echo "$INSTALLED_VERSION_RAW" | grep -q "stable"; then
        INSTALLED_VERSION="${BASE_VERSION}-stable"
    else
        INSTALLED_VERSION="$BASE_VERSION"
    fi
else
    INSTALLED_VERSION=""
fi

# decide version
if [ "$FORCE_UPDATE" -eq 1 ]; then
    VERSION="$LATEST_VERSION"
else
    VERSION="$INSTALLED_VERSION"
fi

# fallback
if [ -z "$VERSION" ] || [ "$VERSION" = "-" ]; then
    VERSION="$LATEST_VERSION"
fi

TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/$VERSION"

# skip if already installed
if [ "$FORCE_UPDATE" -eq 0 ] && [ -d "$TEMPLATE_DIR" ] && [ "$(ls -A "$TEMPLATE_DIR" 2>/dev/null)" ]; then
    echo "✅ Already installed for $VERSION"
    return 0
fi

echo "⬇️ Searching export templates for $VERSION"

TEMPLATE_URL=$(echo "$RELEASE_JSON" | jq -r "
  .[]
  | .assets[]?
  | select(.name? != null)
  | select(.name | test(\"export_templates\"))
  | .browser_download_url
" | head -n 1)

if [ -z "$TEMPLATE_URL" ]; then
    echo "⚠️ No export templates found in GitHub releases"
    echo "📦 Available assets (first release):"
    echo "$RELEASE_JSON" | jq -r ".[0].assets[].name? // empty"
    return 0
fi

echo "⬇️ Downloading: $TEMPLATE_URL"

TEMPLATE_FILE="$TMP_DIR/godot_templates.tpz"

safe_wget "$TEMPLATE_URL" "$TEMPLATE_FILE" || {
    echo "⚠️ Download failed"
    return 0
}

mkdir -p "$TEMPLATE_DIR"

unzip -o "$TEMPLATE_FILE" -d "$TEMPLATE_DIR" || {
    echo "⚠️ Unzip failed"
    return 0
}

echo "✅ Installed Godot templates for $VERSION"
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

rm -rf /opt/gamedev/engines/gdevelop
mkdir -p /opt/gamedev/engines/gdevelop

safe_wget "$GDEV_URL" /opt/gamedev/engines/gdevelop/gdevelop.AppImage || {
    echo "⚠️ GDevelop download failed"
    return 0
}

extract_appimage_icon /opt/gamedev/engines/gdevelop/gdevelop.AppImage
register_bin gdevelop /opt/gamedev/engines/gdevelop/gdevelop.AppImage "GDevelop"
'

run_step "ct.js" "is_installed ctjs" '
mkdir -p "$TMP_DIR"

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

copy_ctjs_icon "$CT_INSTALL"
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
    tar -xvjf "$OUT" -C /opt/gamedev/engines/renpy || {
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

register_bin renpy "$RENPY_LAUNCHER" "RenPy"
'

run_step "LOVE2D" "is_installed love" '
sudo apt install -y love
'

run_step "microStudio" "is_installed microstudio" '
API="https://api.github.com/repos/pmgl/microstudio/releases/latest"

echo "🌐 Fetching microStudio latest release..."

DEB_URL=$(curl -s "$API" | jq -r "
  .assets[]
  | select(.name != null)
  | select(.name | contains(\"linux\") and endswith(\".deb\"))
  | .browser_download_url
" | head -n 1)

if [ -z "$DEB_URL" ]; then
    echo "⚠️ microStudio Linux DEB not found"
    curl -s "$API" | jq -r ".assets[].name"
    return 0
fi

echo "⬇️ Downloading: $DEB_URL"

safe_wget "$DEB_URL" "$TMP_DIR/microstudio.deb" || {
    echo "⚠️ Download failed"
    return 0
}

echo "📦 Installing microStudio..."

sudo dpkg -i "$TMP_DIR/microstudio.deb" || {
    echo "⚠️ dpkg failed, fixing dependencies..."
    sudo apt-get install -f -y || {
        echo "⚠️ dependency fix failed"
        return 0
    }
}

echo "✅ microStudio installed successfully"
'

run_step "Defold" "is_installed defold" '
mkdir -p "$TMP_DIR"

DEFOLD_ZIP="$TMP_DIR/defold.zip"

safe_wget \
    "https://github.com/defold/defold/releases/latest/download/Defold-x86_64-linux.zip" \
    "$DEFOLD_ZIP" || {
    echo "⚠️ Defold download failed"
    return 0
}

rm -rf "$TMP_DIR/defold"
mkdir -p "$TMP_DIR/defold"

unzip -o "$DEFOLD_ZIP" -d "$TMP_DIR/defold" || {
    echo "⚠️ Defold unzip failed"
    return 0
}

DEFOLD_DIR=$(find "$TMP_DIR/defold" -maxdepth 1 -type d -name "Defold" | head -n 1)

if [ -z "$DEFOLD_DIR" ]; then
    echo "⚠️ Defold directory not found"
    return 0
fi

rm -rf /opt/gamedev/engines/Defold
mkdir -p /opt/gamedev/engines

sudo mv "$DEFOLD_DIR" /opt/gamedev/engines/Defold

sudo chmod +x /opt/gamedev/engines/Defold/Defold

sudo tee /usr/local/bin/defold << 'EOF'
#!/bin/bash
cd /opt/gamedev/engines/Defold/ && ./Defold "$@"
EOF

sudo chmod +x /usr/local/bin/defold

create_desktop_entry defold "Defold" "/opt/gamedev/engines/Defold"
'

# -----------------------------
# ADDITIONAL GAME ENGINES
# -----------------------------

run_step "Gideros" "is_installed giderosstudio" '
mkdir -p "$TMP_DIR"

GIDEROS_ARCHIVE="$TMP_DIR/gideros.tar.xz"

safe_wget \
    "https://github.com/gideros/gideros/releases/latest/download/Gideros.tar.xz" \
    "$GIDEROS_ARCHIVE" || {
    echo "⚠️ Gideros download failed"
    return 0
}

rm -rf "$TMP_DIR/gideros"
mkdir -p "$TMP_DIR/gideros"

tar -xvJf "$GIDEROS_ARCHIVE" -C "$TMP_DIR/gideros" || {
    echo "⚠️ Gideros extraction failed"
    return 0
}

GIDEROS_DIR=$(find "$TMP_DIR/gideros" -maxdepth 1 -type d -name "Gideros Studio" | head -n 1)

if [ -z "$GIDEROS_DIR" ]; then
    echo "⚠️ Gideros Studio directory not found"
    return 0
fi

rm -rf /opt/gamedev/engines/Gideros
mkdir -p /opt/gamedev/engines

sudo mv "$GIDEROS_DIR" /opt/gamedev/engines/Gideros

sudo chmod +x /opt/gamedev/engines/Gideros/GiderosStudio
sudo chmod +x /opt/gamedev/engines/Gideros/GiderosPlayer
sudo chmod +x /opt/gamedev/engines/Gideros/GiderosFontCreator
sudo chmod +x /opt/gamedev/engines/Gideros/GiderosTexturePacker

sudo tee /usr/local/bin/giderosstudio > /dev/null << "EOF"
#!/bin/bash
cd /opt/gamedev/engines/Gideros && LD_LIBRARY_PATH=/opt/gamedev/engines/Gideros ./GiderosStudio "$@"
EOF

sudo tee /usr/local/bin/giderosplayer > /dev/null << "EOF"
#!/bin/bash
cd /opt/gamedev/engines/Gideros && LD_LIBRARY_PATH=/opt/gamedev/engines/Gideros ./GiderosPlayer "$@"
EOF

sudo tee /usr/local/bin/giderosfontcreator > /dev/null << "EOF"
#!/bin/bash
cd /opt/gamedev/engines/Gideros && LD_LIBRARY_PATH=/opt/gamedev/engines/Gideros ./GiderosFontCreator "$@"
EOF

sudo tee /usr/local/bin/giderostexturepacker > /dev/null << "EOF"
#!/bin/bash
cd /opt/gamedev/engines/Gideros && LD_LIBRARY_PATH=/opt/gamedev/engines/Gideros ./GiderosTexturePacker "$@"
EOF

sudo chmod +x /usr/local/bin/giderosstudio
sudo chmod +x /usr/local/bin/giderosplayer
sudo chmod +x /usr/local/bin/giderosfontcreator
sudo chmod +x /usr/local/bin/giderostexturepacker

create_desktop_entry giderosstudio "Gideros Studio" "/opt/gamedev/engines/Gideros"
create_desktop_entry giderosplayer "Gideros Player" "/opt/gamedev/engines/Gideros"
create_desktop_entry giderosfontcreator "Gideros Font Creator" "/opt/gamedev/engines/Gideros"
create_desktop_entry giderostexturepacker "Gideros Texture Packer" "/opt/gamedev/engines/Gideros"
'

run_step "Solarus" "is_installed solarus-editor" '
SOLARUS_VERSION="2.0.4"

EDITOR_URL="https://gitlab.com/api/v4/projects/solarus-games%2Fsolarus/packages/generic/solarus/${SOLARUS_VERSION}/solarus-v2.0.4-linux-x64.tar.gz"
LAUNCHER_URL="https://gitlab.com/api/v4/projects/solarus-games%2Fsolarus/packages/generic/solarus/${SOLARUS_VERSION}/solarus-launcher-v2.0.4-linux-x64.tar.gz"

EDITOR_TAR="$TMP_DIR/solarus-editor.tar.gz"
LAUNCHER_TAR="$TMP_DIR/solarus-launcher.tar.gz"

APP_DIR="/opt/gamedev/tools/solarus"

safe_wget "$EDITOR_URL" "$EDITOR_TAR" || {
  echo "⚠️ Solarus Editor download failed"
  return 0
}

safe_wget "$LAUNCHER_URL" "$LAUNCHER_TAR" || {
  echo "⚠️ Solarus Launcher download failed"
  return 0
}

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/editor" "$APP_DIR/launcher"

tar -xzf "$EDITOR_TAR" -C "$APP_DIR/editor" || {
  echo "⚠️ Solarus Editor extraction failed"
  return 0
}

tar -xzf "$LAUNCHER_TAR" -C "$APP_DIR/launcher" || {
  echo "⚠️ Solarus Launcher extraction failed"
  return 0
}

EDITOR_BIN=$(find "$APP_DIR/editor" -type f -name "*.AppImage" | head -n1)
LAUNCHER_BIN=$(find "$APP_DIR/launcher" -type f -name "*.AppImage" | head -n1)

if [ -z "$EDITOR_BIN" ]; then
  echo "⚠️ Could not locate Solarus Editor AppImage"
  find "$APP_DIR/editor" -type f | head -50
  return 0
fi

if [ -z "$LAUNCHER_BIN" ]; then
  echo "⚠️ Could not locate Solarus Launcher AppImage"
  find "$APP_DIR/launcher" -type f | head -50
  return 0
fi

chmod +x "$EDITOR_BIN" "$LAUNCHER_BIN"

extract_appimage_icon "$EDITOR_BIN"
register_bin solarus-editor "$EDITOR_BIN" "Solarus Editor"

extract_appimage_icon "$LAUNCHER_BIN"
register_bin solarus-launcher "$LAUNCHER_BIN" "Solarus Launcher"
'

run_step "Eldiron" "is_installed eldiron-creator" '
API="https://api.github.com/repos/markusmoenig/Eldiron/releases"

echo "🌐 Fetching latest available Eldiron release..."

RELEASES=$(curl -s "$API")

DEB_URL=$(echo "$RELEASES" | jq -r "
  .[]
  | select(.assets? != null)
  | .assets[]
  | select(.name? != null)
  | select(.name | endswith(\".deb\"))
  | .browser_download_url
" | head -n 1)

if [ -z "$DEB_URL" ]; then
    echo "⚠️ No Eldiron .deb found in releases"
    return 0
fi

echo "⬇️ Downloading: $DEB_URL"

safe_wget "$DEB_URL" "$TMP_DIR/eldiron.deb" || {
    echo "⚠️ Download failed"
    return 0
}

echo "📦 Installing Eldiron..."

sudo dpkg -i "$TMP_DIR/eldiron.deb" || {
    echo "⚠️ dpkg failed, fixing dependencies..."
    sudo apt-get install -f -y || {
        echo "⚠️ dependency fix failed"
        return 0
    }

    sudo dpkg -i "$TMP_DIR/eldiron.deb" || {
        echo "⚠️ installation failed"
        return 0
    }
}
'

run_step "GB Studio" "is_installed gb-studio" '
API="https://api.github.com/repos/chrismaltby/gb-studio/releases/latest"

echo "🌐 Fetching GB Studio latest release..."

DEB_URL=$(curl -s "$API" | jq -r "
  .assets[]
  | select(.name != null)
  | select(.name | endswith(\".deb\"))
  | select(.name | contains(\"arm64\") | not)
  | .browser_download_url
" | head -n1)

if [ -z "$DEB_URL" ]; then
    echo "⚠️ GB Studio Linux DEB not found"
    curl -s "$API" | jq -r ".assets[].name"
    return 0
fi

echo "⬇️ Downloading: $DEB_URL"

safe_wget "$DEB_URL" "$TMP_DIR/gbstudio.deb" || {
    echo "⚠️ Download failed"
    return 0
}

echo "📦 Installing GB Studio..."

sudo dpkg -i "$TMP_DIR/gbstudio.deb" || {
    echo "⚠️ dpkg failed, fixing dependencies..."
    sudo apt-get install -f -y || {
        echo "⚠️ dependency fix failed"
        return 0
    }

    sudo dpkg -i "$TMP_DIR/gbstudio.deb" || {
        echo "⚠️ installation failed"
        return 0
    }
}
'
# -----------------------------
# Python Libraries TOOLS
# -----------------------------

run_step "Python Game Dev Env" "test -d /opt/gamedev/python-env" '
python3 -m venv /opt/gamedev/python-env
'
run_step "Python Game Dev Packages" "test -f /opt/gamedev/python-env/bin/python" '
/opt/gamedev/python-env/bin/python -m pip install -U \
  pygame pyglet kivy arcade moderngl pymunk pillow numpy noise pyinstaller
'

# -----------------------------
# CREATIVE TOOLS
# -----------------------------

run_step "Blender" "is_installed blender" '
sudo apt install -y blender
'

run_step "GIMP" "is_installed gimp" '
sudo apt install -y gimp
'

run_step "Krita" "is_installed krita" '
sudo apt install -y krita
'

run_step "Inkscape" "is_installed inkscape" '
sudo apt install -y inkscape
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

run_step "VLC" "is_installed vlc" '
sudo apt install -y vlc || echo "⚠️ VLC install failed"
'

run_step "Kdenlive" "is_installed kdenlive" '
sudo apt install -y kdenlive || echo "⚠️ Kdenlive install failed"
'

run_step "OBS Studio" "is_installed obs" '
sudo apt install -y obs-studio || echo "⚠️ OBS Studio install failed"
'

run_step "LMMS" "is_installed lmms" '
sudo apt install -y lmms || echo "⚠️ LMMS install failed"
'

run_step "Audacity" "is_installed audacity" '
sudo apt install -y audacity || echo "⚠️ Audacity install failed"
'

run_step "Ardour" "is_installed ardour" '
sudo apt install -y ardour || echo "⚠️ Ardour install failed"
'

run_step "Hydrogen Drum Machine" "is_installed hydrogen" '
sudo apt install -y hydrogen hydrogen-drumkits || echo "⚠️ Hydrogen install failed"
'

run_step "Geonkick" "is_installed geonkick" '
sudo apt install -y geonkick || echo "⚠️ Geonkick install failed"
'

# -----------------------------
# LEVEL EDITORS
# -----------------------------

run_step "Tiled Map Editor" "is_installed tiled" '
echo "📦 Installing Tiled Map Editor..."

sudo apt install -y tiled || {
    echo "⚠️ Failed to install Tiled via apt"
    return 0
}

echo "🧭 Verifying installation..."
if command -v tiled >/dev/null 2>&1; then
    echo "✅ Tiled installed successfully"
else
    echo "⚠️ Tiled installed but binary not found"
fi
'

run_step "LDtk" "is_installed ldtk" '
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

extract_appimage_icon "$LDTK_BIN" 
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

mkdir -p /opt/gamedev/tools/obsidian

safe_wget "$OBSIDIAN_URL" /opt/gamedev/tools/obsidian/obsidian.AppImage || {
  echo "⚠️ Obsidian download failed"
  return 0
}

register_bin obsidian /opt/gamedev/tools/obsidian/obsidian.AppImage "Obsidian"
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
# OWNERSHIP
# -----------------------------

# Take ownership of the whole gamedev tree
sudo chown -R "$USER:$USER" "$BASE"

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
