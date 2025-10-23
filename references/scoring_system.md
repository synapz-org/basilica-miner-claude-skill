# Basilica Scoring & Reward System

Detailed scoring formulas, uptime ramp-up mechanics, and reward distribution for Basilica miners.

## Scoring Formula

### Node-Level Scoring

Each GPU node receives a score based on two components:

```
Node Score = (50% × SSH Success Rate) + (50% × Binary Validation Result)
```

**SSH Success Rate**:
- Percentage of times node responds to SSH connection attempts
- Calculated over rolling window of recent attempts
- Measures network availability and reliability

**Binary Validation Result**:
- Boolean: pass (1.0) or fail (0.0)
- Validates GPU attestation, system requirements, Docker capability
- Executed during full validation (every 6 hours)
- Lightweight checks (every 10 min) don't affect this score

### Miner-Level Scoring

```
Miner Score = Average(all node scores)
```

Example with 3 nodes:
- Node 1: (100% SSH + 100% validation) / 2 = 100%
- Node 2: (95% SSH + 100% validation) / 2 = 97.5%
- Node 3: (90% SSH + 0% validation) / 2 = 45%
- **Miner Score**: (100% + 97.5% + 45%) / 3 = **80.83%**

## Uptime Ramp-Up System (14-Day Model)

### Mechanics

New nodes don't immediately earn full rewards. They must prove consistent uptime over 14 days.

```
Uptime Multiplier = min(days_online / 14, 1.0)
Effective GPU Count = actual_gpu_count × uptime_multiplier
```

**Timeline**:
- Day 0: 0% multiplier (0% of potential rewards)
- Day 7: 50% multiplier (50% of potential rewards)
- Day 14: 100% multiplier (full rewards)
- Day 14+: Maintains 100% as long as no failures

### Reset Conditions

**CRITICAL**: Any of these events reset the counter to Day 0:

1. **Validation Failure**
   - Binary validation returns error
   - GPU attestation fails
   - System requirements not met

2. **SSH Connection Failure**
   - Node unreachable via SSH
   - Timeout during connection attempt
   - Authentication failure

3. **Miner Downtime**
   - Miner service stops/crashes
   - Configuration reloaded (sometimes)
   - Network interruption

**Impact**: A single failure can cost 14 days of reward ramp-up. Uptime is critical.

### Example Scenarios

**Scenario 1: Stable Operation**
- Node added on Jan 1
- 100% uptime, all validations pass
- Jan 15: Reaches 100% multiplier
- Continues earning full rewards

**Scenario 2: Early Failure**
- Node added on Jan 1
- Jan 5: SSH connection fails (network issue)
- Counter resets to 0
- Jan 6: Back online, starts from 0% again
- Jan 20: Finally reaches 100%

**Scenario 3: Repeated Failures**
- Node added on Jan 1
- Jan 10: GPU validation fails
- Jan 12: Back online, counter reset
- Jan 18: SSH timeout
- Jan 20: Back online, counter reset again
- Never reaches 14-day mark = minimal rewards

## GPU Eligibility & Categorization

### Eligible GPUs (Earn Rewards)

| GPU Model | Compute Capability | VRAM | Reward Eligible |
|-----------|-------------------|------|----------------|
| H100 | 9.0 | 80GB | ✅ Yes |
| H200 | 9.0 | 141GB | ✅ Yes |
| B200 | 9.0 | 192GB | ✅ Yes |

### Ineligible GPUs (Validate Only, No Rewards)

| GPU Model | Compute Capability | VRAM | Reward Eligible |
|-----------|-------------------|------|----------------|
| A100 | 8.0 | 40GB/80GB | ❌ No |
| V100 | 7.0 | 16GB/32GB | ❌ No |
| RTX 4090 | 8.9 | 24GB | ❌ No |
| Older GPUs | <8.7 | Various | ❌ No |

**Why H100/H200/B200 only?**
- Validators prioritize high-end GPUs for production workloads
- Ensures consistent, high-performance compute
- Minimum compute capability: 8.7
- Minimum CUDA version: 12.8

**Can I still run an A100 node?**
- Yes, it will validate successfully
- Useful for testing setup
- Contributes to network health
- But won't earn rewards

## Weight Distribution

### Weight Calculation

Validators set weights every 360 blocks (~1 hour):

```
Weight = f(GPU_category, validation_success_rate, effective_GPU_count, miner_score)
```

Components:
1. **GPU Category**: H100/H200/B200 weighted higher
2. **Validation Success Rate**: Historical pass/fail rate
3. **Effective GPU Count**: Actual count × uptime multiplier
4. **Miner Score**: Average node scores

### Burn Mechanism

80%+ of validator rewards are sent to burn address:

```
Validator Reward = block_reward × validator_weight
Burn Amount = validator_reward × 0.8
Validator Keep = validator_reward × 0.2
```

This deflationary mechanism benefits all TAO holders.

### Weight Setting Frequency

- **Frequency**: Every 360 blocks
- **Block Time**: ~12 seconds
- **Weight Update Interval**: ~360 × 12s = ~1 hour

Weights adjust dynamically based on recent performance.

## Reward Optimization Strategies

### 1. Maximize Uptime (Most Critical)

**Goal**: Never reset the 14-day counter

Tactics:
- Use systemd with `Restart=always`
- Redundant network connections
- Monitor node health every 60 seconds
- Set up proactive alerts
- Plan maintenance carefully (testnet first)
- Quick issue resolution

**Impact**: 14-day delay per failure is devastating

### 2. Optimize SSH Success Rate

**Goal**: >95% SSH connection success

Tactics:
- Stable network connectivity
- Low-latency network to nodes
- SSH hardening (no password auth)
- Firewall properly configured
- Monitor ping times to nodes
- Use connection multiplexing

