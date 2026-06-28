---
name: clojure-paren-repair
description: Repair Clojure, ClojureScript, EDN, or Lisp parenthesis and delimiter mismatches. Use when a file fails with EOF while reading, unmatched delimiter, or similar bracket balance errors.
---

# Clojure Paren Repair

Use this skill when Clojure-family code has broken delimiter balance.
The goal is to restore syntax with the smallest behavior-preserving edit.

## Workflow

1. Capture the exact reader error first.
   ```bash
   clojure -M:test
   ```
   If there is no test alias, use the project's normal compile, test, lint, or REPL load command.

2. Read the reported file around the error and the form start.
   ```bash
   nl -ba path/to/file.clj | sed -n 'START,ENDp'
   ```
   For `EOF while reading, starting at line N`, inspect from `N` through the end of the enclosing top-level form.
   For `Unmatched delimiter`, inspect 20-40 lines before the reported line.

3. Identify the intended top-level form structure before editing.
   Count only structural delimiters: `(` `)` `[` `]` `{` `}`.
   Ignore delimiters inside strings and comments when reasoning.
   Prefer matching indentation and existing style over reformatting the whole file.

4. Make the smallest possible edit:
   - EOF while reading usually needs one missing closing delimiter at the end of the open form.
   - Unmatched delimiter usually needs one extra closing delimiter removed, or a missing opener restored nearby.
   - Do not rewrite logic, rename locals, or change behavior while fixing delimiter balance.

5. Re-run the same command from step 1.
   If it reveals the next delimiter error, repeat the same narrow workflow.

6. After syntax parses, run formatting or lint only if the repository already defines it.
   ```bash
   clojure -M:format-check
   clojure -M:lint
   ```

## Clojure-Specific Checks

- `defn` with multiple arities has this shape:
  ```clojure
  (defn f
    ([x] ...)
    ([x y] ...))
  ```
- `try` must include a body and at least one `catch` or `finally`.
  A dangling `try` often means parentheses were used to hide a missing `finally`.
- Tests that call private functions should use var quote:
  ```clojure
  (#'some.ns/private-fn arg)
  ```
- In `with-redefs`, bindings are vector pairs:
  ```clojure
  (with-redefs [some.ns/f (fn [_] ...)]
    ...)
  ```

## Safety Rules

- Preserve user changes. Do not reset or checkout files unless explicitly asked.
- Do not fix unrelated lint or style issues during delimiter repair.
- Report the exact file and line range changed, plus the command used to verify parsing.
