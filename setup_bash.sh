#!/usr/bin/env bash

set -euo pipefail

# install pixi and oh-my-bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"

# download and add aliases
curl -fsSL https://raw.githubusercontent.com/d-laub/dlaub-togo/main/aliases.sh >> ~/.bash_aliases

# download custom theme for oh-my-bash
git clone --depth 1 --branch main https://github.com/d-laub/dlaub-togo.git /tmp/dlaub-togo-tmp
mkdir -p ~/.oh-my-bash/themes
cp -r /tmp/dlaub-togo-tmp/agnoster-multiline ~/.oh-my-bash/themes/
rm -rf /tmp/dlaub-togo-tmp

# install global tools
curl -fsSL https://pixi.sh/install.sh | sh
# ~/.bashrc usually returns immediately when sourced from a non-interactive
# script, so PATH updates appended by the pixi installer never run here.
export PATH="${HOME}/.pixi/bin:${PATH}"
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find exa prek git gh less zellij
echo 'eval "$(zoxide init bash)"' >> ~/.bashrc

# set custom theme for oh-my-bash
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' ~/.bashrc

echo 'Finished setting up shell environment from dlaub-togo, reload with "source ~/.bashrc" for changes to take effect.'
