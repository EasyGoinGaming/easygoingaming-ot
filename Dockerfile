# =========================
# Builder stage
# =========================
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    libluajit-5.1-dev \
    libmariadb-dev-compat \
    libboost-all-dev \
    libpugixml-dev \
    libcrypto++-dev \
    libfmt-dev \
    zlib1g-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG TAG=v1.6
RUN git clone --recursive --branch ${TAG} https://github.com/otland/forgottenserver.git

WORKDIR /build/forgottenserver
RUN mkdir build \
 && cd build \
 && cmake .. -DUSE_LUAJIT=ON \
 && make -j$(nproc)

# =========================
# Runtime stage
# =========================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  libluajit-5.1-2 \
  libmariadb3 \
  libboost-iostreams1.83.0 \
  libboost-system1.83.0 \
  libboost-date-time1.83.0 \
  libboost-locale1.83.0 \
  libboost-json1.83.0 \
  libpugixml1v5 \
  libcrypto++8 \
  libfmt9 \
  zlib1g \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/forgottenserver/build/tfs /usr/local/bin/tfs

RUN useradd -m -u 988 container
USER container

WORKDIR /home/container
ENTRYPOINT ["tfs"]
