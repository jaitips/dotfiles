#!/bin/bash

# Name of the tmux session
SESSION_NAME="app"

# Check if the session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

# If the session doesn't exist, create it
if [ $? != 0 ]; then
  # Create a new session with a window called 'nvim'
  tmux new-session -s $SESSION_NAME -n nvim -d

  BACKEND_PATH="$HOME/workplace/gitrepo/keyspace-api"

  # Start nvim in the first window (now index 1)
  tmux send-keys -t $SESSION_NAME:0 "cd ${BACKEND_PATH} && nvim ." C-m

  # Create a second window for terminal/command line (will be index 2)
  tmux new-window -n terminal -t $SESSION_NAME

  # Navigate to your backend directory and start server
  tmux send-keys -t $SESSION_NAME:1 "cd ${BACKEND_PATH}" C-m

  # Select the first window (now index 1)
  tmux select-window -t $SESSION_NAME:0
fi

# Attach to the session
tmux attach-session -t $SESSION_NAME
