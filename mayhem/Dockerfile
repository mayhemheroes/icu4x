# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile (SMALL form) — builds ON TOP of the org C/C++ base image
# (ghcr.io/mayhemheroes/base). ICU4X is a RUST workspace; the base ships NO Rust
# toolchain, so this image installs rustup + cargo-fuzz as root into a SHARED
# location (/opt/toolchains/rust) usable by the non-root `mayhem` user, then runs
# build.sh + test.sh.
#
# Build (from the repo root):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) \
#       [--build-arg SOURCE_DATE_EPOCH=$(date +%s)] \
#       -t icu4x-commit:test .
#
# Two toolchains are installed:
#   - a pinned NIGHTLY (upstream CI's PINNED_CI_NIGHTLY) for cargo-fuzz
#     (-Zsanitizer=address needs nightly);
#   - stable 1.95 — the channel pinned by upstream's rust-toolchain.toml, which
#     rustup resolves for every bare `cargo` invocation in the repo (the test
#     suite runs on it, exactly like upstream's ci-job-test). Preinstalling it
#     keeps the offline PATCH re-run from trying to download a toolchain.
#
# The normalizer differential fuzz targets (compare_utf16/compare_self) bind to
# ICU4C via rust_icu (bindgen), so libicu-dev + libclang are needed at build time
# and libicu at run time — installed below and baked into the image.

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (available to build.sh); never bake it as ENV — an empty value
# breaks clang. build.sh unsets it when empty.
ARG SOURCE_DATE_EPOCH

# Declared for parity with the C/C++ template; cargo-fuzz drives Rust instrumentation via
# RUSTFLAGS (-Zsanitizer=address), NOT $SANITIZER_FLAGS.
ARG SANITIZER_FLAGS
ARG MAYHEM_JOBS=

# Nightly pinned to upstream CI's PINNED_CI_NIGHTLY (Makefile.toml); stable per rust-toolchain.toml.
ARG RUST_TOOLCHAIN=nightly-2026-06-01
ARG RUST_STABLE=1.95
ARG CARGO_FUZZ_VERSION=0.13.1

# Rust toolchain at a FIXED, $HOME-independent prefix under /opt/toolchains/rust (SPEC §6.2 item 8).
ENV RUSTUP_HOME=/opt/toolchains/rust/rustup \
    CARGO_HOME=/opt/toolchains/rust/cargo \
    PATH=/opt/toolchains/rust/cargo/bin:${PATH}

USER root
RUN set -eux; \
    apt-get update; \
    # libicu-dev: ICU4C headers/libs for the rust_icu differential fuzz targets (bindgen at
    # build time, shared libs at run time — baked into this image, satisfying the air gap).
    apt-get install -y --no-install-recommends libicu-dev libclang-19-dev; \
    rm -rf /var/lib/apt/lists/*; \
    # Debian dropped the deprecated icu-config; rust_icu's icu_config feature still
    # shells out to it, so provide a thin shim over pkg-config.
    printf '%s\n' \
      '#!/bin/sh' \
      '# icu-config shim over pkg-config (Debian no longer ships icu-config)' \
      'out=""' \
      'for a in "$@"; do' \
      '  case "$a" in' \
      '    --version) out="$out $(pkg-config --modversion icu-i18n)";;' \
      '    --prefix) out="$out $(pkg-config --variable=prefix icu-i18n)";;' \
      '    --libdir) out="$out $(pkg-config --variable=libdir icu-i18n)";;' \
      '    --cppflags|--cflags|--cxxflags|--cppflags-searchpath) out="$out $(pkg-config --cflags icu-i18n)";;' \
      '    --ldflags|--ldflags-layout) out="$out $(pkg-config --libs icu-i18n)";;' \
      '    --ldflags-libsonly) out="$out $(pkg-config --libs-only-l icu-i18n)";;' \
      '    --ldflags-searchpath) out="$out $(pkg-config --libs-only-L icu-i18n)";;' \
      '    *) ;;' \
      '  esac' \
      'done' \
      'echo $out' \
      > /usr/local/bin/icu-config; \
    chmod +x /usr/local/bin/icu-config; \
    icu-config --version; \
    install -d /opt/toolchains/rust; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --profile minimal --default-toolchain "$RUST_TOOLCHAIN"; \
    rustup component add rust-src --toolchain "$RUST_TOOLCHAIN"; \
    rustup toolchain install "$RUST_STABLE" --profile minimal; \
    cargo "+$RUST_STABLE" install cargo-fuzz --version "$CARGO_FUZZ_VERSION" --locked; \
    # Hand the whole prefix to mayhem (2000): the commit build AND the air-gapped PATCH re-run
    # both run as mayhem and need to read the toolchain + read/refresh the registry cache.
    chown -R 2000:2000 /opt/toolchains/rust; \
    rustc --version; cargo --version; cargo fuzz --version
USER mayhem

# Source enters from the build CONTEXT (the CI checkout): the FULL repo (incl. .git history)
# is copied to /mayhem as `mayhem`; build.sh builds in place.
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

# Run ICU4X's real test suite at build time; a failing suite fails the image build.
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
