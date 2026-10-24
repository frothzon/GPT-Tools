from __future__ import annotations

import unittest

from gmtool.lossless_json import ParseError, loads


class LosslessJsonTests(unittest.TestCase):
    def test_game_maker_trailing_commas_round_trip_byte_exact(self) -> None:
        text = '{\r\n  "name":"demo",\r\n  "values":[1,2,],\r\n}\r\n'
        document = loads(text)
        self.assertEqual(document.value, {"name": "demo", "values": [1, 2]})
        self.assertEqual(document.to_bytes(), text.encode("utf-8"))

    def test_duplicate_keys_are_reported(self) -> None:
        document = loads('{"name":"a","name":"b",}')
        self.assertEqual(document.value["name"], "b")
        self.assertEqual(document.duplicate_keys, ["$.name"])

    def test_parse_error_has_line_and_column(self) -> None:
        with self.assertRaises(ParseError) as raised:
            loads('{\n  "name": @\n}')
        self.assertEqual(raised.exception.line, 2)
        self.assertGreater(raised.exception.column, 1)


if __name__ == "__main__":
    unittest.main()

