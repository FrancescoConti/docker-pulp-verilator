#!/bin/bash
open -a Docker
docker image tag fconti/pulp-verilator:latest fconti/pulp-verilator:arm64
docker push fconti/pulp-verilator:arm64
