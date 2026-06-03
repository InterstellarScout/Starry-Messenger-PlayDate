# Agent Notes

- Keep `tonight-requests-status.txt` updated as work progresses.
- Add new user requests to the appropriate section when they appear.
- Update statuses as implementation, investigation, or follow-up work changes.
- Commit and push completed changes going forward unless the user explicitly says not to.
- Assume all new feature and behavior requests should be applied to `StarryMessenger-Playdate` first unless the user explicitly says otherwise.
- When a change in Starry Messenger affects a corresponding standalone app, mirror the relevant update in `DuckPond`, `GifPlayer`, and `OrbitalRingDefense` as appropriate.
- For Starry Messenger feature requests and bug fixes, run `.\build.ps1 -InstallDevice` after implementation when an unlocked Playdate is connected so the current build is compiled, uploaded, and launched on hardware. Use `.\build.ps1 -InstallDataDisk` only as the mounted-drive fallback.
