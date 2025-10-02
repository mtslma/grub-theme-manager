#!/usr/bin/env bash
# Uninstallation script for the GRUB Theme Manager

# Colors defined here as the source file will be deleted.
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_ORANGE='\033[38;5;208m'
C_YELLOW='\033[1;33m'
C_LIGHT_GRAY='\033[0;37m'

if [ "$(id -u)" -ne 0 ]; then
  echo -e "${C_RED}This script must be run with root privileges. Use: sudo ./uninstall.sh${C_RESET}"
  exit 1
fi

echo -e "${C_ORANGE}Uninstalling GRUB Theme Manager...${C_RESET}"

# Remove the sudoers rule
echo -e "${C_LIGHT_GRAY}=> Removing passwordless access rule...${C_RESET}"
rm -f "/etc/sudoers.d/grub-theme-manager"

# Remove the universal command
echo -e "${C_LIGHT_GRAY}=> Removing universal command 'grub-theme-manager'...${C_RESET}"
rm -f "/usr/local/bin/grub-theme-manager"

# Remove the desktop shortcut
echo -e "${C_LIGHT_GRAY}=> Removing application menu shortcut...${C_RESET}"
rm -f "/usr/share/applications/grub-theme-manager.desktop"

# Remove the application directory from /opt
echo -e "${C_LIGHT_GRAY}=> Removing application files from /opt/grub-theme-manager...${C_RESET}"
rm -rf "/opt/grub-theme-manager"

echo -e "${C_LIGHT_GRAY}=> Updating application database...${C_RESET}"
update-desktop-database &>/dev/null || true

echo ""
echo -e "${C_YELLOW}----------------------------------------${C_RESET}"
echo -e "${C_YELLOW}Uninstallation complete.${C_RESET}"
echo -e "${C_YELLOW}----------------------------------------${C_RESET}"
echo ""

exit 0