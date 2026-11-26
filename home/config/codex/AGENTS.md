# Commit messages

- ALWAYS write every commit message as exactly one line: `what(where): details`.
- `what` is a lowercase Conventional Commit type, such as `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `style`, or `revert`.
- `where` is required and identifies the task, feature, component, or issue, such as `auth` or `Issue45`. Preserve the capitalization of issue identifiers.
- `details` is a concise description of the change.
- Never add a commit body, blank lines, bullet points, trailers, `Co-authored-by`, `Signed-off-by`, AI attribution, or generated-by text. A normal terminating newline is fine.
- Apply this format to every commit you create, including merge, revert, and amended commits; supply an explicit compliant message instead of accepting a generated multiline message.
- Before committing, check the complete message against this rule. After committing, inspect `git log -1 --format=%B` to confirm the stored message complies.

Examples:
- `feat(auth): add password reset`
- `fix(Issue45): handle expired sessions`
- `docs(api): document pagination`
