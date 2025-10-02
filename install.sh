#!/usr/bin/env bash
# Installation script for the GRUB Theme Manager

# Find the absolute path of the repository to load colors and set paths
REPO_PATH=$(dirname "$(readlink -f "$0")")
source "$REPO_PATH/colors.sh"

# Define the permanent installation directory and GRUB config file
INSTALL_DIR="/opt/grub-theme-manager"
GRUB_CONFIG_FILE="/etc/default/grub"

# Function to automatically configure GRUB for a better experience
configure_grub() {
  echo -e "${C_LIGHT_GRAY}=> Backing up and configuring GRUB...${C_RESET}"
  # Create a backup of the original grub file, just in case
  cp "$GRUB_CONFIG_FILE" "$GRUB_CONFIG_FILE.bak.$(date +%Y%m%d%H%M%S)"

  # Ensure the menu is always visible with a 30 second timeout
  sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' "$GRUB_CONFIG_FILE"
  sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=30/' "$GRUB_CONFIG_FILE"
  
  # Set GRUB to remember the last selection. 'saved' is the correct value for this.
  sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' "$GRUB_CONFIG_FILE"
  # Add the SAVEDEFAULT line if it doesn't exist
  grep -qxF 'GRUB_SAVEDEFAULT=true' "$GRUB_CONFIG_FILE" || echo 'GRUB_SAVEDEFAULT=true' >> "$GRUB_CONFIG_FILE"

  # Set the best possible resolution automatically and keep it for the OS
  # Add the line if it doesn't exist, otherwise update it
  if grep -q "^GRUB_GFXMODE=" "$GRUB_CONFIG_FILE"; then
    sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=auto/' "$GRUB_CONFIG_FILE"
  else
    echo 'GRUB_GFXMODE=auto' >> "$GRUB_CONFIG_FILE"
  fi
  
  if grep -q "^GRUB_GFXPAYLOAD_LINUX=" "$GRUB_CONFIG_FILE"; then
    sed -i 's/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/' "$GRUB_CONFIG_FILE"
  else
    echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> "$GRUB_CONFIG_FILE"
  fi

  # Remove the splash screen that often hides the GRUB menu
  sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3"/' "$GRUB_CONFIG_FILE"
}

# 1. Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${C_RED}This script must be run with root privileges. Use: sudo ./install.sh${C_RESET}"
  exit 1
fi

echo -e "${C_YELLOW}Starting GRUB Theme Manager installation...${C_RESET}"

# 2. Copy application files to the permanent directory
echo -e "${C_LIGHT_GRAY}=> Copying application files to $INSTALL_DIR...${C_RESET}"
mkdir -p "$INSTALL_DIR"
cp -r "$REPO_PATH"/* "$INSTALL_DIR/"

# 3. Set correct permissions for the main script
MAIN_SCRIPT_PATH="$INSTALL_DIR/scripts/grub-theme-manager"
chmod +x "$MAIN_SCRIPT_PATH"

# 4. Create the universal command
echo -e "${C_LIGHT_GRAY}=> Creating universal command 'grub-theme-manager'...${C_RESET}"
ln -sf "$MAIN_SCRIPT_PATH" /usr/local/bin/grub-theme-manager

# 5. Configure passwordless access via sudoers
echo -e "${C_LIGHT_GRAY}=> Configuring passwordless access...${C_RESET}"
SUDOERS_FILE="/etc/sudoers.d/grub-theme-manager"
USER_WHO_SUDOED="${SUDO_USER:-$(whoami)}"
echo "$USER_WHO_SUDOED ALL=(ALL) NOPASSWD: /usr/local/bin/grub-theme-manager" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

# 6. Apply the automatic GRUB configurations
configure_grub

# 7. Create the application menu shortcut
echo -e "${C_LIGHT_GRAY}=> Creating application menu shortcut...${C_RESET}"
DESKTOP_FILE_PATH="/usr/share/applications/grub-theme-manager.desktop"

cat > "$DESKTOP_FILE_PATH" <<EOF
[Desktop Entry]
Version=1.0
Name=GRUB Theme Manager
Comment=A simple manager for GRUB bootloader themes
Exec=grub-theme-manager
Icon=$INSTALL_DIR/assets/icon.png
Terminal=true
Type=Application
Categories=System;Settings;
EOF

# 8. Finalize the installation
echo -e "${C_LIGHT_GRAY}=> Updating system configurations...${C_RESET}"
update-desktop-database &>/dev/null || true
update-grub # Apply all GRUB changes made by this script

echo ""
echo -e "${C_YELLOW}----------------------------------------${C_RESET}"
echo -e "${C_YELLOW}Installation complete!${C_RESET}"
echo -e "${C_YELLOW}----------------------------------------${C_RESET}"
echo ""
echo "The program is now installed and GRUB is configured."
echo "You can safely delete the cloned repository folder."
echo "Run by typing 'grub-theme-manager' or using the app menu."
echo ""

exit 0