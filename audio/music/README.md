# Licensed music slot

Drop the approved reference tracks here using these exact file names (any of
.ogg, .mp3 or .wav). They automatically replace the generated fallbacks:

| Use | File name |
|---|---|
| Office theme ("Scope Creep") | `scope_creep.ogg` / `.mp3` / `.wav` |
| Cartoon brawl ("Epic Meltdown, Happy Ending") | `epic_meltdown_happy_ending.ogg` / `.mp3` / `.wav` |

Open the project in the Godot editor once after adding them so they are imported.
Tracks loop automatically. The fallback music lives in `audio/generated/` and
is produced by `tools/gen_audio.py`.
