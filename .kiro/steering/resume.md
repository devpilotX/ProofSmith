ALWAYS-ON RESUME PROTOCOL (read this first, every session)

This project runs across many sessions. Sessions restart when context
fills up. Never assume you remember anything. State lives in files.

On EVERY new session, before doing anything else:
1. Read PROGRESS.md in the project root. It holds the current phase,
   what is PROVED, and the next step.
2. Read the status ledger and run `git log --oneline -20` to see the
   last work done.
3. Open the Lean files and run the build to confirm current state.
4. Continue from the next incomplete step. Do not redo finished work.

Before context gets full, ALWAYS:
- Update PROGRESS.md with exactly where you are and the next action.
- Commit to git with a clear message.
So the next session can pick up instantly.

Then keep following the AUTONOMY DIRECTIVE: run hands-free, make your
own decisions, only stop when the proof is done or you hit a real wall.