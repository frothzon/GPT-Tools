from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from gmtool.capabilities import manifest
from gmtool.compiler import explain_diagnostic, parse_compiler_output
from gmtool.index import build_index
from tests.support import write_fixture


class CompilerDiagnosticTests(unittest.TestCase):
    def test_asset_compiler_error_maps_to_logical_script(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            project = write_fixture(Path(directory))
            index = build_index(project)
            output = 'Error : gml_GlobalScript_scr_math(2) : unexpected symbol "}" in expression\n'
            items = parse_compiler_output(output, index)
            self.assertEqual(len(items), 1)
            self.assertEqual(items[0].resource, "scr_math")
            self.assertEqual(items[0].path.name, "scr_math.gml")
            self.assertEqual(items[0].line, 2)

    def test_duplicate_human_json_and_stderr_errors_are_collapsed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            index = build_index(write_fixture(Path(directory)))
            output = '\n'.join([
                'Error : gml_GlobalScript_scr_math(2) : malformed assignment',
                '{"errors":[{"message":"gml_GlobalScript_scr_math(2) : malformed assignment"}]}',
            ])
            self.assertEqual(len(parse_compiler_output(output, index)), 1)

    def test_object_event_asset_name_maps_to_event_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            index = build_index(write_fixture(Path(directory)))
            items = parse_compiler_output("Error : gml_Object_obj_test_Create_0(1) : malformed assignment\n", index)
            self.assertEqual(items[0].path.name, "Create_0.gml")
            self.assertEqual(items[0].resource, "obj_test")

    def test_explanation_is_actionable_and_conservative(self) -> None:
        result = explain_diagnostic("got '' expected ')'", "GMC001")
        self.assertIn("preceding line", " ".join(result["nextSteps"]))
        self.assertIn("only", result["repair"])

    def test_capability_manifest_marks_unknown_types_read_only(self) -> None:
        result = manifest()
        self.assertEqual(result["families"]["unknown-future-types"]["operations"]["discover"], "implemented")
        self.assertEqual(result["families"]["unknown-future-types"]["operations"]["patch"], "planned")
