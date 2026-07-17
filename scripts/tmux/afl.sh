#!/bin/bash
SESSION_NAME="askforleave"

tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
  API_PATH="$HOME/workplace/gitrepo/askforleave/"

  # Window 1: nvim
  tmux new-session -s $SESSION_NAME -n api-code -d
  tmux send-keys -t $SESSION_NAME:1 "cd ${API_PATH} && nvim ." C-m

  # Window 2:  terminal
  tmux new-window -n terminal -t $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:2 "cd ${API_PATH}" C-m

  tmux select-window -t $SESSION_NAME:2
fi

tmux attach-session -t $SESSION_NAME
