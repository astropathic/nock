#!/bin/bash

# ========= Color Definitions =========
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

# ========= Project Path =========
NCK_DIR="$HOME/nockchain"

# ========= Banner =========
function show_banner() {
  clear
  echo -e "${BOLD}${GREEN}"
  echo "               NOCKCHAIN SETUP                "
  echo "=============================================="
  echo -e "${RESET}"
}

# ========= Check Linux Environment =========
if [[ "$(uname -s)" != "Linux" ]]; then
  echo -e "${RED}[-] This script is for Linux only!${RESET}"
  exit 1
fi

# ========= Install Dependencies =========
function install_dependencies() {
  echo -e "[*] Updating package list and installing dependencies..."
  sudo apt update && sudo apt install -y \
    git curl wget make automake autoconf pkg-config libssl-dev lz4 jq tmux clang llvm unzip build-essential

  if [ $? -ne 0 ]; then
    echo -e "${RED}[-] Failed to install dependencies.${RESET}"
  else
    echo -e "${GREEN}[+] Dependencies installed.${RESET}"
  fi
  pause_and_return
}

# ========= Install Rust =========
function install_rust() {
  if command -v rustc &>/dev/null; then
    echo -e "${YELLOW}[!] Rust already installed.${RESET}"
    pause_and_return
    return
  fi

  echo -e "[*] Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  rustup default stable

  if [ $? -ne 0 ]; then
    echo -e "${RED}[-] Rust installation failed.${RESET}"
  else
    echo -e "${GREEN}[+] Rust installed.${RESET}"
  fi
  pause_and_return
}

# ========= Clone or Update Repo =========
function setup_repository() {
  echo -e "[*] Checking Nockchain repo..."
  if [ -d "$NCK_DIR" ]; then
    echo -e "${YELLOW}[?] Repo exists. Delete and re-clone? (y/n)${RESET}"
    read -r confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      rm -rf "$NCK_DIR"
      git clone https://github.com/zorp-corp/nockchain "$NCK_DIR"
    else
      cd "$NCK_DIR" && git pull
    fi
  else
    git clone https://github.com/zorp-corp/nockchain "$NCK_DIR"
  fi

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[+] Repo ready.${RESET}"
  else
    echo -e "${RED}[-] Repo clone failed.${RESET}"
  fi
  pause_and_return
}

# ========= Build Project =========
function build_project() {
  if [ ! -d "$NCK_DIR" ]; then
    echo -e "${RED}[-] nockchain directory not found.${RESET}"
    pause_and_return
    return
  fi

  cd "$NCK_DIR" || exit 1
  read -p "[?] Number of cores to use for build: " CORE_COUNT
  [[ "$CORE_COUNT" =~ ^[0-9]+$ ]] || CORE_COUNT=1

  echo -e "[*] Building with $CORE_COUNT core(s)..."
  make -j$CORE_COUNT install-hoonc
  make -j$CORE_COUNT build
  make -j$CORE_COUNT install-nockchain-wallet
  make -j$CORE_COUNT install-nockchain

  echo -e "${GREEN}[+] Build complete.${RESET}"
  pause_and_return
}

# ========= Configure Environment =========
function configure_env() {
  echo -e "[*] Configuring environment..."
  RC_FILE="$HOME/.bashrc"
  [[ "$SHELL" == *"zsh"* ]] && RC_FILE="$HOME/.zshrc"

  grep -q 'nockchain/target/release' "$RC_FILE" || \
    echo 'export PATH="$PATH:$HOME/nockchain/target/release"' >> "$RC_FILE"

  grep -q 'LIBCLANG_PATH' "$RC_FILE" || \
    echo 'export LIBCLANG_PATH=/usr/lib/llvm-$(llvm-config --version | cut -d. -f1)/lib' >> "$RC_FILE"

  source "$RC_FILE"
  echo -e "${GREEN}[+] Environment configured.${RESET}"
  pause_and_return
}

# ========= Generate Wallet =========
function generate_wallet() {
  if [ ! -x "$NCK_DIR/target/release/nockchain-wallet" ]; then
    echo -e "${RED}[-] Wallet binary missing. Build first.${RESET}"
    pause_and_return
    return
  fi

  cd "$NCK_DIR"
  echo -e "[*] Generating wallet..."
  OUTPUT=$(./target/release/nockchain-wallet keygen 2>&1 | tr -d '\0')
  echo "$OUTPUT" > wallet.txt

  echo -e "${YELLOW}[+] Wallet generated. Saved to wallet.txt${RESET}"
  PUBKEY=$(echo "$OUTPUT" | grep -i 'public key' | awk '{print $NF}')
  if [ -n "$PUBKEY" ]; then
    echo -e "${YELLOW}Public Key:${RESET} $PUBKEY"
    echo -e "${YELLOW}Add to Makefile: export MINING_PUBKEY := $PUBKEY${RESET}"
  fi
  pause_and_return
}

# ========= Configure Mining Key =========
function configure_mining_key() {
  read -p "[?] Enter your mining public key: " key
  if grep -q "MINING_PUBKEY" "$NCK_DIR/Makefile"; then
    sed -i "s|^export MINING_PUBKEY :=.*|export MINING_PUBKEY := $key|" "$NCK_DIR/Makefile"
  else
    echo "export MINING_PUBKEY := $key" >> "$NCK_DIR/Makefile"
  fi
  echo -e "${GREEN}[+] Mining key configured.${RESET}"
  pause_and_return
}

# ========= Start Leader Node =========
function start_leader_node() {
  if [ ! -d "$NCK_DIR" ]; then
    echo -e "${RED}[-] Nockchain directory not found.${RESET}"
    pause_and_return
    return
  fi

  cd "$NCK_DIR" || exit 1
  echo -e "[*] Starting leader node..."
  tmux new-session -d -s leader "make run-nockchain-leader"
  echo -e "${GREEN}[+] Leader node started.${RESET}"
  tmux attach-session -t leader
  pause_and_return
}

# ========= Pause =========
function pause_and_return() {
  read -p "Press Enter to return to menu..."
}

# ========= Main Menu =========
show_banner
while true; do
  echo -e "${BOLD}========= Nockchain Menu =========${RESET}"
  echo "1) Install dependencies"
  echo "2) Install Rust"
  echo "3) Clone/Update Nockchain repo"
  echo "4) Build Nockchain"
  echo "5) Configure environment"
  echo "6) Generate wallet"
  echo "7) Configure mining key"
  echo "8) Start leader node"
  echo "0) Exit"
  echo "=================================="
  read -p "Select an option: " choice
  case "$choice" in
    1) install_dependencies ;;
    2) install_rust ;;
    3) setup_repository ;;
    4) build_project ;;
    5) configure_env ;;
    6) generate_wallet ;;
    7) configure_mining_key ;;
    8) start_leader_node ;;
    0) echo "bye o/" && exit 0 ;;
    *) echo -e "${RED}[-] Invalid choice.${RESET}" ;;
  esac
done
