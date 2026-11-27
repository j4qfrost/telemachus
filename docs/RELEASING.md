# Releasing Telemachus

A release is cut by pushing a `vX.Y.Z` tag. The version **is** the tag — there is
no version file to bump. Two CI planes react to the tag and produce the release
artifacts in parallel:

| Plane | Runs on | Builds | Lands in |
|---|---|---|---|
| **Forgejo Actions** (`.forgejo/workflows/release.yml`) | snowman runner, Linux | OCI image + thin Linux launcher bundle | Forgejo **container registry** + Forgejo **Release** |
| **GitHub Actions** (`.github/workflows/release.yml`) | hosted macOS + Windows | macOS & Windows source-launcher bundles | GitHub **Release** |

The split is by capability: the Linux runner can't run macOS/Windows tooling, and a
macOS `.dmg` built in CI bakes the runner's path (see below), so the cross-platform
bundles are built on their native GitHub-hosted runners.

## Cut a release

```bash
git tag -a v0.1.0 -m "Telemachus v0.1.0"
git push forgejo v0.1.0 && git push github v0.1.0
```

Push the tag to **both** remotes — `forgejo` triggers Forgejo Actions, `github` triggers
GitHub Actions. Then verify (see below).

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
- **Forgejo Actions repo secrets `RELEASE_TOKEN` + `RELEASE_USER`** — a Forgejo PAT with
  `write:repository` + `write:package` and its user. Used for the registry push and the
  Release publish (the job's own token can't push packages).
- The image is built with **kaniko** in userspace and pushed to
  `git.legionofweird.dev/j4qfrost/telemachus` over HTTPS, so no privileged container or
  Docker daemon is needed.

## Verify after tagging

```bash
# image
docker pull git.legionofweird.dev/j4qfrost/telemachus:v0.1.0
docker run --rm -p 7000:7000 git.legionofweird.dev/j4qfrost/telemachus:v0.1.0
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7000/   # -> 302 (login)

# linux bundle
#   download from the Forgejo Release, then:
sha256sum -c SHA256SUMS
tar xzf Telemachus-linux-v0.1.0.tar.gz && cd telemachus-v0.1.0 && ./start-linux.sh
```

Local dry-runs before tagging: `forgejo-runner exec -W .forgejo/workflows/release.yml --event push`
and `actionlint .github/workflows/release.yml`.
