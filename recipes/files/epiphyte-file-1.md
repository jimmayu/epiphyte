# File encrypt / decrypt (epiphyte-file/1)

**Version:** `epiphyte-file/1` (frozen). Passphrase-protect a single file with AES-256-CBC and PBKDF2. Unix uses system OpenSSL; Windows uses PowerShell/.NET. Both write the same **OpenSSL `Salted__` binary** layout so a file encrypted on one side can be decrypted on the other when parameters match.

## When to use

- You need a portable encrypted copy of one file on a stock machine (no installs).
- You can remember or store a strong passphrase separately from the ciphertext.

## When not to use

- Full-disk encryption (BitLocker, FileVault, LUKS) or archive tools with many options.
- Authenticated encryption as a day-one requirement: `/1` is CBC + PKCS#7, **not** AEAD. A wrong passphrase or a tampered file may fail decrypt or (rarely) yield garbage without a clear authentication error. A future version may add GCM or encrypt-then-MAC.
- Deriving the file key from an `epiphyte-pw/1` **login** password. Use a dedicated passphrase (or fresh random secret).
- Browser VMs or websites holding the passphrase (see PHILOSOPHY.md).

## Prerequisites

| Platform | Need |
|----------|------|
| Linux / macOS | POSIX shell, system `openssl` with `enc -aes-256-cbc -pbkdf2 -iter` (OpenSSL 1.1.1+ / 3.x). |
| Windows | PowerShell with .NET `Aes`, `Rfc2898DeriveBytes` + `HashAlgorithmName.SHA256` (.NET Framework 4.7.2+ / recent Windows 10+, or PowerShell 7). |

If those are missing, **omit** this platform. Do not install packages as part of the recipe.

LibreSSL on some Macs may reject flags or disagree on PBKDF2. If encrypt/decrypt fails or cross-OS decrypt fails, stop — do not invent a weaker fallback.

## Threat model

Confidentiality of the file contents against someone who has the ciphertext but not the passphrase (online attacker / offline guessing slowed by 600000 PBKDF2 iterations).

Does **not** claim authenticity against an active attacker who flips ciphertext bits, nation-state resistance, or safety if the passphrase is short or reused from a login password.

## Defaults (frozen in /1)

| Knob | Value |
|------|--------|
| Cipher | AES-256-CBC, PKCS#7 padding |
| KDF | PBKDF2-HMAC-SHA256 |
| Iterations | `600000` |
| Salt | 8 random bytes |
| File layout | `Salted__` (8) + salt (8) + ciphertext |
| Passphrase | UTF-8 bytes (no trailing newline in the pipe) |
| Key / IV | first 32 / next 16 bytes of a 48-byte PBKDF2 derive |

This matches OpenSSL `enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -salt`.

## Recipe

Set paths first (examples):

```sh
IN=secret.txt
OUT=secret.txt.enc
```

```powershell
$In = 'secret.txt'
$Out = 'secret.txt.enc'
```

### Linux / macOS — encrypt

```sh
# IN=plaintext path, OUT=ciphertext path (.enc)
printf 'Passphrase: ' >&2
stty -echo
IFS= read -r PASS
stty echo
printf '\n' >&2
printf '%s' "$PASS" | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -salt \
  -pass stdin -in "$IN" -out "$OUT"
unset PASS
```

### Linux / macOS — decrypt

```sh
# IN=ciphertext (.enc), OUT=recovered plaintext
printf 'Passphrase: ' >&2
stty -echo
IFS= read -r PASS
stty echo
printf '\n' >&2
printf '%s' "$PASS" | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \
  -pass stdin -in "$IN" -out "$OUT"
unset PASS
```

If OpenSSL prints `bad decrypt`, the passphrase is wrong or the file is not `/1` ciphertext. Do not keep the bad `OUT`.

### Windows (PowerShell) — encrypt

```powershell
# $In = plaintext path; $Out = ciphertext path (.enc)
$PassSecure = Read-Host 'Passphrase' -AsSecureString
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PassSecure)
try {
  $PassPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) | Out-Null
}
$passBytes = [Text.Encoding]::UTF8.GetBytes($PassPlain)
$PassPlain = $null
$PassSecure = $null

$Iter = 600000
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$salt = New-Object byte[] 8
$rng.GetBytes($salt)
$rng.Dispose()

$derive = [Security.Cryptography.Rfc2898DeriveBytes]::new(
  $passBytes, $salt, $Iter, [Security.Cryptography.HashAlgorithmName]::SHA256)
$dk = $derive.GetBytes(48)
$derive.Dispose()
$key = $dk[0..31]
$iv = $dk[32..47]

$aes = [Security.Cryptography.Aes]::Create()
$aes.Mode = [Security.Cryptography.CipherMode]::CBC
$aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
$aes.Key = $key
$aes.IV = $iv
$encryptor = $aes.CreateEncryptor()
$plain = [IO.File]::ReadAllBytes((Resolve-Path $In))
$cipher = $encryptor.TransformFinalBlock($plain, 0, $plain.Length)
$encryptor.Dispose()
$aes.Dispose()

$header = [Text.Encoding]::ASCII.GetBytes('Salted__')
[IO.File]::WriteAllBytes((Join-Path (Get-Location) $Out), ($header + $salt + $cipher))

[Array]::Clear($passBytes, 0, $passBytes.Length)
[Array]::Clear($dk, 0, $dk.Length)
[Array]::Clear($key, 0, $key.Length)
[Array]::Clear($iv, 0, $iv.Length)
[Array]::Clear($plain, 0, $plain.Length)
```

