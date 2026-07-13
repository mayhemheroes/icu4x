#!/usr/bin/env bash
#
# icu4x/mayhem/test.sh — RUN unicode-org/icu4x's own Rust test suite and emit a CTRF
# summary. exit 0 iff no test failed.
#
# This is the exact suite upstream CI runs as ci-job-test → test-all-features
# (tools/make/tests.toml):
#   cargo test --all-features --all-targets --no-fail-fast
# with RUSTFLAGS --cfg=icu4x_run_size_tests, on the stable toolchain pinned by
# rust-toolchain.toml. It covers every workspace crate's unit tests, integration
# tests, known-answer/golden data tests (calendars, collation, normalization,
# datetime, plurals, segmenter, ...) and the struct-size assertion tests — real
# behavioral assertions, so a no-op / exit(0) patch cannot pass.
#
# Skipped upstream jobs (separate CI jobs needing extra toolchains/network — not
# part of the Rust test suite): ci-job-test-docs (doc tests, nightly + RUSTDOCFLAGS),
# ci-job-testdata (regenerates data from network CLDR), ci-job-test-c/js/dart/kotlin
# (FFI suites needing emsdk/dart/kotlin toolchains), ci-job-test-gigo (same tests
# rebuilt without debug assertions).
#
# build.sh pre-compiled the suite with `cargo test --no-run` and identical flags,
# so this script only RUNS it (cached build, no compilation).
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not available — cannot run the test suite" >&2
  emit_ctrf "cargo-test" 0 1 0; exit 2
fi

echo "=== running cargo test (ICU4X upstream suite: --all-features --all-targets) ==="
# Bare cargo resolves the stable toolchain via upstream's rust-toolchain.toml (preinstalled
# in the image). Identical flags to build.sh's `cargo test --no-run` → fully cached.
out="$(RUSTFLAGS="--cfg=icu4x_run_size_tests" cargo test --all-features --all-targets --no-fail-fast --jobs "$MAYHEM_JOBS" 2>&1)"; rc=$?
printf '%s\n' "$out" | tail -200

# libtest prints one line per test binary:
#   test result: ok. 12 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; ...
# Sum across all binaries.
PASSED=0; FAILED=0; IGNORED=0
while read -r p f i; do
  PASSED=$(( PASSED + p )); FAILED=$(( FAILED + f )); IGNORED=$(( IGNORED + i ))
done < <(printf '%s\n' "$out" \
  | sed -n 's/^test result:.* \([0-9][0-9]*\) passed; \([0-9][0-9]*\) failed; \([0-9][0-9]*\) ignored.*/\1 \2 \3/p')

# If we parsed no result lines, fall back to the cargo exit code (e.g. compile error).
if [ "$(( PASSED + FAILED + IGNORED ))" -eq 0 ]; then
  echo "could not parse any 'test result:' lines; using cargo exit code $rc" >&2
  emit_ctrf "cargo-test" 0 1 0; exit 1
fi

# A nonzero cargo rc with zero parsed failures means something else broke (link error,
# crashed test binary) — don't mask it.
if [ "$rc" -ne 0 ] && [ "$FAILED" -eq 0 ]; then
  echo "cargo test exited $rc despite no counted failures — treating as failure" >&2
  emit_ctrf "cargo-test" "$PASSED" 1 "$IGNORED"; exit 1
fi

emit_ctrf "cargo-test" "$PASSED" "$FAILED" "$IGNORED"
