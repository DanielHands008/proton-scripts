#!/bin/bash

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH=$(realpath "./prefix")
#export PROTON_HIDE_NVIDIA_GPU=0
#export VKD3D_CONFIG=dxr11
#export PROTON_ENABLE_NVAPI=1
mkdir -p "$STEAM_COMPAT_DATA_PATH"

if [ ! -f "$STEAM_COMPAT_DATA_PATH/tracked_files" ]; then
    echo " " > "$STEAM_COMPAT_DATA_PATH/tracked_files"
fi

CONFIG_FILE=./proton_config.conf
PROTON_SCRIPT_CONFIG=./proton_script.conf
PLAY_FILE=./play.sh

load_env_values () {
    while IFS= read -r line
    do
        if [[ "$line" == *"="* ]]; then
            IFS='=' read -r env value <<< "$line"
            export $env="$value"
        fi
    done < "$CONFIG_FILE"
}

save_env_values () {
    # First env use a single > to clear the file, then us double >> for each after.
    echo PROTON_SCRIPT=$PROTON_SCRIPT > "$CONFIG_FILE"
}

select_proton_script () {
    PROTON_SCRIPT=$(zenity --file-selection --title="Select proton script" --filename="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/common/" --file-filter="proton")
    if [ -z "$PROTON_SCRIPT" ]; then
        zenity --width=200 --info --text="No proton version selected."
        exit 0
    fi
    save_env_values
}

select_command () {
    PROTON_COMMAND=$(zenity --width=400 --height=300 --list --title="Select Command" --column="Command" --column="Description" "selectproton" "Select proton version." "exe" "Windows executable. (.exe, .msi)" "winetricks" "Open winetricks." "mkplay" "Make play script." "mkdesktop" "Add to launcher. (Requires play script.)" "winecfg" "winecfg" "control" "Controller settings." "custom" "Custom command.")
}


load_env_values

# Select proton version, required before any other action.
if [ -z "$PROTON_SCRIPT" ]; then
    zenity --width=200 --info --text="Select proton script."
    select_proton_script
fi

# TODO: Check if proton script from $PROTON_SCRIPT exists.

# If no arguments were specified then show command selector.
if [ -z "$1" ]; then
    select_command
else
    PROTON_COMMAND=$1
fi

# Select proton version.
if [ "$PROTON_COMMAND" == "selectproton" ]; then
    select_proton_script
    select_command
fi

# Run a windows exe in the prefix.
if [ "$PROTON_COMMAND" == "exe" ]; then
    PROTON_COMMAND=$(zenity --file-selection --title="Select a File" --file-filter=""*.exe" "*.msi" "*.EXE" "*.MSI"")
    elif [ "$PROTON_COMMAND" == "custom" ]; then
    PROTON_COMMAND=$(zenity --entry --text="Command")
fi

# Make play script.
if [ "$PROTON_COMMAND" == "mkplay" ]; then
    
    PROTON_COMMAND=
    
    zenity --width=200 --info --text="Select game install folder."
    GAME_DIR=$(zenity --file-selection --title="Select game install folder." --directory --filename="$(realpath ./)/")
    if [ -z "$GAME_DIR" ]; then
        exit 0
    fi
    zenity --width=200 --info --text="Select game exe."
    GAME_EXE=$(zenity --file-selection --title="Select game exe." --filename="$GAME_DIR/")
    if [ -z "$GAME_EXE" ]; then
        exit 0
    fi
    
cat > "$PLAY_FILE" <<- EOM
#!/bin/bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\$HOME/.steam/steam"
export STEAM_COMPAT_DATA_PATH=\$(realpath "./prefix")
#export PROTON_HIDE_NVIDIA_GPU=0
#export VKD3D_CONFIG=dxr11
#export PROTON_ENABLE_NVAPI=1
mkdir "\$STEAM_COMPAT_DATA_PATH"
cd "$GAME_DIR"
"$PROTON_SCRIPT" run "$GAME_EXE"
read -p "Keep this window open while game is running."
EOM
    
    chmod +x "$PLAY_FILE"
    
    select_command
    
fi

# Make desktop file.
if [ "$PROTON_COMMAND" == "mkdesktop" ]; then
    DESKTOP_NAME=$(zenity --entry --text="Name")
    if [ -z "$DESKTOP_NAME" ]; then
        exit 0
    fi
    ICON_FILE=$(zenity --file-selection --title="Select an Icon (Optional)" --file-filter=""*.png" "*.jpg" "*.jpeg" "*.svg"")
    DESKTOP_FILE=$(zenity --file-selection --save --title="Save Desktop File" --filename="$(realpath ~/.local/share/applications/)/Game.desktop" --file-filter="*.desktop")
    if [ -z "$DESKTOP_FILE" ]; then
        exit 0
    fi
    
cat > "$DESKTOP_FILE" <<- EOM
[Desktop Entry]
Version=1.1
Type=Application
Name=$DESKTOP_NAME
Icon=$ICON_FILE
Exec=bash -c 'cd "$(realpath ./)/" && ./play.sh'
Actions=
Categories=X-GNOME-Other;
Actions=settings;

[Desktop Action settings]
Name=Proton Commands
Exec=bash -c 'cd "$(realpath ./)/" && ./run.sh'
Icon=$ICON_FILE
EOM
    select_command
fi

# Open winetricks in the current prefix.
if [ "$PROTON_COMMAND" == "winetricks" ]; then
    export WINE=$(dirname "$PROTON_SCRIPT")/files/bin/wine64
    export LD_LIBRARY_PATH=$(dirname "$PROTON_SCRIPT")/files/lib:$LD_LIBRARY/PATH
    export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"
    PROTON_COMMAND=
    winetricks --gui
    select_command
fi

# Otherwise run the value of $PROTON_COMMAND in proton.
if [ -n "$PROTON_COMMAND" ]; then
    "$PROTON_SCRIPT" run "$PROTON_COMMAND"
fi
