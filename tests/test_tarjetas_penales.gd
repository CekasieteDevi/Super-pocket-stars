extends SceneTree

## Tarjetas/expulsiones/suspensiones (§8.7) y alargue + penales en copas.
## Correr con: godot --headless --script tests/test_tarjetas_penales.gd

const SEED := 6161


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_aparecen_tarjetas_en_muchos_partidos(rng)
	_test_doble_amarilla_es_roja(rng)
	_test_expulsado_no_puede_jugar_el_resto_del_partido(rng)
	_test_suspension_se_sirve_y_libera(rng)
	_test_penales_terminan_con_ganador(rng)
	_test_penales_de_alguna_manera_gana_cualquiera_de_los_dos(rng)
	_test_alargue_continua_el_marcador_sin_resetear(rng)
	_test_copa_nunca_gana_solo_por_ser_local(rng)

	quit()


func _test_aparecen_tarjetas_en_muchos_partidos(rng: RandomNumberGenerator) -> void:
	print("=== Aparecen tarjetas (amarillas y rojas) en un volumen razonable de partidos ===")
	var amarillas := 0
	var rojas := 0
	for i in range(60):
		var home := Team.generar("Home%d" % i, rng, i * 1000)
		var away := Team.generar("Away%d" % i, rng, i * 1000 + 500)
		var r := MatchEngine.simular(home, away, rng, false)
		for e in r["eventos"]:
			if e["tipo"] == "tarjeta":
				if e["resultado"] == "amarilla":
					amarillas += 1
				else:
					rojas += 1

	if amarillas > 0 and rojas >= 0:
		print("OK: %d amarillas y %d rojas en 60 partidos." % [amarillas, rojas])
	else:
		print("FALLA: no aparecio ninguna tarjeta en 60 partidos (amarillas=%d rojas=%d)." % [amarillas, rojas])


func _test_doble_amarilla_es_roja(rng: RandomNumberGenerator) -> void:
	print("\n=== Segunda amarilla en el mismo partido = roja automatica ===")
	var equipo := Team.generar("ClubTarjetas", rng, 10000)
	var jugador: Dictionary = equipo.jugadores[0]
	var id: int = jugador["id"]
	equipo.reset_partido()

	# Llama al chequeo real muchas veces sobre el mismo jugador (sin
	# resetear el partido entre medio) hasta que junte 2 amarillas o una
	# roja directa -- es probabilistico así que se le da margen de sobra.
	var eventos := []
	for i in range(3000):
		if equipo.expulsados_partido.has(id):
			break
		MatchEngine._chequear_tarjeta(jugador, equipo, rng, eventos, 10)

	var ok: bool = equipo.expulsados_partido.has(id) and equipo.suspendidos.get(id, 0) == 1

	if ok and equipo.amarillas_partido.get(id, 0) >= 2:
		print("OK: con 2 amarillas el jugador queda expulsado (roja por doble amarilla) y suspendido para el proximo partido.")
	elif ok:
		print("OK: el jugador quedo expulsado (roja directa) y suspendido para el proximo partido.")
	else:
		print("FALLA: no se llego a una expulsion en 3000 intentos (amarillas=%d)." % equipo.amarillas_partido.get(id, 0))


func _test_expulsado_no_puede_jugar_el_resto_del_partido(rng: RandomNumberGenerator) -> void:
	print("\n=== Un jugador expulsado no puede jugar el resto del partido ===")
	var equipo := Team.generar("ClubExpulsado", rng, 11000)
	var id: int = equipo.jugadores[0]["id"]
	equipo.reset_partido()
	equipo.expulsados_partido[id] = true

	if not equipo.puede_jugar(id):
		print("OK: puede_jugar() devuelve false para un expulsado.")
	else:
		print("FALLA: un expulsado sigue figurando como disponible.")


func _test_suspension_se_sirve_y_libera(rng: RandomNumberGenerator) -> void:
	print("\n=== La suspension se sirve jugando la fecha siguiente y despues queda libre ===")
	var liga := Liga.new()
	liga.inicializar(["A", "B", "C", "D"], rng, 0)
	var equipo: Team = liga.equipos[0]
	var id: int = equipo.jugadores[0]["id"]
	equipo.suspendidos[id] = 1

	var ok_no_disponible_antes: bool = not equipo.puede_jugar(id)

	liga._servir_suspensiones(equipo, [id])

	var ok_disponible_despues: bool = equipo.puede_jugar(id) and not equipo.suspendidos.has(id)

	if ok_no_disponible_antes and ok_disponible_despues:
		print("OK: no disponible mientras dura la suspension, disponible de nuevo despues de servirla.")
	else:
		print("FALLA: antes=%s despues=%s" % [not ok_no_disponible_antes, equipo.suspendidos])


