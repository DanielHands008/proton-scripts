#!/bin/bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH=$(realpath "./prefix")
#export PROTON_HIDE_NVIDIA_GPU=0
#export VKD3D_CONFIG=dxr11
#export PROTON_ENABLE_NVAPI=1
mkdir -p "$STEAM_COMPAT_DATA_PATH"

if [ -z "$1" ]; then
      PROTON_COMMAND=$(zenity --width=400 --height=300 --list --title="Select Command" --column="Command" --column="Description" "exe" "Windows executable. (.exe, .msi)" "mkplay" "Make play script." "winecfg" "winecfg" "control" "Controller settings." "custom" "Custom command.")
else
      PROTON_COMMAND=$1
fi

if [ "$PROTON_COMMAND" == "exe" ]; then
    PROTON_COMMAND=$(zenity --file-selection --title="Select a File" --file-filter=""*.exe" "*.msi"")
elif [ "$PROTON_COMMAND" == "custom" ]; then
    PROTON_COMMAND=$(zenity --entry --text="Command")
fi

if [ "$PROTON_COMMAND" == "mkplay" ]; then

PROTON_COMMAND=

PLAY_FILE=./play.sh

zenity --width=200 --info --text="Select game install folder."
GAME_DIR=$(zenity --file-selection --directory --filename="./")
zenity --width=200 --info --text="Select game exe."
GAME_EXE=$(zenity --file-selection --filename="$GAME_DIR/")

cat > $PLAY_FILE <<- EOM
#!/bin/bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH=\$(realpath "./prefix")
#export PROTON_HIDE_NVIDIA_GPU=0
#export VKD3D_CONFIG=dxr11
#export PROTON_ENABLE_NVAPI=1
mkdir "\$STEAM_COMPAT_DATA_PATH"
cd "$GAME_DIR"
/mnt/linux-games/Steam/steamapps/common/Proton\ -\ Experimental/proton run "$GAME_EXE" 
EOM

chmod +x $PLAY_FILE

fi

if [ -n "$PROTON_COMMAND" ]; then
    /mnt/linux-games/Steam/steamapps/common/Proton\ -\ Experimental/proton run "$PROTON_COMMAND"
fi
