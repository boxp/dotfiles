# aliases
alias :q="exit"
alias lock="xscreensaver-command --lock"
alias gc="git checkout"
alias gr="git restore"
alias gsw="git switch"
alias gb="git branch"
alias gpull='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias gpush='git push origin $(git rev-parse --abbrev-ref HEAD)'
alias grf='git fetch origin $(git rev-parse --abbrev-ref HEAD) && git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)'
alias gpr="git pull-request --browse"
alias gs="git status"
alias gt="tig"
alias mux="tmuxinator"
alias oplist="op list items | jq -c '.[] | {title: .overview.title, uuid: .uuid}' | peco | jq -r '.uuid' | xargs op get item | jq '.'"
alias vis="vim -S ~/.vim.session"
alias ssm_port_forwarder.sh="$HOME/go/src/github.com/eure/utility-scripts/aws/gateway/ssm_port_forwarder.sh"
alias ssm_gateway_connector.sh="$HOME/go/src/github.com/eure/utility-scripts/aws/gateway/ssm_gateway_connector.sh"

function codex() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -m|--model|--model=*|-m?*)
        command codex "$@"
        return $?
        ;;
    esac
  done

  command codex --model gpt-5.6-terra "$@"
}

function lg() {
  if [[ -n "$TMUX" ]]; then
    tmux popup -h 80% -w 80% -d "$PWD" -E "lazygit -ucd ~/.config/lazygit"
  else
    lazygit -ucd ~/.config/lazygit
  fi
}

function ck_popup_runner() {
  local client state watcher
  client="$(tmux display-message -p '#{client_tty}')"
  state="$(tmux display-message -p -t "$client" '#{session_id}:#{window_id}:#{pane_id}')"

  (
    while :; do
      [[ "$(tmux display-message -p -t "$client" '#{session_id}:#{window_id}:#{pane_id}')" != "$state" ]] && {
        tmux display-popup -C -t "$client"
        break
      }
      sleep 0.1
    done
  ) &
  watcher=$!

  ceeker
  kill "$watcher" 2>/dev/null
}

function ck() {
  if [[ -n "$TMUX" ]]; then
    tmux popup -h 80% -w 80% -d "$PWD" -E "zsh -ic ck_popup_runner"
  else
    ceeker
  fi
}

# prompt
parse_git_branch()
{
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ \1/'
}

setopt prompt_subst

# PROMPT1
PS1="%{[0m%}
%{[33m%}λ%{[0m%} %{[32m%}[%n@%m] %{[33m%}%~%{[0m%}
%(?|%{[36m%}('ω'%) < |%{[31m%}(;ω;%) < )%{[35m%}\$(parse_git_branch) %{[0m%}"

# ghq
export GHQ_ROOT="$HOME/ghq"

# Default EDITOR
export EDITOR="vim"

# AUDIO DRIVER settings
export SDL_AUDIODRIVER='alsa'

# direnv
eval "$(direnv hook zsh)"

# GO
export GOPATH="$HOME/go"
GO111MODULE=on

# ANDROID-SDK
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="/opt/android-sdk"

# z
[[ -r "/usr/share/z/z.sh" ]] && source /usr/share/z/z.sh

# GRENCH
export GRENCH_PORT=39874

 [[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

# TMUX
if which tmux >/dev/null 2>&1; then
    #if not inside a tmux session, and if no session is started, start a new session
    test -z "$TMUX" && (tmux attach || tmux new-session)
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

# vi mode
bindkey -v
KEYTIMEOUT=1  # vi-modeでのモード切り替えを高速化

# vi-modeでモード切り替え時にプロンプトを再描画（表示ズレ防止）
function zle-line-init zle-keymap-select {
    zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

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

# devkitpro
export DEVKITPRO=/opt/devkitpro
export DEVKITARM=/opt/devkitpro/devkitARM
export DEVKITPPC=/opt/devkitpro/devkitPPC

# PATH
export PATH="$HOME/.nodebrew/current/bin:$(ruby -e 'print Gem.user_dir')/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:$HOME/bin:$HOME/.local/bin:$GOPATH/bin:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:/usr/share/git/diff-highlight:./node_modules/.bin:/opt/marp:/opt/webstorm/bin:$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:/opt/Jasper:/opt/Postman/Postman:$HOME/.cache/dein/repos/github.com/liquidz/vim-iced/bin:$PATH"

# ===================
# Machine-specific settings
# ===================
# ~/.pri_zshrc に端末固有の設定を記述可能
[[ -f "$HOME/.pri_zshrc" ]] && source "$HOME/.pri_zshrc"

# ===================
# OS-specific settings
# ===================

# macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS専用の設定をここに追加
  eval "$(/opt/homebrew/bin/brew shellenv)"
  # Homebrew補完パスを追加（compinitより先に設定）
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Windows (WSL, Git Bash, Cygwin)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  # Windows専用の設定をここに追加
  :
fi

# ===================
# Completion settings
# ===================
# 補完システムの有効化
autoload -Uz compinit && compinit

# 補完オプション
setopt auto_menu           # Tab連打で補完候補を順に表示
setopt auto_list           # 自動的に補完候補を表示
setopt list_packed         # 補完候補を詰めて表示
zstyle ':completion:*' menu select  # 矢印キーで補完候補を選択可能に
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # 大文字小文字を区別しない

# ref: https://zenn.dev/shunk031/articles/ghq-gwq-fzf-worktree
function ghq-path() {
    ghq list --full-path | fzf
}

function dev() {
    local moveto
    moveto=$(ghq-path)
    cd "${moveto}" || exit 1

    # rename session if in tmux
    if [[ -n ${TMUX} ]]; then
        local repo_name
        repo_name="${moveto##*/}"

        tmux rename-session "${repo_name//./-}"
    fi
}

function ai_budget_today() {
    "$HOME/ghq/github.com/boxp/dotfiles/scripts/ai-budget-today.sh"
}

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/keitaro.takeuchi/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)
