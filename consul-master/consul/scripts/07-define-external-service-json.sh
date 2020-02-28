#!/bin/bash

cat << EOF | sudo tee external-counting.json
{
  "Name": "external-counting",
  "Tags": [
    "v0.0.4"
  ],
  "Address": "$(hostname -i)",
  "Port": 10001,
  "Check": {
    "Method": "GET",
    "HTTP": "http://$(hostname -i):10001/health",
    "Interval": "1s"
  }
}
EOF
