# Installation Instructions

## Method 1: Install from GitHub Release (Recommended)

1. Download the latest `basilica-miner.zip` from [Releases](https://github.com/synapz-org/basilica-miner-claude-skill/releases)

2. Install via Claude Code:
   ```
   /skills install basilica-miner.zip
   ```

## Method 2: Install from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/synapz-org/basilica-miner-claude-skill.git
   cd basilica-miner-claude-skill
   ```

2. Copy to Claude skills directory:
   ```bash
   mkdir -p ~/.claude/skills/
   cp -r . ~/.claude/skills/basilica-miner/
   ```

3. Restart Claude Code or reload skills

## Method 3: Direct Download

1. Download the packaged skill:
   ```bash
   curl -L -o basilica-miner.zip https://github.com/synapz-org/basilica-miner-claude-skill/raw/main/basilica-miner.zip
   ```

2. Install via Claude Code:
   ```
   /skills install basilica-miner.zip
   ```

## Verification

Once installed, test the skill by asking Claude:
- "Help me set up a Basilica miner"
- "How do I configure SSH for Basilica mining?"
- "Explain the Basilica scoring system"

The skill should activate automatically and provide expert guidance.

## Updating

To update to the latest version:

1. Download the new version
2. Remove the old skill: `/skills remove basilica-miner`
3. Install the new version: `/skills install basilica-miner.zip`

## Troubleshooting Installation

If the skill doesn't activate:

1. Check skill is installed:
   ```
   /skills list
   ```

2. Verify skill files are in:
   ```bash
   ls ~/.claude/skills/basilica-miner/
   ```

3. Check Claude Code logs for errors

4. Try reinstalling the skill
