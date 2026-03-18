#!/usr/bin/env bash

set -euo pipefail

# install pixi and oh-my-bash
curl -fsSL https://pixi.sh/install.sh | sh
curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | sh

# install global tools
pixi g i ripgrep bat glow-md sd zoxide rnr fd-find exa prek git gh

# download and add aliases
curl -fsSL https://raw.githubusercontent.com/d-laub/dlaub-togo/main/aliases.sh >> ~/.bash_aliases

# download custom theme for oh-my-bash
git clone --depth 1 --branch master https://github.com/d-laub/dlaub-togo.git /tmp/dlaub-togo-tmp
mkdir -p ~/.oh-my-bash/themes
cp -r /tmp/dlaub-togo-tmp/agnoster-multiline ~/.oh-my-bash/themes/
rm -rf /tmp/dlaub-togo-tmp

# set custom theme for oh-my-bash
sd '^OSH_THEME=.*$' 'OSH_THEME="agnoster-multiline"' ~/.bashrc
