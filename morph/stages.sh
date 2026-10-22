#!/bin/bash
# Prints the scripts.d stages the generated Dockerfile builds (run generate.sh first).
set -eo pipefail
cd "$(dirname "$0")/.."
grep -o 'src=scripts.d/[^,]*\.sh' Dockerfile | sed 's/^src=//' | sort -u
