FROM fconti/corev-llvm     AS corev_llvm
FROM fconti/pulp-verilator

WORKDIR /app

COPY --from=corev_llvm /app/corev-llvm /app/corev-llvm

SHELL ["/bin/bash", "-c"] 

ENV PATH="/app/gvsoc-venv/bin:$PATH"
ENV PATH="/app/riscv-gcc/bin:$PATH"
# prepare environment
ENV PULP_RISCV_GCC_TOOLCHAIN=/app/riscv-gcc
ENV PATH="/app/gvsoc/install/bin:$PATH"
ENV PATH="/app/verilator/bin:$PATH"
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENTRYPOINT [ "/bin/bash" ]
