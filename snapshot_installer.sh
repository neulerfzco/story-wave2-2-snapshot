#!/bin/bash

# ANSI color codes for highlighting
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Base URLs
latest_url="https://story.iliad.snapshot.neuler.xyz/snapshots/"
pruned_url="https://story.iliad.snapshot.neuler.xyz/snapshots/pruned/"
archive_url="https://story.iliad.archive.snapshot.neuler.xyz/snapshots/archive/"

# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    sudo apt update
    sudo apt install -y aria2 lz4
}

# Fetch and display available snapshots from both pruned and archive servers
fetch_snapshots() {
    echo "Fetching available snapshots..."

    # Fetching pruned snapshots
    echo "Fetching pruned snapshots..."
    geth_pruned_snapshots=$(curl -s "${pruned_url}geth/" | grep -Eo '(href="[^"]*")' | sed 's/href="//g' | sed 's/"//g' | grep -E '\.tar\.lz4$')
    story_pruned_snapshots=$(curl -s "${pruned_url}story/" | grep -Eo '(href="[^"]*")' | sed 's/href="//g' | sed 's/"//g' | grep -E '\.tar\.lz4$')

    # Fetching archive snapshots
    echo "Fetching archive snapshots..."
    geth_archive_snapshots=$(curl -s "${archive_url}geth/" | grep -Eo '(href="[^"]*")' | sed 's/href="//g' | sed 's/"//g' | grep -E '\.tar\.lz4$')
    story_archive_snapshots=$(curl -s "${archive_url}story/" | grep -Eo '(href="[^"]*")' | sed 's/href="//g' | sed 's/"//g' | grep -E '\.tar\.lz4$')
}

# Display and confirm snapshot selection
confirm_snapshot_selection() {
    echo -e "${YELLOW}By default, the latest pruned snapshots will be selected.${NC}"
    echo -e "${CYAN}Are you OK continuing with these snapshots? (y/n) [y]:${NC}"
    read user_choice

    if [[ -z "$user_choice" || "$user_choice" == "y" || "$user_choice" == "Y" ]]; then
        # Default selection: latest snapshots for both Geth and Story
        selected_geth_snapshot="geth_pruned_latest.tar.lz4"
        selected_story_snapshot="story_pruned_latest.tar.lz4"
        geth_snapshot_type="latest"
        story_snapshot_type="latest"
    else
        # Let the user choose between archive and pruned for Geth
        echo -e "${CYAN}Please choose a Geth snapshot type (1 for Pruned, 2 for Archive):${NC}"
        read geth_snapshot_type_choice
        if [ "$geth_snapshot_type_choice" == "1" ]; then
            geth_snapshot_type="pruned"
            echo -e "${CYAN}Available pruned Geth snapshots:${NC}"
            echo "$geth_pruned_snapshots" | nl
            echo -e "${CYAN}Please select a Geth pruned snapshot by number:${NC}"
            read geth_choice
            selected_geth_snapshot=$(echo "$geth_pruned_snapshots" | sed -n "${geth_choice}p")
        else
            geth_snapshot_type="archive"
            echo -e "${CYAN}Available archive Geth snapshots:${NC}"
            echo "$geth_archive_snapshots" | nl
            echo -e "${CYAN}Please select a Geth archive snapshot by number:${NC}"
            read geth_choice
            selected_geth_snapshot=$(echo "$geth_archive_snapshots" | sed -n "${geth_choice}p")
        fi

        # Repeat the process for Story
        echo -e "${CYAN}Please choose a Story snapshot type (1 for Pruned, 2 for Archive):${NC}"
        read story_snapshot_type_choice
        if [ "$story_snapshot_type_choice" == "1" ]; then
            story_snapshot_type="pruned"
            echo -e "${CYAN}Available pruned Story snapshots:${NC}"
            echo "$story_pruned_snapshots" | nl
            echo -e "${CYAN}Please select a Story pruned snapshot by number:${NC}"
            read story_choice
            selected_story_snapshot=$(echo "$story_pruned_snapshots" | sed -n "${story_choice}p")
        else
            story_snapshot_type="archive"
            echo -e "${CYAN}Available archive Story snapshots:${NC}"
            echo "$story_archive_snapshots" | nl
            echo -e "${CYAN}Please select a Story archive snapshot by number:${NC}"
            read story_choice
            selected_story_snapshot=$(echo "$story_archive_snapshots" | sed -n "${story_choice}p")
        fi
    fi

    echo "Selected Geth snapshot: $selected_geth_snapshot"
    echo "Selected Story snapshot: $selected_story_snapshot"
}

# Decompress and install the selected snapshots
install_snapshots() {
    geth_dir="$HOME/.story/geth/iliad/geth/chaindata"
    cosmos_dir="$HOME/.story/story/data"

    # Determine the correct URL for Geth
    if [ "$geth_snapshot_type" == "latest" ]; then
        geth_url="${latest_url}$selected_geth_snapshot"
    elif [ "$geth_snapshot_type" == "pruned" ]; then
        geth_url="${pruned_url}geth/$selected_geth_snapshot"
    else  # archive
        geth_url="${archive_url}geth/$selected_geth_snapshot"
    fi

    # Download and install Geth snapshot
    echo "Downloading Geth snapshot from $geth_url..."
    aria2c -x 4 -s 4 "$geth_url" -d /tmp
    geth_snapshot_file="/tmp/$selected_geth_snapshot"
    echo "Installing Geth snapshot..."
    mkdir -p "$geth_dir"
    lz4 -d "$geth_snapshot_file" -c | tar xf - -C "$geth_dir"

    # Determine the correct URL for Story
    if [ "$story_snapshot_type" == "latest" ]; then
        story_url="${latest_url}$selected_story_snapshot"
    elif [ "$story_snapshot_type" == "pruned" ]; then
        story_url="${pruned_url}story/$selected_story_snapshot"
    else  # archive
        story_url="${archive_url}story/$selected_story_snapshot"
    fi

    # Download and install Story snapshot
    echo "Downloading Story snapshot from $story_url..."
    aria2c -x 4 -s 4 "$story_url" -d /tmp
    story_snapshot_file="/tmp/$selected_story_snapshot"
    echo "Installing Story snapshot..."
    mkdir -p "$cosmos_dir"
    lz4 -d "$story_snapshot_file" -c | tar xf - -C "$cosmos_dir"

    echo "Snapshot installation complete."
}

# Main script execution
install_dependencies
fetch_snapshots
confirm_snapshot_selection
install_snapshots
