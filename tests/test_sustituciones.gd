extends SceneTree

## Sustituciones durante el partido (§8.7) — "11 en cancha" real (antes el
## motor sampleaba directo de los 18 sin ningún concepto de quién juega
## ahora), hasta 5 cambios automáticos por lesión/cansancio en 3 ventanas
## (entretiempo, 60', 75'), sin reemplazo para las rojas.
## Correr con: godot --headless --script tests/test_sustituciones.gd

const SEED := 4141


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_en_cancha_arranca_como_los_titulares(rng)
	_test_arquero_y_disponibles_respetan_en_cancha(rng)
	_test_cambios_nunca_superan_el_maximo(rng)
	_test_expulsado_no_se_reemplaza(rng)
	_test_lesionado_termina_reemplazado_en_alguna_ventana(rng)
	_test_descanso_sustituye_mas_que_rendimiento(rng)
	_test_config_cambios_persiste_en_guardado(rng)

	quit()


func _test_en_cancha_arranca_como_los_titulares(rng: RandomNumberGenerator) -> void:
	print("=== en_cancha arranca como los 11 titulares al resetear el partido ===")
	var equipo := Team.generar("ClubA", rng, 0)
	equipo.reset_partido()
	var ids_titulares := equipo.jugadores.map(func(j): return j["id"])
	var ok: bool = equipo.en_cancha.size() == 11 and equipo.cambios_realizados == 0
	for id in ids_titulares:
		ok = ok and equipo.en_cancha.has(id)
	if ok:
		print("OK: en_cancha = los 11 titulares, cambios_realizados = 0.")
	else:
		print("FALLA: en_cancha=%s" % [equipo.en_cancha])


func _test_arquero_y_disponibles_respetan_en_cancha(rng: RandomNumberGenerator) -> void:
	print("\n=== arquero() y jugadores_disponibles_por_posiciones() usan en_cancha, no los 18 ===")
	var equipo := Team.generar("ClubB", rng, 0)
	equipo.reset_partido()
	var arquero_titular: Dictionary = equipo.arquero()
	var arquero_banco: Dictionary = {}
	for j in equipo.banco:
		if j["posicion"] == "ARQ":
			arquero_banco = j
			break

	equipo.sustituir(arquero_titular["id"], arquero_banco["id"])
	var arquero_despues: Dictionary = equipo.arquero()

	var disponibles := equipo.jugadores_disponibles_por_posiciones(["ARQ"])
	var solo_el_que_entro: bool = disponibles.size() == 1 and disponibles[0]["id"] == arquero_banco["id"]

	if arquero_despues["id"] == arquero_banco["id"] and solo_el_que_entro:
		print("OK: tras el cambio, arquero() y disponibles() devuelven al que ENTRO, no al titular original.")
	else:
		print("FALLA: arquero_despues=%s disponibles=%s" % [arquero_despues.get("id", "?"), disponibles])


func _test_cambios_nunca_superan_el_maximo(rng: RandomNumberGenerator) -> void:
	print("\n=== cambios_realizados nunca pasa de Team.MAX_CAMBIOS (5), pase lo que pase ===")
	var home := Team.generar("Home", rng, 0)
	var away := Team.generar("Away", rng, 100)
	home.config_cambios = "descanso"  # el modo mas agresivo, el que mas presiona el limite
	away.config_cambios = "descanso"

	var excedio := false
	for i in range(30):
		var rng_partido := RandomNumberGenerator.new()
		rng_partido.seed = 2000 + i
		MatchEngine.simular(home, away, rng_partido)
		if home.cambios_realizados > Team.MAX_CAMBIOS or away.cambios_realizados > Team.MAX_CAMBIOS:
			excedio = true
			break

	if not excedio:
		print("OK: en 30 partidos con modo 'descanso' (el mas agresivo), nunca se paso de %d cambios." % Team.MAX_CAMBIOS)
	else:
		print("FALLA: home=%d away=%d" % [home.cambios_realizados, away.cambios_realizados])


