#!/bin/bash

# Read moniker name at the beginning
read -p "Enter your moniker name: " MONIKER_NAME

# Update and install dependencies
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get install -y build-essential jq libssl-dev libseccomp-dev pkg-config

# Install Go
GO_VERSION="1.22.6"
wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo tar -xvf "go${GO_VERSION}.linux-amd64.tar.gz" -C /usr/local --strip-components=1
rm "go${GO_VERSION}.linux-amd64.tar.gz"

# Set up Go environment
mkdir -p "$HOME/go"/{bin,src/github.com}
{
    echo "export GOROOT=/usr/local/go"
    echo "export GOPATH=$HOME/go"
    echo "export GOBIN=\$GOPATH/bin"
    echo "export PATH=\$PATH:\$GOROOT/bin:\$GOBIN"
} >> ~/.bashrc

# Export environment variables for the current session
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOROOT/bin:$GOBIN

# Download and extract Geth
wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.3-b224fdf.tar.gz
tar -xzf geth-linux-amd64-0.9.3-b224fdf.tar.gz
sudo cp geth-linux-amd64-0.9.3-b224fdf/geth "$HOME/go/bin/story-geth"
story-geth version

# Download and extract Story
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.1-57567e5.tar.gz
tar -xzvf story-linux-amd64-0.10.1-57567e5.tar.gz
sudo cp story-linux-amd64-0.10.1-57567e5/story "$HOME/go/bin"
story version

# Init Iliad node
story init --network iliad --moniker "$MONIKER_NAME"

# Create and Configure systemd Service for Story-Geth
echo "Creating systemd service for Story-Geth..."
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=root
ExecStart=$HOME/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Create and Configure systemd Service for Story
echo "Creating systemd service for Story..."
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=root
ExecStart=$HOME/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Updating and define peers
PEERS="10f4a5147c5ae2e4707e9077aad44dd1c3fc7cd3@116.202.217.20:37656,ccb6e8d1788bd46be4abec716e98236c2e21c067@116.202.51.143:26656,17d69e7e7f6b43ef414ee6a4b2585bd9ee0446ce@135.181.139.249:46656,51c6bda6a2632f2d105623026e1caf12743fb91c@204.137.14.33:36656,2027b0adffea21f09d28effa3c09403979b77572@198.178.224.25:26656,56e241d794ec8c12c7a28aa7863db1322589de0a@144.76.202.120:36656,5d7507dbb0e04150f800297eaba39c5161c034fe@135.125.188.77:26656,f8b29354fbe832c1cb011b2fbe4f930f89a0d430@188.245.60.19:26656,c1b1fb63cb1217e6c342c0fd7edf28902e33f189@100.42.179.9:26656,2a77804d55ec9e05b411759c70bc29b5e9d0cce0@165.232.184.59:26656,d6416eb44f9136fc3b03535ae588f63762a67f8e@211.219.19.141:31656,84d347aba1869b924a6d709f133f7b135202a787@84.247.136.201:26656"

# Update peers in config.toml
sed -i "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.story/story/config/config.toml

# Enable and start both service files 
sudo systemctl daemon-reload
sudo systemctl enable story
sudo systemctl enable story-geth

# story-geth
sudo systemctl start story-geth 

# story
sudo systemctl start story 

# Node sync status checker
status=$(curl -s localhost:26657/status | jq -r '.result.sync_info.catching_up')

# Check if the node is synced
if [ "$status" == "false" ]; then
    echo "Node is synced."
else
    echo "Node is not synced."
fi
