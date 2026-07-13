#!/usr/bin/env bash
#
# icu4x/mayhem/build.sh — build unicode-org/icu4x's upstream cargo-fuzz targets as
# sanitized libFuzzer binaries (OSS-Fuzz Rust path: cargo-fuzz + ASan via RUSTFLAGS),
# then pre-build the project's own test suite so mayhem/test.sh only RUNS it.
#
# Fuzz crates (purely additive port — upstream untouched):
#   mayhem/fuzz              — compare_utf16 (differential vs ICU4C via rust_icu; the
#                              historical Mayhem target), compare_self. Harness sources
#                              copied verbatim from components/normalizer/fuzz, which
#                              pins rust_icu "3" (doesn't build against Debian's ICU 76);
#                              mayhem/fuzz binds rust_icu "5" over the same code path.
#   components/calendar/fuzz — construction, add, until (upstream's own crate;
#                              Arbitrary-driven date math)
# (components/collator/fuzz also ships a compare_utf16 binary — same name as the
# normalizer one; the normalizer target keeps the historical name, so the collator
# crate is not built to avoid the /mayhem name collision.)
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${MAYHEM_JOBS:=$(nproc)}"
export MAYHEM_JOBS
# cargo-fuzz has no --jobs flag; cargo reads parallelism from CARGO_BUILD_JOBS.
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"

# DWARF < 4 debug-info contract (§6.2 item 10). The rlenv runtime may export
# RUST_DEBUG_FLAGS before re-running build.sh offline; the := default only applies
# when unset/empty.
: "${RUST_DEBUG_FLAGS:=-C debuginfo=2 -C force-frame-pointers=yes -C llvm-args=--dwarf-version=2}"

cd "$SRC"

# Rust's ASan runtime (librustc-nightly_rt.asan.a) is built with the nightly's bundled
# LLVM (DWARF 5) and linked before project code — strip its debug sections so it
# contributes no .debug_info (the stripped .a is baked into the image; the offline
# PATCH re-run sees the same file).
ASAN_RT="$(find "$RUSTUP_HOME/toolchains" -name "librustc-nightly_rt.asan.a" 2>/dev/null | head -1)"
if [ -n "$ASAN_RT" ] && [ -f "$ASAN_RT" ]; then
    echo "Stripping debug info from Rust ASan runtime to enforce DWARF < 4: $ASAN_RT"
    objcopy --strip-debug "$ASAN_RT"
fi

# libfuzzer-sys compiles libFuzzer from C++ via the cc crate; force DWARF 3 there too.
export CFLAGS="${CFLAGS:+$CFLAGS }-gdwarf-3"
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-gdwarf-3"

# OSS-Fuzz Rust libFuzzer+ASan flags. Rust instrumentation is driven via RUSTFLAGS
# (-Zsanitizer=address), NOT the C/C++ $SANITIZER_FLAGS from the base image (UBSan
# has no Rust equivalent; safe Rust has no UB to recover from). cargo-fuzz sets the
# ASan flag itself by default, but pin it explicitly. --cfg fuzzing matches libfuzzer-sys.
FUZZ_RUSTFLAGS="--cfg fuzzing -Zsanitizer=address ${RUST_DEBUG_FLAGS}"

# The pinned nightly (the Dockerfile's default toolchain). Upstream's rust-toolchain.toml
# pins bare `cargo` to stable 1.95 (used for the test suite below), so the fuzz builds
# select the nightly explicitly. Both toolchains are preinstalled in the image — no
# download happens here or in the offline re-run.
NIGHTLY="$(rustup toolchain list | sed -n 's/^\(nightly[^ ]*\).*/\1/p' | head -1)"
[ -n "$NIGHTLY" ] || { echo "ERROR: no nightly toolchain installed" >&2; exit 1; }

TRIPLE="x86_64-unknown-linux-gnu"

build_fuzz_dir() {
  local dir="$1"; shift
  for t in "$@"; do
    echo "--- building fuzz target: $dir :: $t ---"
    RUSTFLAGS="$FUZZ_RUSTFLAGS" cargo "+$NIGHTLY" fuzz build --fuzz-dir "$dir" -O --debug-assertions "$t"
    local target_dir
    target_dir="$(cargo "+$NIGHTLY" metadata --no-deps --format-version 1 --manifest-path "$dir/Cargo.toml" \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["target_directory"])')"
    local bin="$target_dir/$TRIPLE/release/$t"
    if [ ! -x "$bin" ]; then
      echo "ERROR: expected fuzz binary not found at $bin" >&2
      ls -la "$target_dir/$TRIPLE/release" >&2 || true
      exit 1
    fi
    cp "$bin" "/mayhem/$t"
    echo "built /mayhem/$t"
  done
}

echo "=== cargo fuzz build (pinned nightly $NIGHTLY, ASan via RUSTFLAGS) ==="
echo "RUSTFLAGS=$FUZZ_RUSTFLAGS"
build_fuzz_dir mayhem/fuzz compare_utf16 compare_self
build_fuzz_dir components/calendar/fuzz construction add until

# Pre-build ICU4X's own test suite with the project's NORMAL flags on the stable
# toolchain pinned by upstream's rust-toolchain.toml (bare cargo resolves it) — the
# exact suite upstream CI runs as ci-job-test / test-all-features:
#   cargo test --all-features --all-targets --no-fail-fast
# with RUSTFLAGS --cfg=icu4x_run_size_tests (tools/make/tests.toml setup-test-rustflags).
# mayhem/test.sh then only RUNS it (same flags → cached, no rebuild).
echo "=== cargo test --no-run (upstream suite, stable toolchain, normal flags) ==="
RUSTFLAGS="--cfg=icu4x_run_size_tests" cargo test --no-run --all-features --all-targets --jobs "$MAYHEM_JOBS"

echo "build.sh complete:"
ls -la /mayhem/compare_utf16 /mayhem/compare_self /mayhem/construction /mayhem/add /mayhem/until
