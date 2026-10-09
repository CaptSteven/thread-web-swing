#!/bin/zsh
cd "$(dirname "$0")/web-swing-demo"
exec "../Godot.app/Contents/MacOS/Godot" --path "$PWD"
