#!/bin/bash
echo "Frissítés WineHQ-Devel (10.x/11.x) verzióra..."
# Add architecture
sudo dpkg --add-architecture i386

# Download and add repository key
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

# Add the Ubuntu 24.04 (Noble) repository
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources

# Update package information
sudo apt update

# Install WineHQ Development branch (which contains the latest 10.x/11.x features)
sudo apt install --install-recommends winehq-devel -y

wine --version
echo "Wine frissítés kész."
