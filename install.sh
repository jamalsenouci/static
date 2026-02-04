#!/bin/bash

# PM OS Installer
# Downloads and installs the PM OS desktop app
#
# Usage:
#   curl -fsSL <script-url> | bash -s -- <base-url> [options]
#
# Arguments:
#   BASE_URL          URL where DMG files are hosted (required)
#
# Options:
#   --workspace-ssh   Git SSH URL for workspace repo
#   --workspace-https Git HTTPS URL for workspace repo (fallback)
#   --gh-host         GitHub Enterprise host for gh CLI
#   --gh-repo         Repo path for gh CLI (e.g., user/repo)
#
# Install command:
#   curl -fsSL https://raw.githubusercontent.com/jamalsenouci/static/refs/heads/main/install.sh | bash -s -- \
#     "https://snow.spotify.net/s/pm-os" \
#     --workspace-ssh "git@ghe.spotify.net:jamals/workspace.git" \
#     --workspace-https "https://ghe.spotify.net/jamals/workspace.git" \
#     --gh-host "ghe.spotify.net" \
#     --gh-repo "jamals/workspace"

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="PM OS"
INSTALL_DIR="/Applications"

# Parse arguments
BASE_URL=""
WORKSPACE_REPO_SSH=""
WORKSPACE_REPO_HTTPS=""
GH_HOST=""
GH_REPO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace-ssh)
            WORKSPACE_REPO_SSH="$2"
            shift 2
            ;;
        --workspace-https)
            WORKSPACE_REPO_HTTPS="$2"
            shift 2
            ;;
        --gh-host)
            GH_HOST="$2"
            shift 2
            ;;
        --gh-repo)
            GH_REPO="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}✗${NC} Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$BASE_URL" ]; then
                BASE_URL="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$BASE_URL" ]; then
    echo -e "${RED}✗${NC} Missing required argument: BASE_URL"
    echo ""
    echo "Usage:"
    echo "  curl -fsSL <script-url> | bash -s -- <base-url> [options]"
    echo ""
    echo "Options:"
    echo "  --workspace-ssh    Git SSH URL for workspace repo"
    echo "  --workspace-https  Git HTTPS URL for workspace repo"
    echo "  --gh-host          GitHub Enterprise host for gh CLI"
    echo "  --gh-repo          Repo path for gh CLI (user/repo)"
    echo ""
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                      PM OS Installer                        ${NC}"
echo -e "${BLUE}        Product management, reimagined for AI.               ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    DMG_NAME="PM.OS-arm64.dmg"
    ARCH_DISPLAY="Apple Silicon"
elif [ "$ARCH" = "x86_64" ]; then
    DMG_NAME="PM.OS-x64.dmg"
    ARCH_DISPLAY="Intel"
else
    echo -e "${RED}✗${NC} Unsupported architecture: $ARCH"
    echo "  PM OS requires a Mac with Apple Silicon or Intel processor."
    exit 1
fi

DOWNLOAD_URL="${BASE_URL}/${DMG_NAME// /%20}"
echo -e "  ${BLUE}Detected:${NC} macOS ($ARCH_DISPLAY)"
echo ""

# Check prerequisites (Node.js and Git required for PM OS)
echo -e "${YELLOW}[1/5]${NC} Checking prerequisites..."

# Install Homebrew if needed (used for node/git installation)
ensure_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo -e "  ${BLUE}→${NC} Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add homebrew to path for Apple Silicon
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
}

check_git() {
    if command -v git &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Git found"
        return 0
    fi
    return 1
}

install_git() {
    echo -e "  ${YELLOW}!${NC} Git not found. Installing via Homebrew..."
    ensure_homebrew
    brew install git
    if check_git; then
        return 0
    else
        echo -e "  ${RED}✗${NC} Failed to install Git"
        return 1
    fi
}

check_node() {
    # Check nvm first
    if [ -d "$HOME/.nvm/versions/node" ]; then
        NODE_VERSIONS=$(ls "$HOME/.nvm/versions/node" 2>/dev/null | wc -l)
        if [ "$NODE_VERSIONS" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} Node.js found (via nvm)"
            return 0
        fi
    fi

    # Check homebrew node
    if [ -x "/opt/homebrew/bin/node" ] || [ -x "/usr/local/bin/node" ]; then
        echo -e "  ${GREEN}✓${NC} Node.js found (via Homebrew)"
        return 0
    fi

    # Check system node
    if command -v node &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Node.js found"
        return 0
    fi

    return 1
}

