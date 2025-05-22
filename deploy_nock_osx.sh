#!/bin/bash

# ========= Color Definitions =========
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'

# ========= Project Path =========
NCK_DIR="$HOME/nockchain"

# ========= Banner & Signature =========
function show_banner() {
  clear
  echo -e "${BOLD}${BLUE}"
  echo "       Ok Hi           "
  echo "                       "
  echo "                       "
  echo "                       "
  echo "                       "
  echo "        MWO            "
  echo "-----------------------"
  echo ""
}

# ========= Check macOS Environment =========
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}[-] This script is for macOS only!${RESET}"
  exit 1
fi

# ========= Install Homebrew =========
function install_homebrew() {
  if command -v brew &> /dev/null; then
    echo -e "${YELLOW}[!] Homebrew already installed. Skipping.${RESET}"
    return
  fi
  echo -e "[*] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ $? -ne 0 ]; then
    echo -e "${RED}[-] Homebrew installation failed. Please install manually.${RESET}"
    pause_and_return
    return
  fi
  echo -e "${GREEN}[+] Homebrew installed.${RESET}"
}

# ========= Install Dependencies =========
function install_dependencies() {
  install_homebrew
  echo -e "[*] Installing dependencies..."
  brew install git curl wget make automake autoconf pkg-config openssl lz4 jq tmux llvm
  if [ $? -ne 0 ]; then
    echo -e "${RED}[-] Failed to install dependencies. Check Homebrew or network.${RESET}"
    pause_and_return
    return
  fi
  echo -e "${GREEN}[+] Dependencies installed.${RESET}"
  pause_and_return
}

# ========= Install Rust =========
function install_rust() {
  if command -v rustc &> /dev/null; then
    echo -e "${YELLOW}[!] Rust already installed. Skipping.${RESET}"
    pause_and_return
    return
  fi
  echo -e "[*] Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  rustup default stable
  if [ $? -ne 0 ]; then
    echo -e "${RED}[-] Rust installation failed. Please install manually.${RESET}"
    pause_and_return
    return
  fi
  echo -e "${GREEN}[+] Rust installed.${RESET}"
  pause_and_return
}

# ========= Clone or Update Repo =========
function setup_repository() {
  echo -e "[*] Checking nockchain repo..."
  if [ -d "$NCK_DIR" ]; then
    echo -e "${YELLOW}[?] nockchain directory exists. Delete and re-clone? (y/n)${RESET}"
    read -r confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      rm -rf "$NCK_DIR"
      git clone https://github.com/zorp-corp/nockchain "$NCK_DIR"
      if [ $? -ne 0 ]; then
        echo -e "${RED}[-] Failed to clone repo. Check network or permissions.${RESET}"
        pause_and_return
        return
      fi
    else
      cd "$NCK_DIR" && git pull
      [ -f .env_example ] && mv .env_example .env
    fi
  else
    git clone https://github.com/zorp-corp/nockchain "$NCK_DIR"
    if [ $? -ne 0 ]; then
      echo -e "${RED}[-] Failed to clone repo. Check network or permissions.${RESET}"
      pause_and_return
      return
    fi
  fi
  echo -e "${GREEN}[+] Repository setup complete.${RESET}"
  pause_and_return
}

# ========= Build Project =========
function build_project() {
  if [ ! -d "$NCK_DIR" ]; then
    echo -e "${RED}[-] nockchain directory not found. Please set up repo first.${RESET}"
    pause_and_return
    return
  fi

  cd "$NCK_DIR" || exit 1
  read -p "[?] Enter number of CPU cores to use: " CORE_COUNT
  if ! [[ "$CORE_COUNT" =~ ^[0-9]+$ ]] || [[ "$CORE_COUNT" -lt 1 ]]; then
    echo -e "${RED}[-] Invalid input. Defaulting to 1 core.${RESET}"
    CORE_COUNT=1
  fi

  echo -e "[*] Building core components using ${CORE_COUNT} core(s)..."
  make -j$CORE_COUNT install-hoonc
  make -j$CORE_COUNT build
  make -j$CORE_COUNT install-nockchain-wallet
  make -j$CORE_COUNT install-nockchain
  echo -e "${GREEN}[+] Build complete.${RESET}"
  pause_and_return
}

# ========= Configure Environment Variables =========
function configure_env() {
  echo -e "[*] Configuring environment variables..."
  RC_FILE="$HOME/.zshrc"
  [[ "$SHELL" == *"bash"* ]] && RC_FILE="$HOME/.bashrc"

  if ! grep -q "$HOME/nockchain/target/release" "$RC_FILE"; then
    echo 'export PATH="$PATH:$HOME/nockchain/target/release"' >> "$RC_FILE"
  fi
  if ! grep -q "LIBCLANG_PATH" "$RC_FILE"; then
    echo 'export LIBCLANG_PATH=$(brew --prefix llvm)/lib' >> "$RC_FILE"
  fi
  source "$RC_FILE"
  export LIBCLANG_PATH=$(brew --prefix llvm)/lib
  echo -e "${GREEN}[+] Environment configured.${RESET}"
  pause_and_return
}

