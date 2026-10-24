"""A small lossless reader for GameMaker's JSON-with-trailing-commas format.

The parsed value is convenient for indexing, while the original text and token
spans remain available for future minimal mutations. Merely reading and writing
``LosslessDocument.to_bytes()`` is byte-identical.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import json
from pathlib import Path
import re
from typing import Any


_NUMBER = re.compile(r"-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?")


class ParseError(ValueError):
    def __init__(self, message: str, text: str, offset: int):
        self.offset = max(0, min(offset, len(text)))
        self.line = text.count("\n", 0, self.offset) + 1
        previous = text.rfind("\n", 0, self.offset)
        self.column = self.offset - previous
        super().__init__(f"{message} at line {self.line}, column {self.column}")


@dataclass(frozen=True)
class Token:
    kind: str
    start: int
    end: int
    raw: str
    value: Any = None


@dataclass
class LosslessDocument:
    path: Path | None
    text: str
    value: Any
    tokens: list[Token]
    bom: bool = False
    duplicate_keys: list[str] = field(default_factory=list)

    def to_bytes(self) -> bytes:
        prefix = b"\xef\xbb\xbf" if self.bom else b""
        return prefix + self.text.encode("utf-8")


def _scan(text: str) -> list[Token]:
    tokens: list[Token] = []
    index = 0
    length = len(text)
    while index < length:
        char = text[index]
        if char.isspace():
            start = index
            index += 1
            while index < length and text[index].isspace():
                index += 1
            tokens.append(Token("trivia", start, index, text[start:index]))
            continue
        if text.startswith("//", index):
            start = index
            end = text.find("\n", index + 2)
            index = length if end < 0 else end
            tokens.append(Token("trivia", start, index, text[start:index]))
            continue
        if text.startswith("/*", index):
            start = index
            end = text.find("*/", index + 2)
            if end < 0:
                raise ParseError("unterminated block comment", text, start)
            index = end + 2
            tokens.append(Token("trivia", start, index, text[start:index]))
            continue
        if char in "{}[]:,":
            tokens.append(Token(char, index, index + 1, char, char))
            index += 1
            continue
        if char == '"':
            start = index
            index += 1
            escaped = False
            while index < length:
                current = text[index]
                if escaped:
                    escaped = False
                elif current == "\\":
                    escaped = True
                elif current == '"':
                    index += 1
                    raw = text[start:index]
                    try:
                        value = json.loads(raw)
                    except json.JSONDecodeError as exc:
                        raise ParseError(exc.msg, text, start + exc.pos) from exc
                    tokens.append(Token("string", start, index, raw, value))
                    break
                index += 1
            else:
                raise ParseError("unterminated string", text, start)
            continue
        number = _NUMBER.match(text, index)
        if number:
            raw = number.group(0)
            value = float(raw) if any(c in raw for c in ".eE") else int(raw)
            tokens.append(Token("number", index, number.end(), raw, value))
            index = number.end()
            continue
        matched = False
        for word, value in (("true", True), ("false", False), ("null", None)):
            if text.startswith(word, index):
                boundary = index + len(word)
                if boundary == length or not (text[boundary].isalnum() or text[boundary] == "_"):
                    tokens.append(Token("literal", index, boundary, word, value))
                    index = boundary
                    matched = True
                    break
        if matched:
            continue
        raise ParseError(f"unexpected character {char!r}", text, index)
    tokens.append(Token("eof", length, length, ""))
    return tokens


class _Parser:
    def __init__(self, text: str, tokens: list[Token]):
        self.text = text
        self.tokens = tokens
        self.index = 0
        self.duplicate_keys: list[str] = []

    def _current(self) -> Token:
        while self.tokens[self.index].kind == "trivia":
            self.index += 1
        return self.tokens[self.index]

    def _take(self, kind: str) -> Token:
        token = self._current()
        if token.kind != kind:
            raise ParseError(f"expected {kind!r}, found {token.kind!r}", self.text, token.start)
        self.index += 1
        return token

    def parse(self) -> Any:
        value = self._value("$")
        token = self._current()
        if token.kind != "eof":
            raise ParseError("unexpected content after root value", self.text, token.start)
        return value

    def _value(self, path: str) -> Any:
        token = self._current()
        if token.kind == "{":
            return self._object(path)
        if token.kind == "[":
            return self._array(path)
        if token.kind in {"string", "number", "literal"}:
            self.index += 1
            return token.value
        raise ParseError("expected a value", self.text, token.start)

    def _object(self, path: str) -> dict[str, Any]:
        result: dict[str, Any] = {}
        self._take("{")
        if self._current().kind == "}":
            self.index += 1
            return result
        while True:
            key = self._take("string").value
            self._take(":")
            child_path = f"{path}.{key}"
            value = self._value(child_path)
            if key in result:
                self.duplicate_keys.append(child_path)
            result[key] = value
            token = self._current()
            if token.kind == "}":
                self.index += 1
                return result
            self._take(",")
            if self._current().kind == "}":
                self.index += 1
                return result

    def _array(self, path: str) -> list[Any]:
        result: list[Any] = []
        self._take("[")
        if self._current().kind == "]":
            self.index += 1
            return result
        while True:
            result.append(self._value(f"{path}[{len(result)}]"))
            token = self._current()
            if token.kind == "]":
                self.index += 1
                return result
            self._take(",")
            if self._current().kind == "]":
                self.index += 1
                return result


def loads(text: str, *, path: Path | None = None, bom: bool = False) -> LosslessDocument:
    tokens = _scan(text)
    parser = _Parser(text, tokens)
    value = parser.parse()
    return LosslessDocument(path, text, value, tokens, bom, parser.duplicate_keys)


def load(path: str | Path) -> LosslessDocument:
    resolved = Path(path)
    raw = resolved.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    payload = raw[3:] if bom else raw
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ParseError("file is not valid UTF-8", payload.decode("utf-8", "replace"), exc.start) from exc
    return loads(text, path=resolved, bom=bom)

