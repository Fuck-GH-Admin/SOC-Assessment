# SOC-Shield / REA reverse-engineering resistance experiment

**Branch:** `experiment/rea-soc-hardening-20261123`
**Upstream:** `main` (do not merge until acceptance passes)
**Status:** hardening toolchain committed; **not an accepted commercial release**.

## Purpose and scope

Produce a separate, evidence-backed, obfuscated Flutter Release build for
blind testing against REA. Preserve all original SOC calculations, UI flows,
data, PDF export, local storage, and optional AI functionality.
The application must not become hostile to debuggers, accessibility tools,
antivirus products, or ordinary users.

This is **binary protection**, not encryption of all executable logic.
Flutter's AOT compiler produces machine code; official obfuscation flags
rename program identifiers. Distributed assets and business constants
should still be treated as recoverable by motivated analysts.

## Implemented protections (subject to a successful build)

1. Compile Dart in Flutter Release AOT mode, with `--obfuscate` and
   `--split-debug-info`.
2. Keep generated symbol information under a **private** output directory,
   outside the archive and outside source control.
3. Apply stack protector, FORTIFY, full RELRO, immediate binding (NOW),
   and non-executable stack to the Linux C++ launcher. These harden the
   launcher; they do not recompile the Flutter engine or prebuilt plugins.
4. Verify required Flutter runtime and AOT files exist, and generate a
   SHA-256 manifest covering **every distributed file**.
5. Reject .dart, .symbols, .pdb and .map.json files from the public bundle.
6. Run the Dart analyzer and Flutter test suite before packaging.
7. Keep all modifications on this isolated experiment branch.

The hash manifest enables reproducibility and damage detection against a
trusted copy, but is **not a digital signature**. For authenticated
distribution, sign a release digest with a private publisher-managed key
stored outside source control.

## Not implemented / unsupported claims

- No dynamic self-decrypting packer, multi-layer executable shell, runtime
  anti-debugging, environment fingerprinting, or self-modifying code.
- No attempt to double the source code with defensive junk. Line count is not
  a meaningful measure of security.
- No claim that client-side constants, data and logic are impossible to recover.
- No guarantee of full feature compatibility from compilation alone.
  Linux desktop is still a planned, not officially supported, product target.

## Build

Project baseline: Flutter **3.44.2**, Dart **3.12.2**.

On a supported Ubuntu build host with Flutter and GTK/SQLite/libsecret dev
dependencies installed:

~~~bash
flutter config --enable-linux-desktop
python3 -m unittest discover -s tooling/hardening -p 'test_*.py'
python3 tooling/hardening/build_protected.py \
  --platform linux --output "$PWD/.hardening-out"
~~~

On a Windows build host equipped with MSVC and ATL:

~~~powershell
python tooling/hardening/build_protected.py --platform windows
~~~

Outputs under `.hardening-out/`:

- `public/soc-shield-linux-x64.tar.gz`: distributable archive
- `public/soc-shield-linux-manifest.json`: file digests
- `public/*.sha256`: archive digest
- `private-symbols/linux/`: **keep private**
- `bundles/linux/SOC-Shield/soc_app`: ELF launcher
- `bundles/linux/SOC-Shield/lib/libapp.so`: Dart AOT ELF

**Use the full extracted bundle**, not just the launcher. Flutter requires
engine binaries, AOT library, native libraries and its asset directory.

The branch-specific GitHub Actions workflow
`.github/workflows/rea-hardening-linux.yml` attempts a Linux build and
uploads only public artifacts if tests and compilation succeed.

## Acceptance before calling it functional

Compare the baseline and hardened variants with identical test fixtures:

| Area | Required comparison |
|---|---|
| Scientific calculations | Exact numeric results and static assumptions |
| Persistence | Records, history, draft restore, import/export |
| Reports | PDF output and Chinese font rendering |
| UI | Launch, charts, themes, navigation |
| Performance | Startup, RAM, binary size, CPU |
| Reverse engineering | Recovered algorithms, evidence, hallucinations |
| Recovery | Symbol storage, hash records, crash diagnosis |

Blind REA testing should receive only the packaged binary and a predefined
question set, never the source or evaluation fixtures. Testers should record
both correct findings and false claims.

**Stop condition:** if calculations, saved reports, persisted data, or UI
behavior differ from baseline, reject this release profile. CI tests alone
are not end-to-end GUI functional acceptance.
