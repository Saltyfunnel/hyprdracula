#!/bin/bash
# Dracula-themed helper functions for HyprDracula setup

# Dracula color palette
DRACULA_BG='\033[48;5;234m'    # Dark background
DRACULA_FG='\033[38;5;248m'    # Light gray foreground
DRACULA_PINK='\033[38;5;205m'  # Pink / magenta
DRACULA_PURPLE='\033[38;5;141m'
DRACULA_ORANGE='\033[38;5;214m'
DRACULA_GREEN='\033[38;5;80m'
DRACULA_RED='\033[38;5;203m'
DRACULA_YELLOW='\033[38;5;229m'
BOLD='\033[1m'
NC='\033[0m'

print_error()    { echo -e "${DRACULA_RED}$1${NC}"; }
print_success()  { echo -e "${DRACULA_GREEN}$1${NC}"; }
print_warning()  { echo -e "${DRACULA_ORANGE}$1${NC}"; }
print_info()     { echo -e "${DRACULA_PURPLE}$1${NC}"; }
print_bold_pink(){ echo -e "${DRACULA_PINK}${BOLD}$1${NC}"; }
print_header()   { echo -e "\n${BOLD}${DRACULA_PURPLE}==> $1${NC}"; }

ask_confirmation() {
  while true; do
    read -rp "$(print_warning "$1 (y/n): ")" -n 1
    echo
    case $REPLY in
      [Yy]) return 0 ;;
      [Nn]) print_error "Operation cancelled."; return 1 ;;
      *) print_error "Invalid input. Please answer y or n." ;;
    esac
  done
}

run_command() {
  local cmd="$1"
  local description="$2"
  local ask_confirm="${3:-yes}"
  local use_sudo="${4:-yes}" # yes=run as root, no=run as user

  local full_cmd=""
  if [[ "$use_sudo" == "no" ]]; then
    full_cmd="sudo -u $SUDO_USER bash -c \"$cmd\""
  else
    full_cmd="$cmd"
  fi

  print_info "\nCommand: $full_cmd"
  if [[ "$ask_confirm" == "yes" ]]; then
    if ! ask_confirmation "$description"; then
      return 1
    fi
  else
    print_info "$description"
  fi

  until eval "$full_cmd"; do
    print_error "Command failed: $cmd"
    if [[ "$ask_confirm" == "yes" ]]; then
      if ! ask_confirmation "Retry $description?"; then
        print_warning "$description not completed."
        return 1
      fi
    else
      print_warning "$description failed, no retry (auto mode)."
      return 1
    fi
  done

  print_success "$description completed successfully."
  return 0
}

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    print_error "Please run as root."
    exit 1
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "arch" ]]; then
      print_warning "This script is designed for Arch Linux. Detected: $PRETTY_NAME"
      if ! ask_confirmation "Continue anyway?"; then
        exit 1
      fi
    else
      print_success "Arch Linux detected. Proceeding."
    fi
  else
    print_error "/etc/os-release not found. Cannot determine OS."
    if ! ask_confirmation "Continue anyway?"; then
      exit 1
    fi
  fi
}
