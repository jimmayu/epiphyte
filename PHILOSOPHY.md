# Epiphyte philosophy

Epiphyte is a collection of maximally simple, copy-pasteable CLI recipes for fundamental security jobs. A tech-savvy person should be able to open a recipe in the browser, paste commands into a stock terminal on a locked-down machine, and get real security properties they can verify by reading every character.

No clone required to *use* a recipe. No wordlists. No sidecar files. No custom binaries. No “download our tool.”

An epiphyte lives on a host without becoming the host. These recipes should work on grandma’s laptop without taking it over.

## Audience

Tech-savvy users who understand why local crypto helpers matter — and who are stuck on machines where better tools cannot or should not be installed.

This is not for average consumers. It is also not for people who can freely `brew install` whatever they want. If you can install a real password manager or OpenSSL yourself, do that. Epiphyte is for the constrained case.

## Core principles

1. **Simplicity and portability.** Complexity makes verification and trust harder.
2. **Copy-paste from the markdown.** Recipes must be self-contained on the page.
3. **Stock OS tools only.** A recipe must not tell you to install packages. If a tool is missing, say so and stop.
4. **Prefer strong RNG.** Use `/dev/random` (or the platform CSPRNG equivalent) over `/dev/urandom` when generating secrets. Document when `/dev/random` may block.
5. **No network in recipes.** Do not pipe secrets into `curl` or websites. Browser VMs (for example WebVM) are fine for throwaway learning, not for real master passphrases.
6. **Don’t leak secrets into `ps` or shell history.** Prefer stdin / secret reads; document when a flag will show in process lists.
7. **Correctness over cleverness.** Boring, standard constructions beat cute one-liners.
8. **Omit rather than weaken.** If a platform cannot do a recipe safely with stock tools, omit that platform. No quiet weaker defaults.

## Tools

| Platform | Default toolbox |
|----------|-----------------|
| Windows | PowerShell + .NET crypto only. No OpenSSL requirement. No Git Bash or WSL required. |
| macOS / Linux | Shell + `/dev/random`. System OpenSSL/LibreSSL is allowed **if already present** (check first; never `brew`/`apt` install as part of the recipe). |

- **Python 3** is not used in default recipes.
- **OpenSSL-only** features (for example scrypt) may exist as **advanced badges**, not as defaults.
- Same *output* matters more than same *binary*. Windows may use .NET while Unix uses OpenSSL, as long as documented parameters produce identical results where we promise that.

## Cross-platform output

| Recipe kind | Must match across OS? |
|-------------|------------------------|
| Deterministic site passwords | **Yes** — same master + keyword + versioned params → same password on Windows and Mac/Linux |
| Random password generation | No (fresh entropy each time) |
| File encrypt / decrypt | Best-effort / later — not a day-one requirement |

## Versioning

- Deterministic password recipes are **explicitly versioned** (for example `epiphyte-pw/1`). Old versions stay in the repo forever.
- Changing iterations, charset mapping, or keyword encoding requires a **new version**. Silent breaks are forbidden.
- Other stable recipes **freeze**: bug fixes must not change security-relevant output.
- Never treat login-secret recipes as “living docs.”

## Threat model ceiling

Epiphyte defaults are aimed at **online attackers** and **GPU guessing of a master passphrase** (high, frozen PBKDF2 iteration counts; optional memory-hard badge where stock OpenSSL scrypt exists).

We **do not** claim nation-state resistance, “military-grade” security, or protection against a forensic lab with your hardware.

Especially for deterministic site passwords:

- The site/service keyword must be typed ** identically** every time (`google` ≠ `google.com`).
- If the master passphrase leaks, **every** derived login password leaks.
- This is **not** a full password manager (no per-site overrides, no breach workflow beyond “change master and rotate”).

## In scope

Local copy-paste recipes for:

- Random charset password generation
- Versioned deterministic site passwords (master + site/service keyword via PBKDF2)
- Hashing
- File encrypt / decrypt
- Small encode / decode helpers

## Out of scope (permanent)

- Full password managers as products
- Browser or WebVM workflows for real secrets
- TLS / HTTPS setup
- Disk encryption (BitLocker, FileVault, etc.)
- SSH / GPG as a key-management lifestyle guide
- Messaging apps
- Custom binaries or installers
- Anything that needs a network account to function

Thin `ssh-keygen`-style keypair generation may appear later as a narrow exception. It is not a current promise.

## Recipe shape (planned)

One markdown file per recipe, roughly:

- Title and one-sentence purpose
- When to use / when not to use
- Prerequisites
- Threat model (short)
- Linux / macOS commands
- Windows PowerShell commands
- Verify
- Notes

Planned layout: `recipes/<category>/<id>.md`, plus a short root README index.

## First recipes (planned, not implemented here)

1. Charset password generation from OS CSPRNG
2. Versioned deterministic login-password derivation (PBKDF2-HMAC-SHA256)
3. File encrypt / decrypt (cross-platform interop later)
