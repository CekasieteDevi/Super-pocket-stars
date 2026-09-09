extends SceneTree

## Las copas internacionales jugadas ronda a ronda, como las domésticas.
## Antes se resolvían enteras al cerrar la temporada y el club del jugador
## las veía pasar por el feed sin jugar un partido.
##
## Qué verificamos:
##   1. La temporada internacional arranca CON la temporada, con la previa
##      sorteada y los cupos repartidos.
##   2. Las rondas caen entre semana, repartidas en el calendario: las
##      tres copas terminan con campeón y la mayoría de sus rondas se
##      juegan antes del cierre.
##   3. El cruce del club del jugador FRENA el día y se juega con el motor
##      espacial: fotogramas, historial y noticia, igual que una copa.
##   4. La temporada internacional a medio jugar sobrevive al guardado.
##
## Correr con: godot --path . --headless --script tests/test_internacional_jugable.gd

const SEED := 4413

var fallos := 0


func _init() -> void:
	# El autoload GameState no existe en modo --script, y SIN meterlo en el
	# arbol: _ready() cargaria la partida guardada del usuario.
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(SEED, "Club Prueba")

	_test_arranque(gs)
	_test_partido_del_jugador(gs)
	_test_guardado(gs)
	_test_temporada_entera(SEED)

	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


func _test_arranque(gs) -> void:
	print("=== La temporada internacional arranca con la temporada ===")
	var t = gs.internacional
	_ok(t != null, "hay temporada internacional desde el dia cero.")
	_ok(t.previa_pendiente.size() == 6,
		"la previa tiene 6 cruces sorteados (tiene %d)." % t.previa_pendiente.size())
	_ok(t.copas.is_empty(),
		"las tres copas todavia no tienen fase de liga: primero se juega la previa.")

	# La previa es la primera ronda de todas: recien despues se sabe quien
	# juega Campeones y quien Guerreros.
	t.jugar_siguiente_ronda(gs.rng)
	var tamanos := []
	for clave in TemporadaInternacional.CLAVES:
		tamanos.append(t.copas[clave]["fase"].equipos.size())
	_ok(tamanos == [36, 24, 24],
		"despues de la previa las copas quedan con 36/24/24 equipos (quedaron %s)." % str(tamanos))
	_ok(t.previa_resultados.size() == 6, "quedan los 6 resultados de la previa.")


## El cruce propio con el club del jugador metido a mano en la previa: en
## la partida de verdad hace falta estar en Division 1 y salir primero o
## segundo, y este test mide el camino, no la clasificacion.
func _test_partido_del_jugador(gs) -> void:
	print("\n=== El cruce propio frena el dia y se juega ===")
	var primera: Array = gs.piramide.divisiones[0].equipos
	gs.internacional = TemporadaInternacional.iniciar({
		"campeones": primera.slice(0, 3),
		"guerreros": primera.slice(3, 6),
		"emergentes": primera.slice(6, 10),
		"previa": [[gs.equipo_jugador, primera[10]]],
	})
	gs.dia_proximo_internacional = gs.dia_temporada

	_ok(gs.hay_partido_internacional_hoy(), "el jugador tiene partido internacional hoy.")
	_ok(gs.rival_internacional() == primera[10],
		"el rival del cruce es el que dice el sorteo.")
	var dia_antes: int = gs.dia_temporada
	var novedades: Array = gs.avanzar_un_dia()
	_ok(novedades.is_empty() and gs.dia_temporada == dia_antes,
		"el calendario no avanza mientras el cruce propio espera.")

	var partidos_antes: int = gs.historial_partidos.size()
	gs.jugar_partido_internacional()
	_ok(not gs.ultimos_fotogramas.is_empty(),
		"el cruce propio se juega con el motor espacial (hay fotogramas).")
	_ok(gs.historial_partidos.size() == partidos_antes + 1
			and str(gs.historial_partidos[0]["torneo"]) == "Previa internacional",
		"el partido entra al historial con el nombre del torneo.")
	_ok(not gs.hay_partido_internacional_hoy(),
		"jugado el cruce, el dia se destraba.")

	# La previa reparte: el que gana va a Campeones y el que pierde a
	# Guerreros, asi que el club del jugador sigue jugando de las dos
	# maneras.
	var clave: String = gs.internacional.copa_de(gs.equipo_jugador)
	_ok(clave == "campeones" or clave == "guerreros",
		"despues de la previa el club queda en Campeones o en Guerreros (quedo en \"%s\")." % clave)

	# Y la fase de liga tambien se juega: es el grueso de la competencia.
	var jugo_fase_de_liga := false
	for i in range(12):
		if not gs.internacional.hay_pendiente():
			break
		gs.dia_proximo_internacional = gs.dia_temporada
		if gs.hay_partido_internacional_hoy():
			var era_fase_de_liga: bool = not bool(
				gs.cruce_internacional_de_hoy()["eliminatorio"])
			gs.jugar_partido_internacional()
			if era_fase_de_liga and not gs.ultimos_fotogramas.is_empty():
				jugo_fase_de_liga = true
		else:
			gs.resolver_ronda_internacional()
	_ok(jugo_fase_de_liga,
		"el club juega sus fechas de la fase de liga con el motor espacial.")


