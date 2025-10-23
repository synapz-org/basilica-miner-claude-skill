# Basilica Architecture Reference

Complete system architecture and component interaction for the Basilica decentralized GPU marketplace.

## System Components

### Validator
- **Discovery Engine**: Queries Bittensor metagraph every 10 minutes for miners
- **Verification Engine**: Two-tier validation (full every 6 hours, lightweight every 10 min)
- **Weight Setter**: Sets weights every 360 blocks (~1 hour) based on scoring

### Miner
- **gRPC Server**: Handles validator authentication and node discovery requests (port 8080)
- **Node Manager**: Manages GPU node fleet, health checks, SSH key deployment
- **SSH Session Manager**: Deploys/removes validator SSH keys, maintains miner's key access

### GPU Nodes
- Standard Linux servers with SSH, Docker, NVIDIA drivers
- Direct SSH access from validators for verification
- No agent software required

### Basilica API Gateway (Optional)
- HTTP load balancer across validators
- Not required for miner operations

## Direct SSH Access Model

### Why SSH-Based?
- No executor agent needed on GPU nodes
- Validators upload their own verification binaries
- Prevents miners from faking verification
- Standard SSH security applies
- Ephemeral keys auto-rotate

###Security Model
- Validator hotkey verification (Bittensor signature)
- Ephemeral SSH keys (time-limited, validator-specific)
- Miner controls key deployment duration
- All SSH operations audit-logged
- Target miner hotkey in auth request prevents MITM

## Communication Flow

```
1. Validator queries metagraph → discovers miner endpoint
2. Validator sends gRPC AuthenticateValidator(hotkey, signature, SSH pubkey)
3. Miner verifies signature, deploys SSH key to all nodes
4. Miner responds with node connection details
5. Validator SSH's directly to nodes
6. Validator executes GPU verification binary
7. Validator retrieves JSON results
8. Miner removes SSH key after expiry
```

## File Locations

### Configuration
- Main: `/opt/basilica/config/miner.toml`
- Database: `/opt/basilica/data/miner.db`
- Systemd: `/etc/systemd/system/basilica-miner.service`

### SSH Keys
- Miner key: `~/.ssh/miner_node_key` (private, 600 perms)
- Public key: `~/.ssh/miner_node_key.pub` (644 perms)
- On nodes: `~/.ssh/authorized_keys` (contains both miner and validator keys)

### Logs
- Systemd: `journalctl -u basilica-miner -f`
- Docker: `docker logs -f basilica-miner`

### Source Code Structure
- `crates/basilica-miner/src/main.rs`: Miner entry point and main loop
- `crates/basilica-miner/src/validator_comms.rs`: gRPC server, authentication
- `crates/basilica-miner/src/node_manager.rs`: Node health checks, SSH deployment
- `crates/basilica-miner/src/ssh.rs`: SSH session management
- `crates/basilica-miner/src/config.rs`: Configuration parsing
- `crates/basilica-common/`: Shared types and utilities
- `crates/basilica-validator/`: Validator implementation (for reference)

## Validator Assignment Modes

### Highest Stake (Production)
```toml
[validator_assignment]
enabled = true
strategy = "highest_stake"
min_stake_threshold = 12000.0
validator_hotkey = "5G3qVaXz..." # Optional
```

Selects validator with highest stake above threshold. Most secure.

### Open Access (Testing Only)
```toml
[validator_assignment]
enabled = false
```

Any validator can access nodes. Higher security risk.

## Metrics & Monitoring

### Prometheus Metrics (Port 9090)
- `basilica_miner_node_count`: Number of registered nodes
- `basilica_miner_validator_connections_total`: Total validator auth requests
- `basilica_miner_ssh_deployments_total`: SSH key deployments completed
- `basilica_miner_authentication_requests_total`: Auth requests processed
- `basilica_miner_authentication_success_total`: Successful authentications
- `basilica_miner_authentication_failures_total`: Failed authentications

### Health Endpoint (Port 8080)
```bash
curl http://localhost:8080/health
# Response: {"status":"healthy","timestamp":1704067200}
```

## Deployment Options

### Binary (Direct Execution)
```bash
./basilica-miner --config /opt/basilica/config/miner.toml
```

### Systemd Service
```bash
sudo systemctl start basilica-miner
sudo systemctl status basilica-miner
```

### Docker
```bash
docker run -d \
  --name basilica-miner \
  --restart unless-stopped \
  -v ~/.bittensor:/root/.bittensor:ro \
  -v /opt/basilica/config:/opt/basilica/config:ro \
  -v /opt/basilica/data:/opt/basilica/data \
  -v ~/.ssh:/root/.ssh:ro \
  -p 8080:8080 \
  -p 9090:9090 \
  basilica-miner:latest --config /opt/basilica/config/miner.toml
```

## Network Information

- **Mainnet**: Bittensor Finney, Subnet 39
- **Testnet**: Bittensor Test Network, Subnet 387
- **Chain Endpoint**: `wss://entrypoint-finney.opentensor.ai:443`
- **Discord**: https://discord.gg/4s7A5nQqAn
- **Website**: https://basilica.ai/
