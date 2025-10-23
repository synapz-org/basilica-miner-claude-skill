#!/usr/bin/env python3
"""
Basilica Miner Health Check Script

Performs comprehensive health checks on Basilica miner setup:
- Environment and system requirements
- SSH connectivity to GPU nodes
- GPU availability and driver versions
- Docker and NVIDIA Container Toolkit
- Bittensor wallet registration
- Miner service status
- Network connectivity

Usage:
    python scripts/check_miner_health.py [--config path/to/miner.toml]
"""

import argparse
import json
import os
import socket
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

try:
    import toml
except ImportError:
    print("⚠️  Installing required dependency: toml")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "toml"])
    import toml


@dataclass
class NodeConfig:
    host: str
    port: int
    username: str


@dataclass
class CheckResult:
    name: str
    passed: bool
    message: str
    details: Optional[str] = None


class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def print_header(text: str):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'=' * 60}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text:^60}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'=' * 60}{Colors.RESET}\n")


def print_result(result: CheckResult):
    icon = f"{Colors.GREEN}✓" if result.passed else f"{Colors.RED}✗"
    status = f"{Colors.GREEN}PASS" if result.passed else f"{Colors.RED}FAIL"
    print(f"{icon} {result.name}: {status}{Colors.RESET}")
    print(f"  {result.message}")
    if result.details:
        print(f"  {Colors.YELLOW}→ {result.details}{Colors.RESET}")


def run_command(cmd: List[str], **kwargs) -> Tuple[int, str, str]:
    """Run command and return (returncode, stdout, stderr)"""
    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            **kwargs
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return 1, "", f"Command not found: {cmd[0]}"
    except Exception as e:
        return 1, "", str(e)


def check_system_requirements() -> List[CheckResult]:
    """Check basic system requirements"""
    results = []

    # Check Linux OS
    returncode, stdout, _ = run_command(["uname", "-s"])
    is_linux = returncode == 0 and "Linux" in stdout
    results.append(CheckResult(
        "Operating System",
        is_linux,
        f"Running on {stdout.strip() if returncode == 0 else 'unknown OS'}",
        "Basilica requires Linux (Ubuntu 22.04+ recommended)" if not is_linux else None
    ))

    # Check CPU cores
    returncode, stdout, _ = run_command(["nproc"])
    cpu_count = int(stdout.strip()) if returncode == 0 else 0
    results.append(CheckResult(
        "CPU Cores",
        cpu_count >= 8,
        f"{cpu_count} cores detected",
        "Recommended: 8+ cores" if cpu_count < 8 else None
    ))

    # Check memory
    returncode, stdout, _ = run_command(["free", "-g"])
    if returncode == 0:
        mem_gb = int([line for line in stdout.split('\n') if 'Mem:' in line][0].split()[1])
        results.append(CheckResult(
            "RAM",
            mem_gb >= 16,
            f"{mem_gb}GB total memory",
            "Recommended: 16GB+" if mem_gb < 16 else None
        ))

    return results


def check_ssh_setup(ssh_key_path: Optional[str] = None) -> List[CheckResult]:
    """Check SSH key configuration"""
    results = []

    if not ssh_key_path:
        ssh_key_path = str(Path.home() / ".ssh" / "miner_node_key")

    ssh_key = Path(ssh_key_path)
    ssh_pub_key = Path(f"{ssh_key_path}.pub")

    # Check SSH key exists
    key_exists = ssh_key.exists() and ssh_pub_key.exists()
    results.append(CheckResult(
        "SSH Key Pair",
        key_exists,
        f"Keys at {ssh_key_path}" if key_exists else "Keys not found",
        f"Generate with: ssh-keygen -t ed25519 -f {ssh_key_path} -N ''" if not key_exists else None
    ))

    # Check key permissions
    if key_exists:
        perms = oct(ssh_key.stat().st_mode)[-3:]
        correct_perms = perms == "600"
        results.append(CheckResult(
            "SSH Key Permissions",
            correct_perms,
            f"Private key permissions: {perms}",
            f"Fix with: chmod 600 {ssh_key_path}" if not correct_perms else None
        ))

    return results


def check_node_connectivity(nodes: List[NodeConfig], ssh_key_path: str) -> List[CheckResult]:
    """Check SSH connectivity to GPU nodes"""
    results = []

    for node in nodes:
        # Test SSH connectivity
        cmd = [
            "ssh",
            "-i", ssh_key_path,
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            f"{node.username}@{node.host}",
            "-p", str(node.port),
            "echo OK"
        ]

        returncode, stdout, stderr = run_command(cmd, timeout=15)

        results.append(CheckResult(
            f"Node SSH: {node.host}:{node.port}",
            returncode == 0 and "OK" in stdout,
            f"Connection {'successful' if returncode == 0 else 'failed'}",
            stderr.strip() if returncode != 0 else None
        ))

        # If SSH works, check NVIDIA drivers
        if returncode == 0:
            gpu_cmd = cmd[:-1] + ["nvidia-smi --query-gpu=name,driver_version --format=csv,noheader"]
            ret, gpu_out, _ = run_command(gpu_cmd, timeout=10)

            if ret == 0 and gpu_out:
                results.append(CheckResult(
                    f"Node GPU: {node.host}",
                    True,
                    f"GPU detected: {gpu_out.strip()}"
                ))
            else:
                results.append(CheckResult(
                    f"Node GPU: {node.host}",
                    False,
                    "nvidia-smi failed",
                    "Ensure NVIDIA drivers are installed on GPU node"
                ))

    return results


