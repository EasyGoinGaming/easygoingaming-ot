# builder stage: compile TFS
FROM debian:bookworm AS builder

# install build deps
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git cmake build-essential \
    libluajit-5.1-dev \
    libmariadb-dev-compat \
    libboost-date-time-dev \
    libboost-system-dev \
    libboost-iostreams-dev \
    libpugixml-dev \
    libcrypto++-dev \
    libfmt-dev \
    zlib1g-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# clone specified release (change TAG as needed)
ARG TAG=v1.6
RUN git clone --recursive --branch ${TAG} https://github.com/otland/forgottenserver.git

WORKDIR /build/forgottenserver
RUN mkdir build && cd build && cmake .. && make -j$(nproc)

# runtime stage: only libs + binary
FROM debian:bookworm-slim

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates \
  libluajit-5.1-2 \
  libmariadb3 \
  libboost-date-time \
  libboost-system \
  libboost-iostreams \
  libpugixml1v5 \
  libcryptopp \
  libfmt \
  zlib1g \
  && rm -rf /var/lib/apt/lists/*

# copy compiled binary
COPY --from=builder /build/forgottenserver/build/tfs /usr/local/bin/tfs

# set runtime entry
WORKDIR /home/container
RUN useradd -m -u 988 container
USER container
ENTRYPOINT ["tfs"]