install_node() {
    echo -e "  ${YELLOW}!${NC} Node.js not found. Installing via Homebrew..."
    ensure_homebrew
    echo -e "  ${BLUE}→${NC} Installing Node.js..."
    brew install node

    if check_node; then
        echo -e "  ${GREEN}✓${NC} Node.js installed successfully"
        return 0
    else
        echo -e "  ${RED}✗${NC} Failed to install Node.js"
        return 1
    fi
}

# Optional dependencies for full functionality
check_python() {
    if command -v python3 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Python 3 found"
        return 0
    fi
    return 1
}

install_python() {
    echo -e "  ${YELLOW}!${NC} Python 3 not found. Installing via Homebrew..."
    ensure_homebrew
    brew install python3
    if check_python; then
        return 0
    fi
    return 1
}

check_gcloud() {
    if command -v gcloud &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Google Cloud CLI found"
        return 0
    fi
    return 1
}

install_gcloud() {
    echo -e "  ${YELLOW}!${NC} Google Cloud CLI not found. Installing via Homebrew..."
    ensure_homebrew
    brew install --cask google-cloud-sdk
    if check_gcloud; then
        return 0
    fi
    return 1
}

check_gh() {
    if command -v gh &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} GitHub CLI found"
        return 0
    fi
    return 1
}

# Check and install Git
if ! check_git; then
    if [ -t 0 ]; then
        echo ""
        read -p "  Git is required. Install it now? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_git || exit 1
        else
            echo -e "  ${RED}✗${NC} PM OS requires Git."
            exit 1
        fi
    else
        install_git || exit 1
    fi
fi

# Check and install Node.js
if ! check_node; then
    if [ -t 0 ]; then
        echo ""
        read -p "  Node.js is required. Install it now? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_node || exit 1
        else
            echo -e "  ${RED}✗${NC} PM OS requires Node.js to run."
            echo "  Install Node.js manually: https://nodejs.org/"
            exit 1
        fi
    else
        install_node || exit 1
    fi
fi

# Check optional dependencies (not required, but recommended for full functionality)
echo ""
echo -e "  ${BLUE}Optional dependencies:${NC}"

# Python 3 (for metrics and BigQuery)
if ! check_python; then
    echo -e "  ${YELLOW}○${NC} Python 3 not found (needed for metrics/BigQuery)"
fi

# Google Cloud CLI (for GCP integrations)
if ! check_gcloud; then
    echo -e "  ${YELLOW}○${NC} Google Cloud CLI not found (needed for GCP features)"
fi

# GitHub CLI (for easier repo cloning)
if ! check_gh; then
    echo -e "  ${YELLOW}○${NC} GitHub CLI not found (optional, for repo cloning)"
fi

echo ""

# Offer to install missing optional dependencies
MISSING_OPTIONAL=""
command -v python3 &> /dev/null || MISSING_OPTIONAL="$MISSING_OPTIONAL python3"
command -v gcloud &> /dev/null || MISSING_OPTIONAL="$MISSING_OPTIONAL gcloud"

if [ -n "$MISSING_OPTIONAL" ] && [ -t 0 ]; then
    read -p "  Install missing optional dependencies? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        command -v python3 &> /dev/null || install_python
        command -v gcloud &> /dev/null || install_gcloud
    fi
fi
echo ""

# Check if already installed
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo -e "${YELLOW}PM OS is already installed.${NC}"
    if [ -t 0 ]; then
        # Interactive mode - ask user
        echo ""
        read -p "Do you want to reinstall? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo -e "Opening existing installation..."
            open "$INSTALL_DIR/$APP_NAME.app"
            exit 0
        fi
    else
        # Non-interactive (curl | bash) - reinstall by default
        echo -e "  ${BLUE}→${NC} Reinstalling (non-interactive mode)..."
    fi
    echo -e "${BLUE}→${NC} Removing old version..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Step 2: Download
echo -e "${YELLOW}[2/5]${NC} Downloading PM OS..."
TEMP_DIR=$(mktemp -d)
DMG_PATH="$TEMP_DIR/$DMG_NAME"

# Try direct download first (works if user has browser session cookies)
DOWNLOAD_SUCCESS=false

# Check if running with piped input (curl | bash) - can't do interactive auth
if [ -t 0 ]; then
    # Interactive mode - try download, fall back to browser
    if curl -fsSL --connect-timeout 10 "$DOWNLOAD_URL" -o "$DMG_PATH" 2>/dev/null; then
        # Check if we got HTML (auth page) instead of DMG
        if file "$DMG_PATH" | grep -q "HTML"; then
            rm -f "$DMG_PATH"
        else
            DOWNLOAD_SUCCESS=true
        fi
    fi