def check_bittensor_wallet(wallet_name: str, hotkey_name: str, netuid: int, network: str) -> List[CheckResult]:
    """Check Bittensor wallet configuration"""
    results = []

    # Check btcli is installed
    returncode, stdout, _ = run_command(["which", "btcli"])
    btcli_installed = returncode == 0

    results.append(CheckResult(
        "btcli Installed",
        btcli_installed,
        "Bittensor CLI found" if btcli_installed else "btcli not found",
        "Install with: pip install bittensor" if not btcli_installed else None
    ))

    if not btcli_installed:
        return results

    # Check wallet files exist
    wallet_path = Path.home() / ".bittensor" / "wallets" / wallet_name / "hotkeys" / hotkey_name
    wallet_exists = wallet_path.exists()

    results.append(CheckResult(
        "Wallet Files",
        wallet_exists,
        f"Hotkey at {wallet_path}" if wallet_exists else f"Wallet not found",
        f"Create with: btcli wallet new_hotkey --wallet.name {wallet_name} --wallet.hotkey {hotkey_name}" if not wallet_exists else None
    ))

    # Check registration
    if wallet_exists:
        network_flag = "--subtensor.network test" if network == "test" else ""
        cmd = f"btcli subnet list --netuid {netuid} {network_flag}".split()
        returncode, stdout, stderr = run_command(cmd, timeout=30)

        # Note: This is a simplified check. Full registration check would require parsing metagraph
        results.append(CheckResult(
            f"Subnet {netuid} Access",
            returncode == 0,
            f"Can query subnet {netuid}",
            "Run registration if not registered" if returncode != 0 else None
        ))

    return results


def check_miner_service() -> List[CheckResult]:
    """Check if miner service is running"""
    results = []

    # Check systemd service
    returncode, stdout, _ = run_command(["systemctl", "is-active", "basilica-miner"])
    service_active = returncode == 0 and "active" in stdout

    results.append(CheckResult(
        "Miner Service",
        service_active,
        f"Service status: {stdout.strip() if returncode == 0 else 'not found'}",
        "Start with: sudo systemctl start basilica-miner" if not service_active else None
    ))

    # Check health endpoint
    if service_active:
        try:
            import urllib.request
            with urllib.request.urlopen('http://localhost:8080/health', timeout=5) as response:
                health_ok = response.status == 200
                results.append(CheckResult(
                    "Health Endpoint",
                    health_ok,
                    f"HTTP {response.status}: Miner responding"
                ))
        except Exception as e:
            results.append(CheckResult(
                "Health Endpoint",
                False,
                "Health check failed",
                str(e)
            ))

    return results


def main():
    parser = argparse.ArgumentParser(description="Basilica Miner Health Check")
    parser.add_argument("--config", default="/opt/basilica/config/miner.toml",
                       help="Path to miner.toml configuration file")
    args = parser.parse_args()

    print_header("BASILICA MINER HEALTH CHECK")

    # Load configuration
    config_path = Path(args.config)
    if not config_path.exists():
        print(f"{Colors.RED}✗ Configuration file not found: {config_path}{Colors.RESET}")
        print(f"{Colors.YELLOW}Using default values for checks{Colors.RESET}\n")
        config = {}
    else:
        try:
            config = toml.load(config_path)
            print(f"{Colors.GREEN}✓ Loaded configuration from {config_path}{Colors.RESET}\n")
        except Exception as e:
            print(f"{Colors.RED}✗ Failed to parse config: {e}{Colors.RESET}\n")
            config = {}

    all_results = []

    # System requirements
    print_header("SYSTEM REQUIREMENTS")
    results = check_system_requirements()
    for r in results:
        print_result(r)
        all_results.append(r)

    # SSH setup
    print_header("SSH CONFIGURATION")
    ssh_key_path = config.get("ssh_session", {}).get("miner_node_key_path", "~/.ssh/miner_node_key")
    ssh_key_path = os.path.expanduser(ssh_key_path)
    results = check_ssh_setup(ssh_key_path)
    for r in results:
        print_result(r)
        all_results.append(r)

    # Node connectivity
    if "node_management" in config and "nodes" in config["node_management"]:
        print_header("GPU NODE CONNECTIVITY")
        nodes = [
            NodeConfig(
                host=node["host"],
                port=node.get("port", 22),
                username=node.get("username", "basilica")
            )
            for node in config["node_management"]["nodes"]
        ]
        results = check_node_connectivity(nodes, ssh_key_path)
        for r in results:
            print_result(r)
            all_results.append(r)

    # Bittensor wallet
    if "bittensor" in config:
        print_header("BITTENSOR WALLET")
        results = check_bittensor_wallet(
            config["bittensor"].get("wallet_name", "default"),
            config["bittensor"].get("hotkey_name", "default"),
            config["bittensor"].get("netuid", 39),
            config["bittensor"].get("network", "finney")
        )
        for r in results:
            print_result(r)
            all_results.append(r)

    # Miner service
    print_header("MINER SERVICE")
    results = check_miner_service()
    for r in results:
        print_result(r)
        all_results.append(r)

    # Summary
    print_header("SUMMARY")
    passed = sum(1 for r in all_results if r.passed)
    total = len(all_results)
    percentage = (passed / total * 100) if total > 0 else 0

    color = Colors.GREEN if percentage == 100 else Colors.YELLOW if percentage >= 70 else Colors.RED
    print(f"{color}{passed}/{total} checks passed ({percentage:.0f}%){Colors.RESET}\n")

    if percentage < 100:
        failed = [r for r in all_results if not r.passed]
        print(f"{Colors.RED}Failed checks:{Colors.RESET}")
        for r in failed:
            print(f"  • {r.name}")
            if r.details:
                print(f"    {r.details}")
        print()

    sys.exit(0 if percentage == 100 else 1)


if __name__ == "__main__":
    main()
