#!/bin/bash
xmodmap -e "remove mod4 = Super_L Super_R"
xmodmap -e "keycode 133 = Hyper_L"
#xmodmap -e "keysym Super_L = Meta_L Super_L"
xmodmap -e "remove Control = Control_L" 
xmodmap -e "remove Lock = Caps_Lock" 
xmodmap -e "keycode 66 = Control_L"
xmodmap -e "keycode 37 = Caps_Lock" 
xmodmap -e "add Control = Control_L"
xmodmap -e "add Lock = Caps_Lock" 