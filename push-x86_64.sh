#!/bin/bash
open -a Docker
docker image tag fconti/pulp-verilator:latest fconti/pulp-verilator:x86_64
docker push fconti/pulp-verilator:x86_64