# ========= Generate Wallet =========
function generate_wallet() {
  if [ ! -d "$NCK_DIR" ] || [ ! -f "$NCK_DIR/target/release/nockchain-wallet" ]; then
    echo -e "${RED}[-] Wallet binary or directory not found. Build first.${RESET}"
    pause_and_return
    return
  fi

  cd "$NCK_DIR" || exit 1
  echo -e "[*] Generating wallet key pair..."
  WALLET_CMD="./target/release/nockchain-wallet"
  KEYGEN_OUTPUT=$("$WALLET_CMD" keygen 2>&1 | tr -d '\0')
  if [ $? -ne 0 ]; then
    echo -e "${RED}[-] Key generation failed!${RESET}"
    echo "$KEYGEN_OUTPUT" > "$NCK_DIR/wallet.txt"
    echo -e "[*] Error output saved to $NCK_DIR/wallet.txt"
    pause_and_return
    return
  fi

  echo "$KEYGEN_OUTPUT" > "$NCK_DIR/wallet.txt"
  echo -e "[*] Keys saved to $NCK_DIR/wallet.txt"

  PUBLIC_KEY=$(echo "$KEYGEN_OUTPUT" | grep -i "public key" | awk '{print $NF}')
  if [ -z "$PUBLIC_KEY" ]; then
    echo -e "${RED}[-] Could not extract public key.${RESET}"
    pause_and_return
    return
  fi
  echo -e "${YELLOW}Public Key:${RESET}\n$PUBLIC_KEY"
  echo -e "${YELLOW}[!] Please manually add the following to $NCK_DIR/Makefile:${RESET}"
  echo -e "export MINING_PUBKEY := $PUBLIC_KEY"
  echo -e "${YELLOW}[!] Or use menu option '7) Configure mining key'.${RESET}"
  echo -e "${GREEN}[+] Wallet generated.${RESET}"
  pause_and_return
}

# ========= Configure Mining Public Key =========
function configure_mining_key() {
  if [ ! -f "$NCK_DIR/Makefile" ]; then
    echo -e "${RED}[-] Makefile not found. Cannot set key.${RESET}"
    pause_and_return
    return
  fi

  read -p "[?] Enter your mining public key: " key
  cd "$NCK_DIR" || exit 1
  if grep -q "MINING_PUBKEY" Makefile; then
    sed -i '' "s|^export MINING_PUBKEY ?=.*$|export MINING_PUBKEY ?= $key|" Makefile
  else
    echo "export MINING_PUBKEY ?= $key" >> Makefile
  fi
  echo -e "${GREEN}[+] Mining key updated.${RESET}"
  pause_and_return
}

# ========= Manage Keys (Backup/Import) =========
function manage_keys() {
  echo ""
  echo "Key Management:"
  echo "  1) Backup keys"
  echo "  2) Import keys"
  echo "  0) Return to main menu"
  echo ""
  read -p "Choose an option: " key_choice
  case "$key_choice" in
    1)
      cd "$NCK_DIR" || exit 1
      if [ -f "$NCK_DIR/target/release/nockchain-wallet" ]; then
        echo -e "[*] Backing up keys..."
        ./target/release/nockchain-wallet export-keys
        if [ -f "keys.export" ]; then
          echo -e "${GREEN}[+] Keys backed up to $NCK_DIR/keys.export${RESET}"
        else
          echo -e "${RED}[-] Backup failed!${RESET}"
        fi
      else
        echo -e "${RED}[-] Wallet binary not found. Build first.${RESET}"
      fi
      ;;
    2)
      cd "$NCK_DIR" || exit 1
      if [ -f "$NCK_DIR/target/release/nockchain-wallet" ]; then
        if [ -f "keys.export" ]; then
          echo -e "[*] Importing keys..."
          ./target/release/nockchain-wallet import-keys --input keys.export
          echo -e "${GREEN}[+] Keys imported.${RESET}"
        else
          echo -e "${RED}[-] keys.export file not found!${RESET}"
        fi
      else
        echo -e "${RED}[-] Wallet binary not found. Build first.${RESET}"
      fi
      ;;
    0) return ;;
    *) echo -e "${RED}[-] Invalid option.${RESET}" ;;
  esac
  pause_and_return
}

# ========= Start Leader Node =========
function start_leader_node() {
  if [ ! -d "$NCK_DIR" ]; then
    echo -e "${RED}[-] nockchain directory not found. Set up repo first.${RESET}"
    pause_and_return
    return
  fi

  cd "$NCK_DIR" || exit 1
  echo -e "[*] Starting Leader node..."
  tmux new-session -d -s leader "make run-nockchain-leader"
  echo -e "${GREEN}[+] Leader node running.${RESET}"
  echo -e "${YELLOW}[!] Entering logs. Press Ctrl+B then D to detach.${RESET}"
  sleep 2
  tmux attach-session -t leader
  pause_and_return
}

function pause_and_return() {
  read -p "Press Enter to return to menu..."
}

show_banner

while true; do
  echo "========= Main Menu ========="
  echo "1) Install dependencies"
  echo "2) Install Rust"
  echo "3) Clone/Update Nockchain repo"
  echo "4) Build Nockchain"
  echo "5) Configure environment"
  echo "6) Generate wallet"
  echo "7) Configure mining public key"
  echo "8) Manage keys (backup/import)"
  echo "9) Start Leader node"
  echo "0) Exit"
  echo "============================="
  read -p "Select an option: " choice

  case "$choice" in
    1) install_dependencies ;;
    2) install_rust ;;
    3) setup_repository ;;
    4) build_project ;;
    5) configure_env ;;
    6) generate_wallet ;;
    7) configure_mining_key ;;
    8) manage_keys ;;
    9) start_leader_node ;;
    0) echo "Bye!" && exit 0 ;;
    *) echo -e "${RED}[-] Invalid choice.${RESET}" ;;
  esac
done
