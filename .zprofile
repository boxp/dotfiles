### Ruby ###
export PATH="$HOME/.rbenv/bin:$GOPATH/bin:$PATH"
if which rbenv > /dev/null; then
    eval "$(rbenv init -)"
fi

eval 'set +o history' 2>/dev/null || setopt HIST_IGNORE_SPACE 2>/dev/null
 touch ~/.gitcookies
 chmod 0600 ~/.gitcookies

 git config --global http.cookiefile ~/.gitcookies

 tr , \\t <<\__END__ >>~/.gitcookies
go.googlesource.com,FALSE,/,TRUE,2147483647,o,git-tiyotiyouda.gmail.com=1//0gqc0dyyxP7l7CgYIARAAGBASNwF-L9IrS0nk1ho9yU1CoGyVu_XyodCAydOqkFh1pOoAICKQ2MsUaKKTMunHJrEx3555JQOUarc
go-review.googlesource.com,FALSE,/,TRUE,2147483647,o,git-tiyotiyouda.gmail.com=1//0gqc0dyyxP7l7CgYIARAAGBASNwF-L9IrS0nk1ho9yU1CoGyVu_XyodCAydOqkFh1pOoAICKQ2MsUaKKTMunHJrEx3555JQOUarc
__END__
eval 'set -o history' 2>/dev/null || unsetopt HIST_IGNORE_SPACE 2>/dev/null
