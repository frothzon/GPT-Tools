from __future__ import annotations

import unittest

from gmtool.resource_api import ResourceRecipeError, build_expression


class ResourceRecipeTests(unittest.TestCase):
    def test_common_creation_recipe(self) -> None:
        self.assertEqual(build_expression("create", {"type": "script", "name": "scr_new"}), "RESOURCE CREATE TYPE=script NAME=scr_new")

    def test_room_instance_recipe_preserves_numeric_values(self) -> None:
        expression = build_expression("room-instance-create", {"room": "rm_test", "object": "obj_player", "x": 32, "y": 48})
        self.assertIn("ROOM INSTANCE CREATE", expression)
        self.assertIn("X=32", expression)
        self.assertIn("Y=48", expression)

    def test_quoted_values_are_safe(self) -> None:
        expression = build_expression("create", {"type": "notes", "name": "Note with spaces"})
        self.assertIn('NAME="Note with spaces"', expression)

    def test_newlines_are_rejected(self) -> None:
        with self.assertRaises(ResourceRecipeError):
            build_expression("create", {"type": "script", "name": "bad\nname"})

    def test_required_recipe_fields_fail_before_resource_tool(self) -> None:
        with self.assertRaises(ResourceRecipeError):
            build_expression("object-event-create", {"name": "obj_player"})
