"""Fast, dependency-free tests for the offline release verifier."""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

import build_protected as target


class ManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / "bundle"
        self.bundle.mkdir()
        (self.bundle / "soc_app").write_bytes(b"\x7fELFbinary")
        (self.bundle / "lib").mkdir()
        (self.bundle / "lib/libapp.so").write_bytes(b"\x7fELFdart-aot")
        (self.bundle / "lib/libflutter_linux_gtk.so").write_bytes(b"\x7fELFflutter")
        (self.bundle / "data/flutter_assets").mkdir(parents=True)
        (self.bundle / "data/flutter_assets/AssetManifest.bin").write_bytes(b"manifest")
        self.manifest = self.root / "manifest.json"

    def save(self) -> None:
        self.manifest.write_text(
            json.dumps({"files": target.manifest_of(self.bundle)}), encoding="utf-8"
        )

    def test_runtime_layout(self) -> None:
        target.verify_runtime_layout("linux", self.bundle)

    def test_runtime_layout_rejects_missing_critical_file(self) -> None:
        (self.bundle / "lib/libapp.so").unlink()
        with self.assertRaisesRegex(RuntimeError, "lib/libapp.so"):
            target.verify_runtime_layout("linux", self.bundle)

    def test_manifest_accepts_unmodified_bundle(self) -> None:
        self.save()
        target.verify_manifest(self.manifest, self.bundle)

    def test_manifest_rejects_modified_file(self) -> None:
        self.save()
        (self.bundle / "soc_app").write_bytes(b"changed")
        with self.assertRaisesRegex(RuntimeError, "changed="):
            target.verify_manifest(self.manifest, self.bundle)

    def test_manifest_rejects_added_file(self) -> None:
        self.save()
        (self.bundle / "extra").write_text("injected")
        with self.assertRaisesRegex(RuntimeError, "extra="):
            target.verify_manifest(self.manifest, self.bundle)

    def test_archive_has_expected_root(self) -> None:
        tar = self.root / "bundle.tar.gz"
        target.archive_bundle("linux", self.bundle, tar)
        import tarfile
        with tarfile.open(tar) as stream:
            names = stream.getnames()
        self.assertIn("SOC-Shield/lib/libapp.so", names)


if __name__ == "__main__":
    unittest.main()
