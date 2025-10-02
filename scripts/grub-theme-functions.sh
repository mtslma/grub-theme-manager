# Core functions for the GRUB Theme Manager

# Helpers
require_root() {
  # If the script is not run as root, it re-executes itself with sudo.
  # The sudoers rule created by install.sh prevents a password prompt.
  if [ "$(id -u)" -ne 0 ]; then
    echo -e "${C_ORANGE}Root privileges required. Re-launching with sudo...${C_RESET}"
    # Use exec to replace the current script process with the new sudo process
    exec sudo /usr/local/bin/grub-theme-manager "$@"
  fi
}

ensure_deps() {
  local missing=()
  for cmd in "${DEPENDENCIES[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${C_ORANGE}Missing dependencies: ${missing[*]}${C_RESET}"
    read -r -p "Install now? (Y/n) " confirm
    if [[ "$confirm" =~ ^[yY]$ ]] || [ -z "$confirm" ]; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y >/dev/null 2>&1 || true
      apt-get install -y "${missing[@]}" || {
        echo -e "${C_RED}Failed to install dependencies.${C_RESET}"
        exit 1
      }
      echo -e "${C_YELLOW}Dependencies installed successfully.${C_RESET}"
    else
      echo -e "${C_RED}Dependencies are required. Aborting.${C_RESET}"
      exit 1
    fi
  fi
}

backup_grub_file() {
  cp -a "$GRUB_DEFAULT_FILE" "$GRUB_DEFAULT_FILE.bak.$(date +%Y%m%d%H%M%S)"
}

get_current_theme_name() {
  if [ -f "$GRUB_DEFAULT_FILE" ]; then
    local theme_path
    theme_path=$(grep -E '^\s*GRUB_THEME=' "$GRUB_DEFAULT_FILE" 2>/dev/null | sed -E 's/^[^=]*=(.*)/\1/' | tr -d '"') || true
    if [ -n "$theme_path" ]; then
      [[ "$(basename "$theme_path")" == "theme.txt" ]] && basename "$(dirname "$theme_path")" || basename "$theme_path"
      return
    fi
  fi
  echo "(none)"
}

list_local_repo_themes() {
  [ -d "$LOCAL_THEMES_DIR" ] && (cd "$LOCAL_THEMES_DIR" && ls -1 --hide="*.md" 2>/dev/null) || true
}

list_installed_themes() {
  [ -d "$INSTALL_DIR" ] && ls -1 "$INSTALL_DIR" 2>/dev/null || true
}

