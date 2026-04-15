# Tests

## Overview

| File | Language | Framework | What it tests |
|------|----------|-----------|---------------|
| `test_args.sh` | Bash | Custom assertions | Argument parsing, --arch validation, --help output |
| `test_clone.sh` | Bash | Custom assertions | Clone skip logic, non-git directory handling |
| `test_build.sh` | Bash | Custom assertions | Build command routing, path normalization |

## Running

```bash
# All tests
make test

# Individual suites
bash tests/test_args.sh
bash tests/test_clone.sh
bash tests/test_build.sh
```

## How they work

### test_args.sh

Tests the argument parsing and validation logic:
- `--help` and `-h` output
- Unknown command handling
- Missing required arguments (`--arch`)
- Invalid `--arch` values (arm, x86_64, x64, arm65)
- Valid `--arch` (arm64, amd64)

### test_clone.sh

Tests the clone command behavior:
- Skips if directory already exists (sing-box)
- Error if directory exists but is not a git repository (cronet-go)
- Custom path handling

### test_build.sh

Uses a patched script that mocks the build functions:
- Verifies correct function is called for each command
- Verifies arm64 → cmd_build_arm64, amd64 → cmd_build_amd64
- Tests path normalization (relative → absolute)

## Test environment

- Tests create temporary directories via `mktemp -d` cleaned up via `trap EXIT`
- No root privileges required
- No network access (mocks/verification only)
- No real git clones or builds executed