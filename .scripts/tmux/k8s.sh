#!/bin/bash

# Name of the tmux session
SESSION_NAME="k8s"

# Check if the session already exists
tmux has-session -t $SESSION_NAME 2>/dev/null

# If the session doesn't exist, create it
if [ $? != 0 ]; then
  # Create a new session with a window called 'nvim'
  tmux new-session -s $SESSION_NAME -n nvim -d

  REPO_PATH="$HOME/workplace/gitrepo/keyspace-k8s"

  # Start nvim in the first window (now index 1)
  tmux send-keys -t $SESSION_NAME:1 "cd ${REPO_PATH} && nvim ." C-m

  # Select the first window (now index 1)
  tmux select-window -t $SESSION_NAME:1
fi

# Attach to the session
tmux attach-session -t $SESSION_NAME
