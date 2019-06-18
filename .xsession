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
feh --bg-fill ~/Downloads/cache_1f330eca-f5e9-4432-c4ec-65e94ff769f7.png

# start xmonad
exec xmonad

# start stumpwm
# exec stumpwm

# start xscreensaver
/usr/bin/xscreensaver -no-splash &

start-pulseaudio-x11

export ANDROID_SDK_ROOT="/opt/android-sdk"

# dpi
xrandr --output eDP-1 --scale 1.2x1.2
