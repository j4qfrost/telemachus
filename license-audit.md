# License audit — telemachus (Odysseus fork)

Audit date: 2026-06-07
Project license: MIT (inherited from upstream `pewdiepie-archdaemon/odysseus`)
Upstream: `pewdiepie-archdaemon/odysseus` (MIT) — git remote `upstream`, branch `main`
Distribution intent: permissive-OSS fork, **distributed** as a SaaS-style / network-served app
  (Docker images, Forgejo Release tarballs, GitHub + Forgejo source mirrors, systemd-installed app)

## Verdict

**Compatible with attribution work.** The AGPL item below was **RESOLVED 2026-06-28** by pinning `caldav<2.2` (→2.1.2), which removes `icalendar-searcher` from the lock entirely; one LGPL transitive (`x-wr-timezone`) remains and is satisfied by attribution.

> **Update 2026-06-28 (caldav AGPL resolved).** `requirements.in` now pins `caldav<2.2`. The AGPL dep `icalendar-searcher` was introduced in the caldav **2.2.x** line (not 3.x as stated below) — `caldav<3` would NOT have shed it; `2.1.x` is the last clean release. caldav now resolves to 2.1.2, `icalendar-searcher` is gone from `requirements.txt`/`requirements-dev.txt`, and `src/caldav_sync.py` (which only uses core client/discovery/event-read, never the searcher) still works — 340 tests green. The "Options" under the finding below are kept for history; option 2 was taken (with the corrected `<2.2` floor).

The fork itself is clean on the *fork-compliance* axis: the `LICENSE` file is byte-identical
to upstream's (zero diff vs `upstream/main`), and upstream's attribution infrastructure
(`ACKNOWLEDGMENTS.md` + `licenses/`) is inherited unchanged. The redistribution obligation of
upstream's MIT license (retain copyright + license text) is satisfied.

The open items are about the *dependency supply chain*, not the fork relationship: two copyleft
packages (`icalendar-searcher` AGPL-3.0, `x-wr-timezone` LGPL-3.0) are pulled in as hard,
unconditional transitive dependencies of the core `caldav` dependency and are **not** mentioned
in `ACKNOWLEDGMENTS.md`. Because this app is network-served and distributed as a Docker image,
the AGPL one in particular deserves an explicit decision.

This is an automated audit, not legal advice.

## Findings (risk-tiered)

### Blockers
None. Nothing here hard-blocks the permissive-fork distribution model. The AGPL item below is
elevated to a high Warning rather than a Blocker because (a) the offending package is *only* a
transitive resolver-pulled dep, not first-party code, and (b) for a self-hosted/source-available
fork the AGPL source-offer can be satisfied trivially (the source is already public). The user
should still consciously accept it.

### Warnings

- **`icalendar-searcher==1.0.6` — AGPL-3.0-or-later — CORE transitive dep, UNDISCLOSED.**
  Pulled unconditionally by `caldav` (`Requires-Dist: icalendar-searcher<2,>=1.0.5`). `caldav`
  is a *core* dependency (`requirements.in`, used by `src/caldav_sync.py`), so this AGPL package
  ships in the default Docker image and every install — it is **not** behind the optional flag the
  way PyMuPDF is. It was **not listed in `ACKNOWLEDGMENTS.md`** prior to this audit.
  - Why it matters: AGPL-3.0's network clause (§13) means that if you offer this software's
    functionality over a network to users, those users must be offered the *Corresponding Source*
    of the AGPL-covered portion. The project is explicitly network-served (uvicorn, Docker,
    `tailscale serve`).
  - Mitigating reality: it is not statically combined into a proprietary work; the whole fork is
    public MIT source on GitHub + Forgejo, so the source-offer is effectively already met. The
    AGPL covers *that library's* code, not your MIT code (mere aggregation / use as a library).
  - Options: (1) **Accept and document** — added to `ACKNOWLEDGMENTS.md` in this audit; ensure a
    source link/offer is reachable from the running app (it is, via the public repos). (2) **Remove
    it** — it is only reachable through `caldav`'s ICS search helper; `caldav>=3.x` requires it
    unconditionally, so shedding it means pinning older `caldav` or replacing `caldav`. (3) Confirm
    whether the calendar feature is even shipped in your deployment; if disabled, document that
    AGPL code is present but dormant.

