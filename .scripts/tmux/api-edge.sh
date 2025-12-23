#!/bin/bash
SESSION_NAME="api-edge"

tmux has-session -t $SESSION_NAME 2>/dev/null

if [ $? != 0 ]; then
  API_PATH="$HOME/workplace/gitrepo/keyspace-api"
  EDGE_PATH="$HOME/workplace/gitrepo/keyspace-edge"

  # Window 1: nvim cloud
  tmux new-session -s $SESSION_NAME -n api-code -d
  tmux send-keys -t $SESSION_NAME:1 "cd ${API_PATH} && nvim ." C-m

  # Window 2: nvim edge
  tmux new-window -n edge-code -t $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:2 "cd ${EDGE_PATH} && nvim ." C-m

  # Window 3: logs side-by-side
  tmux new-window -n logs -t $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:3 "cd ${API_PATH} && bun run start:local" C-m
  tmux split-window -h -t $SESSION_NAME:3
  tmux send-keys -t $SESSION_NAME:3.2 "cd ${EDGE_PATH} && bun run dev" C-m

  # Window 4: terminal for git, misc
  tmux new-window -n terminal -t $SESSION_NAME
  tmux send-keys -t $SESSION_NAME:4 "cd ${API_PATH}" C-m

  tmux select-window -t $SESSION_NAME:1
fi

tmux attach-session -t $SESSION_NAME
