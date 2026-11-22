"""Verify protected native SOC calculation against 80 original reference points."""
from __future__ import annotations

import ctypes
import math
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from protected_soc_generate import (
    DART, DEPTHS, EROSIONS, TREATMENTS, generate, parse_reference_data,
)


class ProtectedSocTests(unittest.TestCase):
    def test_exact_existing_soc_values(self) -> None:
        values = parse_reference_data(DART.read_text(encoding="utf-8"))
        self.assertEqual(80, len(values))
        self.assertEqual(2390, values[0])
        self.assertEqual(2390, values[40])
        self.assertTrue(all(0 <= value <= 10000 for value in values))

    @unittest.skipUnless(shutil.which("g++"), "g++ required for native verification")
    def test_encrypted_native_answers_match_all_80_reference_values(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            cpp = root / "native.cc"
            lib = root / "native.so"
            expected = generate(cpp)
            generated = cpp.read_bytes()
            self.assertNotIn(b"23.90", generated)
            self.assertIn(b"EVP_aes_256_gcm", generated)

            subprocess.run(["g++", "-std=c++17", "-O2", "-fPIC", "-shared",
                            str(cpp), "-o", str(lib), "-lcrypto"],
                           check=True, capture_output=True, text=True)
            obj = ctypes.CDLL(str(lib))
            access = obj.soc_data_access
            access.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int]
            access.restype = ctypes.c_double

            i = 0
            for t in range(len(TREATMENTS)):
                for erosion in EROSIONS:
                    for depth in DEPTHS:
                        self.assertAlmostEqual(expected[i] / 100.0,
                                               access(t, erosion, depth),
                                               places=10, msg=f"{t=} {erosion=} {depth=}")
                        i += 1
            self.assertEqual(80, i)
            self.assertTrue(math.isnan(access(-1, 0, 10)))
            self.assertTrue(math.isnan(access(0, 80, 10)))
            self.assertTrue(math.isnan(access(0, 0, 99)))

            # Corrupt the authenticated tag, then compile the deliberately
            # altered image. AES-GCM MUST fail rather than return bad SOC data.
            tampered = generated.decode("utf-8")
            start = tampered.index("static const unsigned char kProtectedTag")
            at = tampered.index("0x", start)
            original = tampered[at:at+4]
            substitute = "0x00" if original != "0x00" else "0xff"
            mutated = tampered[:at] + substitute + tampered[at+4:]
            altered_cpp = root / "tampered.cc"
            altered_cpp.write_text(mutated, encoding="utf-8")
            altered_lib = root / "tampered.so"
            subprocess.run(["g++", "-std=c++17", "-O2", "-fPIC", "-shared",
                            str(altered_cpp), "-o", str(altered_lib), "-lcrypto"],
                           check=True, capture_output=True, text=True)
            broken = ctypes.CDLL(str(altered_lib)).soc_data_access
            broken.argtypes = access.argtypes
            broken.restype = ctypes.c_double
            self.assertTrue(math.isnan(broken(0, 0, 10)))


if __name__ == "__main__":
    unittest.main()
