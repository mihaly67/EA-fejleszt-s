#!/bin/bash
sshpass -p '1104' ssh -o StrictHostKeyChecking=no misi@5.189.163.88 "$@"