### Windows (PowerShell) — decrypt

```powershell
# $In = ciphertext (.enc); $Out = recovered plaintext
$PassSecure = Read-Host 'Passphrase' -AsSecureString
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PassSecure)
try {
  $PassPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) | Out-Null
}
$passBytes = [Text.Encoding]::UTF8.GetBytes($PassPlain)
$PassPlain = $null
$PassSecure = $null

$Iter = 600000
$blob = [IO.File]::ReadAllBytes((Resolve-Path $In))
if ($blob.Length -lt 16) { throw 'File too short for Salted__ layout.' }
$magic = [Text.Encoding]::ASCII.GetString($blob, 0, 8)
if ($magic -ne 'Salted__') { throw 'Not an OpenSSL Salted__ file (epiphyte-file/1).' }
$salt = $blob[8..15]
$cipher = $blob[16..($blob.Length - 1)]

$derive = [Security.Cryptography.Rfc2898DeriveBytes]::new(
  $passBytes, $salt, $Iter, [Security.Cryptography.HashAlgorithmName]::SHA256)
$dk = $derive.GetBytes(48)
$derive.Dispose()
$key = $dk[0..31]
$iv = $dk[32..47]

$aes = [Security.Cryptography.Aes]::Create()
$aes.Mode = [Security.Cryptography.CipherMode]::CBC
$aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
$aes.Key = $key
$aes.IV = $iv
try {
  $decryptor = $aes.CreateDecryptor()
  $plain = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
  $decryptor.Dispose()
} catch {
  throw 'Decrypt failed (wrong passphrase or corrupt file). Do not keep a partial output.'
} finally {
  $aes.Dispose()
}

[IO.File]::WriteAllBytes((Join-Path (Get-Location) $Out), $plain)

[Array]::Clear($passBytes, 0, $passBytes.Length)
[Array]::Clear($dk, 0, $dk.Length)
[Array]::Clear($key, 0, $key.Length)
[Array]::Clear($iv, 0, $iv.Length)
[Array]::Clear($plain, 0, $plain.Length)
```

If `HashAlgorithmName` / this `Rfc2898DeriveBytes` constructor is missing, your .NET is too old for `/1`. Omit rather than falling back to SHA1.

## Verify

1. Encrypt a small text file, decrypt it, compare bytes (`cmp` / `fc /b`). They must match.
2. Decrypt with a wrong passphrase: OpenSSL should report `bad decrypt`; PowerShell should throw. Discard any bad output file.
3. **Cross-check (interop):** encrypt on Unix, decrypt on Windows (or the reverse) with the same passphrase. Plaintext must match. If it does not, stop and report — do not “fix” iterations or digests ad hoc.
4. Header of a `/1` file starts with ASCII `Salted__` (8 bytes) then 8 salt bytes.

Smoke vector used while developing (not a frozen ciphertext): passphrase `test-passphrase-not-real`, plaintext `hello epiphyte file/1\n`, OpenSSL 3.x round-trip OK on Linux.

## Notes

**Passphrase strength**  
Treat it like a master secret. Short or reused passphrases defeat the iteration count.

**Process listings / history**  
These recipes pipe or use SecureString so the passphrase is not a `pass:` CLI argument. Still avoid shell-history logging of pasted secrets and do not `echo` the passphrase.

**Binary vs Base64**  
`/1` writes **binary** `.enc` files. Do not add OpenSSL `-a` unless you intentionally invent a different recipe.

**Large files**  
PowerShell loads the whole file into memory. Huge blobs may need a streaming tool outside this recipe.

**Not in /1**  
AES-GCM, HMAC, scrypt, multi-file archives, streaming APIs, deriving keys from `epiphyte-pw/1`.

## See also

- [PHILOSOPHY.md](../../PHILOSOPHY.md)
- [Deterministic site password (epiphyte-pw/1)](../passwords/epiphyte-pw-1.md)
- [Generate a random password (charset)](../passwords/random-charset.md)
