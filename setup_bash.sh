#!/usr/bin/env bash

set -euo pipefail

# Idempotently sync a block of lines (read from stdin) into a file. The markers
# let a re-run replace the previous block instead of appending a second copy,
# which is what makes this script safe to re-run to refresh a stale image.
sync_block() {
  local file="$1" tag="$2"
  local begin="# BEGIN dlaub-togo:${tag}" end="# END dlaub-togo:${tag}"
  mkdir -p "$(dirname "${file}")"
  touch "${file}"
  awk -v b="${begin}" -v e="${end}" '$0==b{skip=1} !skip; $0==e{skip=0}' "${file}" > "${file}.tmp"
  # `awk 1` rather than `cat`: it terminates a final line that has no newline, which
  # would otherwise glue the END marker onto it and break the next run's strip.
  { printf '%s\n' "${begin}"; awk 1; printf '%s\n' "${end}"; } >> "${file}.tmp"
  mv "${file}.tmp" "${file}"
}

# install oh-my-bash (its installer returns 1 rather than no-op'ing when ~/.oh-my-bash
# already exists, which would abort the whole script under `set -e` on a re-run)
if [[ -d "${HOME}/.oh-my-bash" ]]; then
  echo "oh-my-bash already installed, skipping"
else
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended
fi

export PATH="${HOME}/.local/bin:${PATH}"

# install global tools
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="${HOME}/.pixi/bin:${PATH}"
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find eza prek git gh less zellij dvc rclone awscli uv wandb dust nodejs commitizen ruff actionlint shellcheck
pixi g a -e dvc dvc-s3
# bring already-present globals up to date when re-run against an existing install
pixi global update

# rust (-y so it works in non-TTY contexts like docker build)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
export PATH="${HOME}/.cargo/bin:${PATH}"
curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash
# cargo-update is best-effort: binstall hits GH rate limits on cold CI runs,
# and the source-build fallback needs openssl-sys system deps. Retry on a live shell.
cargo binstall -y cargo-update || echo "WARN: cargo-update install skipped (binstall fetch failed)"

# fresh TUI editor. Installed after rust so the installer's cargo fallback is available
# if the release tarball can't be fetched (GH rate-limits anonymous downloads), and
# -f so an HTTP error page is never piped into sh. No desktop entry/icons on a server.
curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh -s -- --no-desktop-integration

# git
git config --global user.email "60826163+d-laub@users.noreply.github.com"
git config --global user.name "David Laub"
git config --global pull.rebase true

# LLM
mkdir -p "${HOME}/.claude"
bash update_claude.sh
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install superpowers@claude-plugins-official
claude plugin marketplace add ayghri/i-have-adhd
claude plugin install i-have-adhd@i-have-adhd
touch "${HOME}/.claude/.i-have-adhd-always"

## custom statusline + default UI/permission settings (auto mode, fullscreen)
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

## gh
npx -y skills add github/gh-stack --agent claude-code --global -y

## custom libs
npx -y skills add ML4GLand/SeqPro --skill seqpro --agent claude-code --global -y
npx -y skills add d-laub/genoray --agent claude-code --global -y
npx -y skills add mcvickerlab/GenVarLoader --agent claude-code --global -y
npx -y skills add d-laub/xolars --agent claude-code --global -y
npx -y skills add d-laub/dlaub-togo --agent claude-code --global -y -s '*'

# download and add aliases
sync_block "${HOME}/.bash_aliases" aliases < aliases.sh

# set theme (copy the contents, not the directory: `cp -r dir dest/` nests a second
# copy inside the existing theme dir when re-run)
mkdir -p "${HOME}/.oh-my-bash/themes/agnoster-multiline"
cp agnoster-multiline/* "${HOME}/.oh-my-bash/themes/agnoster-multiline/"
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' "${HOME}/.bashrc"

# update ~/.bashrc
sync_block "${HOME}/.bashrc" bashrc <<'EOF'
export PATH="${HOME}/.local/bin:${HOME}/.pixi/bin:${HOME}/.cargo/bin:${PATH}"
eval "$(zoxide init bash)"
eval "$(dvc completion -s bash)"
EOF

# config zellij
mkdir -p "${HOME}/.config/zellij"
cp zellij_config.kdl "${HOME}/.config/zellij/config.kdl"

echo 'Finished setting up shell environment from dlaub-togo, reload with "source ~/.bashrc" for changes to take effect.'
