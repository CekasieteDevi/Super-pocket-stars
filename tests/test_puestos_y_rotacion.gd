extends SceneTree

## §8.4 #4 (fuera de posicion) y #25 (partidos seguidos sin rotar), y los
## dos rasgos que los cancelan: Adaptable y Madrugador. Eran los dos
## ultimos rasgos que el generador repartia sin que hicieran nada.

const SEED := 60912


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_la_distancia_entre_puestos()
	_test_el_tope_es_doce()
	_test_adaptable_lo_cancela(rng)
	_test_el_once_propio_no_paga_nada(rng)
	_test_mover_un_jugador_cuesta(rng)
	_test_partidos_seguidos_y_madrugador(rng)
	_test_pesa_en_el_partido(rng)

	quit()


func _test_la_distancia_entre_puestos() -> void:
	print("=== Cuanto mas lejos del puesto natural, mas caro ===")
	if Puestos.distancia("DC", "DC") != 0:
		print("FALLA: en su propio puesto no puede costar nada.")
		return
	# Un central de lateral es un escalon (cambia de carril, no de linea).
	var lateral := Puestos.distancia("DFC", "LAT")
	# Un central de 9 cruza la cancha entera.
	var delantero := Puestos.distancia("DFC", "DC")
	if not (lateral < delantero):
		print("FALLA: DFC->LAT %d no es menor que DFC->DC %d." % [lateral, delantero])
		return
	if Puestos.modificador("DFC", "LAT") >= 0.0:
		print("FALLA: fuera de puesto tiene que restar.")
		return
	print("OK: DFC de LAT %.0f, DFC de DC %.0f, ARQ de DC %.0f." % [
		Puestos.modificador("DFC", "LAT"), Puestos.modificador("DFC", "DC"),
		Puestos.modificador("ARQ", "DC")])


func _test_el_tope_es_doce() -> void:
	print("\n=== Nunca pasa de -12, que es el tope del GDD ===")
	var peor := 0.0
	for a in Puestos.MAPA:
		for b in Puestos.MAPA:
			var m := Puestos.modificador(str(a), str(b))
			if m < peor:
				peor = m
	if peor < -Puestos.MAXIMO:
		print("FALLA: el peor caso da %.1f, se pasa de -%.0f." % [peor, Puestos.MAXIMO])
		return
	print("OK: el peor cruce de los 49 da %.0f." % peor)


func _test_adaptable_lo_cancela(rng: RandomNumberGenerator) -> void:
	print("\n=== Adaptable juega donde sea sin pagar ===")
	var normal := {"posicion": "DFC", "personalidades": {"positiva": "", "negativa": ""}}
	var adaptable := {"posicion": "DFC", "personalidades": {"positiva": "Adaptable", "negativa": ""}}
	var a := Puestos.modificador_de(normal, "DC")
	var b := Puestos.modificador_de(adaptable, "DC")
	if a >= 0.0:
		print("FALLA: un DFC de 9 tendria que pagar algo.")
		return
	if b != 0.0:
		print("FALLA: Adaptable pago %.1f y no tendria que pagar nada." % b)
		return
	print("OK: un DFC de 9 paga %.0f; el mismo con Adaptable paga 0." % a)


func _test_el_once_propio_no_paga_nada(rng: RandomNumberGenerator) -> void:
	print("\n=== Un equipo parado en su formacion no paga nada ===")
	var e := Team.generar("EnSuPuesto", rng, 0)
	var total := 0.0
	for j in e.jugadores:
		total += e.penalizacion_puesto(int(j["id"]))
	if total != 0.0:
		print("FALLA: un plantel armado para su formacion pago %.1f." % total)
		return
	print("OK: los once en su puesto, 0 de castigo.")


