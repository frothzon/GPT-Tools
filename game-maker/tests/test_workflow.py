from __future__ import annotations
import json
from pathlib import Path
import tempfile
import threading
import unittest
import urllib.request
import urllib.error
from unittest.mock import patch
from tests.support import write_fixture
from gmtool.index import build_index, resolve, resolve_effective
from gmtool.validation import validate
from gmtool.patches import patch_bytes
from gmtool.change_plans import prepare, apply, read_plan, plan_dir
from gmtool.verification import verify
from gmtool.transactions import sha256_bytes, apply_file_set
from gmtool.gm_cli import source_snapshot
from gmtool.workspace import save, digest
from gmtool.symbols import extract
from gmtool.context import context
from gmtool.scenarios import collect, PREFIX, generate, replace_top_level
from gmtool.docs import sync, lookup, search, coverage, extract as extract_doc
from gmtool.cli import _parser
from gmtool.operation_registry import RECIPE_NAMES, assert_mutation_supported
from gmtool.capabilities import manifest
from gmtool.sessions import open_session
from gmtool.server import create_server
from gmtool.mcp_server import handle
from gmtool.recovery import rollback

class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "project"
        self.project = write_fixture(self.root)
        self.tool = Path(self.temp.name) / "tool"
        self.source = self.root / "scripts/scr_math/scr_math.gml"
    def tearDown(self): self.temp.cleanup()
    def change(self, required=None):
        return {"requiredChecks": required or ["structure", "syntax"], "operations": [{"kind": "patch", "spec": "scr_math.code", "expectedHash": sha256_bytes(self.source.read_bytes()), "edits": [{"old": "return a + b;", "new": "return a - b;"}]}]}
    def test_target_collision_maps_distinct_and_missing_remains_error(self):
        descriptor = self.root / "objects/obj_test/obj_test.yy"
        d = {"name": "obj_test", "resourceType": "GMObject", "resourceVersion": "2.0", "eventList": [
            {"eventType": 4, "eventNum": 0, "collisionObjectId": {"name": "obj_test", "path": "objects/obj_test/obj_test.yy"}},
            {"eventType": 4, "eventNum": 0, "collisionObjectId": {"name": "spr_test", "path": "sprites/spr_test/spr_test.yy"}}]}
        descriptor.write_text(json.dumps(d))
        (descriptor.parent / "Collision_obj_test.gml").write_text("value=1;")
        (descriptor.parent / "Collision_spr_test.gml").write_text("value=2;")
        index = build_index(self.project)
        self.assertEqual(resolve(index, "obj_test.Collision.obj_test")[1].path.name, "Collision_obj_test.gml")
        self.assertEqual(resolve(index, "obj_test.Collision.spr_test")[1].path.name, "Collision_spr_test.gml")
        self.assertFalse([d for d in validate(index) if d.code in {"GMV022", "GMV031"}])
        (descriptor.parent / "Collision_obj_test.gml").unlink()
        self.assertTrue([d for d in validate(build_index(self.project)) if d.code == "GMV022"])
    def test_inheritance_resolves_owner(self):
        descriptor = self.root / "objects/obj_test/obj_test.yy"
        from gmtool.lossless_json import load as load_document
        d = load_document(descriptor).value
        d["eventList"] = []; d["parentObjectId"] = {"name": "obj_parent", "path": "objects/obj_parent/obj_parent.yy"}
        descriptor.write_text(json.dumps(d))
        (descriptor.parent / "Create_0.gml").unlink()
        parent = self.root / "objects/obj_parent"; parent.mkdir()
        (parent / "obj_parent.yy").write_text(json.dumps({"name": "obj_parent", "resourceType": "GMObject", "eventList": [{"eventType": 0, "eventNum": 0}]}))
        (parent / "Create_0.gml").write_text("value=1;")
        replace_top_level(self.project, "resources", build_index(self.project).raw_project["resources"] + [{"id": {"name": "obj_parent", "path": "objects/obj_parent/obj_parent.yy"}}])
        self.assertEqual(resolve_effective(build_index(self.project), "obj_test.Create")[0].name, "obj_parent")
    def test_anchored_patch_preserves_bom_crlf(self):
        original = b"\xef\xbb\xbffunction f() {\r\n  return 1;\r\n}\r\n"
        result = patch_bytes(original, [{"old": "return 1;", "new": "return 2;"}])
        self.assertEqual(result, original.replace(b"return 1;", b"return 2;"))
    def test_ambiguous_and_overlapping_anchors_refuse(self):
        with self.assertRaises(ValueError): patch_bytes(b"a a", [{"old": "a", "new": "b"}])
        with self.assertRaises(ValueError): patch_bytes(b"abcdef", [{"old": "abc", "new": "x"}, {"old": "bc", "new": "y"}])
    def test_unified_patch_context_and_counts(self):
        result = patch_bytes(b"a\r\nb\r\n", unified="--- a\n+++ a\n@@ -1,2 +1,2 @@\n a\n-b\n+c\n")
        self.assertEqual(result, b"a\r\nc\r\n")
        with self.assertRaises(ValueError): patch_bytes(b"z\nb\n", unified="@@ -1,2 +1,2 @@\n a\n-b\n+c\n")
    def test_prepare_does_not_touch_project_and_exact_apply(self):
        before = source_snapshot(self.root)
        result = prepare(self.tool, self.project, self.change())
        self.assertEqual(source_snapshot(self.root), before)
        self.assertEqual(verify(self.tool, result["planId"], ["structure", "syntax"])["status"], "passed")
        self.assertEqual(apply(self.tool, result["planId"])["status"], "ready")
        self.assertEqual(source_snapshot(self.root), before)
        self.assertEqual(apply(self.tool, result["planId"], apply_change=True)["status"], "applied")
        self.assertIn("return a - b", self.source.read_text())
    def test_stale_input_and_tampered_candidate_refuse(self):
        result = prepare(self.tool, self.project, self.change())
        verify(self.tool, result["planId"], ["structure", "syntax"])
        self.source.write_text("external edit")
        self.assertEqual(apply(self.tool, result["planId"], apply_change=True)["status"], "stale")
        (plan_dir(self.tool, result["planId"]) / "candidate/scripts/scr_math/scr_math.gml").write_text("tampered")
        with self.assertRaises(RuntimeError): read_plan(self.tool, result["planId"])
    def test_changed_replacement_file_cannot_change_stored_plan(self):
        replacement = Path(self.temp.name) / "replacement.gml"; replacement.write_text("function add(a,b) { return a-b; }\n")
        change = self.change(); change["operations"][0] = {"kind": "replace", "spec": "scr_math.code", "expectedHash": sha256_bytes(self.source.read_bytes()), "from": str(replacement)}
        result = prepare(self.tool, self.project, change)
        replacement.write_text("different")
        verify(self.tool, result["planId"], ["structure", "syntax"])
        apply(self.tool, result["planId"], apply_change=True)
        self.assertIn("return a-b", self.source.read_text())
    def test_default_compile_requirement_blocks_unverified_apply(self):
        result = prepare(self.tool, self.project, self.change(["structure", "syntax", "compile"]))
        verify(self.tool, result["planId"], ["structure", "syntax"])
        self.assertEqual(apply(self.tool, result["planId"], apply_change=True)["status"], "blocked")
    def test_syntax_failure_writes_nothing(self):
        change = self.change(); change["operations"][0]["edits"][0]["new"] = "return (a - b;"
        before = source_snapshot(self.root)
        with self.assertRaises(ValueError): prepare(self.tool, self.project, change)
        self.assertEqual(source_snapshot(self.root), before)
    def test_failed_compile_writes_nothing(self):
        result = prepare(self.tool, self.project, self.change(["structure", "syntax", "compile"]))
        before = source_snapshot(self.root)
        with patch("gmtool.verification.compiler_check", return_value={"status": "failed"}):
            evidence = verify(self.tool, result["planId"])
        self.assertEqual(evidence["checks"]["compile"]["status"], "failed")
        self.assertEqual(apply(self.tool, result["planId"], apply_change=True)["status"], "blocked")
        self.assertEqual(source_snapshot(self.root), before)
    def test_rollback_preserves_external_edit(self):
        candidate = Path(self.temp.name) / "candidate"
        import shutil
        shutil.copytree(self.root, candidate)
        (candidate / self.source.relative_to(self.root)).write_text("new")
        def external_change():
            self.source.write_text("external")
            return ["forced verification failure"]
        with self.assertRaises(RuntimeError):
            apply_file_set(self.root, candidate, expected_snapshot=source_snapshot(self.root), changes={"created": [], "modified": [self.source.relative_to(self.root).as_posix()], "deleted": []}, journal_root=self.tool / ".gmtool-work/transactions", current_snapshot=source_snapshot, verify=external_change)
        self.assertEqual(self.source.read_text(), "external")
        from gmtool.recovery import status
        journal = status(self.tool)[0]
        self.assertEqual(journal["state"], "rollback-conflict")
        with self.assertRaises(RuntimeError): rollback(self.tool, journal["transactionId"], self.root)
    def test_symbol_context_callable_name_and_static_methods(self):
        self.source.write_text("/// @param {Real} x\nfunction Bag(x) constructor { static insert = function(v) { amount=v; }; }\nfunction bag_insert_item() { return new Bag(1); }\n// function fake() {}\n")
        result = context(self.tool, self.project, "bag_insert_item")
        kinds = {s["name"]: s["kind"] for record in result["symbols"] for s in record["symbols"]}
        self.assertEqual(kinds["Bag"], "constructor")
        self.assertEqual(kinds["insert"], "static-method")
        self.assertNotIn("fake", kinds)
    def test_call_arity_nested_strings(self):
        result = extract('f("one,two", [1,2], g(3));')
        self.assertEqual(result["calls"][0]["arity"], 3)
    def test_recipe_help_registry_capability_parity(self):
        parser = _parser(); commands = next(a for a in parser._actions if hasattr(a, "choices") and isinstance(a.choices, dict))
        recipe = commands.choices["resource"]
        choices = next(a.choices for a in recipe._actions if a.dest == "operation")
        self.assertEqual(set(choices), set(RECIPE_NAMES))
        self.assertEqual({r["name"] for r in manifest()["recipes"]}, set(RECIPE_NAMES))
    def test_unknown_version_mutation_refuses(self):
        i = build_index(self.project); i.ide_version = "9999.0.1"
        with self.assertRaises(ValueError): assert_mutation_supported(i, "create", {"type": "script"})
        assert_mutation_supported(i, "list")
    def test_scenario_protocol_complete_and_failing_cases(self):
        def line(record): return PREFIX + json.dumps({"runId": "r", "candidateDigest": "c", **record})
        output = "\n".join([line({"type": "assertion", "test": "a", "passed": True}), line({"type": "complete", "count": 1})])
        self.assertEqual(collect(output, "r", "c", ["a"])["status"], "passed")
        for bad in [output.replace('true', 'false'), output.splitlines()[0], output + "\n" + PREFIX + "bad", output.replace('"r"','"other"')]:
            self.assertEqual(collect(bad, "r", "c", ["a"])["status"], "failed")
        self.assertEqual(collect(output, "r", "c", ["a"], timed_out=True)["status"], "failed")
        self.assertEqual(collect(output, "r", "c", ["a"], exit_code=1)["status"], "failed")
        self.assertEqual(collect("", "r", "c", [])["status"], "failed")
    def test_generated_suite_binds_identity(self):
        code = generate({"tests": [{"name": "sum", "assert": "1+2==3"}]}, "r", "c", Path("C:/tests"))
        self.assertIn('global.gmtool_test_run = "r"', code)
        self.assertIn('count: 1', code)
    def test_docs_extract_sync_search_and_failed_refresh(self):
        base = "https://manual.gamemaker.io/monthly/en/"
        xml = '<urlset><url><loc>GameMaker_Language/GML_Reference/foo.htm</loc></url></urlset>'
        html = '<html><title>foo</title><h1>foo</h1><h2>Syntax:</h2><p>foo(value);</p><h2>Returns:</h2><p>Real</p><h2>Example:</h2><pre>foo(1);</pre></html>'
        def fetcher(url): return xml if url.endswith('sitemap.xml') else html
        imported = sync(self.tool, fetcher=fetcher)
        self.assertEqual(imported["status"], "complete-index")
        self.assertEqual(lookup(self.tool, "foo")["entries"][0]["arity"], {"min": 1, "max": 1, "basis": "documented Syntax section"})
        self.assertEqual(search(self.tool, "foo")["total"], 1)
        old = coverage(self.tool)["snapshotId"]
        def failing(url):
            if url.endswith('sitemap.xml'): return xml
            raise OSError("offline")
        refreshed = sync(self.tool, fetcher=failing)
        self.assertFalse(refreshed["activated"])
        self.assertEqual(coverage(self.tool)["snapshotId"], old)
    def test_local_server_authentication_and_mcp(self):
        with patch('gmtool.environment.doctor', return_value={}): session = open_session(self.tool, self.project)
        server, token = create_server(self.tool, session['sessionId'])
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        origin = f'http://127.0.0.1:{server.server_port}'
        try:
            with self.assertRaises(urllib.error.HTTPError): urllib.request.urlopen(origin+'/')
            self.assertIn(b'GameMaker Workbench', urllib.request.urlopen(origin+'/?token='+token).read())
            raw = json.dumps({'action':'session','args':{}}).encode()
            bad = urllib.request.Request(origin+'/api', data=raw, headers={'X-Gmtool-Token':token})
            with self.assertRaises(urllib.error.HTTPError): urllib.request.urlopen(bad)
            good = urllib.request.Request(origin+'/api', data=raw, headers={'X-Gmtool-Token':token,'Origin':origin})
            self.assertEqual(json.loads(urllib.request.urlopen(good).read())['sessionId'], session['sessionId'])
            self.assertIn('tools', handle(self.tool, session['sessionId'], {'method':'tools/list'}))
            self.assertFalse(handle(self.tool, session['sessionId'], {'method':'tools/call','params':{'name':'session'}})['isError'])
        finally: server.shutdown(); server.server_close(); thread.join()
