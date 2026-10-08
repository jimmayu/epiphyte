# Maintainer notes

For people editing this repo. Users should read [PHILOSOPHY.md](./PHILOSOPHY.md) and a recipe, not this file.

[PHILOSOPHY.md](./PHILOSOPHY.md) is the user-facing constitution: audience, stock tools, threat ceiling, scope, versioning. Do not paste review notes, tool matrices, or unsettled arguments into it. If a rule changes what a user must know to stay safe, it belongs there. If it only changes how we edit, it belongs here.

This file is a checklist, not a second philosophy. Prefer a short rule plus a pointer to the recipe over a restated essay. Delete sections that stop matching the tree.

## What is already decided

These are settled by PHILOSOPHY.md. Do not re-litigate them in a recipe PR:

- Copy-paste from the page. No install step. If the tool is missing, omit the platform.
- No network in recipes. Prefer stdin / secret reads. If a secret must appear in a command flag, the recipe has to say it can show up in process listings.
- Deterministic password recipes are versioned. Silent output changes are forbidden.
- Other stable recipes freeze security-relevant output.
- We do not claim nation-state resistance. Master compromise leaks every derived login password.
- Keyword strings are exact. We do not normalize domains.
- The promise is stock tools on the vast majority of Windows, Linux, and macOS machines, with compatible output. Memory-hard KDFs are advanced badges, not a replacement for PBKDF2 defaults. Do not relitigate that in a recipe PR.
- Do not bump frozen PBKDF2 iterations to feel stronger. `/1` is already at the 600000 HMAC-SHA256 published minimum. A higher count is a new id, a small GPU constant, and a user rotation. Prefer not to spend a version on it.
- PQC is for asymmetric recipes whose stock tools already have ML-KEM or ML-DSA on every platform that recipe claims. Symmetric recipes stay AES-256 / SHA-256. No install step.

## Crypto bar for a new recipe

- Name the construction, parameters, and encoding in a frozen table. No "or similar."
- Say what the attacker is, and what the recipe does not stop. Padding success is not authentication. Blocking `/dev/random` is not extra entropy after the kernel CSPRNG is seeded.
- Master or passphrase strength dominates iteration count. State that next to any KDF number. Do not call a PBKDF2 iteration count GPU-proof.
- Shell must not expand `$`, backticks, backslashes, or `!` inside secrets. Double-quoted `"pass:${SECRET}"` is a known failure. Before freezing a recipe, run it with a secret that contains `$`.
- Check tool exit status (`pipefail` or equivalent). Do not print a short or empty password when derivation fails or the byte string is exhausted. PowerShell already throws; shell must too.
- Distinguish bugfix from break. A quoting or error-handling fix that preserves output for all previously valid inputs may stay on the same id. Any change to KDF, iteration count, encoding, alphabet, or mapping is a new id. Old files stay.
- Do not add hashing or encode/decode recipes by copying a shell pattern that has an open erratum. Fix or explicitly waive the pattern first.

## Portability claims

A recipe may say "Linux / macOS" only for tools named in the recipe, not for the OS family.

- `openssl kdf` was run here on OpenSSL 3.0.13 only. Do not claim OpenSSL 1.1.1 or LibreSSL compatibility unless you have executed the recipe there. macOS system `openssl` is often LibreSSL. Untested means omitted, not "may differ."
- The shipped `epiphyte-pw/1` page still says LibreSSL "may differ." That wording is an open prose fix, not the rule above.
- Windows means the .NET APIs named in the recipe (for `/1` password and file recipes: `Rfc2898DeriveBytes` with `HashAlgorithmName.SHA256`). No SHA1 fallback.
- Same *documented* parameters must match across platforms when the recipe promises that. Same binary is not required.

Record the tool version you actually ran in the PR. Do not invent a supported-version matrix you have not executed.

## Review and vectors

Users never need this repo to *use* a recipe. Reviewers do.

- Every frozen deterministic output needs a vector in `verify/` (not added yet): inputs, raw KDF hex, and final password or ciphertext. Check the hex and the mapping separately so an alphabet bug is not mistaken for a KDF bug.
- File ciphertext vectors must fix the salt. A random-salt round trip does not prove interop.
- Reproduce at least one vector with a second implementation (for example Python `hashlib` or .NET), not only the recipe against itself.
- Windows interop is untested until someone runs the PowerShell on Windows. CI on Linux does not clear that claim. The SHA-256 file recipe is the exception: Windows PowerShell 5.1.26100.9444 `Get-FileHash` matched the published vectors (hello LF, empty file, filename with a space). Do not treat that as a pass for other recipes.
- Do not add a framework, package, or "helper CLI." A small script under `verify/` is allowed if the recipe page still stands alone.

## Open on purpose

Closed, do not reopen: memory-hard as the cross-platform default. Stock Windows .NET does not have scrypt or Argon2. See the promise in PHILOSOPHY.md.

Do not write these into PHILOSOPHY.md until we choose:

- `epiphyte-pw/1` double-quote expansion of master and keyword (`$`, backticks, `\`). Confirmed. Needs an erratum and a decision: byte-preserving bugfix vs `epiphyte-pw/2`.
- Unix hosts without OpenSSL 3 `kdf` have no password recipe. A fallback is a design problem, not a wording tweak.
- Whether `/dev/random` stays mandatory for random generation, or the philosophy is corrected to "seeded kernel CSPRNG; blocking is availability."
- `epiphyte-file/1` is not AEAD. Whether to warn harder in the recipe, ship a later AEAD id, or both.
- Password and file-encrypt vectors are not in-tree yet. The published password string `*d0^ys#+BZ#Fu50rd-EM` has been re-derived out of band; it is not checked by this repo. `verify/sha256-file.sh` checks the SHA-256 file recipe only.

## PR shape

- One recipe or one erratum per PR. Do not mix a new construction with a drive-by edit of a frozen command.
- Prose fixes that do not change commands are fine. If a command changes, say whether any previous input yields different output.
- Update the README index and the shipped list in PHILOSOPHY.md in the same PR as a new recipe.
- No changelog until we have a second prose-only revision worth listing. This file is not that changelog.
