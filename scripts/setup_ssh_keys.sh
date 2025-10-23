#!/usr/bin/env bash
#
# Basilica Miner SSH Setup Script
#
# This script helps set up SSH keys for Basilica miner operations:
# 1. Generates SSH key pair for miner-to-node communication
# 2. Deploys public key to all GPU nodes
# 3. Verifies SSH connectivity
# 4. Tests GPU access via nvidia-smi
#
# Usage:
#   ./scripts/setup_ssh_keys.sh [--key-path ~/.ssh/miner_node_key] [--nodes "user@host1 user@host2"]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SSH_KEY_PATH="${HOME}/.ssh/miner_node_key"
GPU_NODES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --key-path)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --nodes)
            IFS=' ' read -ra GPU_NODES <<< "$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--key-path PATH] [--nodes 'user@host1 user@host2']"
            echo ""
            echo "Options:"
            echo "  --key-path PATH    Path for SSH key (default: ~/.ssh/miner_node_key)"
            echo "  --nodes NODES      Space-separated list of user@host entries"
            echo "  -h, --help         Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Basilica Miner SSH Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Step 1: Generate SSH key if it doesn't exist
echo -e "${YELLOW}Step 1: SSH Key Generation${NC}"
echo "Key path: ${SSH_KEY_PATH}"
echo ""

if [ -f "${SSH_KEY_PATH}" ]; then
    echo -e "${GREEN}✓ SSH key already exists${NC}"
    read -p "Do you want to regenerate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Backing up existing key..."
        mv "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.backup.$(date +%s)"
        mv "${SSH_KEY_PATH}.pub" "${SSH_KEY_PATH}.pub.backup.$(date +%s)"
    else
        echo "Using existing key"
    fi
fi

if [ ! -f "${SSH_KEY_PATH}" ]; then
    echo "Generating Ed25519 SSH key pair..."
    ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -C "basilica-miner-$(hostname)" -N ""

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ SSH key generated successfully${NC}"
    else
        echo -e "${RED}✗ Failed to generate SSH key${NC}"
        exit 1
    fi
fi

# Set correct permissions
chmod 600 "${SSH_KEY_PATH}"
chmod 644 "${SSH_KEY_PATH}.pub"

echo ""
echo "Public key fingerprint:"
ssh-keygen -lf "${SSH_KEY_PATH}.pub"
echo ""

# Step 2: Get GPU node list if not provided
if [ ${#GPU_NODES[@]} -eq 0 ]; then
    echo -e "${YELLOW}Step 2: GPU Node Configuration${NC}"
    echo "Enter GPU nodes (format: user@hostname or user@ip)"
    echo "Press Enter with empty line when done"
    echo ""

    while true; do
        read -p "GPU node ${#GPU_NODES[@]}: " node
        if [ -z "$node" ]; then
            break
        fi
        GPU_NODES+=("$node")
    done

    if [ ${#GPU_NODES[@]} -eq 0 ]; then
        echo -e "${RED}✗ No GPU nodes specified${NC}"
        exit 1
    fi
fi

echo ""
echo "Configured GPU nodes:"
for node in "${GPU_NODES[@]}"; do
    echo "  - ${node}"
done
echo ""

# Step 3: Deploy SSH keys to nodes
echo -e "${YELLOW}Step 3: Deploying SSH Keys${NC}"
echo ""

DEPLOYED_COUNT=0
FAILED_NODES=()

for node in "${GPU_NODES[@]}"; do
    echo "Deploying to ${node}..."

    # Try ssh-copy-id first (cleaner)
    if command -v ssh-copy-id &> /dev/null; then
        if ssh-copy-id -i "${SSH_KEY_PATH}.pub" "${node}" 2>/dev/null; then
            echo -e "${GREEN}✓ Key deployed to ${node}${NC}"
            ((DEPLOYED_COUNT++))
            continue
        fi
    fi

    # Fallback: manual deployment
    if ssh "${node}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" < "${SSH_KEY_PATH}.pub" 2>/dev/null; then
        echo -e "${GREEN}✓ Key deployed to ${node}${NC}"
        ((DEPLOYED_COUNT++))
    else
        echo -e "${RED}✗ Failed to deploy to ${node}${NC}"
        FAILED_NODES+=("$node")
    fi
done

echo ""
echo -e "${GREEN}Deployed to ${DEPLOYED_COUNT}/${#GPU_NODES[@]} nodes${NC}"

if [ ${#FAILED_NODES[@]} -gt 0 ]; then
    echo -e "${RED}Failed nodes:${NC}"
    for node in "${FAILED_NODES[@]}"; do
        echo "  - ${node}"
    done
    echo ""
fi

# Step 4: Verify SSH connectivity
echo -e "${YELLOW}Step 4: Verifying SSH Connectivity${NC}"
echo ""

VERIFIED_COUNT=0

for node in "${GPU_NODES[@]}"; do
    echo "Testing ${node}..."

    if ssh -i "${SSH_KEY_PATH}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${node}" "echo 'SSH OK'" &>/dev/null; then
        echo -e "${GREEN}✓ SSH connection successful${NC}"
        ((VERIFIED_COUNT++))
    else
        echo -e "${RED}✗ SSH connection failed${NC}"
    fi
done

echo ""
echo -e "${GREEN}Verified ${VERIFIED_COUNT}/${#GPU_NODES[@]} nodes${NC}"
echo ""

# Step 5: Test GPU access
echo -e "${YELLOW}Step 5: Testing GPU Access${NC}"
echo ""

GPU_VERIFIED_COUNT=0

for node in "${GPU_NODES[@]}"; do
    echo "Testing GPU on ${node}..."

    if ssh -i "${SSH_KEY_PATH}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${node}" "nvidia-smi --query-gpu=name,driver_version --format=csv,noheader" 2>/dev/null; then
        echo -e "${GREEN}✓ GPU accessible${NC}"
        ((GPU_VERIFIED_COUNT++))
    else
        echo -e "${RED}✗ GPU not accessible or nvidia-smi failed${NC}"
        echo "  Ensure NVIDIA drivers are installed on this node"
    fi
    echo ""
done

echo -e "${GREEN}GPU verified on ${GPU_VERIFIED_COUNT}/${#GPU_NODES[@]} nodes${NC}"
echo ""

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Setup Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "SSH Key: ${SSH_KEY_PATH}"
echo "Total Nodes: ${#GPU_NODES[@]}"
echo "  Deployed: ${DEPLOYED_COUNT}"
echo "  SSH Verified: ${VERIFIED_COUNT}"
echo "  GPU Verified: ${GPU_VERIFIED_COUNT}"
echo ""

if [ ${#FAILED_NODES[@]} -gt 0 ]; then
    echo -e "${RED}⚠ Some nodes failed. Review errors above.${NC}"
    echo ""
fi

echo "Next steps:"
echo "1. Update miner.toml with node configuration:"
echo ""
echo "[node_management]"
echo "nodes = ["
for node in "${GPU_NODES[@]}"; do
    username="${node%%@*}"
    host="${node##*@}"
    echo "  { host = \"${host}\", port = 22, username = \"${username}\" },"
done
echo "]"
echo ""
echo "2. Set SSH key path in miner.toml:"
echo ""
echo "[ssh_session]"
echo "miner_node_key_path = \"${SSH_KEY_PATH}\""
echo ""
echo "3. Run health check:"
echo "   python scripts/check_miner_health.py --config /path/to/miner.toml"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
