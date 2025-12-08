#!/bin/bash

# Check for fswatch
if ! command -v fswatch &> /dev/null; then
    echo "Error: fswatch is not installed."
    echo "Please install it using: brew install fswatch"
    exit 1
fi

# 监听 Sources 目录的变化
echo "Starting watch mode..."

# 首次运行
make run &
PID=$!

fswatch -o Sources | while read; do
    echo "Detected change. Rebuilding..."
    
    # 杀掉旧进程
    if [ -n "$PID" ]; then
        kill $PID
    fi
    
    # 重新构建并运行
    make run &
    PID=$!
done
