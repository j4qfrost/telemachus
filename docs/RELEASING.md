# Releasing Telemachus

A release is cut by pushing a `vX.Y.Z` tag. The version **is** the tag — there is
no version file to bump. Two CI planes react to the tag and produce the release
artifacts in parallel:

| Plane | Runs on | Builds | Lands in |
|---|---|---|---|
| **Woodpecker** (`.woodpecker/release.yml`) | snowman, Linux | OCI image + thin Linux launcher bundle | Forgejo **container registry** + Forgejo **Release** |
| **GitHub Actions** (`.github/workflows/release.yml`) | hosted macOS + Windows | macOS & Windows source-launcher bundles | GitHub **Release** |

The split is by capability: the Linux agent can't run macOS/Windows tooling, and a
macOS `.dmg` built in CI bakes the runner's path (see below), so the cross-platform
bundles are built on their native GitHub-hosted runners.

## Cut a release

```bash
git tag -a v0.1.0 -m "Telemachus v0.1.0"
git push forgejo v0.1.0 && git push github v0.1.0
```

Push the tag to **both** remotes — `forgejo` triggers Woodpecker, `github` triggers
Actions. Then verify (see below).

## What ships

- **Container image** — `…/j4qfrost/telemachus:v0.1.0` and `:latest`. Pull externally via
  the Tailnet TLS endpoint: `docker pull snowman.tailddc637.ts.net:8443/j4qfrost/telemachus:v0.1.0`.
- **`Telemachus-linux-v0.1.0.tar.gz`** (Forgejo Release) — repo source + `start-linux.sh` +
  `install-desktop.sh`. Extract, run `./start-linux.sh` (creates the venv on first run).
- **`Telemachus-macos-v0.1.0.tar.gz`** / **`Telemachus-windows-v0.1.0.zip`** (GitHub Release) —
  source + `start-macos.sh` / `launch-windows.ps1`, each parse-checked on its native runner.

All bundles are "thin": they ship the app source and a launcher, **not** a bundled Python.
The launcher creates the venv on first run.

### Why no `.dmg` from CI

`build-macos-app.sh` bakes an absolute `INSTALL_DIR` (the repo path on the build machine)
into the `.app` launcher, so a CI-built `.dmg` points at `/Users/runner/work/...` and fails
on any other Mac. It remains a **build-on-your-own-Mac** convenience; the GitHub Release
ships the relocatable source bundle instead.

## One-time prerequisites

- **Public GitHub remote.** `git remote add github git@github.com:j4qfrost/telemachus.git`.
  Run the SECURITY.md secret-scan before the first public push. Actions is free on public repos.
- **Woodpecker secret `forgejo_release_token`** — a Forgejo PAT with `write:repository` +
  `write:package` (the shared `forgejo_token` is read-only). Used for the registry push and
  the Release publish.
- **Agent privileged plugin allowlist** — `woodpeckerci/plugin-docker-buildx` must be allowed
  to run privileged (it builds the image via buildkit).
- **`forgejo:3000` is an HTTP registry** — the buildx step sets `insecure: true`. If the host
  Docker daemon rejects it, the fallback is pushing to the TLS endpoint
  `snowman.tailddc637.ts.net:8443`.

## Verify after tagging

```bash
# image
docker pull snowman.tailddc637.ts.net:8443/j4qfrost/telemachus:v0.1.0
docker run --rm -p 7000:7000 snowman.tailddc637.ts.net:8443/j4qfrost/telemachus:v0.1.0
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7000/   # -> 302 (login)

# linux bundle
#   download from the Forgejo Release, then:
sha256sum -c SHA256SUMS
tar xzf Telemachus-linux-v0.1.0.tar.gz && cd telemachus-v0.1.0 && ./start-linux.sh
```

Local dry-runs before tagging: `woodpecker exec --pipeline-event tag .woodpecker/release.yml`
and `actionlint .github/workflows/release.yml`.
