extends SceneTree

## Guardado/carga de partida (§12) — Team/Liga/Piramide/Confederacion/
## Seleccion.guardar()/cargar(), ida y vuelta por JSON de verdad (como hace
## GameState.guardar_partida/cargar_partida), incluyendo referencias
## cruzadas de préstamos y continuidad del rng. Correr con:
## godot --headless --script tests/test_guardado.gd

const SEED := 9191


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_team_roundtrip(rng)
	_test_jugador_id_usable_como_clave_tras_cargar(rng)
	_test_piramide_roundtrip_completo(rng)
	_test_prestamo_resuelve_referencia_real(rng)
	_test_rng_state_continua_la_secuencia(rng)
	_test_borrar_partida_archivo_real()

	quit()


## JSON.stringify + JSON.parse, igual que hace GameState al guardar/cargar
## de archivo — así el test detecta cualquier cosa que no sobreviva la
## vuelta real (claves int convertidas a String, etc.), no solo el dict en memoria.
static func _roundtrip_json(datos: Dictionary) -> Dictionary:
	var texto := JSON.stringify(datos)
	var json := JSON.new()
	json.parse(texto)
	return json.data


func _test_team_roundtrip(rng: RandomNumberGenerator) -> void:
	print("=== Team.guardar()/cargar(): ida y vuelta por JSON preserva el estado ===")
	var equipo := Team.generar("ClubGuardado", rng, 0)
	equipo.reputacion = 63.5
	equipo.quebrado = true
	equipo.instalaciones["medica"] = 4
	equipo.generar_camada(rng, 2)
	var id_jugador: int = equipo.jugadores[0]["id"]
	equipo.suspendidos[id_jugador] = 2

	var datos := _roundtrip_json(equipo.guardar())
	var cargado := Team.cargar(datos)

	var ok: bool = cargado.nombre == equipo.nombre
	ok = ok and cargado.jugadores.size() == equipo.jugadores.size()
	ok = ok and cargado.cantera.size() == 2
	ok = ok and is_equal_approx(cargado.reputacion, 63.5)
	ok = ok and cargado.quebrado == true
	ok = ok and cargado.instalaciones["medica"] == 4
	ok = ok and cargado.suspendidos.get(id_jugador, 0) == 2  # sobrevive como INT, no como "id_jugador" string
	ok = ok and is_equal_approx(cargado.sueldos.get(id_jugador, -1.0), equipo.sueldos[id_jugador])
	ok = ok and is_equal_approx(cargado.clausulas.get(id_jugador, -1.0), equipo.clausulas[id_jugador])

	if ok:
		print("OK: reputacion, quebrado, instalaciones, cantera, suspendidos (con clave int) y sueldos/clausulas sobreviven la vuelta.")
	else:
		print("FALLA: cargado=%s" % [cargado.guardar()])


## Bug real que encontró este mismo test la primera vez: JSON no
## distingue int de float, así que jugador["id"] volvía como 5.0 en vez
## de 5 -- y como Godot trata 5 (int) y 5.0 (float) como claves de
## Dictionary DISTINTAS, absolutamente todo el motor (sueldos, contratos,
## mercado, ánimo...) que hace dict.get(jugador["id"]) fallaría en
## silencio después de cargar. Este test verifica el síntoma exacto.
func _test_jugador_id_usable_como_clave_tras_cargar(rng: RandomNumberGenerator) -> void:
	print("\n=== jugador['id'] sigue siendo un INT usable como clave de Dictionary tras el roundtrip ===")
	var equipo := Team.generar("ClubClaves", rng, 100)
	var datos := _roundtrip_json(equipo.guardar())
	var cargado := Team.cargar(datos)

	var ok := true
	for j in cargado.jugadores:
		var id = j["id"]
		if typeof(id) != TYPE_INT:
			ok = false
		if not cargado.sueldos.has(id):
			ok = false
		if not cargado.contratos.has(id):
			ok = false
		if not cargado.animo.has(id):
			ok = false

	if ok:
		print("OK: jugador['id'] es int y encuentra su entrada en sueldos/contratos/animo tras cargar.")
	else:
		print("FALLA: algun jugador quedo con id no-int o no se encuentra en sus propios dicts del club.")