fi

# If direct download failed, use browser-based flow
if [ "$DOWNLOAD_SUCCESS" = false ]; then
    echo ""
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BLUE}  Authentication required                              ${NC}"
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  A browser window will open. Please:"
    echo ""
    echo -e "    ${YELLOW}1.${NC} Sign in with your ${GREEN}Google account${NC}"
    echo -e "    ${YELLOW}2.${NC} Click the download button for ${GREEN}$ARCH_DISPLAY${NC}"
    echo -e "    ${YELLOW}3.${NC} Wait for download to complete"
    echo -e "    ${YELLOW}4.${NC} ${GREEN}Come back here${NC} — the installer will continue automatically"
    echo ""
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    # Only wait for keypress if running interactively
    if [ -t 0 ]; then
        read -p "  Press Enter to open the browser..."
    else
        echo -e "  Opening browser in 2 seconds..."
        sleep 2
    fi

    # Open the dedicated download page
    open "$BASE_URL/download.html"

    echo ""
    echo -e "  ${YELLOW}⏳ Waiting for download...${NC}"
    echo -e "  Looking for: ${BLUE}$DMG_NAME${NC} in ~/Downloads"
    echo ""
    echo -e "  ${GREEN}Don't close this window!${NC}"
    echo ""

    DOWNLOADS_DIR="$HOME/Downloads"
    MAX_WAIT=300  # 5 minutes
    WAITED=0

    while [ $WAITED -lt $MAX_WAIT ]; do
        # Check for the DMG in Downloads
        if [ -f "$DOWNLOADS_DIR/$DMG_NAME" ]; then
            # Wait a bit for download to complete
            sleep 2
            # Check if file is still being written
            SIZE1=$(stat -f%z "$DOWNLOADS_DIR/$DMG_NAME" 2>/dev/null || echo "0")
            sleep 2
            SIZE2=$(stat -f%z "$DOWNLOADS_DIR/$DMG_NAME" 2>/dev/null || echo "0")

            if [ "$SIZE1" = "$SIZE2" ] && [ "$SIZE1" != "0" ]; then
                cp "$DOWNLOADS_DIR/$DMG_NAME" "$DMG_PATH"
                DOWNLOAD_SUCCESS=true
                echo -e "  ${GREEN}✓${NC} Found downloaded file"
                break
            fi
        fi

        sleep 2
        WAITED=$((WAITED + 2))

        # Show progress every 10 seconds
        if [ $((WAITED % 10)) -eq 0 ]; then
            echo -e "  ... still waiting (${WAITED}s)"
        fi
    done

    if [ "$DOWNLOAD_SUCCESS" = false ]; then
        echo -e "${RED}✗${NC} Download not detected."
        echo ""
        echo "  If you downloaded the file, you can install manually:"
        echo "  1. Double-click the DMG in your Downloads folder"
        echo "  2. Drag PM OS to Applications"
        echo ""
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

echo -e "  ${GREEN}✓${NC} Downloaded"

# Step 3: Mount and install
echo ""
echo -e "${YELLOW}[3/5]${NC} Installing..."

# Mount the DMG
MOUNT_OUTPUT=$(hdiutil attach "$DMG_PATH" -nobrowse 2>&1)

# Parse mount point - it's the last field after /Volumes/
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep "/Volumes/" | sed 's/.*\(\/Volumes\/.*\)/\1/' | tail -1)

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
    # Try common mount point names
    for try_mount in "/Volumes/PM OS" "/Volumes/PM.OS"; do
        if [ -d "$try_mount" ]; then
            MOUNT_POINT="$try_mount"
            break
        fi
    done
fi

if [ ! -d "$MOUNT_POINT" ]; then
    echo -e "${RED}✗${NC} Failed to mount disk image"
    echo "  Mount output: $MOUNT_OUTPUT"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Copy app to Applications
if [ -d "$MOUNT_POINT/$APP_NAME.app" ]; then
    cp -R "$MOUNT_POINT/$APP_NAME.app" "$INSTALL_DIR/"
else
    # Try finding the .app file
    APP_FOUND=$(find "$MOUNT_POINT" -maxdepth 1 -name "*.app" -print -quit)
    if [ -n "$APP_FOUND" ]; then
        cp -R "$APP_FOUND" "$INSTALL_DIR/$APP_NAME.app"
    else
        echo -e "${RED}✗${NC} Could not find app in disk image"
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

