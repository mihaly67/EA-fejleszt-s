#!/bin/bash
echo "Indítom a Keep-Alive modult a Jules Box (100.77.191.66) felé (5 percenként)..."
while true; do
    ping -c 1 100.77.191.66 > /dev/null 2>&1
    sleep 300
done
