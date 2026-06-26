# License audit — telemachus (fork of `pewdiepie-archdaemon/odysseus`)

Audit date: 2026-06-25
Project license: **MIT** (root `LICENSE`, "Copyright (c) 2025 Odysseus Contributors")
Upstream: fork of `pewdiepie-archdaemon/odysseus` — the in-tree MIT `LICENSE` is the declared license and governs the combined fork.
Distribution intent (assumed): **SaaS / network-served self-hosted AI workspace** (FastAPI/uvicorn). This is the strictest lens — AGPL network-copyleft triggers here even without classic "distribution."

> This is an automated audit, not legal advice. It makes obligations legible so you can decide what risk to accept. Detection is from installed `.venv` metadata (Python 3.14.5) cross-referenced with the pinned `requirements.txt` dependency graph.

---

## Verdict

**Compatible with attribution work, with one material copyleft finding to resolve.**

The core Python dependency set is overwhelmingly permissive (MIT / BSD / Apache-2.0 / ISC) and MIT-compatible. The single substantive risk is a **transitive AGPL-3.0 dependency (`icalendar-searcher`) pulled in unconditionally by `caldav` 3.2.1**, plus two transitive **LGPL-3.0** packages from the same subtree. None of these three are mentioned in `ACKNOWLEDGMENTS.md`, and the existing note that "caldav is used under Apache-2.0" no longer fully holds because caldav now drags in AGPL/LGPL code regardless of which license you elect for caldav itself.

---

## Headline finding

`caldav==3.2.1` (a core dependency, imported in `src/caldav_sync.py`) **unconditionally requires `icalendar-searcher` which is AGPL-3.0-or-later** — installed and importable whenever the CalDAV feature runs. For a network-served deployment this pulls AGPL's source-disclosure-to-users obligation into the CalDAV code path, contradicting the current `ACKNOWLEDGMENTS.md` "used under Apache-2.0" framing, and it is **undeclared** in the project's attribution files.

---

## Findings (risk-tiered)

### HIGH

- **`icalendar-searcher==1.0.6` — AGPL-3.0-or-later — transitive (via `caldav`).**
  - **CORRECTION (2026-06-26):** the AGPL floor is **caldav 2.2+, NOT 3.x** — verified against package metadata (caldav 2.1.x is clean; 2.2.x already hard-requires `icalendar-searcher`). The `<3` advice below was wrong and has been superseded by the `<2.2` pin actually shipped.
  - Why HIGH: AGPL network-copyleft + network-served intent + undeclared. `caldav` **2.2+** lists `icalendar-searcher<2,>=1.0.5` as a hard (non-extra) runtime requirement, so it is **not optional** — it installs and is importable any time `caldav` is used. Although the app imports `caldav` (not `icalendar-searcher`) directly, AGPL's reach turns on conveying/serving a work that *includes/links* the AGPL code, which the CalDAV runtime does.
  - Obligation (if you keep it + serve over a network): offer corresponding source for the combined work to users who interact with it over the network, for the CalDAV-touching deployment.
  - Action (pick one):
    1. **Pin caldav below the icalendar-searcher floor. ✅ DONE.** caldav added the hard `icalendar-searcher` requirement in the **2.2.x** line (not 3.x), so `caldav<3` does NOT drop it — the correct constraint is **`caldav<2.2`** (resolves to 2.1.2). Shipped: `requirements.in` now pins `caldav<2.2`, `requirements.txt` re-resolved, `icalendar-searcher` gone from the lock, 329 tests green. `src/caldav_sync.py` uses only core client/discovery/event-read, never the searcher feature.
    2. **Make CalDAV optional.** Move `caldav` (and let its AGPL/LGPL subtree follow) to `requirements-optional.txt`, lazy-import it in `src/caldav_sync.py` (the file already imports `caldav` inside a function), and document it exactly like PyMuPDF is documented today — "installing it brings AGPL obligations for the CalDAV feature on a network-served app." The MIT core then runs without it.
    3. **Accept and disclose.** Keep it, add it to `ACKNOWLEDGMENTS.md`, and implement an AGPL source-offer for network users of the deployment.

### WARNING (copyleft — file-level / weak; obligation is attribution + keep-source-of-modified-files)

