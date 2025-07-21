#!/bin/zsh

# Script to set up an additional GitHub account on macOS (zsh compatible)

# Function to display colored output
print_color() {
    print -P "%F{green}$1%f"
}

# Get user input
print "Enter your GitHub username: "
read GITHUB_USERNAME
print "Enter your email for this GitHub account: "
read GITHUB_EMAIL
print "Enter a nickname for this account (e.g., work, personal): "
read ACCOUNT_NICKNAME

# Create SSH key
print_color "Creating SSH key for $GITHUB_EMAIL..."
SSH_KEY_PATH="$HOME/.ssh/id_ed25519_$ACCOUNT_NICKNAME"
ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH"

# Add SSH key to SSH agent
print_color "Adding SSH key to SSH agent..."
eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY_PATH"

# Copy the public key to clipboard
print_color "Copying public key to clipboard. Please add this key to your GitHub account..."
pbcopy < "$SSH_KEY_PATH.pub"
print "Public key copied to clipboard"
print "Please add this key to your GitHub account at: https://github.com/settings/ssh/new"
print "Press Enter after you've added the key to GitHub..."
read answer

# Update or create SSH config
print_color "Updating SSH config..."
SSH_CONFIG="$HOME/.ssh/config"
if [[ ! -f "$SSH_CONFIG" ]]; then
    touch "$SSH_CONFIG"
    echo "# SSH Config File" > "$SSH_CONFIG"
fi

# Add new host to SSH config
cat >> "$SSH_CONFIG" << EOF

# GitHub account: $ACCOUNT_NICKNAME
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
EOF

# Create global Git config for this account
print_color "Creating a Git configuration helper script..."
GIT_HELPER_PATH="$HOME/bin/git-$ACCOUNT_NICKNAME"
mkdir -p "$HOME/bin"

cat > "$GIT_HELPER_PATH" << EOF
#!/bin/zsh
# Configure Git repository for GitHub account: $ACCOUNT_NICKNAME

if [[ -d ".git" ]] || git rev-parse --git-dir > /dev/null 2>&1; then
    git config user.name "$GITHUB_USERNAME"
    git config user.email "$GITHUB_EMAIL"
    
    # Get the current remote URL
    REMOTE_URL=\$(git config --get remote.origin.url)
    
    # If it's an HTTPS URL, offer to convert to SSH
    if [[ \$REMOTE_URL == https://github.com/* ]]; then
        REPO_PATH=\$(echo \$REMOTE_URL | sed 's/https:\/\/github.com\///')
        print "Current remote URL is HTTPS: \$REMOTE_URL"
        print "Do you want to convert it to SSH? (y/n): "
        read CONVERT
        if [[ \$CONVERT == "y" || \$CONVERT == "Y" ]]; then
            NEW_URL="git@github.com:\$REPO_PATH"
            git remote set-url origin \$NEW_URL
            print "Remote URL updated to: \$NEW_URL"
        fi
    fi
    
    print "Repository configured for GitHub account: $ACCOUNT_NICKNAME"
    print "Username: $GITHUB_USERNAME"
    print "Email: $GITHUB_EMAIL"
else
    print "Not a git repository"
fi
EOF

chmod +x "$GIT_HELPER_PATH"

# Add the helper script to PATH if it's not already there
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    print_color "Added $HOME/bin to PATH in .zshrc"
    print_color "Please restart your terminal or run 'source ~/.zshrc' to update your PATH"
fi

# Create an additional script to clone repositories with this account
CLONE_HELPER_PATH="$HOME/bin/clone-$ACCOUNT_NICKNAME"
cat > "$CLONE_HELPER_PATH" << EOF
#!/bin/zsh
# Helper script to clone repositories for GitHub account: $ACCOUNT_NICKNAME

if [[ \$# -lt 1 ]]; then
    print "Usage: clone-$ACCOUNT_NICKNAME repository-name [directory]"
    exit 1
fi

REPO=\$1
DIR=\$2

if [[ -z \$DIR ]]; then
    git clone git@github.com:$GITHUB_USERNAME/\$REPO.git
else
    git clone git@github.com:$GITHUB_USERNAME/\$REPO.git \$DIR
fi

print "Repository cloned using GitHub account: $ACCOUNT_NICKNAME"
EOF

chmod +x "$CLONE_HELPER_PATH"

print_color "Setup completed successfully!"
print_color "------------------------------"
print_color "SSH key: $SSH_KEY_PATH"
print_color "GitHub Host: github.com-$ACCOUNT_NICKNAME"
print_color "To use this account for a repository:"
print_color "1. To configure an existing repository: cd /path/to/repo && git-$ACCOUNT_NICKNAME"
print_color "2. To clone a new repository: clone-$ACCOUNT_NICKNAME repository-name [directory]"
print_color "3. Or manually: git clone git@github.com-$ACCOUNT_NICKNAME:$GITHUB_USERNAME/repository.git"
print_color "------------------------------"
