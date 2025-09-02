#!/bin/bash
# Script to create missing SSH users for Tailscale SSH

# Function to create a user if it doesn't exist
create_user_if_missing() {
    local username="$1"
    if ! id "$username" >/dev/null 2>&1; then
        echo "Creating user: $username"
        useradd -m -s /bin/bash "$username" 2>/dev/null || true
        echo "$username:claude123" | chpasswd 2>/dev/null || true
        echo "$username ALL=(claude) NOPASSWD:/bin/su" >> /etc/sudoers 2>/dev/null || true
        
        # Create SSH directory and set up key forwarding to claude user
        mkdir -p "/home/$username/.ssh"
        echo "command=\"exec su - claude\" $(cat /home/claude/.ssh/authorized_keys 2>/dev/null || echo '')" > "/home/$username/.ssh/authorized_keys" 2>/dev/null || true
        chown -R "$username:$username" "/home/$username/.ssh" 2>/dev/null || true
        chmod 700 "/home/$username/.ssh" 2>/dev/null || true
        chmod 600 "/home/$username/.ssh/authorized_keys" 2>/dev/null || true
        
        echo "Created user: $username (forwards to claude user)"
    fi
}

# Create common users that Tailscale SSH might try
create_user_if_missing "u0_a619"
create_user_if_missing "mobile" 
create_user_if_missing "android"
create_user_if_missing "user"

# Also allow direct access to claude and root
echo "Users available for SSH:"
echo "- claude (password: claude123)"  
echo "- root (password: claude123)"
echo "- u0_a619 (forwards to claude)"
echo "- mobile (forwards to claude)" 
echo "- android (forwards to claude)"