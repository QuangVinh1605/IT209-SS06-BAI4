#!/bin/bash
# loop-monitor.sh: Ghi thoi gian he thong vao /tmp/monitor.log moi 5 giay
while true; do
    echo "System time: $(date)" >> /tmp/monitor.log
    sleep 5
done
