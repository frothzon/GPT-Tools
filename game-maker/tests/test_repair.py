from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from gmtool.repair import propose


class RepairTests(unittest.TestCase):
    def test_single_unclosed_delimiter_gets_one_candidate(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Create_0.gml"
            path.write_text("if (ready) {\n    run();\n", encoding="utf-8", newline="")
            diagnostics, candidates = propose(path, resource="obj_test")
            self.assertEqual([item.code for item in diagnostics], ["GMS014"])
            self.assertEqual(len(candidates), 1)
            self.assertTrue(candidates[0].repaired.endswith("}\n"))

    def test_multiple_errors_are_refused(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Create_0.gml"
            path.write_text("if ((ready {\n", encoding="utf-8", newline="")
            diagnostics, candidates = propose(path)
            self.assertGreater(len(diagnostics), 1)
            self.assertEqual(candidates, [])

    def test_bom_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Create_0.gml"
            path.write_bytes(b"\xef\xbb\xbf/* open\n")
            _diagnostics, candidates = propose(path)
            self.assertEqual(len(candidates), 1)
            self.assertTrue(candidates[0].to_bytes().startswith(b"\xef\xbb\xbf"))


if __name__ == "__main__":
    unittest.main()

