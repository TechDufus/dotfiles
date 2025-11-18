#!/usr/bin/env bash
# Power menu for Waybar using rofi

entries=" Lock\n⏾ Suspend\n Reboot\n Shutdown\n Log Out"

selected=$(echo -e "$entries" | rofi -dmenu -i -p "Power Menu" -theme-str 'window {width: 250px;} listview {lines: 5;}')

case "$selected" in
    *Lock)
        hyprlock
        ;;
    *Suspend)
        systemctl suspend
        ;;
    *Reboot)
        systemctl reboot
        ;;
    *Shutdown)
        systemctl poweroff
        ;;
    *"Log Out")
        hyprctl dispatch exit
        ;;
esac
