#!/bin/sh

# makes function fail if a command fails
set -e

MESSAGE=""
if [ -n "$2" ]; then
    MESSAGE="$2"
fi

git add .

if output=$(git status --porcelain) && [ -z "$output" ]; then
    echo "Working directory clean - no changes to commit."
elif [ -n "$MESSAGE" ]; then
    git commit -m "$MESSAGE"
else
    git commit
fi

if [ "$1" -gt 0 ]; then
    git push
fi

