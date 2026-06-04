{
  description = "telemachus — self-hosted AI workspace (fork of pewdiepie-archdaemon/odysseus)";

  # Pinned to a tarball URL (not `github:`) so the flake resolves without hitting
  # api.github.com — matches the fleet pattern (see ~/Projects/thea/flake.nix) and
  # is friendlier behind proxies / shared-IP CI runners.
  inputs.nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/refs/heads/nixos-24.11.tar.gz";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in {
      # MINIMAL, fork-friendly devShell. This is a pip/requirements.txt project
      # (NOT uv/poetry); a fully pure Nix build of the dependency closure is
      # impractical and would diverge hard from upstream, so we deliberately
      # provide a venv-friendly Python toolchain instead and let `pip install
      # -r requirements*.txt` populate a local .venv. See README "Nix dev shell".
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          # Project targets py312 (pyproject `target-version = "py312"`, CI image
          # python:3.12). Pin the interpreter to match.
          python = pkgs.python312;
        in {
          default = pkgs.mkShell {
            buildInputs = [
              python
              # venv / pip bootstrap (project uses requirements.txt, not uv).
              python.pkgs.pip
              python.pkgs.virtualenv
              # The fork added a ruff gate (pyproject [tool.ruff], select=["F"]).
              # Provide it from nixpkgs so `ruff check` works without a venv.
              pkgs.ruff
              # Native libs some wheels expect at build/runtime: cryptography &
              # bcrypt link OpenSSL; numpy/fastembed pull a zlib-class stack.
              # gcc gives a compiler for any sdist that must build.
              pkgs.openssl
              pkgs.zlib
              pkgs.gcc
            ];

            shellHook = ''
              # Help wheels that dlopen native libs resolve them inside the shell.
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.openssl pkgs.zlib pkgs.stdenv.cc.cc.lib ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              echo "telemachus dev shell — $(python --version), ruff $(ruff --version)"
              echo "  pip project: create a venv with  python -m venv .venv && . .venv/bin/activate"
              echo "  then         pip install -r requirements.txt -r requirements-dev.txt"
            '';
          };
        });

      # Network-free check: run the same ruff gate CI enforces. Uses only the
      # checked-in [tool.ruff] config (select=["F"]); needs no pip install.
      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          ruff = pkgs.runCommand "telemachus-ruff-check"
            { nativeBuildInputs = [ pkgs.ruff ]; }
            ''
              cd ${self}
              # The nix-store source is read-only; point ruff's cache at the
              # sandbox build dir and run it cacheless so it never writes back.
              export RUFF_CACHE_DIR="$TMPDIR/ruff-cache"
              ruff check --no-cache .
              touch $out
            '';
        });
    };
}
