# syntax=docker/dockerfile:1

ARG DEBIAN_VERSION=bookworm
ARG TFS_REF=v1.6

FROM debian:${DEBIAN_VERSION} AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
  git ca-certificates cmake build-essential \
  libluajit-5.1-dev libmariadb-dev-compat \
  libboost-date-time-dev libboost-system-dev libboost-iostreams-dev \
  libpugixml-dev libcrypto++-dev libfmt-dev zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --recursive --branch "${TFS_REF}" --depth 1 https://github.com/otland/forgottenserver.git
WORKDIR /build/forgottenserver

RUN mkdir -p build && cd build \
  && cmake .. \
  && make -j"$(nproc)"

# ---- runtime ----
FROM debian:${DEBIAN_VERSION}

# For the first pass, easiest is: install runtime libs by installing the same set (minus toolchain).
# We can tighten this later to only required runtime packages.
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  libluajit-5.1-2 libmariadb3 \
  libboost-date-time1.74.0 libboost-system1.74.0 libboost-iostreams1.74.0 \
  libpugixml1v5 libcryptopp8 libfmt8 zlib1g \
  && rm -rf /var/lib/apt/lists/*

# Pterodactyl-friendly user
RUN groupadd -g 988 container && useradd -m -d /home/container -u 988 -g 988 container

# Copy compiled binary
COPY --from=build /build/forgottenserver/build/tfs /usr/local/bin/tfs

WORKDIR /home/container
USER container

# Pterodactyl runs your "startup" command; keeping ENTRYPOINT minimal helps.
CMD ["tfs"]
