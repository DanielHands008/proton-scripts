#!/bin/bash

CONFIG_FILE=./proton_config.conf

LOADED_ENV=()

PASSED_ARGUMENT=$1

CLOSE_ON_COMPLEATION=0

load_env_values () {
    while IFS= read -r line; do
        if [[ "$line" == *"="* ]]; then
            IFS='=' read -r env value <<< "$line"
            export $env="$value"
            LOADED_ENV+=($env)
        fi
    done < "$CONFIG_FILE"
}

save_env_values () {
    rm "$CONFIG_FILE"
    for value in "${LOADED_ENV[@]}"
    do
        if [ ! -z "$value" ]; then
            echo $value="${!value}" >> "$CONFIG_FILE"
        fi
    done
}

set_env () {
    export $1="$2"
    if [[ ! ${LOADED_ENV[*]} =~ "$1" ]]; then
        if [ ! -z "$1" ]; then
            LOADED_ENV+=($1)
        fi
    else
        if [ -z "$2" ]; then
            LOADED_ENV=( "${LOADED_ENV[@]/$1}" )
        fi
    fi
}

select_steam_path () {
    set_env "STEAM_COMPAT_CLIENT_INSTALL_PATH" "$(zenity --file-selection --title="Select steam folder." --directory --filename="$(realpath $HOME/.steam/steam)/")"
    if [ -z "$STEAM_COMPAT_CLIENT_INSTALL_PATH" ]; then
        exit 0
    elif [[ ! -f "$STEAM_COMPAT_CLIENT_INSTALL_PATH/steam.sh" ]]; then
        zenity --width=200 --info --text="Invalid steam folder."
        select_steam_path
    fi
}

select_proton_script () {
    set_env "PROTON_SCRIPT" "$(zenity --file-selection --title="Select proton script" --filename="$STEAM_COMPAT_CLIENT_INSTALL_PATH/steamapps/common/" --file-filter="proton")"
    if [ -z "$PROTON_SCRIPT" ]; then
        zenity --width=200 --info --text="No proton version selected."
        exit 0
    fi
    save_env_values
}

select_game_files () {
    zenity --width=200 --info --text="Select game install folder."
    set_env "GAME_DIR" "$(zenity --file-selection --title="Select game install folder." --directory --filename="$(realpath ./)/")"
    if [ -z "$GAME_DIR" ]; then
        exit 0
    fi
    zenity --width=200 --info --text="Select game exe."
    set_env "GAME_EXE" "$(zenity --file-selection --title="Select game exe." --filename="$GAME_DIR/")"
    if [ -z "$GAME_EXE" ]; then
        exit 0
    fi
    save_env_values
}

select_command () {
    PROTON_COMMAND=$(zenity --width=400 --height=500 --list --title="Select Command" --column="Command" --column="Description" "play" "Play" "steampath" "Select Steam path." "selectproton" "Select proton version." "gamefiles" "Select game files." "setprefix" "Select prefix location. (Default: ./prefix)" "exe" "Windows executable. (.exe, .msi)" "winetricks" "Open winetricks." "mkdesktop" "Add to launcher." "winecfg" "Wine Configuration." "control" "Wine Control Panel." "reboot" "Reboot wine prefix." "custom" "Custom command.")
    if [ -z "$PROTON_COMMAND" ]; then
        exit 0
    fi
    run_command
}

