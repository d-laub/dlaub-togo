#!/usr/bin/env bash

set -euo pipefail

# install oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended

export PATH="${HOME}/.local/bin:${PATH}"

# install global tools
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="${HOME}/.pixi/bin:${PATH}"
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find exa prek git gh less zellij dvc rclone awscli uv wandb dust nodejs commitizen
pixi g a -e dvc dvc-s3

# git
git config --global user.email "60826163+d-laub@users.noreply.github.com"
git config --global user.name "David Laub"
git config --global pull.rebase true

# LLM
curl -fsSL https://claude.ai/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk init --global
claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install superpowers@claude-plugins-official
claude plugin install code-review@claude-plugins-official
claude plugin install feature-dev@claude-plugins-official

# download and add aliases
cat aliases.sh >> "${HOME}/.bash_aliases"

# set theme
mkdir -p "${HOME}/.oh-my-bash/themes"
cp -r agnoster-multiline "${HOME}/.oh-my-bash/themes/"
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' "${HOME}/.bashrc"

# update ~/.bashrc
printf '%s\n' 'export PATH="${HOME}/.local/bin:${PATH}"' >> "${HOME}/.bashrc"
printf '%s\n' 'eval "$(zoxide init bash)"' >> "${HOME}/.bashrc"
printf '%s\n' 'eval "$(dvc completion -s bash)"' >> "${HOME}/.bashrc"

# config zellij
mkdir -p "${HOME}/.config/zellij"
cp zellij_config.kdl "${HOME}/.config/zellij/config.kdl"

echo 'Finished setting up shell environment from dlaub-togo, reload with "source ~/.bashrc" for changes to take effect.'
