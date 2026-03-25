---
name: golangci-lint
description: Run golangci-lint after completing Go code changes to catch lint issues before committing. Use proactively after writing or modifying Go files.
---

# golangci-lint — Post-Work Lint Gate

Run `golangci-lint` after you finish writing or modifying Go code to catch issues early. This skill should be invoked automatically after completing any Go code task, before telling the user the work is done.

## When to Use

- After writing new Go files
- After modifying existing Go files
- After refactoring Go code
- Before declaring a task complete that involved Go changes

## Process

### Step 1: Identify Changed Go Files

Determine which Go packages were modified. Use `git diff --name-only` (and `git diff --cached --name-only` for staged files) filtered to `*.go` to find the affected files. Extract unique package directories from the changed files.

### Step 2: Run golangci-lint

Run the linter scoped to the changed packages for faster feedback:

```bash
golangci-lint run ./path/to/changed/package/...
```

If the set of changed packages is large (more than 10) or spans the whole project, run it on the entire project instead:

```bash
golangci-lint run ./...
```

**Important flags:**
- If a `.golangci.yml` (or `.golangci.yaml`, `.golangci.toml`, `.golangci.json`) exists at the project root, the linter picks it up automatically. Do NOT add `--config` unless the user explicitly asks.
- Do NOT add `--fix` unless the user explicitly asks for auto-fixes.
- Use `--new-from-rev=HEAD~1` only if the user asks to lint just the diff.

### Step 3: Analyze Results

**If the linter exits with 0 (no issues):**
- Report briefly: "golangci-lint passed with no issues."
- Proceed to mark the task complete.

**If the linter reports issues:**
1. Parse the output. Each line typically follows the format:
   ```
   file.go:line:col: message (linter-name)
   ```
2. Group the issues by file.
3. Separate issues into two categories:
   - **Issues in code YOU wrote or modified** — these MUST be fixed.
   - **Pre-existing issues in code you did NOT touch** — report these to the user but do NOT fix them unless asked.

### Step 4: Fix Your Issues

For each issue in code you wrote or modified:

1. Read the file and understand the lint violation.
2. Apply the fix using the Edit tool.
3. After fixing all issues, re-run `golangci-lint` on the affected packages to confirm the fixes are clean.
4. If new issues appear from your fixes, repeat until the linter is clean on your changes.

**Do NOT loop more than 3 times.** If issues persist after 3 rounds, report the remaining issues to the user and ask for guidance.

### Step 5: Report

Provide a concise summary:

```
golangci-lint results:
- X issue(s) found in modified code -> fixed
- Y pre-existing issue(s) in untouched code (not fixed)
```

If there were pre-existing issues, list them briefly so the user is aware:
```
Pre-existing issues (not fixed):
  - pkg/foo/bar.go:42: unused parameter `ctx` (unparam)
  - internal/util.go:17: unnecessary conversion (unconvert)
```

## Important Rules

- ALWAYS run the linter after Go code changes. Do not skip this step.
- ONLY fix issues caused by YOUR changes. Do not go on a cleanup spree of pre-existing issues.
- If `golangci-lint` is not installed, tell the user and suggest: `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest` or `brew install golangci-lint`.
- Respect the project's existing linter configuration. Do not override or ignore it.
- Do not add `//nolint` directives unless there is a clear, justified reason and you explain it to the user.
- If the linter run takes longer than 2 minutes, consider scoping it to only the changed packages.
