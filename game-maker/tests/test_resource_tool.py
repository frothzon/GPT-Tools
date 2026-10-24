from __future__ import annotations

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from gmtool.gm_cli import CommandResult
from gmtool.index import build_index
from gmtool.resource_tool import preview

from support import write_fixture


class ResourceToolPreviewTests(unittest.TestCase):
    def test_expression_runs_only_against_disposable_copy(self) -> None:
        with tempfile.TemporaryDirectory() as project_dir, tempfile.TemporaryDirectory() as tool_dir:
            project = write_fixture(Path(project_dir))
            index = build_index(project)
            original = (index.root / "scripts" / "scr_math" / "scr_math.yy").read_bytes()

            def fake_invoke(_tool_root: Path, _arguments: list[str], *, cwd: Path, timeout: int) -> CommandResult:
                target = cwd / "scripts" / "scr_math" / "scr_math.yy"
                target.write_bytes(target.read_bytes() + b"\n")
                return CommandResult(["fake"], 0, "ok\n", "", 0.01)

            with patch("gmtool.resource_tool.invoke", side_effect=fake_invoke):
                result = preview(Path(tool_dir), index, "resource info expr=scr_math")

            self.assertEqual((index.root / "scripts" / "scr_math" / "scr_math.yy").read_bytes(), original)
            self.assertEqual(result.original_changes, {"created": [], "deleted": [], "modified": []})
            self.assertEqual(result.clone_changes["modified"], ["scripts/scr_math/scr_math.yy"])
            self.assertIsNone(result.workspace)


    def test_resource_tool_note_version_rewrites_are_removed_from_candidate_diff(self) -> None:
        with tempfile.TemporaryDirectory() as project_dir, tempfile.TemporaryDirectory() as tool_dir:
            project = write_fixture(Path(project_dir))
            index = build_index(project)
            note_dir = index.root / "notes" / "whats_next"
            note_dir.mkdir(parents=True)
            note = note_dir / "whats_next.yy"
            note.write_text(
                '{\n  "$GMNotes":"v1",\n  "name":"whats_next",\n'
                '  "resourceType":"GMNotes",\n  "resourceVersion":"2.0",\n}\n',
                encoding="utf-8",
            )
            original_note = note.read_bytes()

            def fake_invoke(_tool_root: Path, _arguments: list[str], *, cwd: Path, timeout: int) -> CommandResult:
                source = cwd / "scripts" / "scr_math" / "scr_math.yy"
                source.write_bytes(source.read_bytes() + b"\n")
                rewritten_note = cwd / "notes" / "whats_next" / "whats_next.yy"
                rewritten_note.write_bytes(rewritten_note.read_bytes().replace(b'"$GMNotes":"v1"', b'"$GMNotes":"v2"'))
                added_note = cwd / "notes" / "generated" / "generated.yy"
                added_note.parent.mkdir(parents=True)
                added_note.write_bytes(b'{"$GMNotes":"v2","name":"generated","resourceType":"GMNotes"}')
                return CommandResult(["fake"], 0, "ok\n", "", 0.01)

            with patch("gmtool.resource_tool.invoke", side_effect=fake_invoke):
                result = preview(Path(tool_dir), index, "resource info expr=scr_math", keep_workspace=True)

            self.assertEqual(note.read_bytes(), original_note)
            self.assertEqual(result.clone_changes["modified"], ["scripts/scr_math/scr_math.yy"])
            self.assertEqual(result.clone_changes["created"], ["notes/generated/generated.yy"])
            self.assertIsNotNone(result.workspace)
            generated_note = result.workspace / "project" / "notes" / "generated" / "generated.yy"
            self.assertIn(b'"$GMNotes":"v1"', generated_note.read_bytes())


if __name__ == "__main__":
    unittest.main()

