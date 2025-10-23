# Basilica Miner Troubleshooting Guide

Comprehensive issue diagnosis and solutions for common Basilica miner problems.

## Category 1: Startup Issues

### Database Connection Failed

**Error**: `Error: unable to open database file`

**Root Causes**:
- Database directory doesn't exist
- Incorrect permissions
- Invalid database path in config

**Solutions**:
```bash
# Create database directory
sudo mkdir -p /opt/basilica/data
sudo chown $USER:$USER /opt/basilica/data

# Verify config path
grep "url = " /opt/basilica/config/miner.toml
# Should be: url = "sqlite:///opt/basilica/data/miner.db"

# Test write access
touch /opt/basilica/data/test.db && rm /opt/basilica/data/test.db
```

###Wallet Loading Failed

**Error**: `Error: Failed to load hotkey: Invalid format`

**Root Causes**:
- Wallet files missing
- Incorrect wallet name/hotkey in config
- Corrupted wallet file
- Wallet not registered to subnet

**Solutions**:
```bash
# Verify wallet files exist
ls ~/.bittensor/wallets/${WALLET_NAME}/hotkeys/${HOTKEY_NAME}

# Check config matches wallet
grep "wallet_name\|hotkey_name" /opt/basilica/config/miner.toml

# Verify wallet format
cat ~/.bittensor/wallets/${WALLET_NAME}/hotkeys/${HOTKEY_NAME} | head -3
# Should show JSON with secretPhrase

# Check registration
btcli wallet overview --wallet.name ${WALLET_NAME} --wallet.hotkey ${HOTKEY_NAME} --netuid 39

# Register if missing
btcli subnet register --netuid 39 --wallet.name ${WALLET_NAME} --wallet.hotkey ${HOTKEY_NAME}
```

### Port Already in Use

**Error**: `Error: Address already in use (os error 98)`

**Root Causes**:
- Another service using port 8080
- Previous miner instance still running
- Port conflict with other application

**Solutions**:
```bash
# Find what's using the port
sudo lsof -i :8080
sudo netstat -tulpn | grep 8080

# Kill conflicting process
sudo kill -9 <PID>

# Or change port in miner.toml
vim /opt/basilica/config/miner.toml
# [validator_comms]
# port = 8081

# Restart miner
sudo systemctl restart basilica-miner
```

## Category 2: SSH Connection Problems

### Permission Denied (publickey)

**Error**: `Error: Failed to connect to node: Permission denied (publickey)`

**Root Causes**:
- Miner's public key not deployed to node
- Wrong key path in config
- Incorrect key permissions
- Wrong username
- SSH key not in authorized_keys

**Solutions**:
```bash
# 1. Verify miner's public key is on node
ssh basilica@node_ip "cat ~/.ssh/authorized_keys | grep miner_node_key"

# 2. Deploy if missing
ssh-copy-id -i ~/.ssh/miner_node_key.pub basilica@node_ip

# Or manual deployment
cat ~/.ssh/miner_node_key.pub | ssh basilica@node_ip "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# 3. Check key permissions on miner server
ls -la ~/.ssh/miner_node_key
# Should be: -rw------- (600)

# Fix permissions
chmod 600 ~/.ssh/miner_node_key
chmod 644 ~/.ssh/miner_node_key.pub

# 4. Verify key path in config
grep "miner_node_key_path" /opt/basilica/config/miner.toml

# 5. Test with verbose output
ssh -i ~/.ssh/miner_node_key -v basilica@node_ip
# Look for "Offering public key" and "Authentication succeeded"

# 6. Check username matches config
grep -A 3 "nodes = " /opt/basilica/config/miner.toml
```

### Connection Timed Out

**Error**: `Error: Connection to 192.168.1.100:22 timed out`

**Root Causes**:
- Network connectivity issue
- Firewall blocking SSH
- SSH server not running on node
- Wrong IP address or port

