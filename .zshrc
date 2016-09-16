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

# Run a command after a plugin is installed/updated
zplug "tj/n", hook-build:"make install"

# Supports checking out a specific branch/tag/commit
zplug "b4b4r07/enhancd", at:v1
zplug "mollifier/anyframe", at:4c23cb60

# Support bitbucket
zplug "b4b4r07/hello_bitbucket", \
    from:bitbucket, \
    as:command, \
    hook-build:"chmod 755 *.sh", \
    use:"*.sh"

# Group dependencies. Load emoji-cli if jq is installed in this example
zplug "stedolan/jq", \
    from:gh-r, \
    as:command, \
    rename-to:jq
zplug "b4b4r07/emoji-cli", \
    on:"stedolan/jq"
# Note: To specify the order in which packages should be loaded, use the nice
#       tag described in the next section

# Set the priority when loading
# e.g., zsh-syntax-highlighting must be loaded
# after executing compinit command and sourcing other plugins
zplug "zsh-users/zsh-syntax-highlighting", nice:10

# Can manage local plugins
zplug "~/.zsh", from:local

# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

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

export NVM_DIR="/home/boxp/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

# Default EDITOR
export EDITOR="vim"

# AUDIO DRIVER settings
export SDL_AUDIODRIVER='alsa'

# direnv
eval "$(direnv hook zsh)"

# gvm settings
 [[ -s "/home/boxp/.gvm/scripts/gvm" ]] && source "/home/boxp/.gvm/scripts/gvm"
 gvm use go1.7
# GOPATH
export GOPATH="$HOME/go"

# ANDROID-SDK
export ANDROID_HOME="/opt/android-sdk"

# z
[[ -r "/usr/share/z/z.sh" ]] && source /usr/share/z/z.sh

# PATH
export PATH="$PATH:$(ruby -e 'print Gem.user_dir')/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:$HOME/bin:$HOME/.local/bin:$GOPATH/bin:$ANDROID_HOME/tools:/usr/share/git/diff-highlight"

# GRENCH
export GRENCH_PORT=39874

# Autostart if not already in tmux.
if [[ ! -n $TMUX ]]; then
  tmux new-session
fi
