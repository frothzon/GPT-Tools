from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from gmtool.gm_cli import source_snapshot
from gmtool.transactions import apply_file_set, apply_single_file, sha256_bytes


class TransactionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.target = self.root / "code.gml"
        self.target.write_bytes(b"value = 1;\n")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_atomic_apply_and_journal(self) -> None:
        before = self.target.read_bytes()
        result = apply_single_file(
            self.target,
            b"value = 2;\n",
            expected_hash=sha256_bytes(before),
            journal_root=self.root / "journal",
            verify=lambda: [],
        )
        self.assertEqual(self.target.read_bytes(), b"value = 2;\n")
        self.assertTrue((result.journal / "manifest.json").is_file())
        self.assertFalse(result.rolled_back)

    def test_concurrent_edit_is_rejected(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "concurrent edit"):
            apply_single_file(
                self.target,
                b"value = 2;\n",
                expected_hash="0" * 64,
                journal_root=self.root / "journal",
            )
        self.assertEqual(self.target.read_bytes(), b"value = 1;\n")

    def test_verification_failure_rolls_back(self) -> None:
        before = self.target.read_bytes()
        with self.assertRaisesRegex(RuntimeError, "verification failed"):
            apply_single_file(
                self.target,
                b"value = 2;\n",
                expected_hash=sha256_bytes(before),
                journal_root=self.root / "journal",
                verify=lambda: ["bad syntax"],
            )
        self.assertEqual(self.target.read_bytes(), before)
        manifests = list((self.root / "journal").glob("*/manifest.json"))
        self.assertEqual(len(manifests), 1)
        self.assertIn('"state": "rolled-back"', manifests[0].read_text(encoding="utf-8"))

    def test_file_set_applies_create_modify_delete(self) -> None:
        original = self.root / "original"
        candidate = self.root / "candidate"
        original.mkdir()
        candidate.mkdir()
        (original / "modified.txt").write_text("before", encoding="utf-8")
        (original / "deleted.txt").write_text("delete", encoding="utf-8")
        (candidate / "modified.txt").write_text("after", encoding="utf-8")
        (candidate / "created.txt").write_text("create", encoding="utf-8")
        before = source_snapshot(original)
        result = apply_file_set(
            original,
            candidate,
            expected_snapshot=before,
            changes={"created": ["created.txt"], "modified": ["modified.txt"], "deleted": ["deleted.txt"]},
            journal_root=self.root / "multi-journal",
            current_snapshot=source_snapshot,
            verify=lambda: [],
        )
        self.assertEqual((original / "modified.txt").read_text(encoding="utf-8"), "after")
        self.assertEqual((original / "created.txt").read_text(encoding="utf-8"), "create")
        self.assertFalse((original / "deleted.txt").exists())
        self.assertFalse(result.rolled_back)

    def test_file_set_rolls_back_all_changes(self) -> None:
        original = self.root / "original"
        candidate = self.root / "candidate"
        original.mkdir()
        candidate.mkdir()
        (original / "modified.txt").write_text("before", encoding="utf-8")
        (original / "deleted.txt").write_text("delete", encoding="utf-8")
        (candidate / "modified.txt").write_text("after", encoding="utf-8")
        (candidate / "created.txt").write_text("create", encoding="utf-8")
        before = source_snapshot(original)
        with self.assertRaisesRegex(RuntimeError, "verification failed"):
            apply_file_set(
                original,
                candidate,
                expected_snapshot=before,
                changes={"created": ["created.txt"], "modified": ["modified.txt"], "deleted": ["deleted.txt"]},
                journal_root=self.root / "multi-journal",
                current_snapshot=source_snapshot,
                verify=lambda: ["invalid"],
            )
        self.assertEqual((original / "modified.txt").read_text(encoding="utf-8"), "before")
        self.assertEqual((original / "deleted.txt").read_text(encoding="utf-8"), "delete")
        self.assertFalse((original / "created.txt").exists())


if __name__ == "__main__":
    unittest.main()
