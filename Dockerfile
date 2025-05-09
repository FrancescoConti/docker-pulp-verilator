#
# Stage 1: building GVSOC & PULP GCC on non-Linux platforms
#
FROM fconti/hsdes-container AS gvsoc-gcc

#
# Stage 2: building LLVM
#
FROM fconti/corev-llvm     AS corev_llvm

#
# Stage 3: building CV32 GCC
# 
FROM ubuntu:24.04 AS builder
RUN DEBIAN_FRONTEND=noninteractive apt update && apt upgrade -y
ENV TZ=Europe/Rome

# install deps
RUN DEBIAN_FRONTEND=noninteractive apt update && apt install -y --no-install-recommends --allow-unauthenticated \
autoconf \
automake \
autotools-dev \
curl \
python3 \
libmpc-dev \
libmpfr-dev \
libgmp-dev \
gawk \
bison \
flex \
texinfo \
gperf \
libtool \
patchutils \
bc \
zlib1g-dev \
libexpat-dev \
git \
ca-certificates

WORKDIR /app/

# install also GCC for CV32
RUN git clone --recursive https://github.com/pulp-platform/riscv-gnu-toolchain.git
RUN DEBIAN_FRONTEND=noninteractive apt update && apt install -y --no-install-recommends --allow-unauthenticated \
make \
build-essential
RUN cd riscv-gnu-toolchain && ./configure --prefix=/app/riscv-gcc11 --with-arch=rv32imfcxpulpv3 --with-abi=ilp32 --enable-multilib && make -j4
RUN cd riscv-gnu-toolchain && make install

#
# Stage 4: running GVSOC & PULP GCC
#
FROM ubuntu:24.04
RUN apt update && apt upgrade -y
ENV TZ=Europe/Rome

WORKDIR /app

COPY --from=gvsoc-gcc /app/gvsoc /app/gvsoc
COPY --from=gvsoc-gcc /app/gvsoc-venv /app/gvsoc-venv
COPY --from=gvsoc-gcc /app/riscv-gcc /app/riscv-gcc7
COPY --from=builder /app/riscv-gcc11 /app/riscv-gcc11
COPY --from=gvsoc-gcc /app/pulp-sdk /app/pulp-sdk
COPY --from=corev_llvm /app/corev-llvm /app/corev-llvm

SHELL ["/bin/bash", "-c"] 

ENV PATH="/app/gvsoc-venv/bin:$PATH"
ENV PATH="/app/riscv-gcc/bin:$PATH"

# install deps
RUN DEBIAN_FRONTEND=noninteractive apt update && apt install -y --no-install-recommends --allow-unauthenticated \
python3-pip \
libtool \
build-essential \
git \
doxygen \
libsdl2-dev \
curl \
cmake \
gtkwave \
libsndfile1-dev \
rsync \
autoconf \
automake \
texinfo \
pkg-config \
libsdl2-ttf-dev

# install Verilator deps
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-unauthenticated \
git help2man perl python3 make autoconf g++ flex bison ccache \
libgoogle-perftools-dev numactl perl-doc \
libfl2  \
libfl-dev \
zlib1g zlib1g-dev

# install Verilator
RUN git clone --depth 1 -b v5.034 https://github.com/verilator/verilator verilator-build
RUN cd verilator-build; autoconf; ./configure --prefix=/app/verilator
RUN cd verilator-build; make -j `nproc`
RUN cd verilator-build; make install

# install SDK (different version of GVSOC!)
# RUN git clone --recursive https://github.com/pulp-platform/pulp-sdk
# patch SDK to use new GVSOC
RUN sed -i '312,313d' /app/pulp-sdk/rtos/pulpos/common/rules/pulpos/default_rules.mk
# source SDK when entering the docker environment
RUN echo ". /app/pulp-sdk/configs/pulp-open.sh" >> /etc/bash.bashrc

# install Bender deps
RUN curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf > rustup-init.sh
ENV CARGO_HOME=/app/cargo
ENV RUSTUP_HOME=/app/rustup
RUN chmod +x rustup-init.sh; ./rustup-init.sh -y
ENV PATH="/app/cargo/bin:$PATH"
RUN cargo install bender

# install vim,ssh
RUN DEBIAN_FRONTEND=noninteractive apt update
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-unauthenticated vim ssh

# add local user
RUN useradd -ms /bin/bash pulp
USER pulp

# prepare environment
ENV PULP_RISCV_GCC_TOOLCHAIN=/app/riscv-gcc11
ENV PATH="/app/gvsoc/install/bin:$PATH"
ENV PATH="/app/verilator/bin:$PATH"
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENTRYPOINT [ "/bin/bash" ]
