#!/bin/zsh
# ==============================================================================
# Title: install.sh
# Author: Daniel Vier
# Email: daniel.vier@gmail.com
# Description: Automates the setup and configuration of macOS, including
#              installation of essential applications and system preferences.
# Last Updated: March 1, 2024
# ==============================================================================

SCRIPT_DIR=${0:A:h}
SCRIPT_NAME=${0:t}
source "${SCRIPT_DIR}/config"

typeset -A SECTION_PARAMETERS=(
  authenticate-sudo RUN_AUTHENTICATE_SUDO
  update-macos RUN_UPDATE_MACOS
  install-rosetta RUN_INSTALL_ROSETTA
  install-homebrew RUN_INSTALL_HOMEBREW
  install-brew-packages RUN_INSTALL_BREW_PACKAGES
  install-app-store RUN_INSTALL_APP_STORE
  install-vscode-extensions RUN_INSTALL_VSCODE_EXTENSIONS
  install-node RUN_INSTALL_NODE
  install-npm-packages RUN_INSTALL_NPM_PACKAGES
  install-dotnet RUN_INSTALL_DOTNET
  install-firefox-developer RUN_INSTALL_FIREFOX_DEVELOPER
  install-databases RUN_INSTALL_DATABASES
  setup-mysql RUN_SETUP_MYSQL
  install-games RUN_INSTALL_GAMES
  install-unity-hub RUN_INSTALL_UNITY_HUB
  install-figma RUN_INSTALL_FIGMA
  cleanup-homebrew RUN_CLEANUP_HOMEBREW
  configure-settings RUN_CONFIGURE_SETTINGS
  configure-dock RUN_CONFIGURE_DOCK
  configure-git RUN_CONFIGURE_GIT
  install-oh-my-zsh RUN_INSTALL_OH_MY_ZSH
  reboot RUN_REBOOT
)
typeset -A CLI_SECTION_VALUES
VERBOSE=0

usage() {
  echo "Usage: ${SCRIPT_NAME} [--verbose] [--all yes|no] [--section yes|no]"
  echo
  echo "  --verbose                   Show detailed diagnostic output"
  echo "  --all                       Run or skip every unspecified section"
  echo
  echo "Sections:"
  for section in ${(ok)SECTION_PARAMETERS}; do
    echo "  --${section}"
  done
  echo
  echo "The equivalent config variables are the RUN_* values in config.example."
}

while (( $# > 0 )); do
  argument=$1
  case "$argument" in
    --help|-h)
      usage
      exit 0
      ;;
    --verbose)
      VERBOSE=1
      shift
      continue
      ;;
    --*=*)
      option=${argument%%=*}
      value=${argument#*=}
      ;;
    --*)
      if (( $# < 2 )); then
        echo "Missing yes/no value for ${argument}" >&2
        exit 2
      fi
      option=$argument
      value=$2
      shift
      ;;
    *)
      echo "Unknown argument: ${argument}" >&2
      usage >&2
      exit 2
      ;;
  esac

  section=${option#--}
  if [[ "$section" != all ]]; then
    variable_name=${SECTION_PARAMETERS[$section]-}
  else
    variable_name=RUN_ALL
  fi
  if [[ -z "$variable_name" ]]; then
    echo "Unknown section: ${section}" >&2
    usage >&2
    exit 2
  fi
  case ${(L)value} in
    y|yes|true|1|n|no|false|0) ;;
    *)
      echo "Invalid value '${value}' for ${option}; use yes or no." >&2
      exit 2
      ;;
  esac
  if [[ "$section" == all ]]; then
    CLI_ALL_VALUE=$value
  else
    CLI_SECTION_VALUES[$variable_name]=$value
  fi
  shift
done

verbose_output() {
  (( VERBOSE )) || return 0
  echo "${GREY}$*${NC}"
}

should_run() {
  local variable_name=$1
  local prompt=$2
  local value

  verbose_output "Resolving ${variable_name}: ${prompt}"

  if (( ${+CLI_SECTION_VALUES[$variable_name]} )); then
    value=${CLI_SECTION_VALUES[$variable_name]}
  elif (( ${(P)+variable_name} )); then
    value=${(P)variable_name}
  elif [[ -n ${CLI_ALL_VALUE+x} ]]; then
    value=$CLI_ALL_VALUE
  elif [[ -n ${RUN_ALL+x} ]]; then
    value=$RUN_ALL
  else
    read "value?${prompt} [y/N] "
  fi

  verbose_output "Determined value for ${variable_name}: ${value}"

  case ${(L)value} in
    y|yes|true|1) return 0 ;;
    n|no|false|0|'') return 1 ;;
    *)
      echo "Invalid value '${value}' for ${variable_name}; use yes or no." >&2
      exit 2
      ;;
  esac
}

