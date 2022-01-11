#!/bin/bash

export STEAM_COMPAT_DATA_PATH=$(realpath "./prefix")
#export PROTON_HIDE_NVIDIA_GPU=0
#export VKD3D_CONFIG=dxr11
#export PROTON_ENABLE_NVAPI=1
mkdir -p "$STEAM_COMPAT_DATA_PATH"

if [ ! -f "$STEAM_COMPAT_DATA_PATH/tracked_files" ]; then
    echo " " > "$STEAM_COMPAT_DATA_PATH/tracked_files"
fi

CONFIG_FILE=./proton_config.conf
PLAY_FILE=./play.sh

load_env_values () {
    while IFS= read -r line; do
        if [[ "$line" == *"="* ]]; then
            IFS='=' read -r env value <<< "$line"
            export $env="$value"
        fi
    done < "$CONFIG_FILE"
}

save_env_values () {
    # First env use a single > to clear the file, then us double >> for each after.
    echo PROTON_SCRIPT=$PROTON_SCRIPT > "$CONFIG_FILE"
    echo STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_COMPAT_CLIENT_INSTALL_PATH >> "$CONFIG_FILE"
    echo GAME_DIR=$GAME_DIR >> "$CONFIG_FILE"
    echo GAME_EXE=$GAME_EXE >> "$CONFIG_FILE"
}

select_steam_path () {
    export STEAM_COMPAT_CLIENT_INSTALL_PATH=$(zenity --file-selection --title="Select steam folder." --directory --filename="$(realpath $HOME/.steam/steam)/")
    if [ -z "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ]; then
        exit 0
    elif [[ ! -f "$STEAM_COMPAT_CLIENT_INSTALL_PATH/steam.sh" ]]; then
        zenity --width=200 --info --text="Invalid steam folder."
        select_steam_path
    fi
}

select_proton_script () {
    PROTON_SCRIPT=$(zenity --file-selection --title="Select proton script" --filename="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/common/" --file-filter="proton")
    if [ -z "$PROTON_SCRIPT" ]; then
        zenity --width=200 --info --text="No proton version selected."
        exit 0
    fi
    save_env_values
}

select_game_files () {
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
    save_env_values
}

select_command () {
    PROTON_COMMAND=$(zenity --width=400 --height=300 --list --title="Select Command" --column="Command" --column="Description" "play" "Play" "steampath" "Select Steam path." "selectproton" "Select proton version." "gamefiles" "Select game files." "exe" "Windows executable. (.exe, .msi)" "winetricks" "Open winetricks." "mkdesktop" "Add to launcher." "winecfg" "Wine Configuration." "control" "Wine Control Panel." "custom" "Custom command.")
    run_command
}

run_command () {
    echo "run command"
    echo $PROTON_COMMAND

    if [ "$PROTON_COMMAND" == "play" ]; then

        if [[ -z $GAME_DIR || ! -f $GAME_EXE ]]; then
            select_game_files
        fi
        cd "$GAME_DIR"
        PROTON_COMMAND="$GAME_EXE"

        # Select Steam path.
    elif [ "$PROTON_COMMAND" == "steampath" ]; then
        PROTON_COMMAND=
        select_steam_path
        save_env_values
        select_command

        # Select proton version.
    elif [ "$PROTON_COMMAND" == "selectproton" ]; then
        PROTON_COMMAND=
        select_proton_script
        select_command

        # Select game files.
    elif [ "$PROTON_COMMAND" == "gamefiles" ]; then
        PROTON_COMMAND=
        select_game_files
        select_command

        # Run a windows exe in the prefix.
    elif [ "$PROTON_COMMAND" == "exe" ]; then
        PROTON_COMMAND=$(zenity --file-selection --title="Select a File" --file-filter=""*.exe" "*.msi" "*.EXE" "*.MSI"")

        # Run custom command.
    elif [ "$PROTON_COMMAND" == "custom" ]; then
        PROTON_COMMAND=$(zenity --entry --text="Command")

        # Make desktop file.
    elif [ "$PROTON_COMMAND" == "mkdesktop" ]; then
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
Exec=bash -c 'cd "$(realpath ./)/" && ./run.sh play'
Actions=
Categories=X-GNOME-Other;
Actions=settings;

[Desktop Action settings]
Name=Proton Commands
Exec=bash -c 'cd "$(realpath ./)/" && ./run.sh'
Icon=$ICON_FILE
EOM
        select_command

        # Open winetricks in the current prefix.
    elif [ "$PROTON_COMMAND" == "winetricks" ]; then
        export WINE=$(dirname "$PROTON_SCRIPT")/files/bin/wine64
        export LD_LIBRARY_PATH=$(dirname "$PROTON_SCRIPT")/files/lib:$LD_LIBRARY/PATH
        export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"
        PROTON_COMMAND=
        winetricks --gui
        select_command
    fi

    # Otherwise run the value of $PROTON_COMMAND in proton.
    if [ -n "$PROTON_COMMAND" ]; then
        "$PROTON_SCRIPT" runinprefix "$PROTON_COMMAND"
        PROTON_COMMAND=
    fi

}

load_env_values

# Get steam folder.
if [[ ! -f "$STEAM_COMPAT_CLIENT_INSTALL_PATH/steam.sh" ]]; then
    if [[ ! -f $"$(realpath "$HOME/.local/share/Steam")/steam.sh" ]]; then
        zenity --width=200 --info --text="Select Steam folder. (Folder containing 'steam.sh')"
        select_steam_path
    else
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$(realpath "$HOME/.local/share/Steam")"
    fi
    save_env_values
fi

# Select proton version, required before any other action.
if [ -z "$PROTON_SCRIPT" ]; then
    zenity --width=200 --info --text="Select proton script."
    select_proton_script
fi

# If no arguments were specified then show command selector.
if [ -z "$1" ]; then
    select_command
else
    PROTON_COMMAND=$1
    run_command
fi