- **`recurring-ical-events==3.8.2` — LGPL-3.0-or-later — transitive (via `caldav`).** Undeclared. Used as an unmodified library (dynamic import), so LGPL is satisfied by attribution + allowing users to relink/replace the library; no obligation to open the rest of the app. Action: add to `ACKNOWLEDGMENTS.md`; if you take HIGH-finding option 1 or 2 this disappears.
- **`x-wr-timezone==2.0.1` — LGPL-3.0-or-later — transitive (via `recurring-ical-events` / `caldav`).** Same as above. Undeclared. Action: declare, or remove with the caldav subtree.
- **`certifi==2026.5.20` — MPL-2.0.** File-level copyleft; used unmodified. Obligation: preserve license/notice. Undeclared in the Python table. Action: add to attribution (low effort).
- **`orjson==3.11.9` — `MPL-2.0 AND (Apache-2.0 OR MIT)`.** MPL component is file-level copyleft on the unmodified library. Obligation: attribution. Undeclared. Action: add to attribution.
- **`tqdm==4.67.3` — `MPL-2.0 AND MIT`.** Same shape as orjson. Undeclared. Action: add to attribution.
- **`pillow==12.2.0` — MIT-CMU (HPND-style).** Permissive; attribution only. Undeclared. Action: add to attribution. (Note: `fastembed` and `qrcode[pil]` both pull Pillow into core.)

### WATCH (already known / already handled — no new action)

- **PyMuPDF==1.27.2.3 — AGPL-3.0 (or Artifex commercial).** Correctly kept **optional** (`requirements-optional.txt`), lazy-imported, and clearly documented in `ACKNOWLEDGMENTS.md`. This is the model the caldav HIGH finding should follow. No new action.
- **`caldav==3.2.1` itself — `GPL-3.0-or-later OR Apache-2.0` (dual).** The dual license on caldav *itself* is fine under the Apache-2.0 election, as ACKNOWLEDGMENTS states. The problem is not caldav's own license but its AGPL/LGPL *dependencies* (above).
- **Docker-composed services** (`searxng` AGPL-3.0, `ntfy` Apache/GPL-2.0): already disclosed in ACKNOWLEDGMENTS as "bundled via compose, not modified, not distributed." Pulling images at runtime does not bind this codebase. No action.

### Attribution-gap summary (Apache-2.0 / permissive notice obligations)

The core ships many **Apache-2.0** deps that carry a notice-preservation obligation: `bcrypt`, `chromadb-client`, `fastembed`, `grpcio`, `hf-xet`, `huggingface-hub`, `niquests`, all `opentelemetry-*`, `python-multipart`, `requests`, `tenacity`, `tokenizers`, `tzdata`. Apache-2.0 also requires propagating any upstream **NOTICE** file if one ships. `ACKNOWLEDGMENTS.md` lists FastAPI/Pydantic/etc. but is **not exhaustive** of the ~80 transitive packages. Recommended: generate a complete `THIRD_PARTY_LICENSES` from the resolved venv and ship it with releases, rather than hand-maintaining the table.

### First-party

- **No `license` field in `pyproject.toml` / `setup.py`.** The root `LICENSE` (MIT) is the only declaration. Minor: add `license = "MIT"` (SPDX) to `pyproject.toml` so packaging metadata matches the file. Severity LOW (fork, self-hosted).
- **LICENSE copyright holder = "Odysseus Contributors."** Consistent with upstream branding the fork retains; not a defect. The fork inherits upstream's MIT terms — preserve upstream's copyright notice (already done via the in-tree LICENSE).

---

## Obligations checklist

- [x] LICENSE file present (MIT) and matches the fork's distribution
- [ ] `license = "MIT"` added to `pyproject.toml` (currently absent)
- [ ] AGPL transitive (`icalendar-searcher`) resolved or disclosed (HIGH finding)
- [ ] LGPL transitives (`recurring-ical-events`, `x-wr-timezone`) declared or removed
- [ ] MPL deps (`certifi`, `orjson`, `tqdm`) added to attribution
- [ ] Complete `THIRD_PARTY_LICENSES` generated from the resolved venv and shipped with releases (replaces the hand-kept table)
- [x] PyMuPDF AGPL kept optional + documented (already done)
- [x] Docker-composed AGPL/GPL services disclosed as composed-not-distributed (already done)

---

## Inventory (core `requirements.txt`, resolved from `.venv`)

