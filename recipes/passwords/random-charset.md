# Generate a random password (charset)

Produce one high-entropy password from the operating system CSPRNG and print it once.

## When to use

- You need a fresh password to store in a password manager or set on a single account.
- You are on a stock machine and can paste a short recipe from this page.

## When not to use

- Memorable passphrases / diceware (Epiphyte does not ship wordlists).
- Deriving the *same* password every time for a site (see the deterministic site-password recipe, when published).
- Anything that requires installing tools or using a browser VM.

## Prerequisites

| Platform | Need |
|----------|------|
| Linux / macOS | POSIX shell, `dd`, `od`, `/dev/random` |
| Windows | PowerShell with .NET (`RandomNumberGenerator`) |

No package installs. If `/dev/random` or PowerShell crypto is missing, stop — do not fall back to a weak RNG.

## Threat model

This protects against guessing a freshly generated password (online attacker / GPU guessing of the password itself).

It does **not** protect you after you paste the password into a phishing page, leave it in terminal scrollback, or screenshot it. It does not claim nation-state resistance.

## Defaults (frozen)

| Knob | Value |
|------|--------|
| Length | `20` |
| Alphabet | `A–Z`, `a–z`, `0–9`, and `!@#%^*_+-=?` (74 characters) |
| Mapping | Rejection sampling so every alphabet character is equally likely |
| RNG | `/dev/random` (Unix) / `RandomNumberGenerator` (Windows) |

Alphabet string used below (same on both platforms):

```text
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+-=?
```

Symbols omit `$`, quotes, backticks, backslash, and other shell-hostile characters so pasting is safer. For letters and digits only, see Notes.

## Recipe

### Linux / macOS

Paste into Terminal. Uses `/dev/random` and rejection sampling.

```sh
ALPH='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+-=?'
LEN=20
LC_ALL=C
n=${#ALPH}
# Reject bytes that would bias modulo mapping: threshold = 256 - (256 % n)
thresh=$((256 - 256 % n))
out=
while [ "${#out}" -lt "$LEN" ]; do
  b=$(dd if=/dev/random bs=1 count=1 2>/dev/null | od -An -tu1)
  b=$(printf '%s' "$b" | tr -d ' \n')
  [ -n "$b" ] || continue
  [ "$b" -ge "$thresh" ] && continue
  out="${out}$(printf '%s' "$ALPH" | dd bs=1 count=1 skip=$((b % n)) 2>/dev/null)"
done
printf '%s\n' "$out"
unset ALPH LEN n thresh out b
```

Notes for this block:

- On a freshly booted or embedded device, `/dev/random` may block until the kernel has entropy. That is intentional.
- Do not replace `/dev/random` with `/dev/urandom` in this recipe unless you are changing the frozen method on purpose (that would be a different recipe).

### Windows (PowerShell)

Paste into PowerShell.

```powershell
$Alph = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+-=?'
$Len = 20
$n = $Alph.Length
$thresh = 256 - (256 % $n)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$buf = New-Object byte[] 1
$chars = New-Object char[] $Len
$i = 0
while ($i -lt $Len) {
  $rng.GetBytes($buf)
  if ($buf[0] -ge $thresh) { continue }
  $chars[$i] = $Alph[$buf[0] % $n]
  $i++
}
-join $chars
$rng.Dispose()
```

Do **not** use `Get-Random` or `System.Random`.

## Verify

1. Output length is exactly `20` (or your chosen `LEN`).
2. Every character is in the alphabet above.
3. Run the recipe twice — the two outputs differ.
4. Do not paste the password into an online “password strength” site.

## Notes

**History / leakage**

- Prefer copying from the terminal once into a password manager.
- Avoid `echo '…' > file` unless you understand leftover data on disk.
- Do not pass the generated password as a command-line argument to another program (it can show up in process listings).

**Alphanumeric-only variant**

Set the alphabet to letters and digits only (62 characters) and keep the same rejection-sampling loop:

```text
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789
```

**“Readable” variant**

If you must avoid ambiguous glyphs, drop `0O1lI` from the alphabet and keep rejection sampling. That is a different alphabet — document which one you used.

**Changing length**

Change `LEN` / `$Len` only. Do not “make it more secure” by switching to a non-CSPRNG.

## See also

- [PHILOSOPHY.md](../../PHILOSOPHY.md)
