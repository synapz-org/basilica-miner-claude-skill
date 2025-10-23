# Basilica Miner Claude Skill

A Claude Code skill for expert-level setup, management, and troubleshooting of Basilica GPU miner operations on Bittensor Subnet 39 (mainnet) or 387 (testnet).

## Overview

This skill transforms Claude into a Basilica GPU mining expert, providing comprehensive guidance on:

- **Miner Setup & Configuration** - SSH keys, wallet setup, node configuration
- **Validator Interaction** - Authentication, SSH access, verification process
- **Performance Optimization** - Uptime management, scoring optimization, rewards maximization
- **Monitoring & Maintenance** - Health checks, metrics, proactive alerts
- **Troubleshooting** - SSH issues, validator discovery, GPU validation, scoring problems

**Key Focus**: The #1 issue miners face is SSH configuration for validator access to GPU nodes. This skill provides automated scripts and step-by-step guidance to resolve this and other common problems.

## Installation

### Install via Claude Code

1. Download `basilica-miner.zip` from releases
2. In Claude Code, use the command:
   ```
   /skills install basilica-miner.zip
   ```

### Manual Installation

1. Clone or download this skill
2. Copy to your Claude skills directory:
   ```bash
   cp -r basilica-miner ~/.claude/skills/
   ```

## Usage

Once installed, the skill automatically activates when you ask Claude about Basilica mining topics:

- "Help me set up a Basilica miner"
- "My validator authentication is failing, what's wrong?"
- "How do I fix SSH permission denied errors on my GPU nodes?"
- "Explain the Basilica scoring system"
- "Why am I getting zero rewards?"
- "How do I configure miner.toml for production?"

## Skill Contents

### SKILL.md
Main skill document with:
- 6-phase miner setup workflow
- SSH configuration (the #1 pain point)
- Validator interaction and authentication
- Scoring and rewards system
- Monitoring and maintenance
- Troubleshooting common issues
- Best practices

### scripts/

Executable utilities for miner operations:

- **check_miner_health.py** - Comprehensive health check
  - System requirements validation
  - SSH connectivity to all GPU nodes
  - GPU availability and driver versions
  - Bittensor wallet registration
  - Miner service status

- **setup_ssh_keys.sh** - Automated SSH setup
  - Generates miner SSH key pair
  - Deploys to all GPU nodes
  - Verifies connectivity and GPU access
  - Provides configuration snippets

- **generate_config.sh** - Interactive config generator
  - Guided prompts for all settings
  - Network, wallet, and node details
  - Creates production-ready miner.toml

### references/

Detailed reference documentation loaded as needed:

- **basilica_architecture.md** - Complete system architecture, component interaction, SSH access model
- **troubleshooting_guide.md** - Comprehensive issue diagnosis and solutions with code references
- **scoring_system.md** - Detailed scoring formulas, uptime ramp-up, reward distribution

## Key Features

### Comprehensive Coverage
- Complete Basilica codebase knowledge (miners, validators, scoring)
- All SSH configuration patterns and issues
- Hardware requirements and GPU eligibility
- Monitoring dashboards and critical metrics
- 14-day uptime ramp-up system

### Actionable Guidance
- Step-by-step setup workflows with scripts
- Troubleshooting guides with symptoms → solutions
- Performance benchmarks and target metrics
- Code references with exact file paths

### Progressive Disclosure
- Lean SKILL.md for quick reference
- Detailed references loaded only when needed
- Scripts for deterministic operations

## System Requirements

### Miner Server
- **OS**: Linux (Ubuntu 22.04+ recommended)
- **CPU**: 8+ cores
- **RAM**: 16GB+
- **Network**: Public IP or port forwarding, port 8080 (gRPC), port 9090 (Prometheus)
- **Bittensor**: Wallet registered to subnet 39 (mainnet) or 387 (testnet)

### GPU Nodes
- **GPU**: NVIDIA H100, H200, or B200 (for rewards)
  - A100, V100, RTX validate but earn NO REWARDS
- **CUDA**: ≥12.8
- **Driver**: Latest NVIDIA drivers
- **Docker**: Docker + NVIDIA Container Toolkit
- **User**: Dedicated user account (e.g., `basilica`)
- **Storage**: 1TB+ free disk space
- **SSH**: SSH server with key-based authentication

### Bittensor Requirements
- Registered wallet on subnet 39 (mainnet) or 387 (testnet)
- TAO tokens for registration fee
- Hotkey with sufficient stake (for validator assignment)

## Quick Start

1. **Prerequisites**: Ensure system requirements met

2. **Generate SSH Keys**:
   ```bash
   ./scripts/setup_ssh_keys.sh
   ```

3. **Generate Configuration**:
   ```bash
   ./scripts/generate_config.sh miner.toml
   ```

4. **Verify Setup**:
   ```bash
   python scripts/check_miner_health.py --config miner.toml
   ```

5. **Build and Deploy Miner**:
   ```bash
   git clone https://github.com/one-covenant/basilica
   cd basilica
   ./scripts/miner/build.sh --release
   sudo mkdir -p /opt/basilica/{config,data}
   sudo cp basilica-miner /opt/basilica/
   sudo cp miner.toml /opt/basilica/config/
   ```

6. **Start Miner**:
   ```bash
   sudo systemctl start basilica-miner
   sudo journalctl -u basilica-miner -f
   ```

## Common Issues Solved

### SSH Permission Denied
90% of miner issues are SSH-related. The skill provides:
- Automated SSH key deployment script
- Step-by-step manual setup
- Permission troubleshooting
- Verification commands

### Validator Authentication Failed
- System clock synchronization (most common cause)
- Signature verification configuration
- Network time drift resolution

### GPU Validation Failing
- CUDA version requirements
- NVIDIA Container Toolkit installation
- Docker GPU access configuration
- Compute capability verification

### Zero/Low Rewards
- GPU eligibility (H100/H200/B200 only)
- Uptime ramp-up system (14-day model)
- Scoring optimization strategies
- Validation success monitoring

## Resources

- **Basilica GitHub**: https://github.com/one-covenant/basilica
- **Miner Docs**: https://github.com/one-covenant/basilica/blob/main/docs/miner.md
- **Discord**: https://discord.gg/GyzhzRWJBQ
- **Basilica Website**: https://basilica.ai/
- **Covenant AI**: https://covenant.ai/ (Basilica's parent company)
- **Bittensor Docs**: https://docs.learnbittensor.org

## Key Innovations

### SSH-Based Direct Access
Basilica's unique architecture:
- Validators SSH **directly** to GPU nodes (no intermediary)
- Miners orchestrate access by managing ephemeral SSH keys
- Validators upload their own verification binaries
- Prevents spoofing while maintaining security

### 14-Day Uptime Ramp-Up
- New nodes start at 0% reward multiplier
- Linear increase to 100% over 14 days
- **Any validation failure resets counter to 0**
- Emphasizes reliability and uptime

### Two-Tier Validation
- **Full** (every 6 hours): Complete GPU attestation
- **Lightweight** (every 10 min): SSH connectivity test
- Balances thorough verification with efficiency

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

## License

This skill is provided as-is for educational and operational purposes. Please refer to the Basilica project's license for information about the underlying codebase.

## Acknowledgments

Built with deep analysis of the [Basilica](https://github.com/one-covenant/basilica) codebase and designed to help GPU providers successfully operate miners with high uptime, proper validation, and maximum rewards.
