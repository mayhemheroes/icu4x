# Build Stage
FROM ghcr.io/evanrichter/cargo-fuzz:latest as builder

## Dependencies
RUN git clone --depth=1 https://github.com/google/rust_icu

## Add source code to the build stage.
ADD . /src
WORKDIR /src

RUN echo building instrumented harnesses && \
    bash -c "pushd components/normalizer/fuzz && cargo +nightly -Z sparse-registry fuzz build && popd" && \
    mv components/normalizer/fuzz/target/x86_64-unknown-linux-gnu/release/compare_utf16 /compare_utf16 && \
    echo done

RUN echo building non-instrumented harnesses && \
    export RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1" && \
    bash -c "pushd components/normalizer/fuzz && cargo +nightly -Z sparse-registry build --release && popd" && \
    mv components/normalizer/fuzz/target/release/compare_utf16 /compare_utf16_no_inst && \
    echo done

# Package Stage
FROM rustlang/rust:nightly

COPY --from=builder /compare_utf16 /compare_utf16_no_inst /
