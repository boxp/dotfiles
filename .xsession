# set the cursor
xsetroot -cursor_name left_ptr

# x window
xrdb -merge $HOME/.Xresources

# uim
export GTK_IM_MODULE='ibus'
export QT_IM_MODULE='ibus'
export XMODIFIERS=@im='ibus'
ibus-daemon --xim -d

# set keymap
setxkbmap -layout us
xmodmap $HOME/.Xmodmap

xcompmgr -c &
nitrogen --restore

# start lighter.pl
sudo perl $HOME/bin/lighter.pl &

# start xmonad
exec xmonad

# start xscreensaver
xscreensaver -no-splash &

# start xscreensaver
/usr/bin/xscreensaver -no-splash &

start-pulseaudio-x11
