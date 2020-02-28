#!/bin/bash

# Use absolute path for the go bonary

cat << EOF | sudo tee /etc/systemd/system/external-counting.service
  [Unit]
  Description = "External Counting Service"
  
  [Service]
  KillSignal=INT
  Environment="PORT=10001"
  ExecStart=/bin/counting-service
  Restart=always

  [Install]
  WantedBy=multi-user.target
EOF