- **`x-wr-timezone==2.0.1` — LGPL-3.0-or-later — CORE transitive dep, UNDISCLOSED.**
  Pulled unconditionally by `recurring-ical-events` (`Requires-Dist: x-wr-timezone>=1.0.0`), which
  is pulled by `caldav` and `icalendar-searcher`. Core path, ships by default. Was **not listed in
  `ACKNOWLEDGMENTS.md`** prior to this audit.
  - Why it matters: LGPL obligations are light when the library is used as-is and dynamically
    (Python import = dynamic). The obligation is essentially: preserve the notice, and allow a
    user to relink/replace the LGPL lib with a modified version (trivially true for a `pip`
    dependency). No copyleft propagates to your MIT code.
  - Action: **Accept and document** — added to `ACKNOWLEDGMENTS.md`. No code change needed; the
    `pip`-installed, unmodified, importable form already satisfies LGPL's relink requirement.

- **`PyMuPDF==1.27.2.3` — AGPL-3.0 / Artifex commercial (dual) — OPTIONAL, correctly disclosed,
  but currently installed in the audited venv.** Listed in `requirements-optional.txt` and
  flagged accurately in `ACKNOWLEDGMENTS.md` (lazy-imported, form-filling only, AGPL network
  clause attaches to that feature). No action on the docs. Note: it *is* present in the local
  `.venv` — fine for dev, but anyone building a *distributed* image with the optional extras
  installed inherits the same AGPL §13 network obligation for the form-filling feature. The default
  `Dockerfile` installs only `requirements.txt`, so the shipped image does not include it. Good.

- **SearXNG (`searxng/searxng:latest`) — AGPL-3.0 — composed via `docker-compose.yml`.**
  Correctly disclosed in `ACKNOWLEDGMENTS.md`. Run as a separate, unmodified container image over
  the network (mere aggregation); its AGPL does not reach into the MIT codebase. If you fork/modify
  the SearXNG image and serve it, AGPL §13 would attach to *that* service. No action as-is.

- **`certifi` (MPL-2.0), `tqdm` (MPL-2.0 AND MIT), `orjson` (Apache/MIT/MPL-2.0) — file-level
  copyleft (MPL-2.0), used unmodified.** MPL-2.0 only requires that *modified MPL files* stay MPL.
  You import these unmodified, so the only obligation is notice retention. Not individually listed
  in `ACKNOWLEDGMENTS.md`'s Python table, but covered by the general "preserve upstream notices"
  posture. Low priority; optionally add to the attribution table for completeness.

### Unknowns

- A handful of packages ship no `License:` field and no license classifier in their installed
  `METADATA` (e.g. `anyio`, `attrs`, `cffi`, `cryptography`, `fastapi`, `numpy`, `pydantic`,
  `pydantic-core`, `starlette`, `uvicorn`, `typing-extensions`, `jsonschema`). These are all
  **well-known permissive** packages (MIT / BSD / Apache-2.0 / PSF) whose licenses are published
  in their repos and `LICENSE` files inside the wheel — the blank field is a metadata-emission
  quirk of newer `pyproject`-only builds (PEP 639 transition), not an actual unknown license.
  Treated as permissive with high confidence; not flagged as risk. For a high-stakes release,
  confirm with `pip-licenses --with-license-file` or `scancode-toolkit`.
  - `fastapi` MIT, `starlette` BSD-3, `uvicorn` BSD-3, `pydantic`/`pydantic-core` MIT,
    `anyio` MIT, `attrs` MIT, `cffi` MIT, `cryptography` Apache-2.0 OR BSD-3, `numpy` BSD-3,
    `typing-extensions` PSF-2.0, `jsonschema` MIT, `idna` BSD-3, `pyyaml` MIT, `click` BSD-3.

- `pycparser` reports `License: LICENSE:` (a parse artifact). Actual license is **BSD-3-Clause**.
  No risk; metadata noise.

### First-party

