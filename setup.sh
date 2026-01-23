#!/bin/sh

[ -e ~/.xmonad ] || ln -s ~/ghq/github.com/boxp/dotfiles/.xmonad ~/.xmonad
[ -e ~/.Xmodmap ] || ln -s ~/ghq/github.com/boxp/dotfiles/.Xmodmap ~/.Xmodmap
[ -e ~/.Xresources ] || ln -s ~/ghq/github.com/boxp/dotfiles/.Xresources ~/.Xresources
[ -e ~/.dein.toml ] || ln -s ~/ghq/github.com/boxp/dotfiles/.dein.toml ~/.dein.toml
[ -e ~/.dein_lazy.toml ] || ln -s ~/ghq/github.com/boxp/dotfiles/.dein_lazy.toml ~/.dein_lazy.toml
[ -e ~/.vimrc ] || ln -s ~/ghq/github.com/boxp/dotfiles/.vimrc ~/.vimrc
[ -e ~/.xmobarrc ] || ln -s ~/ghq/github.com/boxp/dotfiles/.xmobarrc ~/.xmobarrc
[ -e ~/.xsession ] || ln -s ~/ghq/github.com/boxp/dotfiles/.xsession ~/.xsession
[ -e ~/.zprofile ] || ln -s ~/ghq/github.com/boxp/dotfiles/.zprofile ~/.zprofile
[ -e ~/.zshrc ] || ln -s ~/ghq/github.com/boxp/dotfiles/.zshrc ~/.zshrc
[ -e ~/.tmux.conf ] || ln -s ~/ghq/github.com/boxp/dotfiles/.tmux.conf ~/.tmux.conf
[ -e ~/.mysnippets ] || ln -s ~/ghq/github.com/boxp/dotfiles/.mysnippets ~/.mysnippets
[ -e ~/.spacemacs ] || ln -s ~/ghq/github.com/boxp/dotfiles/.spacemacs ~/.spacemacs
[ -e ~/.aerospace.toml ] || ln -s ~/ghq/github.com/boxp/dotfiles/.aerospace.toml ~/.aerospace.toml
mkdir -p ~/.config
[ -e ~/.config/ghostty ] || ln -s ~/ghq/github.com/boxp/dotfiles/.config/ghostty ~/.config/ghostty
[ -e ~/.config/gwq ] || ln -s ~/ghq/github.com/boxp/dotfiles/.config/gwq ~/.config/gwq
mkdir -p ~/.claude
[ -e ~/.claude/CLAUDE.md ] || ln -s ~/ghq/github.com/boxp/dotfiles/.claude/CLAUDE.md ~/.claude/CLAUDE.md
[ -e ~/.claude/skills ] || ln -s ~/ghq/github.com/boxp/dotfiles/.claude/skills ~/.claude/skills
