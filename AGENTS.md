# Animaciones: lectura obligatoria antes de corregirlas

Leer [match/3d/LEEME.md](match/3d/LEEME.md) ante saltos, patinadas o
diferencias entre laboratorio y partido. `docs/diagnostico_animaciones_partido.md`
es de la vista vieja (borrada en la etapa 8 del Motor V2): sirve como historia.

- Reproducir la receta del partido y registrar la acción real (`get_accion`) antes de atribuir el síntoma a un clip.
- Validar el camino completo: motor (CanchitaV2Nativa) → PartidoVistoV2 → VistaV2 → Jugador3D.
- El motor avanza a 60 pasos por segundo y la vista interpola entre dos pasos: no confundir pasos con cuadros.
- Medir sobre el mundo, no sobre la vista: `SALTO_PELOTA`, `ENCIMADOS`, `PATINA` y `ESPERA` (docs/motor_v2.md).
- Mirar el problema en `motor_v2/laboratorio_partido.tscn`, con render real.
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

Godot 4.7.2 se usa para verificar fixes en modo headless o para exportar builds.

Permitido (agentes y subagentes):
- Ejecutar `Godot_v4.7.2-stable_win64_console.exe --headless` para correr pruebas, regresiones y verificaciones de escena.
- Exportar APK de Android solo si el usuario lo pide explícitamente.
- Instalar el APK por ADB y verificar que abra solo si el usuario lo pide explícitamente.
- Abrir el juego con el editor gráfico (`Godot_v4.7.2-stable_win64.exe --path .`) cuando el usuario lo pida en ese momento, para que pruebe o vea el juego.

Prohibido:
- Abrir el editor gráfico sin que el usuario lo haya pedido en ese momento.
- Abrir, cerrar, reiniciar o interactuar con una instancia de Godot que el usuario tenga abierta.
- Matar procesos de Godot que no hayas iniciado vos.
- Usar otra versión de Godot.

Además podés: inspeccionar el proyecto, editar GDScript y fuentes, revisar `.tscn`/`.tres`, usar Git y análisis estático.

After making changes, tell me exactly what I should test manually in Godot.

I will run the Godot editor and game myself.

# SUBAGENTES

- Haiku 5.5 explora y lee código. No edita archivos ni hace commits; su salida es un hallazgo con archivo y línea.
- Opus 5.5 arregla los bugs y después verifica que el fix funcione: corre Godot headless según la sección de Godot y reporta el resultado.
- Los subagentes no ven esta conversación ni este archivo salvo que se lo pases en la tarea: incluir archivos permitidos, archivos prohibidos, síntoma y criterio de aceptación.
- Un solo agente integra los cambios compartidos, la entrada de changelog y el commit.
- Reportar por separado: observado, corregido, verificado en headless, y pendiente de prueba manual en Godot.

