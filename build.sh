#!/usr/bin/env bash
set -Eeuo pipefail

docker build -t rajuahmmed/php:7.2 php/7.2
docker build -t rajuahmmed/php:7.3 php/7.3
docker build -t rajuahmmed/php:7.4 php/7.4
docker build -t rajuahmmed/php php/8.0
docker build -t rajuahmmed/php:8.1 php/8.1
docker build -t rajuahmmed/php:8.2 php/8.2