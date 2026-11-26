# Decisions

One line each: what was chosen, and why. Newest at the bottom.

| # | Decision | Reason |
|---|---|---|
| 1 | Built the project in a new folder `/home/user/mog-wars` in the cloud container, not `C:\dev\mog-wars` | The PC folder was not offered to cloud sessions (the app listed it as unavailable), and attaching one needs a person to approve |
| 2 | Clean project layout (no `roblox-framework` template) | The brief asked for a clean client/server/shared layout; shared systems can be added later when a slice needs them |
| 3 | `DESIGN.md` not copied in; `CLAUDE.md` tells sessions to stop if it is missing | The file was never readable from the cloud session |
| 4 | Pinned tools to the same versions as the framework (Rojo 7.7.0, Selene 0.27.1, StyLua 0.20.0) | They were already chosen for the framework, so the two projects behave the same |
| 5 | No GitHub repo created, nothing pushed | The owner said not to push tonight, and creating a repo needs the owner's account |
