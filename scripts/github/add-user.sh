#!/usr/bin/env bash

# Script to set up an additional GitHub account (Linux/macOS compatible)

set -euo pipefail

# Check for root/sudo privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[31mError: This script must be run with sudo.\033[0m"
    echo -e "\033[31mUsage: sudo $0\033[0m"
    exit 1
fi

# Function to display colored output
print_color() {
    echo -e "\033[32m$1\033[0m"
}

# Get user input
read -rp "Enter your GitHub username: " GITHUB_USERNAME
read -rp "Enter your email for this GitHub account: " GITHUB_EMAIL
read -rp "Enter a nickname for this account (e.g., work, personal): " ACCOUNT_NICKNAME

# Create SSH key
print_color "Creating SSH key for $GITHUB_EMAIL..."
SSH_KEY_PATH="$HOME/.ssh/id_ed25519_$ACCOUNT_NICKNAME"
ssh-keygen -t ed25519 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH"

# Add SSH key to SSH agent
print_color "Adding SSH key to SSH agent..."
eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY_PATH"

# Copy or display the public key
print_color "Public key:"
echo "---"
cat "$SSH_KEY_PATH.pub"
echo "---"

if command -v pbcopy &>/dev/null; then
    pbcopy < "$SSH_KEY_PATH.pub"
    echo "Public key copied to clipboard (pbcopy)."
elif command -v xclip &>/dev/null; then
    xclip -selection clipboard < "$SSH_KEY_PATH.pub"
    echo "Public key copied to clipboard (xclip)."
elif command -v xsel &>/dev/null; then
    xsel --clipboard < "$SSH_KEY_PATH.pub"
    echo "Public key copied to clipboard (xsel)."
else
    echo "No clipboard tool found — copy the key above manually."
fi

echo "Please add this key to your GitHub account at: https://github.com/settings/ssh/new"
read -rp "Press Enter after you've added the key to GitHub..."

# Update or create SSH config
print_color "Updating SSH config..."
SSH_CONFIG="$HOME/.ssh/config"
if [[ ! -f "$SSH_CONFIG" ]]; then
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    echo "# SSH Config File" > "$SSH_CONFIG"
fi

# Use a unique Host alias so multiple accounts don't clash
cat >> "$SSH_CONFIG" << EOF

# GitHub account: $ACCOUNT_NICKNAME
Host github.com-$ACCOUNT_NICKNAME
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
EOF

# Create Git config helper script
print_color "Creating a Git configuration helper script..."
mkdir -p "$HOME/bin"

GIT_HELPER_PATH="$HOME/bin/git-$ACCOUNT_NICKNAME"
cat > "$GIT_HELPER_PATH" << 'OUTER'
#!/usr/bin/env bash
# Configure Git repository for GitHub account: __NICKNAME__

if [[ -d ".git" ]] || git rev-parse --git-dir > /dev/null 2>&1; then
    git config user.name "__USERNAME__"
    git config user.email "__EMAIL__"

    # Get the current remote URL
    REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || true)

    # If it's an HTTPS URL, offer to convert to SSH with the right Host alias
    if [[ "$REMOTE_URL" == https://github.com/* ]]; then
        REPO_PATH="${REMOTE_URL#https://github.com/}"
        echo "Current remote URL is HTTPS: $REMOTE_URL"
        read -rp "Convert to SSH (github.com-__NICKNAME__)? (y/n): " CONVERT
        if [[ "$CONVERT" == "y" || "$CONVERT" == "Y" ]]; then
            NEW_URL="git@github.com-__NICKNAME__:$REPO_PATH"
            git remote set-url origin "$NEW_URL"
            echo "Remote URL updated to: $NEW_URL"
        fi
    fi

    echo "Repository configured for GitHub account: __NICKNAME__"
    echo "  Username: __USERNAME__"
    echo "  Email:    __EMAIL__"
else
    echo "Error: not a git repository" >&2
    exit 1
fi
OUTER

# Replace placeholders
sed -i "s/__NICKNAME__/$ACCOUNT_NICKNAME/g" "$GIT_HELPER_PATH"
sed -i "s/__USERNAME__/$GITHUB_USERNAME/g" "$GIT_HELPER_PATH"
sed -i "s/__EMAIL__/$GITHUB_EMAIL/g" "$GIT_HELPER_PATH"
chmod +x "$GIT_HELPER_PATH"

# Create clone helper script
CLONE_HELPER_PATH="$HOME/bin/clone-$ACCOUNT_NICKNAME"
cat > "$CLONE_HELPER_PATH" << OUTER
#!/usr/bin/env bash
# Clone repositories using GitHub account: $ACCOUNT_NICKNAME

if [[ \$# -lt 1 ]]; then
    echo "Usage: clone-$ACCOUNT_NICKNAME <owner/repo | repo> [directory]"
    exit 1
fi

REPO=\$1
DIR=\${2:-}

# If no slash, assume the configured username
if [[ "\$REPO" != */* ]]; then
    REPO="$GITHUB_USERNAME/\$REPO"
fi

if [[ -z "\$DIR" ]]; then
    git clone "git@github.com-$ACCOUNT_NICKNAME:\$REPO.git"
else
    git clone "git@github.com-$ACCOUNT_NICKNAME:\$REPO.git" "\$DIR"
fi

echo "Repository cloned using GitHub account: $ACCOUNT_NICKNAME"
OUTER
chmod +x "$CLONE_HELPER_PATH"

# Add ~/bin to PATH if needed
SHELL_RC="$HOME/.bashrc"
[[ -n "${ZSH_VERSION:-}" ]] && SHELL_RC="$HOME/.zshrc"

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
    print_color "Added \$HOME/bin to PATH in $SHELL_RC"
    print_color "Run 'source $SHELL_RC' or restart your terminal."
fi

print_color "------------------------------"
print_color "Setup completed!"
print_color "SSH key:     $SSH_KEY_PATH"
print_color "SSH alias:   github.com-$ACCOUNT_NICKNAME"
print_color ""
print_color "Usage:"
print_color "  Configure existing repo:  cd /path/to/repo && git-$ACCOUNT_NICKNAME"
print_color "  Clone a repo:             clone-$ACCOUNT_NICKNAME owner/repo"
print_color "  Manual clone:             git clone git@github.com-$ACCOUNT_NICKNAME:$GITHUB_USERNAME/repo.git"
print_color "------------------------------"
