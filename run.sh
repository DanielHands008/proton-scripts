#!/bin/bash

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH=$(realpath "./prefix")
#export PROTON_HIDE_NVIDIA_GPU=0
#export VKD3D_CONFIG=dxr11
#export PROTON_ENABLE_NVAPI=1
mkdir -p "$STEAM_COMPAT_DATA_PATH"

PROTON_SCRIPT_CONFIG=./proton_script.conf
PLAY_FILE=./play.sh

select_proton_script () {
    PROTON_SCRIPT=$(zenity --file-selection --title="Select a File" --filename="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/common/" --file-filter="proton")
    if [ -z "$PROTON_SCRIPT" ]; then
    	zenity --width=200 --info --text="No proton version selected."
    	exit 0
    fi
    echo $PROTON_SCRIPT > $PROTON_SCRIPT_CONFIG
}

if [ -f $PROTON_SCRIPT_CONFIG ]; then
    PROTON_SCRIPT=$(<$PROTON_SCRIPT_CONFIG)
fi

if [ -z "$PROTON_SCRIPT" ]; then
    zenity --width=200 --info --text="Select proton script."
    select_proton_script
fi

select_command () {
  if [ -z "$1" ]; then
        PROTON_COMMAND=$(zenity --width=400 --height=300 --list --title="Select Command" --column="Command" --column="Description" "selectproton" "Select proton version." "exe" "Windows executable. (.exe, .msi)" "mkplay" "Make play script." "winecfg" "winecfg" "control" "Controller settings." "custom" "Custom command.")
  else
        PROTON_COMMAND=$1
  fi
}
select_command

if [ "$PROTON_COMMAND" == "selectproton" ]; then
    select_proton_script
    select_command
fi

if [ "$PROTON_COMMAND" == "exe" ]; then
    PROTON_COMMAND=$(zenity --file-selection --title="Select a File" --file-filter=""*.exe" "*.msi"")
elif [ "$PROTON_COMMAND" == "custom" ]; then
    PROTON_COMMAND=$(zenity --entry --text="Command")
fi

if [ "$PROTON_COMMAND" == "mkplay" ]; then

PROTON_COMMAND=

zenity --width=200 --info --text="Select game install folder."
GAME_DIR=$(zenity --file-selection --directory --filename="$(realpath ./)/")
if [ -z "$GAME_DIR" ]; then
    exit 0
fi
zenity --width=200 --info --text="Select game exe."
GAME_EXE=$(zenity --file-selection --filename="$GAME_DIR/")
if [ -z "$GAME_EXE" ]; then
    exit 0
fi

cat > $PLAY_FILE <<- EOM
#!/bin/bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH=\$(realpath "./prefix")
#export PROTON_HIDE_NVIDIA_GPU=0
#export VKD3D_CONFIG=dxr11
#export PROTON_ENABLE_NVAPI=1
mkdir "\$STEAM_COMPAT_DATA_PATH"
cd "$GAME_DIR"
"$PROTON_SCRIPT" run "$GAME_EXE" 
EOM

chmod +x $PLAY_FILE

select_command

fi

if [ -n "$PROTON_COMMAND" ]; then
    "$PROTON_SCRIPT" run "$PROTON_COMMAND"
fi