**Solutions**:
```bash
# 1. Test network connectivity
ping -c 3 node_ip

# 2. Check SSH port is open
nc -zv node_ip 22
telnet node_ip 22

# 3. Verify SSH is running on node
ssh user@node_ip "sudo systemctl status sshd"

# 4. Check firewall allows SSH from miner
ssh user@node_ip "sudo ufw status | grep 22"

# Add rule if needed
ssh user@node_ip "sudo ufw allow from <MINER_IP> to any port 22"

# 5. Verify IP and port in config
grep -A 5 "nodes = " /opt/basilica/config/miner.toml

# 6. Test from miner server
ssh -i ~/.ssh/miner_node_key -o ConnectTimeout=10 basilica@node_ip "echo OK"
```

### Host Key Verification Failed

**Error**: `Host identification has changed`

**Root Causes**:
- Node was reinstalled
- Node's host key changed
- MITM attack (rare)

**Solutions**:
```bash
# Remove old host key
ssh-keygen -R node_ip

# Accept new key
ssh -i ~/.ssh/miner_node_key basilica@node_ip "echo OK"
# Answer 'yes' to host key prompt

# Or configure to skip verification (less secure, testing only)
# Add to ~/.ssh/config:
# Host gpu-*
#     StrictHostKeyChecking no
#     UserKnownHostsFile /dev/null
```

## Category 3: Validator Discovery Issues

### No Validators Discovered

**Error**: `WARN: No validators found matching criteria`

**Root Causes**:
- Stake threshold too high
- No validators on subnet
- Network connectivity to chain
- Wrong network configured

**Solutions**:
```bash
# 1. Check validator assignment config
grep -A 5 "validator_assignment" /opt/basilica/config/miner.toml

# 2. Lower stake threshold
vim /opt/basilica/config/miner.toml
# [validator_assignment]
# min_stake_threshold = 1000.0  # Lower for testing

# 3. Or disable for testing
# [validator_assignment]
# enabled = false

# 4. Verify validators exist on subnet
btcli subnet list --netuid 39 | grep validator_permit | grep true

# 5. Check network connectivity
ping -c 3 entrypoint-finney.opentensor.ai

# 6. Verify correct network in config
grep "network\|netuid" /opt/basilica/config/miner.toml
# Should be: network = "finney", netuid = 39 (mainnet)
# Or: network = "test", netuid = 387 (testnet)

# 7. Restart miner
sudo systemctl restart basilica-miner

# 8. Watch for validator discovery
sudo journalctl -u basilica-miner -f | grep validator
```

### Validator Authentication Failed

**Error**: `ERROR: Validator authentication failed: Invalid signature`

**Root Causes**:
- System clock not synchronized (most common)
- Signature verification too strict
- Network time drift
- Invalid validator hotkey

**Solutions**:
```bash
# 1. Check system clock (CRITICAL!)
timedatectl
# Should show: "System clock synchronized: yes"

# 2. Sync time if needed
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd
sudo systemctl status systemd-timesyncd

# 3. Force time sync
sudo ntpdate -s time.nist.gov

# 4. Verify timezone
timedatectl list-timezones | grep UTC
sudo timedatectl set-timezone UTC

# 5. Check security config
grep "verify_signatures" /opt/basilica/config/miner.toml
# Should be: verify_signatures = true (production)

# 6. For testing ONLY, disable verification
# verify_signatures = false
# (Re-enable for production!)

# 7. Restart miner after time sync
sudo systemctl restart basilica-miner

# 8. Monitor auth attempts
sudo journalctl -u basilica-miner -f | grep "authentication"
```

## Category 4: Node Registration Issues

### No Nodes Registered

**Error**: `WARN: No nodes registered - miner will not serve validators`

**Root Causes**:
- SSH access to nodes failed
- No nodes configured in miner.toml
- Node manager initialization failed