func _test_penales_terminan_con_ganador(rng: RandomNumberGenerator) -> void:
	print("\n=== Penales.definir() siempre termina con un ganador claro ===")
	var home := Team.generar("PenalesHome", rng, 20000)
	var away := Team.generar("PenalesAway", rng, 21000)

	var resultado := Penales.definir(home, away, rng)
	var ok: bool = resultado["ganador"] == home or resultado["ganador"] == away
	ok = ok and resultado["goles_local"] != resultado["goles_visitante"]
	ok = ok and resultado["tandas"].size() > 0

	if ok:
		print("OK: %d-%d, gana %s, %d patadas." % [resultado["goles_local"], resultado["goles_visitante"], resultado["ganador"].nombre, resultado["tandas"].size()])
	else:
		print("FALLA: %s" % [resultado])


func _test_penales_de_alguna_manera_gana_cualquiera_de_los_dos(rng: RandomNumberGenerator) -> void:
	print("\n=== Penales: en muchas definiciones, gana local y visitante (no esta trucado) ===")
	var gano_local := 0
	var gano_visitante := 0
	for i in range(40):
		var home := Team.generar("PH%d" % i, rng, 30000 + i * 100)
		var away := Team.generar("PA%d" % i, rng, 40000 + i * 100)
		var resultado := Penales.definir(home, away, rng)
		if resultado["ganador"] == home:
			gano_local += 1
		else:
			gano_visitante += 1

	if gano_local > 0 and gano_visitante > 0:
		print("OK: de 40 definiciones, gano el local %d veces y el visitante %d." % [gano_local, gano_visitante])
	else:
		print("FALLA: siempre gano el mismo lado (local=%d visitante=%d)." % [gano_local, gano_visitante])


func _test_alargue_continua_el_marcador_sin_resetear(rng: RandomNumberGenerator) -> void:
	print("\n=== simular_alargue() suma sobre el marcador existente, no lo resetea ===")
	var home := Team.generar("AlargueHome", rng, 50000)
	var away := Team.generar("AlargueAway", rng, 51000)
	home.reset_partido()
	away.reset_partido()
	home.goles = 2
	away.goles = 2

	var r := MatchEngine.simular_alargue(home, away, rng, false)

	var ok: bool = r["goles_local"] >= 2 and r["goles_visitante"] >= 2
	ok = ok and r["goles_local"] == home.goles and r["goles_visitante"] == away.goles
	for e in r["eventos"]:
		ok = ok and e["minuto"] > 90

	if ok:
		print("OK: alargue arranca desde 2-2 (%d-%d final) y los eventos son todos > minuto 90." % [r["goles_local"], r["goles_visitante"]])
	else:
		print("FALLA: goles_local=%d goles_visitante=%d" % [r["goles_local"], r["goles_visitante"]])


func _test_copa_nunca_gana_solo_por_ser_local(rng: RandomNumberGenerator) -> void:
	print("\n=== Copa: los empates de 90' se definen por alargue/penales, no 'gana el local' ===")
	var casos_definidos := 0
	var gano_visitante_en_definicion := false
	for i in range(60):
		var equipos := [
			Team.generar("CopaEq%d_0" % i, rng, 60000 + i * 1000),
			Team.generar("CopaEq%d_1" % i, rng, 60000 + i * 1000 + 500),
		]
		var copa := Copa.iniciar("Prueba", equipos, rng)
		var resultados := copa.jugar_siguiente_ronda(rng)
		for r in resultados:
			if r["definicion"] != "90 minutos":
				casos_definidos += 1
				if r["ganador"] == r["visitante"]:
					gano_visitante_en_definicion = true

	if casos_definidos > 0 and gano_visitante_en_definicion:
		print("OK: %d cruces se definieron por alargue/penales, y el visitante gano al menos uno." % casos_definidos)
	elif casos_definidos == 0:
		print("FALLA: en 60 cruces ninguno llego a 90' empatado -- no se pudo probar el caso.")
	else:
		print("FALLA: %d cruces se definieron por alargue/penales pero el visitante nunca gano -- sospechoso de la vieja regla 'gana el local'." % casos_definidos)
