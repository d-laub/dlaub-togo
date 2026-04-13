#!/usr/bin/env bash

set -euo pipefail

# install oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended

# all ~/.bashrc edits must be after oh-my-bash install

# install global tools
curl -fsSL https://pixi.sh/install.sh | sh
export PATH="${HOME}/.pixi/bin:${PATH}"
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find exa prek git gh less zellij dvc rclone awscli uv
pixi g a -e dvc dvc-s3

curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk init --global

# download and add aliases
cat aliases.sh >> "${HOME}/.bash_aliases"

# set theme
mkdir -p "${HOME}/.oh-my-bash/themes"
cp -r agnoster-multiline "${HOME}/.oh-my-bash/themes/"
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' "${HOME}/.bashrc"

# update ~/.bashrc
printf '%s\n' 'eval "$(zoxide init bash)"' >> "${HOME}/.bashrc"
printf '%s\n' 'eval "$(dvc completion -s bash)"' >> "${HOME}/.bashrc"

# config zellij
mkdir -p "${HOME}/.config/zellij"
cp zellij_config.kdl "${HOME}/.config/zellij/config.kdl"

echo 'Finished setting up shell environment from dlaub-togo, reload with "source ~/.bashrc" for changes to take effect.'
