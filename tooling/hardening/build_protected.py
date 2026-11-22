#!/usr/bin/env python3
"""Build and verify an obfuscated SOC-Shield desktop release.

All build flags target the compiled release. Do not modify the scientific
calculation engine or introduce debug-sensitive behavior.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "soc_app"


def run(argv: list[str], cwd: Path = APP) -> str:
    print("+", " ".join(argv), flush=True)
    process = subprocess.run(argv, cwd=cwd, check=True, text=True,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(process.stdout[-3000:], flush=True)
    return process.stdout


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_runtime_layout(platform: str, directory: Path) -> None:
    if platform == "linux":
        required = ("soc_app", "lib/libapp.so", "lib/libflutter_linux_gtk.so",
                    "data/flutter_assets/AssetManifest.bin")
    else:
        required = ("soc_app.exe", "flutter_windows.dll", "data/app.so",
                    "data/flutter_assets/AssetManifest.bin")
    missing = [p for p in required if not (directory / p).is_file()]
    if missing:
        raise RuntimeError("Release bundle missing: " + ", ".join(missing))


def manifest_of(directory: Path) -> dict[str, dict[str, str | int]]:
    files = {}
    for path in sorted(directory.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(directory).as_posix()
        if path.is_symlink():
            # Symlinks may point outside the release bundle. Reject rather
            # than silently shipping external host dependencies.
            raise RuntimeError(f"Symlink in release bundle: {rel}")
        files[rel] = {"bytes": path.stat().st_size, "sha256": sha256(path)}
    return files


def archive_bundle(platform: str, directory: Path, target: Path) -> None:
    if platform == "linux":
        with tarfile.open(target, "w:gz") as archive:
            archive.add(directory, arcname="SOC-Shield")
    else:
        with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED,
                             compresslevel=9) as archive:
            for file in sorted(directory.rglob("*")):
                if file.is_file():
                    archive.write(file, "SOC-Shield/" +
                                  file.relative_to(directory).as_posix())


def verify_manifest(manifest_file: Path, bundle: Path) -> None:
    record = json.loads(manifest_file.read_text(encoding="utf-8"))
    expected = record["files"]
    actual = manifest_of(bundle)
    if expected != actual:
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        modified = sorted(k for k in set(actual) & set(expected)
                          if actual[k] != expected[k])
        raise RuntimeError(
            f"Integrity mismatch: missing={missing}, extra={extra}, changed={modified}"
        )
    print(f"Integrity PASS: {len(expected)} files", flush=True)


def build(args: argparse.Namespace) -> None:
    target = args.output.expanduser().resolve()
    # Guard against accidentally wiping parts of the source checkout.
    if target == ROOT or target == APP or APP in target.parents:
        raise SystemExit("Output must not be the project or a subdirectory of soc_app")
    private_symbols = target / "private-symbols" / args.platform
    public = target / "public"
    package_dir = target / "bundles" / args.platform
    private_symbols.mkdir(parents=True, exist_ok=True)
    public.mkdir(parents=True, exist_ok=True)
    target_bundle = package_dir / "SOC-Shield"
    if target_bundle.exists():
        shutil.rmtree(target_bundle)
    target_bundle.parent.mkdir(parents=True, exist_ok=True)

    if not args.skip_tests:
        run([args.flutter, "pub", "get"])
        run(["dart", "analyze", "lib"])
        run([args.flutter, "test"])
    else:
        run([args.flutter, "pub", "get"])

    command = [args.flutter, "build", args.platform, "--release", "--obfuscate",
               f"--split-debug-info={private_symbols}"]
    run(command)

    relative = ("build/linux/x64/release/bundle" if args.platform == "linux"
                else "build/windows/x64/runner/Release")
    built_bundle = APP / relative
    verify_runtime_layout(args.platform, built_bundle)
    shutil.copytree(built_bundle, target_bundle, symlinks=False)

    file_index = manifest_of(target_bundle)
    forbidden_suffixes = (".dart", ".symbols", ".pdb", ".map.json")
    leaks = [name for name in file_index if name.lower().endswith(forbidden_suffixes)]
    if leaks:
        raise RuntimeError("Debug/source artifacts unexpectedly distributed: "
                           + ", ".join(leaks))

    revision = run(["git", "rev-parse", "HEAD"], ROOT).strip().splitlines()[-1]
    metadata = {
        "application": "SOC-Shield",
        "build_profile": "flutter-release-aot-obfuscated",
        "platform": args.platform,
        "source_commit": revision,
        "protections": {
            "dart_obfuscation": True,
            "split_debug_info": True,
            "debug_symbols_in_public_archive": False,
            "runtime_antidebug": False,
            "dynamic_packer": False,
        },
        "files": file_index,
    }
    manifest_path = public / f"soc-shield-{args.platform}-manifest.json"
    manifest_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False)
                             + "\n", encoding="utf-8")
    verify_manifest(manifest_path, target_bundle)
    name = ("soc-shield-linux-x64.tar.gz" if args.platform == "linux"
            else "soc-shield-windows-x64.zip")
    archive_path = public / name
    archive_bundle(args.platform, target_bundle, archive_path)
    archive_hash = sha256(archive_path)
    (public / f"{name}.sha256").write_text(
        f"{archive_hash}  {name}\n", encoding="utf-8"
    )
    print(f"PUBLIC_ARCHIVE={archive_path}")
    print(f"ARCHIVE_SHA256={archive_hash}")
    print(f"PRIVATE_SYMBOLS={private_symbols} (do NOT publish)")
    print("PASS: release bundle packaged and manifest verified")
    print("NOT VERIFIED: actual GUI runtime and scientific workflow correctness")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("linux", "windows"), required=True)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--output", type=Path, default=ROOT / ".hardening-out")
    parser.add_argument("--skip-tests", action="store_true",
                        help="Only when equivalent tests have already passed on same commit")
    parser.add_argument("--verify-manifest", type=Path)
    parser.add_argument("--bundle", type=Path)
    args = parser.parse_args()
    if args.verify_manifest:
        if not args.bundle:
            parser.error("--bundle is required with --verify-manifest")
        verify_manifest(args.verify_manifest, args.bundle)
        return
    if not APP.is_dir():
        raise SystemExit("soc_app checkout not found")
    build(args)


if __name__ == "__main__":
    main()
