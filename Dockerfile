#
# Stage 1: building GVSOC & PULP GCC on non-Linux platforms
#
FROM ubuntu:24.04 AS builder
RUN apt update && apt upgrade -y
ENV TZ=Europe/Rome

# install deps
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-unauthenticated \
build-essential \
git \
doxygen \
python3-pip \
libsdl2-dev \
curl \
cmake \
gtkwave \
libsndfile1-dev \
rsync \
autoconf \
automake \
texinfo \
libtool \
pkg-config \
libsdl2-ttf-dev

# install deps (GCC)
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-unauthenticated \
autotools-dev \
libmpc-dev \
libmpfr-dev \
libgmp-dev \
gawk \
bison \
flex \
gperf \
patchutils \
bc \
zlib1g-dev

# # Set the locale, because Vivado crashes otherwise
# ENV LANG=en_US.UTF-8
# ENV LANGUAGE=en_US:en
# ENV LC_ALL=en_US.UTF-8

WORKDIR /app/

# install GVSOC
RUN git clone https://github.com/gvsoc/gvsoc
RUN cd gvsoc
RUN cd gvsoc; git submodule update --init --recursive
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-unauthenticated python3.12-venv
RUN python3 -m venv gvsoc-venv
ENV PATH="/app/gvsoc-venv/bin:$PATH"
RUN cd gvsoc; pip install -r core/requirements.txt
RUN cd gvsoc; pip install -r gapy/requirements.txt
RUN cd gvsoc; make all TARGETS=pulp-open
ENV PATH="/app/gvsoc/install/bin:$PATH"

# install GCC
RUN git clone --recursive https://github.com/pulp-platform/pulp-riscv-gnu-toolchain
RUN cd pulp-riscv-gnu-toolchain; ./configure --prefix=/app/riscv-gcc --with-arch=rv32imc --with-cmodel=medlow --enable-multilib
RUN cd pulp-riscv-gnu-toolchain; make

# # install SDK (different version of GVSOC!)
# RUN git clone --recursive https://github.com/pulp-platform/pulp-sdk
# RUN cd pulp-sdk; . configs/pulp-open.sh; make build

#
# Stage 2: running GVSOC & PULP GCC
#
FROM ubuntu:24.04
RUN apt update && apt upgrade -y
ENV TZ=Europe/Rome

WORKDIR /app

COPY --from=builder /app/gvsoc /app/gvsoc
COPY --from=builder /app/gvsoc-venv /app/gvsoc-venv
COPY --from=builder /app/riscv-gcc /app/riscv-gcc

SHELL ["/bin/bash", "-c"] 

ENV PATH="/app/gvsoc-venv/bin:$PATH"
ENV PATH="/app/riscv-gcc/bin:$PATH"

# install deps
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-unauthenticated \
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
RUN git clone https://github.com/verilator/verilator verilator-build
RUN cd verilator-build; git checkout stable; autoconf; ./configure --prefix=/app/verilator
RUN cd verilator-build; make -j `nproc`
RUN cd verilator-build; make install

# install SDK (different version of GVSOC!)
RUN git clone --recursive https://github.com/pulp-platform/pulp-sdk
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
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-unauthenticated vim ssh

# add local user
RUN useradd -ms /bin/bash pulp
USER pulp

# prepare environment
ENV PULP_RISCV_GCC_TOOLCHAIN=/app/riscv-gcc
ENV PATH="/app/gvsoc/install/bin:$PATH"
ENV PATH="/app/verilator/bin:$PATH"
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENTRYPOINT [ "/bin/bash" ]
