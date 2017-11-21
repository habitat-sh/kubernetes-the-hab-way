#!/bin/bash

set -euo pipefail

case "$(hostname)" in
  node-0)
    route add -net 10.21.0.0/16 gw 192.168.222.11
    route add -net 10.22.0.0/16 gw 192.168.222.12
    route add -net 10.23.0.0/16 gw 192.168.222.13
    route add -net 10.24.0.0/16 gw 192.168.222.14
    route add -net 10.25.0.0/16 gw 192.168.222.15
    ;;
  node-1)
    route add -net 10.20.0.0/16 gw 192.168.222.10
    route add -net 10.22.0.0/16 gw 192.168.222.12
    route add -net 10.23.0.0/16 gw 192.168.222.13
    route add -net 10.24.0.0/16 gw 192.168.222.14
    route add -net 10.25.0.0/16 gw 192.168.222.15
    ;;
  node-2)
    route add -net 10.20.0.0/16 gw 192.168.222.10
    route add -net 10.21.0.0/16 gw 192.168.222.11
    route add -net 10.23.0.0/16 gw 192.168.222.13
    route add -net 10.24.0.0/16 gw 192.168.222.14
    route add -net 10.25.0.0/16 gw 192.168.222.15
    ;;
  node-3)
    route add -net 10.20.0.0/16 gw 192.168.222.10
    route add -net 10.21.0.0/16 gw 192.168.222.11
    route add -net 10.22.0.0/16 gw 192.168.222.12
    route add -net 10.24.0.0/16 gw 192.168.222.14
    route add -net 10.25.0.0/16 gw 192.168.222.15
    ;;
  node-4)
    route add -net 10.20.0.0/16 gw 192.168.222.10
    route add -net 10.21.0.0/16 gw 192.168.222.11
    route add -net 10.22.0.0/16 gw 192.168.222.12
    route add -net 10.23.0.0/16 gw 192.168.222.13
    route add -net 10.25.0.0/16 gw 192.168.222.15
    ;;
  node-5)
    route add -net 10.20.0.0/16 gw 192.168.222.10
    route add -net 10.21.0.0/16 gw 192.168.222.11
    route add -net 10.22.0.0/16 gw 192.168.222.12
    route add -net 10.23.0.0/16 gw 192.168.222.13
    route add -net 10.24.0.0/16 gw 192.168.222.14
    ;;
esac
