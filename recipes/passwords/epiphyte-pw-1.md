# Deterministic site password (epiphyte-pw/1)

**Version:** `epiphyte-pw/1` (frozen). Same master + keyword always yields the same password on stock Windows PowerShell and on Mac/Linux with system OpenSSL. Breaking changes require `epiphyte-pw/2` and leave this file untouched.

Turn a master passphrase plus a site/service keyword into a 20-character login password.

## When to use

- You want the same site password on grandma's Windows box and a Mac/Linux machine without installing a password manager.
- You can remember one strong master and a simple keyword per site.

## When not to use

- As a full password manager (no per-site overrides, no breach workflow beyond changing the master and rotating).
- With a browser VM or website holding the master (see PHILOSOPHY.md).
- If OpenSSL is missing on Unix and you cannot use the PowerShell recipe instead.

## Prerequisites

| Platform | Need |
|----------|------|
| Linux / macOS | POSIX shell, system `openssl` 3.x with `openssl kdf` (OpenSSL or LibreSSL may differ; see Notes). |
| Windows | PowerShell with .NET supporting `Rfc2898DeriveBytes` + `HashAlgorithmName.SHA256` (.NET Framework 4.7.2+ / recent Windows 10+, or PowerShell 7). |

If those are missing, **omit** this platform. Do not install packages as part of the recipe.

## Threat model

Designed against online attackers and GPU guessing of the master (high frozen iteration count).

- The keyword must be typed **exactly** the same every time (`google` is not `google.com`).
- If the master leaks, every derived site password leaks.
- We do **not** claim nation-state resistance.

## Defaults (frozen in /1)

| Knob | Value |
|------|--------|
| KDF | PBKDF2-HMAC-SHA256 |
| Iterations | `600000` |
| Master | UTF-8 bytes of the passphrase |
| Salt | UTF-8 bytes of the keyword (exact string) |
| Raw derive length | 128 bytes |
| Output length | 20 |
| Alphabet | same as random-charset recipe (73 chars): `A-Za-z0-9` + `!@#%^*_+-=?` |
| Mapping | rejection sampling over derived bytes |

Alphabet string:

```text
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+-=?
```

## Recipe

### Linux / macOS

Requires `openssl kdf`. Master may appear briefly in process listings via `-kdfopt pass:...` (see Notes).

```sh
printf 'Master passphrase: ' >&2
stty -echo
IFS= read -r MASTER
stty echo
printf '\n' >&2
printf 'Site/service keyword: ' >&2
IFS= read -r KEYWORD
printf '\n' >&2

ALPH='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+-=?'
LEN=20
ITER=600000
LC_ALL=C
n=${#ALPH}
thresh=$((256 - 256 % n))

hex=$(openssl kdf -keylen 128 \
  -kdfopt digest:SHA256 \
  -kdfopt "pass:${MASTER}" \
  -kdfopt "salt:${KEYWORD}" \
  -kdfopt "iter:${ITER}" \
  PBKDF2 | tr -d ':\n ')

out=
i=0
hlen=${#hex}
while [ "${#out}" -lt "$LEN" ] && [ "$i" -lt "$hlen" ]; do
  pair=${hex:i:2}
  i=$((i + 2))
  b=$((16#$pair))
  [ "$b" -ge "$thresh" ] && continue
  out="${out}$(printf '%s' "$ALPH" | dd bs=1 count=1 skip=$((b % n)) 2>/dev/null)"
done

printf '%s\n' "$out"
unset MASTER KEYWORD ALPH LEN ITER n thresh hex out i hlen pair b
```

If `openssl kdf` errors, stop. Do not switch algorithms.

### Windows (PowerShell)

```powershell
$Master = Read-Host 'Master passphrase' -AsSecureString
$Keyword = Read-Host 'Site/service keyword'
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Master)
try {
  $MasterPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) | Out-Null
}

$Alph = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+-=?'
$Len = 20
$Iter = 600000
$n = $Alph.Length
$thresh = 256 - (256 % $n)

$salt = [Text.Encoding]::UTF8.GetBytes($Keyword)
$derive = [Security.Cryptography.Rfc2898DeriveBytes]::new(
  $MasterPlain,
  $salt,
  $Iter,
  [Security.Cryptography.HashAlgorithmName]::SHA256
)
$bytes = $derive.GetBytes(128)
$derive.Dispose()

$chars = New-Object char[] $Len
$i = 0
foreach ($b in $bytes) {
  if ($b -ge $thresh) { continue }
  $chars[$i] = $Alph[$b % $n]
  $i++
  if ($i -ge $Len) { break }
}
if ($i -lt $Len) { throw 'Not enough derived bytes; do not improvise.' }
-join $chars

$MasterPlain = $null
$Master = $null
```

If `HashAlgorithmName` / this constructor is missing, your .NET is too old for `/1`. Omit rather than falling back to SHA1.

## Verify

1. On one machine, master `test-master` and keyword `example.com` must produce:

```text
*d0^ys#+BZ#Fu50rd-EM
```

2. Run the same inputs on the other platform. The string must match exactly.
3. Change one character of the keyword. The password must change.
4. Do not paste the master into a website to "test" it.

## Notes

**Process listings (Unix)**  
`openssl ... -kdfopt pass:${MASTER}` can expose the master in `ps` while it runs. Keep the session brief and local. A future version may use a safer pass source if we can do it without breaking `/1` output.

**LibreSSL**  
Some Macs ship LibreSSL. If `openssl kdf` is missing or PBKDF2 output differs, this Unix recipe does not apply. Use another machine or PowerShell. Do not "fix" with another KDF.

**Keyword hygiene**  
Pick a rule and keep it (for example always the registrable domain: `example.com`). Write your rule down offline. Epiphyte will not normalize for you.

**Not in /1**  
Memory-hard scrypt, raw 256-bit keys, alphanumeric-only output. Those need new version ids if added.

## See also

- [PHILOSOPHY.md](../../PHILOSOPHY.md)
- [Generate a random password (charset)](./random-charset.md)
