# Animaciones: lectura obligatoria antes de corregirlas

Leer [docs/diagnostico_animaciones_partido.md](docs/diagnostico_animaciones_partido.md)
ante saltos, regates rotos o diferencias entre laboratorio y partido.

- Reproducir el guardado y registrar la acción real antes de atribuir el síntoma a un regate.
- Validar el camino completo: motor → fotogramas → VistaPartido → VistaCancha → textura.
- No confundir ticks de simulación con cuadros del sprite. No restaurar «un tick por dibujo».
- Revisar celdas vacías y dibujos repetidos por fallback: una textura no nula no prueba una animación.
- Probar los cinco regates dentro de la vista del partido, con interpolación y render real.
- Respetar las reglas de ejecución de Godot de abajo y las autorizaciones explícitas de la conversación.
- Informar por separado lo observado, lo corregido y lo que no se pudo verificar.

# CHANGELOG (obligatorio para toda IA y toda persona)

Cada cambio a la aplicación es una versión nueva. La pantalla de inicio
muestra "Actualización v x.x.xx" y un botón "Changelog" con la lista.

- Registrá cada cambio en `data/changelog.json` (el registro de cambios).
- Agregá la entrada nueva ARRIBA de todo. La primera entrada define la versión.
- Subí el último tramo de a uno: `0.4.00` → `0.4.01`. Después de `.99`, subí el del medio y volvé a `.00`.
- Escribí una sola frase simple, que entienda alguien que no programa. Ejemplo: "Los arqueros atajan mejor los remates de lejos."
- Formato: `{"version": "0.4.01", "fecha": "AAAA-MM-DD", "cambio": "..."}`.
- Un commit = una entrada. No juntes cambios distintos en una frase.
- El hook `.githooks/pre-commit` (script que git corre antes de cada commit) rechaza el commit sin versión nueva. No lo saltees con `--no-verify`.
- Si el hook no está activo, activalo: `git config core.hooksPath .githooks`.
- `tests/test_changelog.gd` valida el formato dentro de la regresión.

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