echo -e "  ${GREEN}✓${NC} Installed to $INSTALL_DIR"

# Unmount
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

# Cleanup
rm -rf "$TEMP_DIR"

# Step 3: Fix signature and remove quarantine (so it opens without Gatekeeper warning)
echo ""
echo -e "${YELLOW}[3/5]${NC} Configuring app..."
# Remove all extended attributes (quarantine, provenance, etc.)
xattr -cr "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
# Ad-hoc sign the app to fix any signature issues
codesign --force --deep --sign - "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} App configured"

# Step 4: Clone workspace repository (if configured)
echo ""
echo -e "${YELLOW}[4/5]${NC} Setting up workspace..."

WORKSPACE_DIR="$HOME/workspace"

# Skip if no workspace repo configured
if [ -z "$WORKSPACE_REPO_SSH" ] && [ -z "$WORKSPACE_REPO_HTTPS" ]; then
    echo -e "  ${BLUE}→${NC} No workspace repository configured"
    mkdir -p "$WORKSPACE_DIR"
    echo -e "  ${GREEN}✓${NC} Created empty workspace at $WORKSPACE_DIR"
elif [ -d "$WORKSPACE_DIR" ]; then
    if [ -d "$WORKSPACE_DIR/.git" ]; then
        echo -e "  ${GREEN}✓${NC} Workspace already exists at $WORKSPACE_DIR"
        # Pull latest changes
        echo -e "  ${BLUE}→${NC} Pulling latest changes..."
        cd "$WORKSPACE_DIR" && git pull --quiet 2>/dev/null || true
        cd - > /dev/null
    else
        echo -e "  ${YELLOW}!${NC} Directory exists but is not a git repo: $WORKSPACE_DIR"
        echo -e "  ${BLUE}→${NC} Skipping workspace clone"
    fi
else
    echo -e "  ${BLUE}→${NC} Cloning workspace repository..."
    CLONE_SUCCESS=false

    # Try SSH first (if configured)
    if [ -n "$WORKSPACE_REPO_SSH" ]; then
        if git clone "$WORKSPACE_REPO_SSH" "$WORKSPACE_DIR" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Workspace cloned via SSH"
            CLONE_SUCCESS=true
        fi
    fi

    # Try GitHub CLI (if configured and SSH failed)
    if [ "$CLONE_SUCCESS" = false ] && [ -n "$GH_HOST" ] && [ -n "$GH_REPO" ]; then
        if command -v gh &> /dev/null; then
            echo -e "  ${BLUE}→${NC} SSH failed, trying GitHub CLI..."
            if GH_HOST="$GH_HOST" gh repo clone "$GH_REPO" "$WORKSPACE_DIR" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Workspace cloned via GitHub CLI"
                CLONE_SUCCESS=true
            fi
        fi
    fi

    # Fall back to HTTPS (if configured)
    if [ "$CLONE_SUCCESS" = false ] && [ -n "$WORKSPACE_REPO_HTTPS" ]; then
        echo -e "  ${BLUE}→${NC} Trying HTTPS (may prompt for credentials)..."
        if git clone "$WORKSPACE_REPO_HTTPS" "$WORKSPACE_DIR" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Workspace cloned via HTTPS"
            CLONE_SUCCESS=true
        fi
    fi

    if [ "$CLONE_SUCCESS" = false ]; then
        echo -e "  ${YELLOW}!${NC} Could not clone workspace"
        echo -e "  ${BLUE}→${NC} Creating empty workspace directory..."
        mkdir -p "$WORKSPACE_DIR"
        if [ -n "$WORKSPACE_REPO_SSH" ]; then
            echo ""
            echo -e "  ${YELLOW}To set up workspace manually:${NC}"
            echo -e "    git clone $WORKSPACE_REPO_SSH ~/workspace"
        fi
    fi
fi

# Step 5: Final setup
echo ""
echo -e "${YELLOW}[5/5]${NC} Finishing up..."
echo -e "  ${GREEN}✓${NC} Ready to launch"

# Done!
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}                  Installation complete!                     ${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BLUE}Installed at:${NC}  $INSTALL_DIR/$APP_NAME.app"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. PM OS will open automatically"
echo -e "  2. Connect your Jira and Calendar in Settings"
echo -e "  3. Open the Terminal tab to talk to AI"
echo ""

# Open the app
echo -e "${BLUE}→${NC} Launching PM OS..."
open "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo -e "  ${GREEN}Enjoy! 🚀${NC}"
echo ""
