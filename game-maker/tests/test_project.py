from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from gmtool.diagnostics import scan_source
from gmtool.graph import build_graph
from gmtool.index import build_index, find_resources, resolve
from gmtool.previews import build_preview
from gmtool.validation import validate

from support import write_fixture


class ProjectTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.project = write_fixture(self.root)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_index_and_summary(self) -> None:
        index = build_index(self.project)
        summary = index.summary()
        self.assertEqual(summary["project"], "Fixture")
        self.assertEqual(summary["resourceCount"], 4)
        self.assertEqual(summary["resourceTypes"]["GMObject"], 1)
        self.assertEqual(summary["sourceFileCount"], 4)

    def test_logical_resolution(self) -> None:
        index = build_index(self.project)
        resource, source = resolve(index, "obj_test.Create")
        self.assertEqual(resource.name, "obj_test")
        self.assertIsNotNone(source)
        self.assertEqual(source.path.name, "Create_0.gml")
        _, vertex = resolve(index, "shd_test.vertex")
        self.assertEqual(vertex.path.name, "shd_test.vsh")
        _, script_code = resolve(index, "scr_math.code")
        self.assertEqual(script_code.path.name, "scr_math.gml")

    def test_find_searches_sources_and_types(self) -> None:
        index = build_index(self.project)
        self.assertEqual([item.name for item in find_resources(index, "create")], ["obj_test"])
        self.assertEqual([item.name for item in find_resources(index, "GMShader")], ["shd_test"])

    def test_fixture_validates_cleanly(self) -> None:
        diagnostics = validate(build_index(self.project))
        errors = [item for item in diagnostics if item.severity == "error"]
        self.assertEqual(errors, [], [item.message for item in diagnostics])

    def test_missing_event_source_is_reported(self) -> None:
        (self.root / "objects" / "obj_test" / "Create_0.gml").unlink()
        diagnostics = validate(build_index(self.project))
        self.assertIn("GMV022", {item.code for item in diagnostics})

    def test_gmnotes_v2_is_rejected_before_ide_load(self) -> None:
        project_text = self.project.read_text(encoding="utf-8")
        registration = '    {"id":{"name":"spr_test","path":"sprites/spr_test/spr_test.yy",},},'
        note_registration = '    {"id":{"name":"note_legacy","path":"notes/note_legacy/note_legacy.yy",},},\n'
        self.assertIn(registration, project_text)
        self.project.write_text(project_text.replace(registration, note_registration + registration), encoding="utf-8")

        note = self.root / "notes" / "note_legacy" / "note_legacy.yy"
        note.parent.mkdir(parents=True)
        note.write_text(
            '{"$GMNotes":"v2","%Name":"note_legacy","name":"note_legacy","resourceType":"GMNotes","resourceVersion":"2.0",}\n',
            encoding="utf-8",
        )

        diagnostics = validate(build_index(self.project))
        notes_errors = [item for item in diagnostics if item.code == "GMV024"]
        self.assertEqual(len(notes_errors), 1)
        self.assertIn("cannot downgrade", notes_errors[0].message)

    def test_syntax_scanner_finds_unclosed_delimiter(self) -> None:
        source = self.root / "bad.gml"
        source.write_text("if (ready {\n    run();\n}\n", encoding="utf-8")
        diagnostics = scan_source(source)
        self.assertIn("GMS014", {item.code for item in diagnostics})

    def test_preview_bundle_is_content_addressed(self) -> None:
        index = build_index(self.project)
        resource, _ = resolve(index, "scr_math")
        tool_root = self.root / "tool"
        manifest = build_preview(tool_root, index, resource)
        output = Path(manifest["output"])
        self.assertTrue((output / "manifest.json").is_file())
        self.assertTrue((output / "summary.md").is_file())
        self.assertTrue((output / "resource.json").is_file())
        self.assertEqual(manifest["renderer"], "data-only")
        second = build_preview(tool_root, index, resource)
        self.assertEqual(second["output"], manifest["output"])
        self.assertTrue((output / "preview.html").is_file())

    def test_dependency_graph_marks_code_references_as_soft(self) -> None:
        (self.root / "objects" / "obj_test" / "Create_0.gml").write_text("scr_math();\n", encoding="utf-8")
        index = build_index(self.project)
        graph = build_graph(index, "scr_math")
        self.assertTrue(any(edge["kind"] == "code-reference" and edge["confidence"] == "static-text" for edge in graph["edges"]))


if __name__ == "__main__":
    unittest.main()
