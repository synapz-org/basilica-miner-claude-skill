#!/usr/bin/env bash
#
# Basilica Miner Configuration Generator
#
# Generates a miner.toml configuration file with guided prompts
#
# Usage:
#   ./scripts/generate_config.sh [output_path]

set -e

OUTPUT_PATH="${1:-miner.toml}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Basilica Miner Configuration Generator${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ -f "${OUTPUT_PATH}" ]; then
    echo -e "${YELLOW}⚠ Configuration file already exists: ${OUTPUT_PATH}${NC}"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Bittensor configuration
echo -e "${YELLOW}Bittensor Configuration${NC}"
echo ""

read -p "Wallet name [default]: " WALLET_NAME
WALLET_NAME="${WALLET_NAME:-default}"

read -p "Hotkey name [default]: " HOTKEY_NAME
HOTKEY_NAME="${HOTKEY_NAME:-default}"

echo ""
echo "Select network:"
echo "  1) Mainnet (finney, subnet 39)"
echo "  2) Testnet (test, subnet 387)"
read -p "Choice [1]: " NETWORK_CHOICE
NETWORK_CHOICE="${NETWORK_CHOICE:-1}"

if [ "$NETWORK_CHOICE" = "2" ]; then
    NETWORK="test"
    NETUID=387
else
    NETWORK="finney"
    NETUID=39
fi

read -p "External IP address: " EXTERNAL_IP

read -p "Axon port [8080]: " AXON_PORT
AXON_PORT="${AXON_PORT:-8080}"

echo ""

# Node management
echo -e "${YELLOW}GPU Node Configuration${NC}"
echo "Enter GPU nodes (format: hostname or IP)"
echo "Press Enter with empty line when done"
echo ""

NODES=()
while true; do
    read -p "Node $((${#NODES[@]}+1)) hostname/IP (or Enter to finish): " NODE_HOST
    if [ -z "$NODE_HOST" ]; then
        break
    fi

    read -p "  SSH port [22]: " NODE_PORT
    NODE_PORT="${NODE_PORT:-22}"

    read -p "  SSH username [basilica]: " NODE_USER
    NODE_USER="${NODE_USER:-basilica}"

    NODES+=("$NODE_HOST|$NODE_PORT|$NODE_USER")
done

if [ ${#NODES[@]} -eq 0 ]; then
    echo -e "${RED}✗ No nodes configured${NC}"
    exit 1
fi

echo ""

# SSH configuration
echo -e "${YELLOW}SSH Configuration${NC}"
echo ""

read -p "Miner SSH key path [~/.ssh/miner_node_key]: " SSH_KEY_PATH
SSH_KEY_PATH="${SSH_KEY_PATH:-~/.ssh/miner_node_key}"

echo ""

# Validator assignment
echo -e "${YELLOW}Validator Assignment Strategy${NC}"
echo ""
echo "  1) Highest stake (recommended - single trusted validator)"
echo "  2) Open access (any validator - testing only)"
read -p "Choice [1]: " VALIDATOR_STRATEGY
VALIDATOR_STRATEGY="${VALIDATOR_STRATEGY:-1}"

if [ "$VALIDATOR_STRATEGY" = "1" ]; then
    VALIDATOR_ENABLED="true"
    VALIDATOR_ASSIGNMENT_STRATEGY="highest_stake"

    read -p "Minimum stake threshold (TAO) [12000]: " MIN_STAKE
    MIN_STAKE="${MIN_STAKE:-12000}"

    read -p "Preferred validator hotkey (optional): " VALIDATOR_HOTKEY
else
    VALIDATOR_ENABLED="false"
    VALIDATOR_ASSIGNMENT_STRATEGY="highest_stake"
    MIN_STAKE="0"
    VALIDATOR_HOTKEY=""
fi

echo ""

# Metrics
echo -e "${YELLOW}Monitoring Configuration${NC}"
echo ""

read -p "Enable Prometheus metrics? (Y/n): " ENABLE_METRICS
ENABLE_METRICS="${ENABLE_METRICS:-Y}"

if [[ $ENABLE_METRICS =~ ^[Yy]$ ]]; then
    METRICS_ENABLED="true"
    read -p "Prometheus port [9090]: " PROM_PORT
    PROM_PORT="${PROM_PORT:-9090}"
else
    METRICS_ENABLED="false"
    PROM_PORT="9090"
fi

echo ""

# Generate configuration
echo -e "${GREEN}Generating configuration...${NC}"
echo ""

cat > "${OUTPUT_PATH}" << EOF
# Basilica Miner Configuration
# Generated on $(date)

[bittensor]
wallet_name = "${WALLET_NAME}"
hotkey_name = "${HOTKEY_NAME}"
network = "${NETWORK}"
netuid = ${NETUID}
external_ip = "${EXTERNAL_IP}"
axon_port = ${AXON_PORT}
weight_interval_secs = 300

[database]
url = "sqlite:///opt/basilica/data/miner.db"
run_migrations = true

[validator_comms]
host = "0.0.0.0"
port = ${AXON_PORT}

[node_management]
nodes = [
EOF

for node_config in "${NODES[@]}"; do
    IFS='|' read -r host port user <<< "$node_config"
    echo "  { host = \"${host}\", port = ${port}, username = \"${user}\" }," >> "${OUTPUT_PATH}"
done

cat >> "${OUTPUT_PATH}" << EOF
]
health_check_interval = 60
health_check_timeout = 10
max_retry_attempts = 3
auto_recovery = true

[ssh_session]
miner_node_key_path = "${SSH_KEY_PATH}"
default_node_username = "basilica"

[security]
verify_signatures = true

[metrics]
enabled = ${METRICS_ENABLED}

[metrics.prometheus]
host = "127.0.0.1"
port = ${PROM_PORT}

[validator_assignment]
enabled = ${VALIDATOR_ENABLED}
strategy = "${VALIDATOR_ASSIGNMENT_STRATEGY}"
min_stake_threshold = ${MIN_STAKE}.0
EOF

if [ -n "$VALIDATOR_HOTKEY" ]; then
    echo "validator_hotkey = \"${VALIDATOR_HOTKEY}\"" >> "${OUTPUT_PATH}"
fi

echo ""
echo -e "${GREEN}✓ Configuration written to: ${OUTPUT_PATH}${NC}"
echo ""
echo "Summary:"
echo "  Network: ${NETWORK} (subnet ${NETUID})"
echo "  Wallet: ${WALLET_NAME}/${HOTKEY_NAME}"
echo "  Nodes: ${#NODES[@]}"
echo "  Metrics: ${METRICS_ENABLED}"
echo ""
echo "Next steps:"
echo "1. Review and adjust ${OUTPUT_PATH} if needed"
echo "2. Ensure SSH keys are set up:"
echo "   ./scripts/setup_ssh_keys.sh --key-path ${SSH_KEY_PATH}"
echo "3. Verify wallet is registered to subnet ${NETUID}:"
echo "   btcli wallet overview --wallet.name ${WALLET_NAME} --wallet.hotkey ${HOTKEY_NAME} --netuid ${NETUID}"
echo "4. Deploy miner binary to /opt/basilica/"
echo "5. Start miner:"
echo "   sudo systemctl start basilica-miner"
echo ""