func _test_mover_un_jugador_cuesta(rng: RandomNumberGenerator) -> void:
	print("\n=== Arrastrar a alguien a otro puesto se paga ===")
	var e := Team.generar("Movido", rng, 0)
	var roles: Array = Formaciones.roles(e.formacion)
	# Se intercambian el arquero y el ultimo del once: es el cruce mas
	# grande que se puede hacer arrastrando en la pantalla de Formacion.
	var arquero: Dictionary = e.jugadores[0]
	# Sin rasgos: si al arquero le tocaba Adaptable —un 8% del pool comun—
	# no pagaba nada y el test fallaba sin que hubiera nada roto.
	arquero["personalidades"] = {"positiva": "", "negativa": ""}
	e.jugadores[0] = e.jugadores[roles.size() - 1]
	e.jugadores[roles.size() - 1] = arquero
	var castigo := e.penalizacion_puesto(int(arquero["id"]))
	if castigo >= 0.0:
		print("FALLA: poner al arquero de %s no costo nada." % roles[roles.size() - 1])
		return
	print("OK: el arquero puesto de %s paga %.0f." % [roles[roles.size() - 1], castigo])


func _test_partidos_seguidos_y_madrugador(rng: RandomNumberGenerator) -> void:
	print("\n=== Jugarlo todo sin rotar se paga, salvo si es Madrugador ===")
	var e := Team.generar("SinRotar", rng, 0)
	var j: Dictionary = e.jugadores[3]
	var id := int(j["id"])

	j["partidos_seguidos_titular"] = Team.PARTIDOS_SEGUIDOS_SIN_COSTO
	if e.penalizacion_partidos_seguidos(id) != 0.0:
		print("FALLA: hasta %d seguidos no tendria que costar." % Team.PARTIDOS_SEGUIDOS_SIN_COSTO)
		return

	j["partidos_seguidos_titular"] = Team.PARTIDOS_SEGUIDOS_SIN_COSTO + 2
	var algo := e.penalizacion_partidos_seguidos(id)
	if algo >= 0.0:
		print("FALLA: con %d seguidos tendria que restar." % (Team.PARTIDOS_SEGUIDOS_SIN_COSTO + 2))
		return

	j["partidos_seguidos_titular"] = 60
	var tope := e.penalizacion_partidos_seguidos(id)
	if tope < -Team.COSTO_MAXIMO_SEGUIDOS:
		print("FALLA: con 60 seguidos da %.1f, se pasa del tope." % tope)
		return

	j["personalidades"] = {"positiva": "Madrugador", "negativa": ""}
	if e.penalizacion_partidos_seguidos(id) != 0.0:
		print("FALLA: Madrugador no tendria que pagar nada.")
		return
	print("OK: %d seguidos 0, %d seguidos %.1f, 60 seguidos %.0f (tope), y Madrugador 0." % [
		Team.PARTIDOS_SEGUIDOS_SIN_COSTO, Team.PARTIDOS_SEGUIDOS_SIN_COSTO + 2, algo, tope])


func _test_pesa_en_el_partido(rng: RandomNumberGenerator) -> void:
	print("\n=== Un once desordenado rinde peor que el mismo once ordenado ===")
	var muestras := 60
	var puntos_ordenado := 0
	var puntos_revuelto := 0

	for i in range(muestras):
		var r1 := RandomNumberGenerator.new()
		r1.seed = 5150 + i
		var casa := Team.generar("Casa", r1, 0)
		var visita := Team.generar("Visita", r1, 100)
		puntos_ordenado += _puntos(MatchEngine.simular(casa, visita, r1, false))

		var r2 := RandomNumberGenerator.new()
		r2.seed = 5150 + i
		var casa2 := Team.generar("Casa", r2, 0)
		var visita2 := Team.generar("Visita", r2, 100)
		# Mismo plantel, misma semilla: lo unico distinto es que estan
		# parados al reves.
		casa2.jugadores.reverse()
		puntos_revuelto += _puntos(MatchEngine.simular(casa2, visita2, r2, false))

	if puntos_revuelto >= puntos_ordenado:
		print("FALLA: revuelto %d puntos, ordenado %d." % [puntos_revuelto, puntos_ordenado])
		return
	print("OK: en %d partidos, ordenado %d puntos y con el once dado vuelta %d." % [
		muestras, puntos_ordenado, puntos_revuelto])


func _puntos(res: Dictionary) -> int:
	var gf: int = res["goles_local"]
	var gc: int = res["goles_visitante"]
	if gf > gc:
		return 3
	return 1 if gf == gc else 0