| Package | Version | SPDX / license | Source | License source |
|---|---|---|---|---|
| annotated-doc | 0.0.4 | MIT | PyPI | metadata |
| annotated-types | 0.7.0 | MIT | PyPI | classifier |
| anyio | 4.13.0 | MIT | PyPI | metadata |
| attrs | 26.1.0 | MIT | PyPI | metadata |
| bcrypt | 5.0.0 | Apache-2.0 | PyPI | metadata |
| beautifulsoup4 | 4.14.3 | MIT | PyPI | metadata |
| caldav | 3.2.1 | GPL-3.0-or-later OR Apache-2.0 (elect Apache-2.0) | PyPI | expression |
| certifi | 2026.5.20 | **MPL-2.0** | PyPI | classifier |
| cffi | 2.0.0 | MIT | PyPI | metadata |
| charset-normalizer | 3.4.7 | MIT | PyPI | metadata |
| chromadb-client | 1.5.9 | Apache-2.0 | PyPI | classifier |
| click | 8.4.1 | BSD-3-Clause | PyPI | metadata |
| croniter | 6.2.2 | MIT | PyPI | metadata |
| cryptography | 48.0.0 | Apache-2.0 OR BSD-3-Clause | PyPI | expression |
| defusedxml | 0.7.1 | PSF-2.0 | PyPI | classifier |
| dnspython | 2.8.0 | ISC | PyPI | classifier |
| fastapi | 0.136.3 | MIT | PyPI | metadata |
| fastembed | 0.8.0 | **Apache-2.0** (PyPI classifier mislabels "Other/Proprietary"; bundled LICENSE is Apache-2.0) | PyPI | license file |
| filelock | 3.29.0 | MIT | PyPI | metadata |
| flatbuffers | 25.12.19 | Apache-2.0 | PyPI | classifier |
| fsspec | 2026.4.0 | BSD-3-Clause | PyPI | metadata |
| googleapis-common-protos | 1.75.0 | Apache-2.0 | PyPI | classifier |
| greenlet | 3.5.1 | MIT AND PSF-2.0 | PyPI | expression |
| grpcio | 1.81.0 | Apache-2.0 | PyPI | metadata |
| h11 | 0.16.0 | MIT | PyPI | classifier |
| hf-xet | 1.5.0 | Apache-2.0 | PyPI | metadata |
| httpcore | 1.0.9 | BSD-3-Clause | PyPI | metadata |
| httpx | 0.28.1 | BSD-3-Clause | PyPI | classifier |
| httpx-sse | 0.4.3 | MIT | PyPI | classifier |
| huggingface-hub | 1.17.0 | Apache-2.0 | PyPI | classifier |
| icalendar | 7.1.2 | BSD-2-Clause | PyPI | metadata |
| icalendar-searcher | 1.0.6 | **AGPL-3.0-or-later** | PyPI | metadata |
| idna | 3.17 | BSD-3-Clause | PyPI | metadata |
| jh2 | 5.0.13 | MIT | PyPI | metadata |
| jsonschema | 4.26.0 | MIT | PyPI | metadata |
| jsonschema-specifications | 2025.9.1 | MIT | PyPI | metadata |
| loguru | 0.7.3 | MIT | PyPI | classifier |
| lxml | 6.1.1 | BSD-3-Clause | PyPI | classifier |
| markdown | 3.10.2 | BSD-3-Clause | PyPI | metadata |
| markdown-it-py | 4.2.0 | MIT | PyPI | classifier |
| mcp | 1.27.2 | MIT | PyPI | classifier |
| mdurl | 0.1.2 | MIT | PyPI | classifier |
| mmh3 | 5.2.1 | MIT | PyPI | classifier |
| niquests | 3.18.8 | Apache-2.0 | PyPI | metadata |
| numpy | 2.4.6 | BSD-3-Clause AND 0BSD AND MIT AND Zlib AND CC0-1.0 | PyPI | expression |
| onnxruntime | 1.26.0 | MIT | PyPI | classifier |
| opentelemetry-* (7 pkgs) | 1.42.1 / 0.63b1 | Apache-2.0 | PyPI | metadata |
| orjson | 3.11.9 | **MPL-2.0 AND (Apache-2.0 OR MIT)** | PyPI | expression |
| overrides | 7.7.0 | Apache-2.0 | PyPI | metadata |
| packaging | 26.2 | Apache-2.0 OR BSD-2-Clause | PyPI | expression |
| pillow | 12.2.0 | MIT-CMU (HPND) | PyPI | expression |
| protobuf | 6.33.6 | BSD-3-Clause | PyPI | metadata |
| py-rust-stemmers | 0.1.8 | MIT (upstream) | PyPI | (no metadata; upstream MIT) |
| pybase64 | 1.4.3 | BSD-2-Clause | PyPI | classifier |
| pycparser | 3.0 | BSD-3-Clause | PyPI | metadata |
| pydantic / pydantic-core / pydantic-settings | 2.13.4 / 2.46.4 / 2.14.1 | MIT | PyPI | metadata |
| pygments | 2.20.0 | BSD-2-Clause | PyPI | metadata |
| pyjwt | 2.13.0 | MIT | PyPI | metadata |
| pyotp | 2.9.0 | MIT | PyPI | classifier |
| pypdf | 6.12.2 | BSD-3-Clause | PyPI | metadata |
| python-dateutil | 2.9.0.post0 | Apache-2.0 OR BSD-3-Clause (dual) | PyPI | classifier |
| python-dotenv | 1.2.2 | BSD-3-Clause | PyPI | metadata |
| python-multipart | 0.0.30 | Apache-2.0 | PyPI | metadata |
| pyyaml | 6.0.3 | MIT | PyPI | metadata |
| qh3 | 1.9.0 | BSD-3-Clause | PyPI | classifier |
| qrcode | 8.2 | BSD-3-Clause | PyPI | classifier |
| recurring-ical-events | 3.8.2 | **LGPL-3.0-or-later** | PyPI | expression |
| referencing | 0.37.0 | MIT | PyPI | metadata |
| requests | 2.34.2 | Apache-2.0 | PyPI | metadata |
| rich | 15.0.0 | MIT | PyPI | classifier |
| rpds-py | 2026.5.1 | MIT | PyPI | metadata |
| shellingham | 1.5.4 | ISC | PyPI | classifier |
| six | 1.17.0 | MIT | PyPI | metadata |
| soupsieve | 2.8.4 | MIT | PyPI | metadata |
| sqlalchemy | 2.0.50 | MIT | PyPI | metadata |
| sse-starlette | 3.4.4 | BSD-3-Clause | PyPI | metadata |
| starlette | 1.2.1 | BSD-3-Clause | PyPI | metadata |
| tenacity | 9.1.4 | Apache-2.0 | PyPI | metadata |
| tokenizers | 0.23.1 | Apache-2.0 | PyPI | classifier |
| tqdm | 4.67.3 | **MPL-2.0 AND MIT** | PyPI | expression |
| typer | 0.25.1 | MIT | PyPI | metadata |
| typing-extensions | 4.15.0 | PSF-2.0 | PyPI | expression |
| typing-inspection | 0.4.2 | MIT | PyPI | metadata |
| tzdata | 2026.2 | Apache-2.0 | PyPI | metadata |
| urllib3 | 2.7.0 | MIT | PyPI | metadata |
| urllib3-future | 2.21.901 | MIT | PyPI | metadata |
| uvicorn | 0.48.0 | BSD-3-Clause | PyPI | metadata |
| wassima | 2.1.0 | MIT | PyPI | metadata |
| x-wr-timezone | 2.0.1 | **LGPL-3.0-or-later** | PyPI | metadata |
| youtube-transcript-api | 1.2.4 | MIT | PyPI | metadata |