func _test_guardado(gs) -> void:
	print("\n=== La internacional a medio jugar sobrevive al guardado ===")
	# Por el mismo camino que la partida: a JSON y de vuelta, que es donde
	# los enteros se vuelven float y las referencias a Team se pierden.
	var texto := JSON.stringify(gs.internacional.guardar())
	var json := JSON.new()
	_ok(json.parse(texto) == OK, "el guardado de la internacional es JSON valido.")
	var indice: Dictionary = gs.confederacion.indice_de_equipos()
	var cargada = TemporadaInternacional.cargar(json.data, indice)

	var claves_iguales := true
	var tablas_iguales := true
	for clave in gs.internacional.copas:
		if not cargada.copas.has(clave):
			claves_iguales = false
			continue
		var original: Dictionary = gs.internacional.copas[clave]
		var vuelta: Dictionary = cargada.copas[clave]
		if int(original["fecha"]) != int(vuelta["fecha"]):
			tablas_iguales = false
		if original["fase"].tabla_ordenada() != vuelta["fase"].tabla_ordenada():
			tablas_iguales = false
		if original["fase"].equipos.size() != vuelta["fase"].equipos.size():
			tablas_iguales = false
	_ok(claves_iguales, "vuelven las tres copas.")
	_ok(tablas_iguales, "vuelven la fecha, la tabla y los equipos de cada fase de liga.")
	_ok(cargada.hay_pendiente() == gs.internacional.hay_pendiente(),
		"vuelve igual de terminada (o de pendiente) que estaba.")


## Una temporada completa por el camino de la partida: las rondas caen
## entre semana y no todas amontonadas en el cierre.
func _test_temporada_entera(semilla: int) -> void:
	print("\n=== Una temporada entera, ronda a ronda ===")
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(semilla, "Club Prueba")

	var fecha_del_final := -1
	var pasos := 0
	while gs.temporada_actual == 1 and pasos < 5000:
		pasos += 1
		if fecha_del_final < 0 and not gs.internacional.hay_pendiente():
			fecha_del_final = gs.fecha_actual
		if gs.hay_partido_hoy():
			gs.jugar_siguiente_fecha()
			continue
		if gs.hay_partido_de_copa_hoy():
			gs.resolver_ronda_de_copa()
			continue
		if gs.hay_partido_internacional_hoy():
			gs.resolver_ronda_internacional()
			continue
		gs.avanzar_un_dia()

	var fechas: int = gs.piramide.divisiones[0].fixture.size()
	_ok(gs.temporada_actual == 2, "la temporada cerro (pasos=%d)." % pasos)
	_ok(fecha_del_final > 0 and fecha_del_final <= fechas,
		"la internacional termino en la fecha %d de %d, no en el cierre." % [
			fecha_del_final, fechas])

	var campeones := []
	for clave in TemporadaInternacional.CLAVES:
		var datos: Dictionary = gs.copas_internacionales.get(clave, {})
		campeones.append(str(datos.get("campeon", "")))
	_ok(not campeones.has(""),
		"las tres copas terminaron con campeon (%s)." % ", ".join(campeones))

	var rondas_campeones: int = gs.copas_internacionales["campeones"]["rondas"].size()
	_ok(rondas_campeones == 4,
		"la Copa de Campeones jugo sus 4 rondas de eliminacion (jugo %d)." % rondas_campeones)

	# Y la temporada que viene arranca con la internacional nueva ya
	# sorteada, igual que el Rey.
	_ok(gs.internacional != null and gs.internacional.previa_pendiente.size() == 6,
		"la temporada 2 arranca con la previa internacional sorteada.")
	_ok(int(gs.copas_internacionales.get("temporada", 0)) == 1,
		"la pantalla de copas sigue mostrando la internacional de la temporada 1 "
		+ "hasta que se juegue la previa de la 2.")
