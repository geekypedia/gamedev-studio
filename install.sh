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
        echo "⚠️ safe_wget: empty URL"
        return 1
    fi

    echo "⬇️ Downloading: $url"

    # Create isolated temp directory per run
    local TMP_DIR="/tmp/5ddd20fa-76f4-40a2-8fc1-9599cac0924e"
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
            safe_wget "$url" "/tmp/$name.zip" || return 0
            unzip -o "/tmp/$name.zip" -d "$dest" || return 0
        ;;

        tar.gz)
            safe_wget "$url" "/tmp/$name.tar.gz" || return 0
            tar -xzf "/tmp/$name.tar.gz" -C "$dest" || return 0
        ;;

        tar.bz2)
            safe_wget "$url" "/tmp/$name.tar.bz2" || return 0
            tar -xjf "/tmp/$name.tar.bz2" -C "$dest" || return 0
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
mkdir -p "$BASE"/{engines,tools,art,web,audio,dev,pipelines}

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

run_step "Google Chrome" "is_ok google-chrome google-chrome-stable chromium" '
safe_wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb /tmp/chrome.deb || {
  echo "⚠️ Download failed"
  return 0
}

sudo dpkg -i /tmp/chrome.deb || {
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
API="https://api.github.com/repos/godotengine/godot/releases/latest"

TEMPLATE_URL=$(curl -s "$API" | jq -r "
  .assets[]
  | select(.name != null)
  | select(.name | index(\"export_templates\"))
  | .browser_download_url
" | head -n 1)

if [ -z "$TEMPLATE_URL" ]; then
  echo "⚠️ Could not find export templates URL"
  curl -s "$API" | jq -r ".assets[].name"
  return 0
fi

echo "Downloading: $TEMPLATE_URL"

safe_wget "$TEMPLATE_URL" /tmp/godot_templates.tpz || {
  echo "⚠️ Download failed, skipping templates"
  return 0
}

VERSION=$(curl -s "$API" | jq -r ".tag_name")

mkdir -p "$HOME/.local/share/godot/export_templates/$VERSION" || {
  echo "⚠️ Failed to create directory"
  return 0
}

unzip -o /tmp/godot_templates.tpz -d "$HOME/.local/share/godot/export_templates/$VERSION" || {
  echo "⚠️ Unzip failed"
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

chmod +x /opt/gamedev/engines/gdevelop.AppImage
sudo ln -sf /opt/gamedev/engines/gdevelop.AppImage /usr/local/bin/gdevelop
'

run_step "ct.js" "is_installed ctjs" '
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

mkdir -p /opt/gamedev/engines/ctjs

safe_wget "$CT_URL" /tmp/ctjs.zip || {
  echo "⚠️ ct.js download failed"
  return 0
}

unzip -o /tmp/ctjs.zip -d /opt/gamedev/engines/ctjs || {
  echo "⚠️ Failed to extract ct.js"
  return 0
}

chmod +x /opt/gamedev/engines/ctjs/linux64/ctjs 2>/dev/null || true

if [ -f /opt/gamedev/engines/ctjs/linux64/ctjs ]; then
  sudo ln -sf /opt/gamedev/engines/ctjs/linux64/ctjs /usr/local/bin/ctjs
else
  echo "⚠️ ct.js executable not found"
fi
'

run_step "RenPy" "is_installed renpy" '
API="https://api.github.com/repos/renpy/renpy/releases/latest"

DATA=$(curl -s "$API")

# Prefer SDK tar.bz2
RENPY_URL=$(echo "$DATA" | jq -r '
  .assets[]
  | select(.name | endswith("sdk.tar.bz2"))
  | .browser_download_url
' | head -n1)

EXT="tar.bz2"

# Fallback to zip if tar.bz2 not found
if [ -z "$RENPY_URL" ]; then
    RENPY_URL=$(echo "$DATA" | jq -r '
      .assets[]
      | select(.name | endswith("sdk.zip"))
      | .browser_download_url
    ' | head -n1)

    EXT="zip"
fi

if [ -z "$RENPY_URL" ]; then
    echo "⚠️ Could not find RenPy SDK (tar.bz2 or zip)"
    return 0
fi

echo "⬇️ RenPy URL: $RENPY_URL"

OUT="/tmp/renpy.$EXT"

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
FILE_ID="1EFo7Ye_rl7bGNr4iehXIgFg4gn2IcWDX"

mkdir -p /opt/gamedev/art/piskel

gdrive_download "$FILE_ID" /tmp/piskel.zip || {
    echo "⚠️ Piskel download failed"
    return 0
}

unzip -o /tmp/piskel.zip -d /opt/gamedev/art/piskel || {
    echo "⚠️ Failed to extract Piskel"
    return 0
}

BIN=$(find /opt/gamedev/art/piskel -type f -executable | head -n1)

if [ -z "$BIN" ]; then
    echo "⚠️ No executable found for Piskel"
    return 0
fi

chmod +x "$BIN"
register_bin piskel "$BIN"
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

safe_wget "$PIXEL_URL" /tmp/pixelorama.tar.gz || {
    echo "⚠️ Pixelorama download failed"
    return 0
}

rm -rf /opt/gamedev/art/pixelorama
mkdir -p /opt/gamedev/art/pixelorama

tar -xzf /tmp/pixelorama.tar.gz -C /opt/gamedev/art/pixelorama || {
    echo "⚠️ Extraction failed"
    return 0
}

PIXEL_BIN=$(find /opt/gamedev/art/pixelorama -type f -name "Pixelorama*" -executable | head -n1)

if [ -z "$PIXEL_BIN" ]; then
    echo "⚠️ Pixelorama binary not found"
    return 0
fi

chmod +x "$PIXEL_BIN"
sudo ln -sf "$PIXEL_BIN" /usr/local/bin/pixelorama
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

safe_wget "$ZIP_URL" /tmp/libresprite.zip || {
    echo "⚠️ LibreSprite download failed"
    return 0
}

rm -rf /opt/gamedev/art/libresprite
mkdir -p /opt/gamedev/art/libresprite

unzip -o /tmp/libresprite.zip -d /opt/gamedev/art/libresprite || {
    echo "⚠️ Extraction failed"
    return 0
}

# Find actual AppImage inside extracted folder
LS_BIN=$(find /opt/gamedev/art/libresprite -type f -name "*.AppImage" | head -n 1)

if [ -z "$LS_BIN" ]; then
    echo "⚠️ LibreSprite AppImage not found after extraction"
    return 0
fi

chmod +x "$LS_BIN"
sudo ln -sf "$LS_BIN" /usr/local/bin/libresprite
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
LDTK_URL=$(
  curl -s https://api.github.com/repos/deepnight/ldtk/releases/latest |
  jq -r "
    .assets[]
    | select(.name==\"ubuntu-distribution.zip\")
    | .browser_download_url
  " | head -n1
)

if [ -z "$LDTK_URL" ]; then
  echo "⚠️ Could not find LDtk Linux build"
  return 0
fi

safe_wget "$LDTK_URL" /tmp/ldtk.zip || {
  echo "⚠️ LDtk download failed"
  return 0
}

mkdir -p /opt/gamedev/tools/ldtk
unzip -o /tmp/ldtk.zip -d /opt/gamedev/tools/ldtk || return 0

LDTK_BIN=$(safe_find_exec /opt/gamedev/tools/ldtk)

if [ -n "$LDTK_BIN" ]; then
  chmod +x "$LDTK_BIN"
  sudo ln -sf "$LDTK_BIN" /usr/local/bin/ldtk
else
  echo "⚠️ Could not locate LDtk executable"
fi
'

run_step "LDtk Sync Pipeline" "is_installed ldtk-sync" '
sudo tee /usr/local/bin/ldtk-sync >/dev/null <<'EOF'
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

chmod +x /opt/gamedev/tools/obsidian.AppImage
sudo ln -sf /opt/gamedev/tools/obsidian.AppImage /usr/local/bin/obsidian
'

# -----------------------------
# DEPLOYMENT
# -----------------------------

run_step "itch.io Butler" "is_installed butler" '
safe_wget https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default /tmp/butler.zip || {
    echo "⚠️ Failed to download Butler"
    return 0
}

rm -rf /tmp/butler_unpack
mkdir -p /tmp/butler_unpack

unzip -o /tmp/butler.zip -d /tmp/butler_unpack || {
    echo "⚠️ Failed to extract Butler"
    return 0
}

BUTLER_BIN=$(find /tmp/butler_unpack -type f -name butler | head -n1)

if [ -n "$BUTLER_BIN" ]; then
    register_bin butler "$BUTLER_BIN"
else
    echo "⚠️ Could not locate Butler executable"
fi
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
