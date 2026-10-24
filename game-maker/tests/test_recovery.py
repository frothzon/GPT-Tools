from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from gmtool.recovery import rollback, status
from gmtool.transactions import sha256_bytes


class RecoveryTests(unittest.TestCase):
    def test_unfinished_file_set_can_be_rolled_back(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            tool_root = Path(directory) / "tool"
            project = Path(directory) / "project"
            project.mkdir()
            target = project / "game.yyp"
            target.write_text("before", encoding="utf-8")
            transaction = tool_root / ".gmtool-work" / "transactions" / "tx-test"
            (transaction / "before").mkdir(parents=True)
            (transaction / "before" / "game.yyp").write_text("before", encoding="utf-8")
            target.write_text("after", encoding="utf-8")
            (project / "created.txt").write_text("created", encoding="utf-8")
            manifest = {"transactionId": "tx-test", "root": str(project), "changes": {"created": ["created.txt"], "modified": ["game.yyp"], "deleted": []}, "state": "written"}
            manifest.update({"beforeHashes": {"game.yyp": sha256_bytes(b"before"), "created.txt": None}, "afterHashes": {"game.yyp": sha256_bytes(b"after"), "created.txt": sha256_bytes(b"created")}, "writtenPaths": ["game.yyp", "created.txt"]})
            (transaction / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
            self.assertEqual(status(tool_root)[0]["state"], "written")
            result = rollback(tool_root, "tx-test", project)
            self.assertTrue(result["changed"])
            self.assertEqual(target.read_text(encoding="utf-8"), "before")
            self.assertFalse((project / "created.txt").exists())
            self.assertEqual(status(tool_root)[0]["state"], "rolled-back")
