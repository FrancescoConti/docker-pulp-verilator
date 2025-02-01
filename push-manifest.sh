#!/bin/bash
docker manifest create fconti/pulp-verilator:latest \
  --amend fconti/pulp-verilator:arm64 \
  --amend fconti/pulp-verilator:x86_64
docker manifest push fconti/pulp-verilator:latest
