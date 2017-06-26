source ~/.zplug/init.zsh

# zplug
# Make sure to use double quotes
zplug "zsh-users/zsh-history-substring-search"

# Use the package as a command
# And accept glob patterns (e.g., brace, wildcard, ...)
zplug "Jxck/dotfiles", as:command, use:"bin/{histuniq,color}"

# Can manage everything e.g., other person's zshrc
zplug "tcnksm/docker-alias", use:zshrc

# Disable updates using the "frozen:" tag
zplug "k4rthik/git-cal", as:command, frozen:1

# Grab binaries from GitHub Releases
# and rename with the "rename-to:" tag
zplug "junegunn/fzf-bin", \
    from:gh-r, \
    as:command, \
    rename-to:fzf, \
    use:"*darwin*amd64*"

# Supports checking out a specific branch/tag/commit
zplug "b4b4r07/enhancd", at:v1
zplug "mollifier/anyframe", at:4c23cb60

# Set the priority when loading
# e.g., zsh-syntax-highlighting must be loaded
# after executing compinit command and sourcing other plugins
zplug "zsh-users/zsh-syntax-highlighting", nice:10

# Can manage local plugins
zplug "~/.zsh", from:local

# Install plugins if there are plugins that have not been installed
# if ! zplug check --verbose; then
#     printf "Install? [y/N]: "
#     if read -q; then
#         echo; zplug install
#     fi
# fi

# Then, source plugins and add commands to $PATH
zplug load --verbose

# aliases
alias :q="exit"
alias lock="xscreensaver-command --lock"
alias git="hub"
alias gc="git checkout"
alias gb="git branch"
alias gpr="git pull-request --browse -F $(git rev-parse --show-toplevel)/.github/PULL_REQUEST_TEMPLATE.md"
alias gs="git status"
alias gt="tig"
alias mux="tmuxinator"
alias vis="vim -S ~/.vim.session"

# prompt
parse_git_branch()
{
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ \1/'
}

setopt prompt_subst

# PROMPT1
PS1="%{[0m%}
%{[33m%}λ%{[0m%} %{[32m%}[%n@%m] %{[33m%}%~%{[0m%}
%(?|%{[36m%}ﾙｲ%) ﾟ ヮﾟﾉ%) <|%{[31m%}ﾙｲ%)；ﾟ -ﾟ ﾉ%) <)%{[35m%}\$(parse_git_branch) %{[0m%}"

# ghq
export GHQ_ROOT="$HOME/go/src"

# Default EDITOR
export EDITOR="vim"

# AUDIO DRIVER settings
export SDL_AUDIODRIVER='alsa'

# direnv
eval "$(direnv hook zsh)"

# GOPATH
export GOPATH="$HOME/go"

# ANDROID-SDK
export ANDROID_HOME="/opt/android-sdk"

# z
[[ -r "/usr/share/z/z.sh" ]] && source /usr/share/z/z.sh

# PATH
export PATH="$HOME/.nodebrew/current/bin:$(ruby -e 'print Gem.user_dir')/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:$HOME/bin:$HOME/.local/bin:$GOPATH/bin:$ANDROID_HOME/tools:/usr/share/git/diff-highlight:$HOME/.goenv/bin:./node_modules/.bin:$PATH"

# GRENCH
export GRENCH_PORT=39874

 [[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

# Autostart if not already in tmux.
if [[ ! -n $TMUX ]]; then
  tmux new -s default
fi

# added by travis gem
[ -f /Users/boxp/.travis/travis.sh ] && source /Users/boxp/.travis/travis.sh
[[ -s "$HOME/.avn/bin/avn.sh" ]] && source "$HOME/.avn/bin/avn.sh" # load avn

# http://qiita.com/shibukk/items/80430b54ecda7f36ca44
function gwt() {
	GIT_CDUP_DIR=`git rev-parse --show-cdup`
	git worktree add ${GIT_CDUP_DIR}git-worktrees/$1 $1
}

# peco history
function peco-select-history() {
	local tac
	if which tac > /dev/null; then
		tac="tac"
	else
		tac="tail -r"
	fi
	BUFFER=$(\history -n 1 | \
		eval $tac | \
		peco --query "$LBUFFER")
	CURSOR=$#BUFFER
	zle clear-screen
}
zle -N peco-select-history
bindkey '^r' peco-select-history

# goenv
export GOENV_ROOT="$HOME/.goenv"

eval "$(goenv init -)"

# vi mode
bindkey -v

# HISTORY
export HISTFILE=${HOME}/.zsh_history
export HISTSIZE=1000
export SAVEHIST=100000
setopt hist_ignore_dups
setopt EXTENDED_HISTORY

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/boxp/Downloads/google-cloud-sdk/path.zsh.inc' ]; then source '/home/boxp/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/home/boxp/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then source '/home/boxp/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

eval $(thefuck --alias)
