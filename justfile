test:
    nix flake check -j2

# Push all check/package outputs for the current system to the geo-overlay
# cachix cache. Depends on `test` so the store paths are guaranteed to exist.
# Requires `cachix` on PATH and prior `cachix authtoken` or CACHIX_AUTH_TOKEN.
cache: test
    #!/usr/bin/env bash
    set -euo pipefail
    system="$(nix eval --raw --impure --expr builtins.currentSystem)"
    attrs="$(nix eval ".#checks.${system}" --apply builtins.attrNames --json | jq -r '.[]')"
    installables=()
    for attr in $attrs; do
        installables+=(".#checks.${system}.${attr}")
    done
    echo "Pushing ${#installables[@]} packages for ${system} to cachix geo-overlay…"
    nix build --no-link --print-out-paths "${installables[@]}" \
      | cachix push geo-overlay
