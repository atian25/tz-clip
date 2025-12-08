#!/bin/bash

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