install_homebrew() {
  local brew_command
  if command -v brew >/dev/null 2>&1; then
    brew_command=$(command -v brew)
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    brew_command=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_command=/usr/local/bin/brew
  fi

  if [[ -z "$brew_command" ]]; then
    echo
    echo "${GREEN}Installing Homebrew"
    echo
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
      brew_command=/opt/homebrew/bin/brew
    elif [[ -x /usr/local/bin/brew ]]; then
      brew_command=/usr/local/bin/brew
    fi
  fi

  if [[ -z "$brew_command" ]]; then
    echo "${RED}Homebrew installation failed: brew was not found.${NC}" >&2
    return 1
  fi

  local shellenv_line="eval \"\$(${brew_command} shellenv)\""
  touch "${HOME}/.zprofile"
  grep -Fqx "$shellenv_line" "${HOME}/.zprofile" || echo "$shellenv_line" >> "${HOME}/.zprofile"
  eval "$(${brew_command} shellenv)"

  echo
  echo "${GREEN}Checking installation.."
  echo
  "$brew_command" update && "$brew_command" doctor || return 1
  export HOMEBREW_NO_INSTALL_CLEANUP=1
}

# COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
GREY='\033[0;90m'
NC='\033[0m' # No Color

#########
# Start #
#########

echo "install.sh"
echo
if should_run RUN_AUTHENTICATE_SUDO "Authenticate with sudo upfront?"; then
  echo Enter root password

  # Ask for the administrator password upfront.
  sudo -v

  # Keep Sudo until script is finished
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done 2>/dev/null &
fi

# Update macOS
if should_run RUN_UPDATE_MACOS "Update macOS?"; then
  echo
  echo "${GREEN}Looking for updates.."
  echo
  sudo softwareupdate -i -a
fi

# Install Rosetta
if should_run RUN_INSTALL_ROSETTA "Install Rosetta?"; then
  sudo softwareupdate --install-rosetta --agree-to-license
fi

# Install Homebrew
if should_run RUN_INSTALL_HOMEBREW "Install Homebrew?"; then
  install_homebrew || exit 1
fi

# Check for Brewfile in the current directory and use it if present
if should_run RUN_INSTALL_BREW_PACKAGES "Install Homebrew packages?"; then
  if [ -f "${SCRIPT_DIR}/Brewfile" ]; then
    echo
    echo "${GREEN}Brewfile found. Using it to install packages..."
    brew bundle --file="${SCRIPT_DIR}/Brewfile"
    echo "${GREEN}Installation from Brewfile complete."
  else
    echo
    echo "${GREEN}Installing formulae..."
    for formula in "${FORMULAE[@]}"; do
      brew install "$formula"
      if [ $? -ne 0 ]; then
        echo "${RED}Failed to install $formula. Continuing...${NC}"
      fi
    done

    echo "${GREEN}Installing casks..."
    for cask in "${CASKS[@]}"; do
      brew install --cask "$cask"
      if [ $? -ne 0 ]; then
        echo "${RED}Failed to install $cask. Continuing...${NC}"
      fi
    done
  fi
fi

# App Store
if should_run RUN_INSTALL_APP_STORE "Install apps from App Store?"; then
  brew install mas
  for app in "${APPSTORE[@]}"; do
    mas install "$app"
  done
fi

# VS Code Extensions
if should_run RUN_INSTALL_VSCODE_EXTENSIONS "Install VS Code extensions?"; then
  for extension in "${VSCODE[@]}"; do
    code --install-extension "$extension"
  done
fi

