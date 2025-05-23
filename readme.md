## Nockchain Overview

Nockchain is a compact blockchain designed for high-performance computation, utilizing Zero-Knowledge Proof of Work (zkPoW). Miners generate a ZK-Proof (ZKP) for a fixed puzzle, hash the ZKP, and earn \$NOCK based on their computational output.

A Public Testnet is available for anyone to set up a **local testnet node** and a **testnet miner**, enabling users to explore how the system operates before Mainnet deployment.

---

## \$NOCK Token Information

* Genesis and \$NOCK mining start on May 21st.
* Blocks are produced every 10 minutes, similar to Bitcoin.
* Total supply is capped at 2^32 nocks (\~4.29 billion).
* Fair launch: All tokens are distributed through mining.
* \$NOCK is used for purchasing blockspace on the Nockchain network.

---

## Mining Guide

* Mining principles are identical to traditional PoW (Proof of Work) systems like Bitcoin.
* Higher computational resources = increased mining rewards.
* More miners = higher network hashrate = greater mining difficulty.

### Option 1: Solo Mining (CLI)

* Run a standalone, CPU-powered mining node. Substantial hardware is recommended.
* Follow instructions in the [CLI Setup](https://github.com/0xmoei/nockchain/blob/main/README.md#cli-miner-setup).

### Option 2: Mining Pools & Option 3: GUI Mining

* Join a mining pool to share computational work and earn proportional rewards.
* Officially supported mining method is via CLI; there are no endorsed GUI or pool solutions yet.
* Community-led projects such as [**Nockpool**](https://swps.io/nockpool) are emerging with GUI-based nodes for simplified setup and wallet management.

![Nockpool Interface](https://github.com/user-attachments/assets/6f58647d-2255-4ebb-839c-eeb539cac258)

---

## CLI Miner Setup

### Hardware Recommendations

> Note: These are testnet estimates. Actual requirements may vary post-Mainnet.

| RAM   | CPU               | Storage        |
| ----- | ----------------- | -------------- |
| 64 GB | 6 cores or better | 100-200 GB SSD |

* More cores yield better hashrates.
* Final hardware benchmarks will become clear after launch.

### OS Compatibility

* **Windows Users:** Install Ubuntu using this [guide](https://github.com/0xmoei/Install-Linux-on-Windows).
* **VPS Users:** Purchase a crypto-friendly VPS [here](https://my.hostbrr.com/order/forms/a/NTMxNw==) or consult the [VPS setup guide](https://github.com/0xmoei/Linux_Node_Guide/).

> Mining starts on CPU and may eventually migrate to GPU/ASIC.

---

## CLI Installation

### Step 1: System Prep

Update system and install dependencies:

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libclang-dev llvm-dev -y
```

Install Rust:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

Enable memory overcommit:

```bash
sudo sysctl -w vm.overcommit_memory=1
```

### Step 2: Clean Old Installations

```bash
screen -XS miner quit
rm -rf nockchain .nockapp
```

### Step 3: Clone Repository

```bash
git clone https://github.com/zorp-corp/nockchain
cd nockchain
```

### Step 4: Build Project

Copy and configure environment:

```bash
cp .env_example .env
```

Compile:

```bash
make install-hoonc
make build
make install-nockchain-wallet
make install-nockchain
export PATH="$HOME/.cargo/bin:$PATH"
```

### Step 5: Wallet Setup

```bash
export PATH="$HOME/.cargo/bin:$PATH"
nockchain-wallet keygen
```

Save your mnemonic, public key, and private key. Set `MINING_PUBKEY=` in `.env`:

```bash
nano .env
```

Use `Ctrl + X`, then `Y`, then `Enter` to save.

### Step 6: Backup & Restore Wallet Keys

Backup:

```bash
nockchain-wallet export-keys
```

Restore:

```bash
nockchain-wallet import-keys --input keys.export
```

> NAT users may need to configure port forwarding. 

### Step 7: Run a Miner

```bash
sudo sysctl -w vm.overcommit_memory=1
cd ~/nockchain
```

To run Miner 1:

```bash
mkdir miner1 && cd miner1
screen -S miner1
```

Start mining:

```bash
RUST_LOG=info,nockchain=info,nockchain_libp2p_io=info,libp2p=info,libp2p_quic=info \
MINIMAL_LOG_FORMAT=true \
nockchain --mine --mining-pubkey PUB_KEY
```

Optional: connect to peers

```bash
--peer /ip4/95.216.102.60/udp/3006/quic-v1 \
--peer /ip4/65.108.123.225/udp/3006/quic-v1 ...
```

You're mining if you see messages like `generating new candidate`. Errors like `timer` or `ConnectionError` are non-blocking.

![Miner Screenshot](https://github.com/user-attachments/assets/61730f44-c55c-4452-918c-b216982f2033)

Use `Ctrl + A + D` to detach the screen. Monitor RAM usage (`htop`) before adding more miner instances.

### Common Commands

Restarting:

```bash
rm -rf ./.data.nockchain .socket/nockchain_npc.sock
```

Screen utilities:

```bash
screen -r miner   # reattach
screen -ls        # list screens
screen -XS miner quit  # kill screen
```

---

### Wallet Balance Check

Run from a miner directory like `cd ~/nockchain/miner1`:

```bash
nockchain-wallet --nockchain-socket .socket/nockchain_npc.sock list-notes
```

Sample output:

```
- name: [first='xxxxx' last='xxxxx']
- assets: 2.576.980.378
- source: [p=[BLAH] is-coinbase=%.y]
```