create_prefix () {
    mkdir -p "$STEAM_COMPAT_DATA_PATH"
    # Are tracked files required?
    echo "" > "$STEAM_COMPAT_DATA_PATH/tracked_files"
    #find "$(realpath "$STEAM_COMPAT_DATA_PATH/pfx")" -type f > "$STEAM_COMPAT_DATA_PATH/tracked_files"
    #find "$(realpath "$GAME_DIR")" -type f >> "$STEAM_COMPAT_DATA_PATH/tracked_files"
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

        # Select proton version.
    elif [ "$PROTON_COMMAND" == "selectproton" ]; then
        PROTON_COMMAND=
        select_proton_script

        # Select game files.
    elif [ "$PROTON_COMMAND" == "gamefiles" ]; then
        PROTON_COMMAND=
        select_game_files

    elif [ "$PROTON_COMMAND" == "setprefix" ]; then
        PROTON_COMMAND=
        set_env "STEAM_COMPAT_DATA_PATH" "$(zenity --file-selection --title="Select prefix folder." --directory --filename="$(realpath ./)/")"
        save_env_values

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
Exec=bash -c 'cd "$(realpath ./)/" && $0 play'
Categories=X-GNOME-Other;
Actions=settings;

[Desktop Action settings]
Name=Proton Commands
Exec=bash -c 'cd "$(realpath ./)/" && $0'
Icon=$ICON_FILE
EOM

        # Open winetricks in the current prefix.
    elif [ "$PROTON_COMMAND" == "winetricks" ]; then
        if [[ -f "$(dirname "$PROTON_SCRIPT")/files/bin/wine64" ]]; then
            export WINE="$(dirname "$PROTON_SCRIPT")/files/bin/wine64"
        else
            export WINE="$(dirname "$PROTON_SCRIPT")/dist/bin/wine64"
        fi
        export LD_LIBRARY_PATH=$(dirname "$PROTON_SCRIPT")/files/lib:$LD_LIBRARY/PATH
        export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"
        PROTON_COMMAND=
        create_prefix
        winetricks --gui

        # Reboot the current prefix.
    elif [ "$PROTON_COMMAND" == "reboot" ]; then
        if [[ -f "$(dirname "$PROTON_SCRIPT")/files/bin/wine64" ]]; then
            export WINE="$(dirname "$PROTON_SCRIPT")/files/bin/wine64"
        else
            export WINE="$(dirname "$PROTON_SCRIPT")/dist/bin/wine64"
        fi
        export LD_LIBRARY_PATH=$(dirname "$PROTON_SCRIPT")/files/lib:$LD_LIBRARY/PATH
        export WINEPREFIX="$STEAM_COMPAT_DATA_PATH/pfx"
        PROTON_COMMAND=
        create_prefix
        $WINE reboot
    fi

    # Otherwise run the value of $PROTON_COMMAND in proton.
    if [ -n "$PROTON_COMMAND" ]; then
        create_prefix

        # Check which run commands are available.
        if  grep -q "runinprefix" "$PROTON_SCRIPT" ; then
            "$PROTON_SCRIPT" runinprefix "$PROTON_COMMAND"
        elif grep -q "waitforexitandrun" "$PROTON_SCRIPT" ; then
            "$PROTON_SCRIPT" waitforexitandrun "$PROTON_COMMAND"
            read  -n 1 -p "Keep window open while app is running."
        else
            "$PROTON_SCRIPT" run "$PROTON_COMMAND"
            read  -n 1 -p "Keep window open while app is running."
        fi

        if [ "$PROTON_COMMAND" == "winecfg" ] || [ "$PROTON_COMMAND" == "control" ]; then
            CLOSE_ON_COMPLEATION=0
        else
            CLOSE_ON_COMPLEATION=1
        fi
        PROTON_COMMAND=
    fi

    if [ "$CLOSE_ON_COMPLEATION" == "0" ] && [ "$PASSED_ARGUMENT" = "" ]; then
        select_command
    fi

}

load_env_values

# Set default prefix location.
if [[ -z "$STEAM_COMPAT_DATA_PATH" ]]; then
    set_env "STEAM_COMPAT_DATA_PATH" "$(realpath "./prefix")"
    save_env_values
fi

# Get steam folder.
if [[ ! -f "$STEAM_COMPAT_CLIENT_INSTALL_PATH/steam.sh" ]]; then
    if [[ ! -f $"$(realpath "$HOME/.local/share/Steam")/steam.sh" ]]; then
        zenity --width=200 --info --text="Select Steam folder."
        select_steam_path
    else
        set_env "STEAM_COMPAT_CLIENT_INSTALL_PATH" "$(realpath "$HOME/.local/share/Steam")"
    fi
    save_env_values
fi

# Select proton version, required before any other action.
if [ -z "$PROTON_SCRIPT" ]; then
    zenity --width=200 --info --text="Select proton script."
    select_proton_script
fi

# If no arguments were specified then show command selector.
if [ -z "$PASSED_ARGUMENT" ]; then
    select_command
else
    PROTON_COMMAND=$PASSED_ARGUMENT
    run_command
fi