### Optional (`requirements-optional.txt`) — install-time opt-in

| Package | License | Note |
|---|---|---|
| duckduckgo-search (8.1.1) | MIT | permissive; pulls `primp` (MIT) |
| PyMuPDF (1.27.2.3) | **AGPL-3.0 or Artifex commercial** | already optional + documented; AGPL applies to the form-filling feature only |

### Dev-only (`requirements-dev.txt`) — not shipped, not distributed

`pytest` (MIT), `pytest-asyncio` (Apache-2.0), `pytest-randomly` (MIT), `ruff` (MIT), `iniconfig` (MIT), `pluggy` (MIT). All permissive; not part of the distributed artifact.

> Other packages present in the venv (`cyclonedx-python-lib`, `pip-audit`, `pip_audit`, `cachecontrol`, etc., all Apache-2.0/MIT) are audit/SBOM tooling, not project dependencies — excluded from obligations.

---

## Tooling used

- `importlib.metadata` over the project `.venv` (Python 3.14.5) for authoritative installed-license metadata (License-Expression, License field, classifiers, bundled LICENSE files).
- `importlib.metadata.requires("caldav")` to confirm the AGPL/LGPL subtree is a hard (non-extra) requirement.
- Cross-referenced against pinned `requirements.txt` / `requirements-optional.txt` / `requirements-dev.txt` and the existing `ACKNOWLEDGMENTS.md` + `licenses/`.
- `pip-licenses` was not installed; the venv metadata path above is equivalent for this purpose. For a high-stakes release, run a source-level scanner (`scancode-toolkit`) and have legal review.

## Caveats

- Automated audit, not legal advice. AGPL/LGPL "reach" into a Python app via transitive deps is fact-specific; the HIGH finding flags exposure so you can decide.
- **`fastembed`'s PyPI classifier is wrong** ("Other/Proprietary License"); its bundled LICENSE is Apache-2.0. Worth remembering — tooling that trusts the classifier will mis-flag it as proprietary.
- **`caldav` 3.x is the regression vector**: it made `icalendar-searcher` (AGPL) a hard requirement, so simply electing Apache-2.0 *for caldav* no longer keeps the install AGPL-free. Pinning the caldav major version is the cleanest fix.
- Re-run this audit after any change to `requirements*.txt`.
