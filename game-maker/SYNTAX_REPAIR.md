# Syntax diagnosis and conservative repair

This specification covers fast discovery and safe repair of simple syntax errors in GML, shader source, and GameMaker metadata. The goal is to remove mechanical friction for agents without turning compiler failures into speculative code rewrites.

## Commands

```powershell
# Diagnose the project or only recently changed resources.
gmtool diagnose game.yyp --json
gmtool diagnose game.yyp --changed --type gml,shader
gmtool diagnose game.yyp obj_player.Step --context 4

# Explain one diagnostic with logical resource and source context.
gmtool explain-error game.yyp --diagnostic GM2001

# Generate a verified patch without changing the working project.
gmtool repair-syntax game.yyp --changed --dry-run --json
gmtool repair-syntax game.yyp obj_player.Step --diagnostic GM2001 --dry-run

# Apply exactly a previously reviewed repair plan if hashes still match.
gmtool repair-syntax game.yyp --apply-plan repair-plan.json
```

`diagnose` returns stable records with severity, source (`lexer`, `parser`, `metadata`, `shader`, or `gm-cli compiler`), original code/message, logical resource, event/stage, absolute path, line/column/range, nearby source, related/cascade diagnostics, build profile, and suggested next action.

## Diagnostic pipeline

1. Discover the project and map logical resources to source files.
2. Hash all inputs and select changed files when requested.
3. Run encoding, conflict-marker, and delimiter/string/comment scans without modifying files.
4. Parse GameMaker JSON-like metadata with the lossless parser and report exact token expectations.
5. Run any proven version-specific GML/shader parser checks available locally.
6. Compile a disposable project copy through pinned `gm-cli compile`; capture stdout, stderr, exit code, target, runtime, toolchain, config, and duration.
7. Normalize paths and compiler messages back to logical resources.
8. Collapse obvious cascades under the earliest/root diagnostic while retaining every raw message.
9. Rank errors by confidence and likely repairability; never hide a compiler diagnostic.

Fast checks are advisory. A clean local scan does not replace compilation, and a candidate repair is not accepted until the authoritative compiler check passes the verification rules below.

## Eligible automatic repairs

Candidate generators are token-aware and version-specific. A class remains disabled until mutation tests prove it. Initial high-confidence classes may include:

- removal of unresolved merge-conflict markers when exactly one mechanically selected side is supplied by a reviewed plan;
- insertion/removal of one unmatched `(`, `)`, `[`, `]`, `{`, or `}` when the parser identifies a unique location;
- closure of an unterminated string or block comment at a uniquely implied boundary;
- repair of a malformed escape sequence when there is exactly one legal literal representation of the existing text;
- insertion/removal of one separator or terminator only when the target-version grammar and compiler location make it unique;
- removal of one duplicated adjacent punctuation token caused by a mechanical edit;
- repair of a truncated GameMaker JSON-like key/value delimiter, quote, comma, or container close when the lossless parser identifies one unique edit and the complete project validates afterward;
- replacement of an event/shader/source file with its reviewed, conflict-free staged counterpart when hashes and logical identity match.

The list is deliberately narrow. GML permits constructs that resemble errors in other languages; rules must come from target-version fixtures and compiler evidence, not generic JavaScript/C assumptions.

## Never auto-fix

The following require an explicit human/agent-authored code change, even if a model can suggest one:

- `=` versus `==`, boolean/operator substitutions, precedence changes, or altered control flow;
- changed identifier, function, resource, variable, property, enum, macro, or argument names;
- adding/removing `return`, `break`, `continue`, `exit`, event inheritance, or function calls;
- inferred declarations, missing arguments, type conversions, default values, or asset references;
- moving code across scopes/events or reordering statements;
- shader type/precision/math changes;
- deletion of “unexpected” code to make parsing succeed;
- more than the configured repair budget or changes spanning unrelated locations;
- any candidate whose success depends on selecting among multiple valid interpretations.

