#!/bin/bash
# Setup SSH key for easier Tailscale SSH access

echo "Setting up SSH key for claude user..."

# Check if we have an SSH key
if [ ! -f "$HOME/.ssh/id_rsa.pub" ] && [ ! -f "$HOME/.ssh/id_ed25519.pub" ]; then
    echo "No SSH public key found. Please generate one first:"
    echo "  ssh-keygen -t ed25519 -C \"your_email@example.com\""
    exit 1
fi

# Find the public key
if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    PUBKEY_FILE="$HOME/.ssh/id_ed25519.pub"
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    PUBKEY_FILE="$HOME/.ssh/id_rsa.pub"
fi

echo "Using public key: $PUBKEY_FILE"

# Add the SSH key to the container
docker compose exec claude-cli bash -c "
    mkdir -p /home/claude/.ssh
    echo '$(cat $PUBKEY_FILE)' >> /home/claude/.ssh/authorized_keys
    chmod 600 /home/claude/.ssh/authorized_keys
    chmod 700 /home/claude/.ssh
    chown -R claude:claude /home/claude/.ssh
    echo 'SSH key added successfully!'
"

echo "SSH setup complete! You should now be able to SSH with:"
echo "  ssh claude@claude-cli.mouse-carp.ts.net"
