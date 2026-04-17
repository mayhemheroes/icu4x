# Build Stage
FROM --platform=linux/amd64 ubuntu:22.04 AS builder

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y     curl build-essential git pkg-config libicu-dev libclang-dev clang
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly-2025-09-01
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo +nightly-2025-09-01 install -f cargo-fuzz

RUN git clone --depth=1 https://github.com/google/rust_icu

ADD . /src
WORKDIR /src/components/normalizer

RUN cargo +nightly-2025-09-01 fuzz build &&     mv fuzz/target/x86_64-unknown-linux-gnu/release/compare_utf16 /compare_utf16

RUN RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1"     cargo +nightly-2025-09-01 build --release --manifest-path fuzz/Cargo.toml &&     mv fuzz/target/release/compare_utf16 /compare_utf16_no_inst

# Package Stage
FROM ubuntu:22.04

COPY --from=builder /compare_utf16 /compare_utf16_no_inst /
