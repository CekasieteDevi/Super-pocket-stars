# GODOT / WINDOWS RULES

## Version obligatoria

Usar siempre Godot 4.7.2-stable:

- Editor: `E:\IntelliJ\Super Pocket Stars\Godot_v4.7.2-stable_win64.exe`
- Console: `E:\IntelliJ\Super Pocket Stars\Godot_v4.7.2-stable_win64_console.exe`
- No usar Godot 4.7.1 ni otra versión.

Never execute Godot from Codex.

Never run:

- Godot.exe
- Godot_*_win64.exe
- Godot_*_console.exe
- godot --headless
- godot --editor
- godot --path
- any Godot project validation command

Do not launch, stop, restart, or interact with my running Godot editor.

You may:

- inspect the project
- edit GDScript files
- edit source files
- inspect .tscn/.tres files when necessary
- use Git and static analysis

After making changes, tell me exactly what I should test manually in Godot.

I will run the Godot editor and game myself.