func _test_piramide_roundtrip_completo(rng: RandomNumberGenerator) -> void:
	print("\n=== Piramide.guardar()/cargar(): las 10 divisiones completas sobreviven ===")
	var piramide := Piramide.generar(rng)
	var equipo_jugador: Team = piramide.divisiones[9].equipos[0]
	equipo_jugador.caja["fichajes"] = 12345.0

	var datos := _roundtrip_json(piramide.guardar())
	var cargada := Piramide.cargar(datos)

	var ok: bool = cargada.divisiones.size() == 10
	for d in range(10):
		ok = ok and cargada.divisiones[d].equipos.size() == 20

	var encontrado: Team = null
	for e in cargada.divisiones[9].equipos:
		if e.nombre == equipo_jugador.nombre:
			encontrado = e
			break
	ok = ok and encontrado != null and is_equal_approx(encontrado.caja["fichajes"], 12345.0)

	if ok:
		print("OK: 10 divisiones x 20 equipos, y el equipo del jugador se relocaliza por nombre con su estado intacto.")
	else:
		print("FALLA: divisiones=%d" % cargada.divisiones.size())


func _test_prestamo_resuelve_referencia_real(rng: RandomNumberGenerator) -> void:
	print("\n=== Un prestamo activo guarda el nombre del club y vuelve a ser una referencia real tras cargar ===")
	var piramide := Piramide.generar(rng)
	var origen: Team = piramide.divisiones[5].equipos[0]
	var destino: Team = piramide.divisiones[5].equipos[1]
	destino.caja["fichajes"] = 1000000.0
	var jugador_id: int = origen.banco[0]["id"]

	var resultado := Prestamos.ceder(origen, destino, jugador_id, 3)
	if not resultado["exito"]:
		print("FALLA: no se pudo armar el prestamo para el test (%s)" % [resultado])
		return

	var datos := _roundtrip_json(piramide.guardar())
	var cargada := Piramide.cargar(datos)  # Piramide.cargar() ya llama a resolver_prestamos()

	var origen_cargado: Team = null
	var destino_cargado: Team = null
	for e in cargada.divisiones[5].equipos:
		if e.nombre == origen.nombre:
			origen_cargado = e
		if e.nombre == destino.nombre:
			destino_cargado = e

	var info: Dictionary = origen_cargado.prestados_afuera.get(jugador_id, {})
	var ok: bool = info.has("club") and info["club"] is Team
	ok = ok and info["club"] == destino_cargado  # la MISMA instancia que vive en la piramide cargada, no una copia suelta

	if ok:
		print("OK: prestados_afuera['club'] es una referencia Team real tras cargar, y apunta al Team correcto de la piramide.")
	else:
		print("FALLA: info=%s" % [info])


func _test_rng_state_continua_la_secuencia(rng: RandomNumberGenerator) -> void:
	print("\n=== Guardar el rng.state permite continuar la MISMA secuencia tras cargar ===")
	var rng_original := RandomNumberGenerator.new()
	rng_original.seed = 555
	for i in range(37):
		rng_original.randf()  # lo desincroniza del seed puro, como pasaria jugando de verdad

	var seed_guardado: int = rng_original.seed
	var state_guardado: int = rng_original.state

	var siguientes_originales := []
	for i in range(5):
		siguientes_originales.append(rng_original.randf())

	var rng_cargado := RandomNumberGenerator.new()
	rng_cargado.seed = seed_guardado
	rng_cargado.state = state_guardado
	var siguientes_cargados := []
	for i in range(5):
		siguientes_cargados.append(rng_cargado.randf())

	if siguientes_originales == siguientes_cargados:
		print("OK: la secuencia despues de 'cargar' es identica a si nunca se hubiera guardado.")
	else:
		print("FALLA: originales=%s cargados=%s" % [siguientes_originales, siguientes_cargados])


func _test_borrar_partida_archivo_real() -> void:
	print("\n=== Guardar/borrar un archivo real en user:// ===")
	var ruta := "user://partida_test.json"
	var file := FileAccess.open(ruta, FileAccess.WRITE)
	file.store_string(JSON.stringify({"prueba": true}))
	file.close()

	var existia_antes := FileAccess.file_exists(ruta)
	DirAccess.remove_absolute(ruta)
	var existe_despues := FileAccess.file_exists(ruta)

	if existia_antes and not existe_despues:
		print("OK: el archivo se crea y despues se borra correctamente.")
	else:
		print("FALLA: existia_antes=%s existe_despues=%s" % [existia_antes, existe_despues])
