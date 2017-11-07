#!/bin/bash

set -euo pipefail

route add default gw 192.168.222.1
eval "$(route -n | awk '{ if ($8 =="enp0s3" && $2 != "0.0.0.0") print "route del default gw " $2; }')"
