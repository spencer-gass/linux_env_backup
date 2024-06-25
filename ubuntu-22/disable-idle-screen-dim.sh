# by default when either screen diming or power saver mode are enabled
# the screen dims after ~20 seconds of inactivity. It's nice to have 
# power saver mode enable when battery is low so running this command
# which removed the screen dimming from power saver mode is nice.
gsettings set org.gnome.settings-daemon.plugins.power idle-brightness 100
