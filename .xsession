# set the cursor
xsetroot -cursor_name left_ptr

# x window
xrdb -merge $HOME/.Xresources

# ibus
export GTK_IM_MODULE='ibus'
export QT_IM_MODULE='ibus'
export XMODIFIERS=@im='ibus'
ibus-daemon -drx

# set keymap
setxkbmap -layout us
xmodmap $HOME/.Xmodmap

xcompmgr -c &
feh --bg-fill ~/Downloads/MVIMG_20191121_065738\(1\).jpg

# start xmonad
exec xmonad

# start stumpwm
# exec stumpwm

# start xscreensaver
/usr/bin/xscreensaver -no-splash &

start-pulseaudio-x11

export ANDROID_SDK_ROOT="/opt/android-sdk"

# for vscode
export PATH=$PATH:/home/boxp/.goenv/shims

# dpi
xrandr --output eDP-1 --scale 0.8x0.8
