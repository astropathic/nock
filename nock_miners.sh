#!/bin/bash

# --- Install Homebrew and tmux on macOS if needed ---
if [[ "$(uname)" == "Darwin" ]]; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Installing..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Determine shell profile for persistence
    SHELL_NAME=$(basename "$SHELL")
    if [[ "$SHELL_NAME" == "zsh" ]]; then
      PROFILE="$HOME/.zprofile"
    else
      PROFILE="$HOME/.bash_profile"
    fi

    # Determine correct brew shellenv command for arch
    if [[ -d "/opt/homebrew" ]]; then
      BREW_ENV_CMD='eval "$(/opt/homebrew/bin/brew shellenv)"'
    else
      BREW_ENV_CMD='eval "$(/usr/local/bin/brew shellenv)"'
    fi

    # Append to profile if missing
    if ! grep -Fq "$BREW_ENV_CMD" "$PROFILE"; then
      echo "$BREW_ENV_CMD" >> "$PROFILE"
      echo "Added Homebrew environment setup to $PROFILE"
    fi

    # Source profile immediately to update current session
    # shellcheck source=/dev/null
    source "$PROFILE"
  fi

  # Install tmux if missing
  if ! command -v tmux >/dev/null 2>&1; then
    echo "Installing tmux with Homebrew..."
    brew install tmux
  fi

else
  # Debian-based Linux systems install tmux if missing
  if ! command -v tmux >/dev/null 2>&1; then
    echo "Installing tmux..."
    sudo apt update
    sudo apt install -y tmux
  fi
fi

# --- Kill old nockchain miners if running ---
PIDS=$(pgrep -f run_nockchain_miner.sh)
if [[ -n "$PIDS" ]]; then
  echo "Found running nockchain miner processes:"
  echo "$PIDS"
  read -p "Kill them before starting new ones? (y/n) " ANSWER
  if [[ "$ANSWER" == "y" ]]; then
    echo "$PIDS" | xargs kill -9
    echo "Killed existing miner processes."
  else
    echo "Aborting."
    exit 1
  fi
fi

# --- Prompt user ---
read -p "How many miners to run? " NUM
if ! [[ "$NUM" =~ ^[0-9]+$ ]]; then
  echo "Invalid number"
  exit 1
fi

read -p "View logs in one pane or split view? (Enter 1 for one pane, 2 for split) " VIEW
if ! [[ "$VIEW" =~ ^[12]$ ]]; then
  echo "Invalid choice"
  exit 1
fi

# --- Setup ---
cd ~/nockchain/ || exit 1
rm -rf miner*

BASE_DIR="$(pwd)"
SESSION="nockminers"
LOG_FILE="$BASE_DIR/miners.log"

> "$LOG_FILE"  # Clear old log

if [[ "$VIEW" == "1" ]]; then
  tmux new-session -d -s "$SESSION" -n "miners" "tail -f \"$LOG_FILE\""
  for i in $(seq 1 "$NUM"); do
    MINER_NAME="miner$i"
    MINER_DIR="${BASE_DIR}/${MINER_NAME}"
    mkdir -p "$MINER_DIR"
    cp "$BASE_DIR/.env" "$MINER_DIR/"
    (
      cd "$MINER_DIR"
      sh ../scripts/run_nockchain_miner.sh 2>&1 | sed "s/^/[$MINER_NAME] /" >> "$LOG_FILE"
    ) &
  done
else
  for i in $(seq 1 "$NUM"); do
    MINER_NAME="miner$i"
    MINER_DIR="${BASE_DIR}/${MINER_NAME}"
    mkdir -p "$MINER_DIR"
    cp "$BASE_DIR/.env" "$MINER_DIR/"
    CMD="cd \"$MINER_DIR\" && sh ../scripts/run_nockchain_miner.sh"

    if [[ $i -eq 1 ]]; then
      tmux new-session -d -s "$SESSION" -n "$MINER_NAME" "$CMD"
    else
      tmux new-window -t "$SESSION:" -n "$MINER_NAME" "$CMD"
    fi
  done
fi

tmux attach-session -t "$SESSION"