func _test_expulsado_no_se_reemplaza(rng: RandomNumberGenerator) -> void:
	print("\n=== Un expulsado (roja) nunca se cambia por un suplente ===")
	var equipo := Team.generar("ClubExpulsado", rng, 0)
	equipo.reset_partido()
	var jugador: Dictionary = equipo.jugadores[1]
	equipo.expulsados_partido[jugador["id"]] = true
	equipo.resistencia[jugador["id"]] = 0.5  # ademas cansado, para probar que ni asi se lo cambia

	var log := []
	var eventos := []
	MatchEngine._procesar_cambios_equipo(equipo, 45, false, log, eventos)

	if equipo.en_cancha.has(jugador["id"]) and equipo.cambios_realizados == 0:
		print("OK: el expulsado sigue en_cancha (el equipo juega con uno menos), no se genero ningun cambio.")
	else:
		print("FALLA: en_cancha.has=%s cambios_realizados=%d" % [equipo.en_cancha.has(jugador["id"]), equipo.cambios_realizados])


func _test_lesionado_termina_reemplazado_en_alguna_ventana(rng: RandomNumberGenerator) -> void:
	print("\n=== Un jugador lesionado a mitad de partido termina afuera de en_cancha ===")
	var equipo := Team.generar("ClubLesionado", rng, 0)
	var rival := Team.generar("Rival", rng, 100)
	equipo.reset_partido()
	rival.reset_partido()

	var jugador: Dictionary = equipo.jugadores[3]  # un LAT, tiene reemplazo directo en banco
	equipo.lesionar(jugador["id"], "Desgarro leve isquiotibiales", 14)

	var log := []
	var eventos := []
	MatchEngine._procesar_cambios_equipo(equipo, 45, false, log, eventos)

	if not equipo.en_cancha.has(jugador["id"]) and equipo.cambios_realizados == 1:
		print("OK: el lesionado salio en la primera ventana de cambios (entretiempo).")
	else:
		print("FALLA: en_cancha.has=%s cambios_realizados=%d" % [equipo.en_cancha.has(jugador["id"]), equipo.cambios_realizados])


func _test_descanso_sustituye_mas_que_rendimiento(rng: RandomNumberGenerator) -> void:
	print("\n=== 'Priorizar descanso' hace mas cambios en promedio que 'Priorizar rendimiento' ===")
	var home := Team.generar("HomeConfig", rng, 0)
	var away := Team.generar("AwayConfig", rng, 100)

	var muestras := 40
	home.config_cambios = "descanso"
	var total_descanso := 0
	for i in range(muestras):
		var rng_partido := RandomNumberGenerator.new()
		rng_partido.seed = 3000 + i
		MatchEngine.simular(home, away, rng_partido)
		total_descanso += home.cambios_realizados

	home.config_cambios = "rendimiento"
	var total_rendimiento := 0
	for i in range(muestras):
		var rng_partido := RandomNumberGenerator.new()
		rng_partido.seed = 3000 + i
		MatchEngine.simular(home, away, rng_partido)
		total_rendimiento += home.cambios_realizados

	if total_descanso > total_rendimiento:
		print("OK: 'descanso' hizo %d cambios en %d partidos vs %d de 'rendimiento'." % [total_descanso, muestras, total_rendimiento])
	else:
		print("FALLA: descanso=%d rendimiento=%d" % [total_descanso, total_rendimiento])


func _test_config_cambios_persiste_en_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== config_cambios sobrevive un guardar/cargar, y un guardado viejo cae en 'equilibrado' ===")
	var equipo := Team.generar("ClubGuardado", rng, 0)
	equipo.config_cambios = "rendimiento"
	var datos := equipo.guardar()
	var texto := JSON.stringify(datos)
	var cargado := Team.cargar(JSON.parse_string(texto))

	var datos_viejos := equipo.guardar()
	datos_viejos.erase("config_cambios")
	var cargado_viejo := Team.cargar(JSON.parse_string(JSON.stringify(datos_viejos)))

	if cargado.config_cambios == "rendimiento" and cargado_viejo.config_cambios == "equilibrado":
		print("OK: round-trip preserva 'rendimiento', guardado viejo sin la clave cae en 'equilibrado'.")
	else:
		print("FALLA: cargado=%s cargado_viejo=%s" % [cargado.config_cambios, cargado_viejo.config_cambios])
