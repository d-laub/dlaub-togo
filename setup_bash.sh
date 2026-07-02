#!/usr/bin/env bash

set -euo pipefail

# install oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended

export PATH="${HOME}/.local/bin:${PATH}"

# install global tools
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="${HOME}/.pixi/bin:${PATH}"
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find exa prek git gh less zellij dvc rclone awscli uv wandb dust nodejs commitizen ruff
pixi g a -e dvc dvc-s3

# fresh TUI editor
curl https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh

# rust (-y so it works in non-TTY contexts like docker build)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
export PATH="${HOME}/.cargo/bin:${PATH}"
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
# cargo-update is best-effort: binstall hits GH rate limits on cold CI runs,
# and the source-build fallback needs openssl-sys system deps. Retry on a live shell.
cargo binstall -y cargo-update || echo "WARN: cargo-update install skipped (binstall fetch failed)"

# git
git config --global user.email "60826163+d-laub@users.noreply.github.com"
git config --global user.name "David Laub"
git config --global pull.rebase true

# LLM
## rtk
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
# LLM global instructions: idempotently sync global_claude.md into ~/.claude/CLAUDE.md
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
mkdir -p "${HOME}/.claude"
touch "${CLAUDE_MD}"
# strip any previously-synced block (inclusive of markers), then append the current one
awk '/<!-- BEGIN dlaub-togo:global_claude.md -->/{skip=1} !skip; /<!-- END dlaub-togo:global_claude.md -->/{skip=0}' "${CLAUDE_MD}" > "${CLAUDE_MD}.tmp"
cat global_claude.md >> "${CLAUDE_MD}.tmp"
mv "${CLAUDE_MD}.tmp" "${CLAUDE_MD}"
rtk init --global

## official
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install superpowers@claude-plugins-official

## custom statusline + default UI/permission settings (auto mode, fullscreen)
mkdir -p "${HOME}/.claude"
cp statusline-command.sh "${HOME}/.claude/statusline-command.sh"
chmod +x "${HOME}/.claude/statusline-command.sh"
python3 -c "import json, pathlib; p = pathlib.Path.home() / '.claude' / 'settings.json'; s = json.loads(p.read_text()) if p.exists() else {}; s['statusLine'] = {'type': 'command', 'command': 'bash ' + str(pathlib.Path.home() / '.claude' / 'statusline-command.sh')}; s['tui'] = 'fullscreen'; s.setdefault('permissions', {})['defaultMode'] = 'auto'; p.write_text(json.dumps(s, indent=2))"

## tilth
cargo binstall -y tilth
tilth install claude-code --edit

## marimo
npx -y skills add marimo-team/marimo-pair --agent claude-code --global -y
npx -y skills add marimo-team/skills --skill marimo-notebook --agent claude-code --global -y

## runpod
npx -y skills add runpod/skills --agent claude-code --global -y

## custom libs
npx -y skills add ML4GLand/SeqPro --skill seqpro --agent claude-code --global -y
npx -y skills add d-laub/genoray --agent claude-code --global -y
npx -y skills add mcvickerlab/GenVarLoader --agent claude-code --global -y
npx -y skills add d-laub/xolars --agent claude-code --global -y
npx -y skills add d-laub/dlaub-togo --agent claude-code --global -y -s '*'

# download and add aliases
cat aliases.sh >> "${HOME}/.bash_aliases"

# set theme
mkdir -p "${HOME}/.oh-my-bash/themes"
cp -r agnoster-multiline "${HOME}/.oh-my-bash/themes/"
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' "${HOME}/.bashrc"

# update ~/.bashrc
printf '%s\n' 'export PATH="${HOME}/.local/bin:${HOME}/.pixi/bin:${HOME}/.cargo/bin:${PATH}"' >> "${HOME}/.bashrc"
printf '%s\n' 'eval "$(zoxide init bash)"' >> "${HOME}/.bashrc"
printf '%s\n' 'eval "$(dvc completion -s bash)"' >> "${HOME}/.bashrc"

# config zellij
mkdir -p "${HOME}/.config/zellij"
cp zellij_config.kdl "${HOME}/.config/zellij/config.kdl"

echo 'Finished setting up shell environment from dlaub-togo, reload with "source ~/.bashrc" for changes to take effect.'
