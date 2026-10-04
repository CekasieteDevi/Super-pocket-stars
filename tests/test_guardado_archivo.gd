extends SceneTree

## Guardado y carga de la partida contra el disco (BUG-001 y BUG-002 de
## docs/bugs_pendientes.md): escritura con temporal y respaldo, aviso de
## fallo a la interfaz, y archivos rotos o incompatibles que no tocan la
## partida activa. Usa un archivo de prueba: la partida del usuario no
## se toca.
##
## Correr con: godot --path . --headless --script tests/test_guardado_archivo.gd

const SEED := 5151
# Archivo propio: test_guardado usa partida_test.json y corren a la vez.
const RUTA := "user://partida_test_archivo.json"

var fallos := 0


func _init() -> void:
	# Sin meterlo en el arbol: _ready() cargaria la partida del usuario.
	var gs = load("res://game/game_state.gd").new()
	gs.ruta_partida = RUTA
	gs.borrar_partida()
	gs.partida_nueva(SEED, "Club Guardado")

	_test_guardar_y_cargar(gs)
	_test_respaldo(gs)
	_test_archivos_invalidos(gs)
	_test_apertura_fallida(gs)

	gs.borrar_partida()
	gs.free()
	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


func _escribir(ruta: String, texto: String) -> void:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	f.store_string(texto)
	f.close()


func _test_guardar_y_cargar(gs) -> void:
	print("=== Guardar y cargar ===")
	_ok(gs.guardar_partida(), "guardar devuelve true.")
	_ok(FileAccess.file_exists(RUTA), "el archivo queda en su lugar.")
	_ok(not FileAccess.file_exists(RUTA + ".tmp"), "no queda el temporal.")
	var nombre: String = gs.equipo_jugador.nombre
	var temporada: int = gs.temporada_actual
	gs.temporada_actual = 99
	_ok(gs.cargar_partida(), "cargar devuelve true.")
	_ok(gs.temporada_actual == temporada and gs.equipo_jugador.nombre == nombre,
		"la partida vuelve como estaba.")


func _test_respaldo(gs) -> void:
	print("=== Respaldo del guardado anterior ===")
	_ok(gs.guardar_partida(), "el segundo guardado devuelve true.")
	_ok(FileAccess.file_exists(RUTA + ".bak"), "el guardado anterior queda como respaldo.")
	# Un corte en medio de la escritura deja el principal roto: el
	# respaldo tiene que alcanzar.
	_escribir(RUTA, "{\"version\": 1, \"piramide\": ")
	_ok(gs.cargar_partida(), "con el principal roto, carga el respaldo.")


func _test_archivos_invalidos(gs) -> void:
	print("=== Archivos invalidos no tocan la partida activa ===")
	gs.guardar_partida()
	DirAccess.remove_absolute(RUTA + ".bak")
	var texto_bueno: String = FileAccess.get_file_as_string(RUTA)
	var bueno: Dictionary = JSON.parse_string(texto_bueno)
	var futuro := bueno.duplicate()
	futuro["version"] = gs.VERSION_PARTIDA + 1
	var sin_division := bueno.duplicate()
	sin_division["division_jugador"] = 57
	var sin_piramide := bueno.duplicate()
	sin_piramide.erase("piramide")
	var casos := {
		"una lista JSON": "[1, 2, 3]",
		"un diccionario vacio": "{}",
		"una version futura": JSON.stringify(futuro),
		"una division inexistente": JSON.stringify(sin_division),
		"sin piramide": JSON.stringify(sin_piramide),
		"texto que no es JSON": "esto no es json",
	}
	var temporada: int = gs.temporada_actual
	var equipo = gs.equipo_jugador
	for caso in casos:
		_escribir(RUTA, casos[caso])
		var cargo: bool = gs.cargar_partida()
		_ok(not cargo and gs.equipo_jugador == equipo and gs.temporada_actual == temporada,
			"%s: la carga falla y la partida activa sigue igual." % caso)
	_escribir(RUTA, texto_bueno)


func _test_apertura_fallida(gs) -> void:
	print("=== Apertura fallida ===")
	gs.ruta_partida = "user://carpeta_que_no_existe/partida_test.json"
	_ok(not gs.guardar_partida(), "sin carpeta, guardar devuelve false en vez de romperse.")
	gs.ruta_partida = RUTA
	_ok(FileAccess.file_exists(RUTA), "el guardado anterior sigue disponible.")
