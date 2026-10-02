from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from zipfile import ZIP_DEFLATED, ZipFile

from check_ipa_size import check_size


class IpaSizeTest(unittest.TestCase):
    def test_counts_frameworks_but_not_archive_metadata(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "app.ipa"
            with ZipFile(path, "w") as archive:
                archive.writestr("Payload/Runner.app/Runner", b"1234")
                archive.writestr("Payload/Runner.app/Frameworks/vision", b"123456")
                archive.writestr("metadata.txt", b"not installed")
            report = check_size(path)
            self.assertEqual(report["uncompressed_app_bytes"], 10)
            self.assertTrue(report["within_budget"])

    def test_compression_cannot_hide_an_oversized_app(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "app.ipa"
            with ZipFile(path, "w", compression=ZIP_DEFLATED) as archive:
                with archive.open("Payload/Runner.app/Runner", "w") as target:
                    for _ in range(66):
                        target.write(bytes(1_000_000))
            report = check_size(path)
            self.assertLess(report["ipa_bytes"], 1_000_000)
            self.assertEqual(report["uncompressed_app_bytes"], 66_000_000)
            self.assertFalse(report["within_budget"])

    def test_missing_payload_is_rejected(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "app.ipa"
            with ZipFile(path, "w") as archive:
                archive.writestr("metadata.txt", "empty")
            with self.assertRaises(ValueError):
                check_size(path)


if __name__ == "__main__":
    unittest.main()
