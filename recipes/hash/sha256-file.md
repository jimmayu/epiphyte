# SHA-256 hash of a file

Print the SHA-256 fingerprint of a file: 64 lowercase hex characters. The same file bytes produce the same hash on Windows, Linux, and macOS.

This does not encrypt the file and does not prove who made it. It tells you whether two copies have the same bytes.

## When to use

- You want to check that a file was not changed or corrupted.
- Someone you trust published a SHA-256 hash, and you want to compare it to your copy.
- You want a fingerprint you can read over the phone or paste into a note.

## When not to use

- Hiding a file. Anyone can recompute this hash.
- Turning a password into a login secret. That is a different recipe (`epiphyte-pw/1`).
- Proving a person signed the file. This hash has no key.
- MD5 or SHA-1. Do not substitute them.

## Prerequisites

| Platform | Need |
|----------|------|
| Linux | `sha256sum` (coreutils) and `cut` |
| macOS | `shasum` (ships with macOS) and `cut` |
| Windows | PowerShell `Get-FileHash` (Windows 10 or newer, or PowerShell 7) |

No package installs. If the tool is missing, stop.

## Threat model

A matching hash means the file bytes match, **if** you got the expected hash from somewhere an attacker cannot change. If someone can replace both the file and the published hash, this check does not help.

SHA-256 is not a signature. It is not encryption. It does not claim nation-state resistance.

## Defaults (frozen)

| Knob | Value |
|------|--------|
| Algorithm | SHA-256 |
| Input | Exact file bytes. The filename is not hashed. |
| Output | 64 lowercase hex characters, then a newline. No filename. |
| Text vs binary | No text mode. A newline byte in the file changes the hash. |

Do not print uppercase. Windows `Get-FileHash` is uppercase until `.ToLower()`.

## Recipe

Set the path, then paste the block for your system. Quote paths that contain spaces.

### Linux / macOS

```sh
# Change this to your file.
FILE=secret.txt
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -- "$FILE" | cut -d ' ' -f 1
elif command -v shasum >/dev/null 2>&1; then
  shasum -a 256 -- "$FILE" | cut -d ' ' -f 1
else
  printf '%s\n' 'Need sha256sum (Linux) or shasum (macOS). Stop.' >&2
  exit 1
fi
```

Linux usually has `sha256sum`. macOS usually has `shasum` and not `sha256sum`. Either command hashes the same bytes. The recipe prints only the hash so the two tools match.

### Windows (PowerShell)

```powershell
# Change this to your file.
$File = 'secret.txt'
(Get-FileHash -Algorithm SHA256 -Path $File).Hash.ToLower()
```

Do not use `certutil` for this recipe. Its extra header lines are a different format.

If `Get-FileHash` is missing, stop. Do not fall back to MD5.

## Verify

1. The output is 64 characters, only `0-9` and `a-f`.
2. Hash the same file twice. The two lines match.
3. Change one byte. The hash changes.
4. **Known file.** Create a file whose bytes are exactly `hello epiphyte` plus one newline (the byte `0a`, not a Windows-only `\r\n`).

Linux / macOS:

```sh
printf 'hello epiphyte\n' > hello.txt
```

Windows (PowerShell):

```powershell
[IO.File]::WriteAllBytes('hello.txt', [Text.Encoding]::ASCII.GetBytes("hello epiphyte`n"))
```

The hash must be:

```text
c4ad2c6f007b94e68d0b0422712ab02a820ff4c0a6aea03808cd864cdf985bc4
```

An empty file must hash to:

```text
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

5. Hash the same `hello.txt` on another operating system. The 64 characters must match. Uppercase is not a match for this recipe — the PowerShell line lowercases it. `Get-FileHash` without `.ToLower()` prints `C4AD2C6F…`, which is the same digest in a different case.

## Notes

**Newlines**  
`hello epiphyte` and `hello epiphyte` plus Enter are different files. Type the check with `printf` or `WriteAllBytes`, not with an editor that adds `\r\n` or a final blank line, or the known hash will not match. Your real files should be hashed as they are; do not “fix” them to match a hash.

**What a match does not mean**  
It does not mean the file is safe to open. It means the bytes match the bytes someone hashed. Trust depends on how you received the expected hash.

**Large files**  
These tools stream the file. You do not need to load it into an editor.

**Checked tools**  
Linux `sha256sum`, macOS `shasum -a 256`, PowerShell 7.4.7 `Get-FileHash` (Microsoft’s PowerShell container, not a Windows kernel), and Windows PowerShell 5.1.26100.9444 `Get-FileHash` on Windows all produced the vectors above, including a filename with a space and a file with a zero byte. On 5.1, `.Hash` without `.ToLower()` was `C4AD2C6F007B94E68D0B0422712AB02A820FF4C0A6AEA03808CD864CDF985BC4` for the hello file — the same digest, uppercase. A file saved with Windows `\r\n` is a different hash from the published newline vector — that is the newline rule, not a tool mismatch. On that same 5.1 host, `Set-Content -Encoding Ascii` of `hello epiphyte` (which writes `\r\n`) hashed to `7c983a2badda47dcbc9903e935bd83550199e03f6fd64ea22cd00b9672a6d9de`, not the hello vector.

**Not in this recipe**  
SHA-512, HMAC, signing, hashing a typed password, Base64.

## See also

- [PHILOSOPHY.md](../../PHILOSOPHY.md)
- [File encrypt / decrypt (epiphyte-file/1)](../files/epiphyte-file-1.md)