**Solutions**:
```bash
# 1. Check nodes configured
grep -A 10 "node_management" /opt/basilica/config/miner.toml

# 2. Verify SSH access to each node
for node in node1 node2; do
  ssh -i ~/.ssh/miner_node_key basilica@$node "echo OK"
done

# 3. Run health check
python scripts/check_miner_health.py --config /opt/basilica/config/miner.toml

# 4. Check miner logs for registration errors
sudo journalctl -u basilica-miner | grep -i "node\|register\|ERROR"

# 5. Test manual SSH
ssh -i ~/.ssh/miner_node_key -v basilica@node_ip "nvidia-smi"

# 6. Restart miner after fixing SSH
sudo systemctl restart basilica-miner
```

### Node Health Check Failed

**Error**: `Node health check failed: Connection refused`

**Root Causes**:
- Node offline or unreachable
- SSH service stopped
- Network issues
- Firewall changes

**Solutions**:
```bash
# 1. Ping node
ping -c 3 node_ip

# 2. Check SSH access
nc -zv node_ip 22

# 3. Verify node is running
# (access via console/IPMI if SSH down)

# 4. Check health check settings
grep -A 5 "health_check" /opt/basilica/config/miner.toml
# Increase timeout if network is slow:
# health_check_timeout = 30

# 5. Monitor health checks
sudo journalctl -u basilica-miner -f | grep "health"
```

## Category 5: GPU Validation Issues

### CUDA Version Check Failed

**Error**: `CUDA version check failed: version 11.8 < required 12.8`

**Root Causes**:
- CUDA toolkit too old
- NVIDIA driver too old
- CUDA not installed

**Solutions**:
```bash
# 1. Check current CUDA version
ssh basilica@node "nvcc --version"

# 2. Check NVIDIA driver version
ssh basilica@node "nvidia-smi | grep 'Driver Version'"

# 3. Install CUDA 12.8+ (Ubuntu example)
ssh basilica@node << 'EOF'
wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_550.54.15_linux.run
sudo sh cuda_12.8.0_550.54.15_linux.run --silent --toolkit
EOF

# 4. Update environment
ssh basilica@node << 'EOF'
echo 'export PATH=/usr/local/cuda-12.8/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
EOF

# 5. Verify installation
ssh basilica@node "nvcc --version | grep 'release 12'"
```

### Docker GPU Access Denied

**Error**: `docker: Error response from daemon: could not select device driver "" with capabilities: [[gpu]]`

**Root Causes**:
- NVIDIA Container Toolkit not installed
- Docker not configured for GPU
- User not in docker group

**Solutions**:
```bash
# 1. Install NVIDIA Container Toolkit
ssh basilica@node << 'EOF'
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
EOF

# 2. Configure Docker
ssh basilica@node "sudo nvidia-ctk runtime configure --runtime=docker"

# 3. Restart Docker
ssh basilica@node "sudo systemctl restart docker"

# 4. Add user to docker group
ssh basilica@node "sudo usermod -aG docker basilica"

# 5. Test Docker GPU access
ssh basilica@node "docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi"
```

### Compute Capability Too Low

**Error**: `GPU compute capability 6.1 < required 8.7`

**Root Causes**:
- GPU too old (not H100/H200/B200)
- Wrong GPU in node
- GPU not eligible for rewards

**Solutions**:
```bash
# 1. Check GPU model and compute capability
ssh basilica@node "nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader"

# 2. Eligible GPUs:
# - H100 (compute capability 9.0) ✓
# - H200 (compute capability 9.0) ✓
# - B200 (compute capability 9.0) ✓
# - A100 (compute capability 8.0) - validates but NO REWARDS
# - Older GPUs - not eligible

# 3. If GPU ineligible, replace with H100/H200/B200
# Or accept no rewards (still validates for testing)
```

## Category 6: Rewards & Scoring Issues

### Low or Zero Rewards

**Symptoms**:
- Miner running but no rewards
- Low weights in metagraph
- Uptime counter keeps resetting

**Root Causes**:
- GPU not eligible (must be H100/H200/B200)
- Validation failures resetting 14-day counter
- Low SSH success rate
- Not attracting validators