**Impact**: Direct 50% contribution to node score

### 3. Ensure Binary Validation Success

**Goal**: 100% validation pass rate

Tactics:
- Install CUDA ≥12.8
- NVIDIA Container Toolkit properly configured
- Test Docker GPU access regularly
- Maintain 1TB+ free storage
- Keep drivers updated
- Run validation tests manually

**Impact**: Other 50% contribution to node score

### 4. Scale Node Count

**Goal**: More nodes = more rewards

Tactics:
- Start with 1-2 nodes to prove setup
- Add nodes incrementally after stable
- Maintain >95% uptime across all nodes
- Each node multiplies earning potential

**Impact**: Linear reward scaling with node count

**Note**: ALL nodes must maintain uptime. One failing node lowers average.

### 5. Use High-Value GPUs

**Goal**: H100/H200/B200 for maximum weights

Tactics:
- Prioritize H200 (141GB VRAM) if available
- H100 is excellent baseline (80GB VRAM)
- Avoid A100 for earning (use for testing only)

**Impact**: Validator weight preference for top GPUs

## Target Metrics for Top Miners

| Metric | Target | Elite | Impact |
|--------|--------|-------|--------|
| SSH Success Rate | >95% | >98% | 50% of node score |
| Binary Validation | 100% | 100% | 50% of node score |
| Uptime Days | 14+ | 30+ | Reward multiplier |
| Validator Auth Rate | >90% | >95% | Discovery frequency |
| Response Time | <5s | <2s | Validator preference |
| Node Count | 2+ | 5+ | Total reward capacity |

## Monitoring Key Metrics

### Prometheus Metrics to Watch

```bash
# Node count (should match config)
curl http://localhost:9090/metrics | grep basilica_miner_node_count

# Validator connections (should be growing)
curl http://localhost:9090/metrics | grep basilica_miner_validator_connections_total

# SSH deployments (validator activity)
curl http://localhost:9090/metrics | grep basilica_miner_ssh_deployments_total

# Authentication success rate (should be >90%)
curl http://localhost:9090/metrics | grep basilica_miner_authentication_success_total
curl http://localhost:9090/metrics | grep basilica_miner_authentication_failures_total
```

### Log Patterns to Monitor

```bash
# Validator authentication (should see regularly)
sudo journalctl -u basilica-miner -f | grep "Successfully authenticated validator"

# SSH key deployment (validator accessing nodes)
sudo journalctl -u basilica-miner -f | grep "Deployed SSH key"

# Node connectivity issues (should be rare)
sudo journalctl -u basilica-miner -f | grep "Node connectivity lost"

# Validation failures (investigate immediately)
sudo journalctl -u basilica-miner -f | grep -E "validation.*failed"
```

### Metagraph Monitoring

```bash
# Check your weights
btcli subnet metagraph --netuid 39 | grep <YOUR_HOTKEY>

# Compare with top miners
btcli subnet metagraph --netuid 39 | sort -k4 -rn | head -20

# Track weight changes over time
btcli subnet metagraph --netuid 39 --save-to-file metagraph.json
```

## Common Scoring Issues

### Issue: Score is 0 despite miner running

**Likely Causes**:
- No eligible GPUs (A100 doesn't count)
- Validation failures
- SSH connectivity issues
- Not discovered by validators

**Diagnosis**:
```bash
# Check GPU models
ssh basilica@node "nvidia-smi --query-gpu=name --format=csv,noheader"

# Check validation logs
sudo journalctl -u basilica-miner | grep -E "validation|binary"

# Check SSH success
sudo journalctl -u basilica-miner | grep "Node connectivity"

# Verify validators are connecting
sudo journalctl -u basilica-miner | grep "authenticated validator"
```

### Issue: Score is low (< 50%)

**Likely Causes**:
- SSH success rate below target
- Some nodes offline
- Validation failures on some nodes

**Diagnosis**:
```bash
# Run health check
python scripts/check_miner_health.py --config /opt/basilica/config/miner.toml

# Check per-node status
sudo journalctl -u basilica-miner | grep "Node.*health"

# Test each node manually
for node in node1 node2; do
  ssh -i ~/.ssh/miner_node_key basilica@$node "nvidia-smi" || echo "Failed: $node"
done
```

### Issue: Uptime counter keeps resetting

**Likely Causes**:
- Validation failures
- Network interruptions
- Miner restarts

**Solutions**:
- Enable systemd auto-restart
- Improve network stability
- Monitor validation success
- Fix any failing nodes immediately
- Test changes on testnet first

## Reward Economics

### Expected Earnings

Rewards depend on:
- **Your Weight**: % of total validator weights directed to you
- **Emission Rate**: Fixed TAO emission per block for subnet
- **Competition**: Other miners' performance and GPU counts

**Formula** (simplified):
```
Your Rewards = (Your Weight / Total Weights) × Subnet Emission × (1 - Burn Rate)
```

**Note**: 80%+ burns to address, but your % of remaining 20% depends on weight.

### Optimizing ROI

1. **Maximize Uptime**: Reach and maintain 100% multiplier
2. **Scale Efficiently**: Add nodes only after proven stability
3. **Use Premium GPUs**: H200 > H100 > (A100 gets nothing)
4. **Minimize Downtime**: Each failure costs 14 days of ramp-up
5. **Monitor Actively**: Catch and fix issues within minutes

### Break-Even Analysis

Consider:
- GPU rental costs (if using Basilica or others)
- Network/power costs
- Setup time investment
- 14-day ramp-up period (zero rewards)
- Ongoing maintenance effort

**Recommendation**: Start small (1-2 nodes), prove profitability, then scale.
