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

# Heavy jobs on this laptop

The laptop (16 cores) is shared by every project and every agent. On 2026-11-03, two projects' agents each running builds, tests and Blender renders together drove it to 100%.

- Run every heavy command through one shared lock: `flock /tmp/claude-1000/heavy.lock nice -n 10 <cmd>`. Heavy commands include test suites, builds (`go build`, `next build`, `docker build`), push hooks, Blender renders and ffmpeg encodes. Every project uses this same lock file, so only one heavy job runs on the machine at a time.
- Cap threads inside each job:
  - Next.js / Node:
    - Set `experimental.cpus: 4` in `next.config` so `next build` uses 4 workers instead of all cores.
    - Test runners use 2 workers: Vitest or Jest `--maxWorkers=2`, Playwright `--workers=2`.
    - Monorepo task runners stay at `--concurrency=2`.
    - Never run `next build` while `next dev` is compiling the same app.
  - Go: `GOMAXPROCS=6`, `go test -p 2`.
  - Blender: `-t 6`.
  - ffmpeg: `-threads 6`.
- Never start heavy jobs side by side, in the background or in parallel agents. Every brief to a spawned agent repeats these rules.
- Run only the tests the change touches; leave the full suite to the push hook or CI.
- Kill what you started: background dev servers, headless browsers, watchers and renders stop when the task ends.

# Clean, fast code

- Read the code and trace the real flow before editing. Fix the root cause once, in the shared place every caller goes through.
- Write the shortest diff that works. Reuse what the repo already has before writing new code, and add no abstractions or dependencies nobody asked for.
- Every non-trivial change leaves one runnable test that fails if the logic breaks.
- Lint and format only the files you changed; never run a repo-wide autofix.
- Commit only the paths you changed (`git commit -- <paths>`), so other agents' work isn't swept in.
- Parallel agents each work in their own git worktree.