- **No drift.** `LICENSE` is identical to `upstream/main:LICENSE` (MIT, "Copyright (c) 2025
  Odysseus Contributors"). Correct per the fork rule — the fork did **not** relicense, and the
  copyright holder line was correctly left as upstream's, not swapped to AnhQuan Nguyen.
- The in-tree app brands itself "Odysseus" while the dir/remote is "telemachus"; `README.md`
  and `ACKNOWLEDGMENTS.md` both disclose the fork relationship and link upstream. Consistent.
- `setup.py` is a first-run setup *script*, not packaging metadata — it carries no `license=`
  field, so there is no manifest-vs-LICENSE disagreement to reconcile. `pyproject.toml` is
  tooling-only (pytest/ruff), also no `license` field. No inconsistency.
- README §License says "MIT -- see LICENSE and ACKNOWLEDGMENTS.md". Accurate.

## Inventory (resolved runtime set — `requirements.txt`, pip-compile-pinned)

Method: parsed the pinned, transitively-resolved `requirements.txt` and cross-checked each
package's license against the installed `*.dist-info/METADATA` (`License:` + classifiers) in the
local `.venv` (Python 3.14). `pip-licenses` is not installed; the METADATA read is equivalent
truth for the resolved set. Blank-metadata packages were mapped to their well-known SPDX IDs.

| Package | Version | License (SPDX) | Notes |
|---|---|---|---|
| fastapi | 0.136.3 | MIT | core |
| starlette | 1.2.1 | BSD-3-Clause | via fastapi/mcp |
| uvicorn | 0.48.0 | BSD-3-Clause | core |
| pydantic | 2.13.4 | MIT | core |
| pydantic-core | 2.46.4 | MIT | |
| pydantic-settings | 2.14.1 | MIT | core |
| python-multipart | 0.0.30 | Apache-2.0 | core |
| python-dotenv | 1.2.2 | BSD-3-Clause | core |
| httpx | 0.28.1 | BSD-3-Clause | core |
| httpcore | 1.0.9 | BSD-3-Clause | |
| httpx-sse | 0.4.3 | MIT | |
| anyio | 4.13.0 | MIT | |
| h11 | 0.16.0 | MIT | |
| sqlalchemy | 2.0.50 | MIT | core |
| greenlet | 3.5.1 | MIT / PSF | via sqlalchemy |
| pypdf | 6.12.2 | BSD-3-Clause | core PDF text |
| beautifulsoup4 | 4.14.3 | MIT | core |
| soupsieve | 2.8.4 | MIT | |
| charset-normalizer | 3.4.7 | MIT | core |
| numpy | 2.4.6 | BSD-3-Clause | core |
| chromadb-client | 1.5.9 | Apache-2.0 | core RAG |
| fastembed | 0.8.0 | Apache-2.0 | core embeddings |
| onnxruntime | 1.26.0 | MIT | via fastembed |
| tokenizers | 0.23.1 | Apache-2.0 | via fastembed |
| huggingface-hub | 1.17.0 | Apache-2.0 | via fastembed |
| hf-xet | 1.5.0 | Apache-2.0 | |
| py-rust-stemmers | 0.1.8 | MIT | |
| mmh3 | 5.2.1 | MIT | |
| loguru | 0.7.3 | MIT | |
| pillow | 12.2.0 | MIT-CMU (HPND) | via fastembed/qrcode |
| youtube-transcript-api | 1.2.4 | MIT | core |
| defusedxml | 0.7.1 | PSF-2.0 | via youtube-transcript-api |
| markdown | 3.10.2 | BSD-3-Clause | core |
| markdown-it-py | 4.2.0 | MIT | |
| mdurl | 0.1.2 | MIT | |
| icalendar | 7.1.2 | BSD-2-Clause | core |
| **icalendar-searcher** | **1.0.6** | **AGPL-3.0-or-later** | **core transitive (caldav) — see Warnings** |
| recurring-ical-events | 3.8.2 | LGPL-3.0+ (per repo) | via caldav |
| **x-wr-timezone** | **2.0.1** | **LGPL-3.0-or-later** | **core transitive (recurring-ical-events) — see Warnings** |
| python-dateutil | 2.9.0.post0 | Apache-2.0 OR BSD-3 (dual) | core |
| caldav | 3.2.1 | GPL-3.0+ OR Apache-2.0 (dual; used under Apache-2.0) | core; pulls AGPL/LGPL transitives |
| dnspython | 2.8.0 | ISC | via caldav |
| lxml | 6.1.1 | BSD-3-Clause | via caldav |
| niquests | 3.18.8 | Apache-2.0 | via caldav |
| urllib3-future | 2.21.901 | MIT | via niquests |
| jh2 | 5.0.13 | Apache-2.0 (BSD class.) | via urllib3-future |
| qh3 | 1.9.0 | BSD-3-Clause | via urllib3-future |
| wassima | 2.1.0 | MIT | via niquests |
| cryptography | 48.0.0 | Apache-2.0 OR BSD-3-Clause | core |
| cffi | 2.0.0 | MIT | via cryptography |
| pycparser | 3.0 | BSD-3-Clause | via cffi |
| pyjwt | 2.13.0 | MIT | via mcp |
| bcrypt | 5.0.0 | Apache-2.0 | core |
| mcp | 1.27.2 | MIT | core |
| sse-starlette | 3.4.4 | BSD-3-Clause | via mcp |
| pyotp | 2.9.0 | MIT | core |
| qrcode | 8.2 | BSD-3-Clause | core (qrcode[pil]) |
| croniter | 6.2.2 | MIT | core |
| requests | 2.34.2 | Apache-2.0 | via fastembed |
| certifi | 2026.5.20 | MPL-2.0 | file-level copyleft, unmodified |
| urllib3 | 2.7.0 | MIT | via requests |
| idna | 3.17 | BSD-3-Clause | |
| six | 1.17.0 | MIT | |
| tqdm | 4.67.3 | MPL-2.0 AND MIT | file-level copyleft, unmodified |
| orjson | 3.11.9 | Apache-2.0 / MIT / MPL-2.0 | via chromadb-client |
| typer | 0.25.1 | MIT | via huggingface-hub |
| click | 8.4.1 | BSD-3-Clause | |
| rich | 15.0.0 | MIT | |
| pygments | 2.20.0 | BSD-2-Clause | |
| shellingham | 1.5.4 | ISC | |
| jsonschema | 4.26.0 | MIT | |
| jsonschema-specifications | 2025.9.1 | MIT | |
| referencing | 0.37.0 | MIT | |
| rpds-py | 2026.5.1 | MIT | |
| attrs | 26.1.0 | MIT | |
| annotated-types | 0.7.0 | MIT | |
| annotated-doc | 0.0.4 | MIT (assumed) | blank metadata |
| typing-extensions | 4.15.0 | PSF-2.0 | |
| typing-inspection | 0.4.2 | MIT | |
| opentelemetry-* (api/sdk/proto/exporters/semconv) | 1.42.1 / 0.63b1 | Apache-2.0 | via chromadb-client |
| googleapis-common-protos | 1.75.0 | Apache-2.0 | |
| grpcio | 1.81.0 | Apache-2.0 | |
| protobuf | 6.33.6 | BSD-3-Clause | |
| flatbuffers | 25.12.19 | Apache-2.0 | via onnxruntime |
| overrides | 7.7.0 | Apache-2.0 | |
| tenacity | 9.1.4 | Apache-2.0 | |
| pybase64 | 1.4.3 | BSD-2-Clause | |
| filelock | 3.29.0 | Unlicense / public domain | via huggingface-hub |
| fsspec | 2026.4.0 | BSD-3-Clause | |
| packaging | 26.2 | Apache-2.0 OR BSD-2 | |
| pyyaml | 6.0.3 | MIT | |
| tzdata | 2026.2 | Apache-2.0 | |

### Optional set (`requirements-optional.txt`) — flagged separately

| Package | Version | License (SPDX) | Notes |
|---|---|---|---|
| duckduckgo-search | 8.1.1 | MIT | optional search provider; permissive |
| primp | 1.3.1 | MIT | via duckduckgo-search |
| **PyMuPDF** | **1.27.2.3** | **AGPL-3.0 / Artifex commercial (dual)** | optional form-filling only; lazy-imported; correctly disclosed |

### Dev set (`requirements-dev.txt`) — not distributed

pytest (MIT), pytest-asyncio (Apache-2.0), pytest-randomly (MIT), ruff (MIT), pluggy (MIT),
iniconfig (MIT). All permissive; dev-only, not shipped in the runtime image.

## Obligations checklist

- [x] LICENSE file present and matches upstream (MIT, unmodified) — fork-compliant
- [x] Upstream attribution preserved (`ACKNOWLEDGMENTS.md` + `licenses/` inherited unchanged)
- [x] Adapted-code attributions present (opencode MIT, llmfit MIT, DeepResearch Apache-2.0 with full texts in `licenses/`)
- [x] Apache-2.0 deps: no upstream NOTICE files require bundling beyond existing attribution table
- [x] LGPL deps dynamically linked (Python import; relink-replaceable via pip) — obligation met in form
- [x] **`icalendar-searcher` (AGPL-3.0) added to `ACKNOWLEDGMENTS.md`** — attribution-gap fix applied in this audit
- [x] **`x-wr-timezone` (LGPL-3.0) added to `ACKNOWLEDGMENTS.md`** — attribution-gap fix applied in this audit
- [ ] AGPL source-offer for `icalendar-searcher`: confirm the running app exposes a link to the public source (currently satisfied implicitly by public GitHub/Forgejo mirrors; consider an explicit in-app "source" link)
- [ ] Decide whether the CalDAV feature (and thus the AGPL/LGPL transitives) ships in the distributed image, or is gated/removable
- [x] No deps with genuinely unspecified licenses (blank-metadata packages map to known permissive SPDX IDs)

## Fork-compliance verdict

**COMPLIANT with upstream's MIT license.** Specifically:
- License-text retention: `LICENSE` is byte-identical to `upstream/main` — satisfied.
- Copyright-notice retention: upstream's "Copyright (c) 2025 Odysseus Contributors" preserved
  (correctly *not* swapped to the fork author, per the originated-vs-forked rule).
- Attribution: README + ACKNOWLEDGMENTS disclose the fork and link upstream.
- Source-availability: MIT does not require it; the fork publishes source on GitHub + Forgejo
  anyway, which also covers any inbound AGPL/LGPL source-offer obligations.
- Distribution surfaces (Docker image on the tailnet registry + Forgejo, Forgejo Release tarball,
  systemd-installed app, source mirrors) all carry the unmodified MIT LICENSE and ACKNOWLEDGMENTS
  in-tree — MIT's "include the notice in all copies or substantial portions" is satisfied for each.

The fork does **not** relicense and introduces no first-party copyleft. The only residual risk is
the dependency supply chain's two copyleft transitives, addressed above.

## Tooling used

- Manual parse of pip-compile-pinned `requirements.txt` / `requirements-optional.txt` / `requirements-dev.txt` (the resolved transitive truth).
- Cross-check against installed `*.dist-info/METADATA` (`License:`, `License-Expression`, classifiers) in `.venv` (Python 3.14.5).
- `git diff upstream/main..HEAD -- LICENSE` and `git show upstream/main:...` for fork-compliance.
- `Requires-Dist` chain tracing to confirm `caldav -> icalendar-searcher (AGPL)` and `caldav -> recurring-ical-events -> x-wr-timezone (LGPL)` are unconditional core requirements.
- `pip-licenses` is **not installed**; to regenerate with license-file bodies:
  `.venv/bin/pip install pip-licenses && .venv/bin/pip-licenses --format=json --with-urls --with-license-file`.

## Caveats

- This is an automated audit, not legal advice. For a high-stakes public release, run
  `scancode-toolkit` for source-level scanning and have counsel review the AGPL CalDAV transitive.
- Detection is only as good as declared metadata; several packages emit blank `License:` fields
  under the PEP 639 transition — they were mapped to well-known SPDX IDs by repository knowledge,
  not read from the wheel's bundled LICENSE file. Confirm before a high-stakes release.
- Unusual-license memo for the workspace: **`icalendar-searcher` is AGPL-3.0 and rides in via the
  permissive-looking `caldav` library as an unconditional transitive** — any other fleet project
  using `caldav>=3.x` inherits the same AGPL transitive silently. Worth remembering when auditing
  agraledger / hekate / anything touching CalDAV.
- Re-run this audit after any `requirements*.txt` change (re-pin invalidates the resolved set).