**Solutions**:
```bash
# 1. Check GPU eligibility
ssh basilica@node "nvidia-smi --query-gpu=name --format=csv,noheader"
# Must be H100, H200, or B200 for rewards

# 2. Monitor validation success rate
curl http://localhost:9090/metrics | grep authentication_success
# Should be >90%

# 3. Check uptime (14-day ramp-up, resets on failure)
# Any validation failure resets counter - minimize downtime

# 4. Verify validators discovering you
sudo journalctl -u basilica-miner -f | grep "authenticated validator"
# Should see regular authentications

# 5. Check SSH success rate
sudo journalctl -u basilica-miner | grep "Node connectivity lost"
# Should be rare (<5% of checks)

# 6. Compare with other miners
btcli subnet metagraph --netuid 39
# Look at weights distribution

# 7. Ensure proper validator assignment
grep -A 5 "validator_assignment" /opt/basilica/config/miner.toml
# Use highest_stake with min 12000 TAO

# 8. Monitor Prometheus metrics
curl http://localhost:9090/metrics | grep basilica_miner
```

### Uptime Counter Resetting

**Symptoms**:
- Never reaching 14-day mark
- Rewards not increasing
- Frequent validation failures

**Root Causes**:
- Node downtime or restarts
- SSH connectivity issues
- GPU validation failures
- Network interruptions

**Solutions**:
```bash
# 1. Use systemd for auto-restart
sudo systemctl enable basilica-miner
# Restart=always in service file

# 2. Monitor node health continuously
grep -A 5 "health_check" /opt/basilica/config/miner.toml
# health_check_interval = 60  # Check every minute
# auto_recovery = true

# 3. Set up alerting
*/5 * * * * python /path/to/check_miner_health.py || mail -s "Alert" admin@example.com

# 4. Minimize planned downtime
# - Test on testnet first
# - Quick maintenance windows
# - Use rolling updates if multiple nodes

# 5. Monitor for failures
sudo journalctl -u basilica-miner | grep -E "ERROR|FAIL|lost"

# 6. Ensure stable network
# - Redundant network connections
# - Quality network provider
# - Monitor ping times to nodes
```

## Diagnostic Commands

### Quick Health Check
```bash
python scripts/check_miner_health.py --config /opt/basilica/config/miner.toml
```

### View Miner Logs
```bash
sudo journalctl -u basilica-miner -f
sudo journalctl -u basilica-miner -n 100 --no-pager
```

### Test SSH to All Nodes
```bash
for node in $(grep "host = " /opt/basilica/config/miner.toml | awk -F'"' '{print $2}'); do
  echo "Testing $node..."
  ssh -i ~/.ssh/miner_node_key basilica@$node "echo OK && nvidia-smi --query-gpu=name --format=csv,noheader"
done
```

### Check Metrics
```bash
curl http://localhost:8080/health
curl http://localhost:9090/metrics | grep basilica_miner
```

### Verify Configuration
```bash
./basilica-miner --config /opt/basilica/config/miner.toml config validate
./basilica-miner --config /opt/basilica/config/miner.toml config show
```

### Test Node SSH Manually
```bash
./basilica-miner --config /opt/basilica/config/miner.toml service test-ssh
```

## Prevention Best Practices

1. **Always run health check after changes**
   ```bash
   python scripts/check_miner_health.py --config miner.toml
   ```

2. **Use automated SSH setup script**
   ```bash
   ./scripts/setup_ssh_keys.sh --nodes "basilica@node1 basilica@node2"
   ```

3. **Enable NTP for time sync**
   ```bash
   sudo timedatectl set-ntp true
   ```

4. **Use systemd for auto-restart**
   - Handles crashes gracefully
   - Maintains uptime for 14-day ramp-up

5. **Monitor logs proactively**
   ```bash
   sudo journalctl -u basilica-miner -f | grep -E "(ERROR|WARN|authenticated)"
   ```

6. **Test on testnet first**
   - Subnet 387 (testnet)
   - Validate setup before mainnet

7. **Regular backups**
   ```bash
   cp /opt/basilica/config/miner.toml /opt/basilica/config/miner.toml.backup.$(date +%s)
   ```