# Install Node.js
if should_run RUN_INSTALL_NODE "Install Node.js?"; then
  if [[ -z ${NODE_INSTALL_METHOD+x} ]]; then
    read "NODE_INSTALL_METHOD?Install Node.js via NVM or Homebrew? [nvm/homebrew] "
  fi

  case ${(L)NODE_INSTALL_METHOD} in
    nvm|n)
      echo "${GREEN}Installing NVM..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

      # Loads NVM
      export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

      echo "${GREEN}Installing Node via NVM..."
      nvm install --lts
      nvm install node
      nvm alias default node
      nvm use default
      ;;
    homebrew|brew|b)
      echo "${GREEN}Installing Node via Homebrew..."
      brew install node
      ;;
    *)
      echo "Invalid NODE_INSTALL_METHOD '${NODE_INSTALL_METHOD}'; use nvm or homebrew." >&2
      exit 2
      ;;
  esac
fi

# Install NPM Packages
if should_run RUN_INSTALL_NPM_PACKAGES "Install global NPM packages?"; then
  echo
  echo "${GREEN}Installing Global NPM Packages..."
  npm install -g ${NPMPACKAGES[@]}
fi

# Optional Packages
if should_run RUN_INSTALL_DOTNET "Install .NET?"; then
  brew install dotnet
  export DOTNET_ROOT="/opt/homebrew/opt/dotnet/libexec"
fi

if should_run RUN_INSTALL_FIREFOX_DEVELOPER "Install Firefox Developer Edition?"; then
  brew tap homebrew/cask-versions
  brew install firefox-developer-edition
fi

if should_run RUN_INSTALL_DATABASES "Install PostgreSQL, MySQL, and MongoDB?"; then
  # Postgres
  brew install postgresql
  # MySQL
  brew install mysql
  if should_run RUN_SETUP_MYSQL "Set up MySQL now?"; then
    echo "${GREEN}Starting MySQL..."
    brew services start mysql
    sleep 2
    mysql_secure_installation
  fi
  # MongoDB
  brew tap mongodb/brew
  brew install mongodb-community
fi

if should_run RUN_INSTALL_GAMES "Install Epic Games and Steam?"; then
  brew install steam epic-games
fi

if should_run RUN_INSTALL_UNITY_HUB "Install Unity Hub?"; then
  brew install unity-hub
fi

if should_run RUN_INSTALL_FIGMA "Install Figma?"; then
  brew install figma
fi

# Cleanup
if should_run RUN_CLEANUP_HOMEBREW "Clean up and configure Homebrew autoupdate?"; then
  echo
  echo "${GREEN}Cleaning up..."
  brew update && brew upgrade && brew cleanup && brew doctor
  mkdir -p ~/Library/LaunchAgents
  brew tap homebrew/autoupdate
  brew autoupdate start $HOMEBREW_UPDATE_FREQUENCY --upgrade --cleanup --immediate --sudo
fi

# Settings
if should_run RUN_CONFIGURE_SETTINGS "Configure default system settings?"; then
  echo "${GREEN}Configuring default settings..."
  for setting in "${SETTINGS[@]}"; do
    eval $setting
  done
fi

# Dock settings
if should_run RUN_CONFIGURE_DOCK "Apply Dock settings?"; then
  if ! command -v brew >/dev/null 2>&1; then
    install_homebrew || exit 1
  fi
  brew install dockutil
  # Handle replacements
  for item in "${DOCK_REPLACE[@]}"; do
    IFS="|" read -r add_app replace_app <<<"$item"
    dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null
  done
  # Handle additions
  for app in "${DOCK_ADD[@]}"; do
    dockutil --add "$app" &>/dev/null
  done
  # Handle removals
  for app in "${DOCK_REMOVE[@]}"; do
    dockutil --remove "$app" &>/dev/null
  done
fi

# Git Login
if should_run RUN_CONFIGURE_GIT "Configure Git?"; then
  echo
  echo "${GREEN}SET UP GIT"
  echo

  if [[ -z ${GIT_NAME+x} ]]; then
    read "GIT_NAME?${RED}Please enter your git username:${NC} "
  fi
  if [[ -z ${GIT_EMAIL+x} ]]; then
    read "GIT_EMAIL?${RED}Please enter your git email:${NC} "
  fi

  git config --global user.name "$GIT_NAME"
  git config --global user.email "$GIT_EMAIL"
  git config --global color.ui true

  echo
  echo "${GREEN}GITTY UP!"
fi

# ohmyzsh
if should_run RUN_INSTALL_OH_MY_ZSH "Install Oh My Zsh?"; then
  echo
  echo "${GREEN}Installing ohmyzsh!"
  echo
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo "${GREEN}Done"
echo
echo
if should_run RUN_REBOOT "Reboot now?"; then
  sudo reboot
fi
exit