These can be reported as suggestions with evidence, but `repair-syntax` must refuse them.

## Candidate verification

For each repairable root diagnostic:

1. Generate bounded candidates ordered by fewest changed bytes and strongest parser evidence.
2. Apply one candidate to a fresh disposable project copy.
3. Re-run local parsing and the same `gm-cli compile` profile.
4. Reject the candidate if the targeted diagnostic remains, any new diagnostic appears, a previously passing target fails, metadata outside the expected save set changes, or the compiler/ResourceTool rewrites unrelated files.
5. If exactly one candidate succeeds, emit a repair plan containing unified diff, rationale, confidence, source hashes, validation results, and expiry conditions.
6. If zero or multiple candidates succeed, do not auto-apply; return the candidates and ambiguity explanation.
7. On application, re-check hashes, write transactionally, compile again from the committed bytes, and rollback if verification differs.

Compiler success is necessary but not always sufficient. When a syntax fix could plausibly alter behavior, it is demoted to a suggestion and requires explicit review plus relevant runtime tests.

## Repair budgets and defaults

- Default scope: files changed in the current task when that set is known; otherwise the first compiler root error.
- Default automatic budget: one file, one root diagnostic, one contiguous edit, and at most two punctuation characters.
- A broader budget requires an explicit flag and still cannot bypass prohibited semantic classes.
- Preserve encoding, BOM, newline style, indentation, comments, and all bytes outside the minimal edit span.
- Never run a formatter as part of repair.
- Never edit generated/cache/build output or files outside the selected project.

## Agent-facing experience

A concise text diagnostic should look like:

```text
obj_player.Step (objects/obj_player/Step_0.gml:42:18)
Root error: expected ')' before '{'
Related: 5 later parse errors are likely cascades.
Repairable: high confidence; insert ')' at line 42, column 18.
Verification: local parse passed; gm-cli VM/Windows compile passed on disposable copy.
Working tree: unchanged (dry run).
```

JSON output includes the raw compiler messages so another agent can audit normalization. Source context must be bounded and must not dump unrelated files or secrets.

## Shader handling

- Diagnose vertex and fragment stages together and preserve stage identity.
- Compile using every configured target whose shader language is relevant; a Windows-only pass is not cross-target proof.
- Only delimiter/comment/string/preprocessor-token fixes meeting the same uniqueness rule are eligible initially.
- Link/interface errors, type mismatches, missing uniforms/varyings, precision changes, and target portability issues are suggestions, not automatic syntax repairs.

## Metadata handling

- Distinguish malformed text from a valid but semantically invalid GameMaker resource.
- Repair only the smallest uniquely implied syntax token using the lossless CST.
- Validate the entire reference graph after repair.
- Compare against a disposable ResourceTool/IDE round-trip and report normalization separately.
- Never synthesize missing resource fields as “syntax repair”; that belongs to a versioned resource adapter and an explicit migration/repair command.

## Tests and acceptance

- Seed one controlled syntax mutation at a time into valid GML, shader, and every metadata fixture; store expected root diagnostic, permitted patch, and compiler result.
- Include nested delimiters, strings containing comment/delimiter characters, multiline strings/comments, macros/preprocessor directives, template-like literals supported by GML, Unicode, CRLF/LF, and EOF truncation.
- Include negative cases where a tempting punctuation change compiles but alters meaning; these must be refused.
- Test multiple simultaneous errors, cascades, stale line mappings, duplicate resource names, case differences, and compiler messages without paths.
- Inject concurrent edits and crashes during plan/apply/rollback.
- Track precision and refusal rates. The release gate prioritizes zero known unsafe auto-fixes over the number of errors repaired.
- A repair class is enabled for a GameMaker version only after its full mutation corpus passes local parsing, disposable `gm-cli` compilation, no-unrelated-byte checks, and rollback tests.