# Core Actions
install_selected_local_themes() {
  local local_themes installed missing selection

  local_themes=$(list_local_repo_themes)
  [ -z "$local_themes" ] && { echo -e "${C_LIGHT_GRAY}No local themes found in $LOCAL_THEMES_DIR${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  installed=$(list_installed_themes)
  missing=$(comm -23 <(echo "$local_themes") <(echo "$installed"))
  [ -z "$missing" ] && { echo -e "${C_LIGHT_GRAY}All available local themes are already installed.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  selection=$(echo "$missing" | fzf --multi --prompt="Themes to install> " --height=40% --header=$'Install Local Themes\n' --no-sort)
  [ -z "$selection" ] && { echo -e "${C_LIGHT_GRAY}No themes chosen.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  mkdir -p "$INSTALL_DIR"
  for t in $selection; do
    [ ! -d "$LOCAL_THEMES_DIR/$t" ] && { echo -e "${C_ORANGE}Theme directory for '$t' is missing, skipping.${C_RESET}"; continue; }
    cp -a "$LOCAL_THEMES_DIR/$t" "$INSTALL_DIR/" && chown -R root:root "$INSTALL_DIR/$t"
    echo -e "${C_YELLOW}Installed: $t${C_RESET}"
  done

  update-grub >/dev/null 2>&1 || echo -e "${C_ORANGE}Warning: update-grub command failed or is not available.${C_RESET}"
  read -r -p "Done. Press Enter to continue..."
}

# --- THIS FUNCTION HAS BEEN FIXED ---
download_missing_from_github() {
  echo -e "${C_LIGHT_GRAY}Checking remote repository for new themes...${C_RESET}"
  local remote local_list to_download chosen tmpdir

  remote=$(curl -sSf "$API_CONTENTS_URL" | jq -r '.[].name' 2>/dev/null) || remote=""
  [ -z "$remote" ] && { echo -e "${C_LIGHT_GRAY}No themes found or network error.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  local_list=$(list_local_repo_themes)
  to_download=$(comm -23 <(echo "$remote") <(echo "$local_list"))
  [ -z "$to_download" ] && { echo -e "${C_LIGHT_GRAY}Your local themes are up-to-date.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  chosen=$(echo "$to_download" | fzf --multi --prompt="Themes to download> " --height=40% --header=$'Download Remote Themes\n' --no-sort)
  [ -z "$chosen" ] && { echo -e "${C_LIGHT_GRAY}No selection made.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  mkdir -p "$LOCAL_THEMES_DIR"
  for t in $chosen; do
    echo -e "${C_ORANGE}Downloading: $t...${C_RESET}"
    tmpdir=$(mktemp -d)
    
    # Download all theme files into the temporary directory, preserving structure
    curl -sSf "$API_CONTENTS_URL/$t" | jq -r '.[].path' 2>/dev/null | while read -r path; do
      [ -z "$path" ] && continue
      mkdir -p "$tmpdir/$(dirname "$path")"
      wget -q -O "$tmpdir/$path" "$RAW_BASE_URL/$path" || echo -e "${C_RED}Warning: Failed to download sub-file: $path${C_RESET}"
    done

    # Define the source path of the theme inside the temp directory
    THEME_SOURCE_PATH="$tmpdir/themes/$t"

    # Check if the downloaded theme exists at the expected path
    if [ -d "$THEME_SOURCE_PATH" ]; then
        # Move the theme folder from the temp directory to the final destination
        mv "$THEME_SOURCE_PATH" "$LOCAL_THEMES_DIR/"
        echo -e "${C_YELLOW}Successfully downloaded: $t${C_RESET}"
    else
        echo -e "${C_RED}Failed to process download for '$t'. Structure was unexpected.${C_RESET}"
    fi

    rm -rf "$tmpdir"
  done

  echo -e "${C_YELLOW}Download process complete.${C_RESET}"
  read -r -p "Press Enter to continue..."
}

remove_themes() {
  local installed chosen confirm
  installed=$(list_installed_themes)
  [ -z "$installed" ] && { echo -e "${C_LIGHT_GRAY}No themes are currently installed.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  chosen=$(echo "$installed" | fzf --multi --prompt="Select themes to remove> " --height=40% --header=$'Remove Installed Themes\n' --no-sort)
  [ -z "$chosen" ] && { echo -e "${C_LIGHT_GRAY}No selection made.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  echo -e "${C_ORANGE}You are about to permanently remove:\n$chosen${C_RESET}"
  read -r -p "Are you sure? (y/N) " confirm
  [[ ! "$confirm" =~ ^[yY]$ ]] && { echo -e "${C_LIGHT_GRAY}Operation cancelled.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  for t in $chosen; do
    rm -rf "$INSTALL_DIR/$t" && echo -e "${C_YELLOW}Removed: $t${C_RESET}" || echo -e "${C_RED}Failed to remove: $t${C_RESET}"
  done
  update-grub >/dev/null 2>&1 || true
  read -r -p "Done. Press Enter to continue..."
}

activate_theme() {
  local installed choice path
  installed=$(list_installed_themes)
  [ -z "$installed" ] && { echo -e "${C_LIGHT_GRAY}No themes are installed to activate.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  choice=$(echo "$installed" | fzf --prompt="Choose theme to activate> " --height=40% --header=$'Activate a Theme\n' --no-sort)
  [ -z "$choice" ] && { echo -e "${C_LIGHT_GRAY}No selection made.${C_RESET}"; read -r -p "Press Enter to continue..."; return; }

  backup_grub_file
  path="$INSTALL_DIR/$choice"
  [[ -f "$path/theme.txt" ]] && path="$path/theme.txt"

  if grep -qE '^\s*GRUB_THEME=' "$GRUB_DEFAULT_FILE"; then
    sed -i -E "s|^\s*GRUB_THEME=.*|GRUB_THEME=\"$path\"|" "$GRUB_DEFAULT_FILE"
  else
    echo "GRUB_THEME=\"$path\"" >> "$GRUB_DEFAULT_FILE"
  fi

  update-grub >/dev/null 2>&1 || echo -e "${C_ORANGE}Warning: update-grub command failed or is not available.${C_RESET}"
  echo -e "${C_YELLOW}Activated theme: $choice${C_RESET}"
  read -r -p "Press Enter to continue..."
}

# Menu
main_menu() {
  local options="Activate a theme\nInstall local themes\nRemove installed themes\nDownload themes from GitHub\nExit"

  while true; do
    clear
    printf "${C_RED}========================================\n"
    printf "          GRUB Theme Manager\n"
    printf "========================================${C_RESET}\n\n"

    printf "Current active theme: ${C_YELLOW}%s${C_RESET}\n\n" "$(get_current_theme_name)"

    local choice
    choice=$(echo -e "$options" | fzf --height=10 --prompt="Select an option > " --header=$'Use ARROWS and ENTER\n' --no-sort)
    
    # If ESC is pressed, choice is empty and the loop continues.
    [ -z "$choice" ] && continue

    case "$choice" in
      "Activate a theme")           activate_theme ;;
      "Install local themes")      install_selected_local_themes ;;
      "Remove installed themes")   remove_themes ;;
      "Download themes from GitHub") download_missing_from_github ;;
      "Exit")                      echo -e "${C_ORANGE}Bye.${C_RESET}"; exit 0 ;;
    esac
  done
}