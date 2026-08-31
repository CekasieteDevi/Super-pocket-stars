extends SceneTree

## §4.2: con rivales metidos en su propio tercio, el arquero la manda
## lejos en vez de repartirla corto — y eso lo decide su INTELIGENCIA.
##
## Viene de verlo jugando: el arquero atajaba, se la daba a un central con
## delanteros encima, se la sacaban en la puerta del area y le pegaban al
## arco, una y otra vez.

const SEED := 8800


func _init() -> void:
	_test_el_arquero_lucido_la_revienta()
	_test_sin_rivales_cerca_reparte_tranquilo()
	quit()


## Arma la escena: arquero con la pelota, `invasores` rivales metidos en
## su tercio, y sus companeros a distancia de pase.
func _escena(inteligencia: int, invasores: int, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = "despejado"
	visita.clima_partido = "despejado"
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var arq: Dictionary = casa.arquero()
	if not arq.is_empty():
		arq["atributos"]["inteligencia"] = inteligencia

	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, true, 1)
	var clave := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] and str(e["rol"]) == "ARQ":
			clave = id
			break
	var e_arq: Dictionary = estado["jugadores"][clave]
	e_arq["pos"] = Vector2(-48.0, 0.0)
	estado["pelota"]["poseedor_id"] = clave
	estado["pelota"]["pos"] = e_arq["pos"]
	estado["pelota"]["en_vuelo"] = false

	var metidos := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"]:
			if str(e["rol"]) in ["DFC", "LAT"]:
				e["pos"] = Vector2(-36.0, -10.0 if int(id) % 2 == 0 else 10.0)
			continue
		if metidos < invasores:
			e["pos"] = Vector2(-32.0 + metidos * 2.0, -8.0 + metidos * 8.0)
			metidos += 1
		else:
			e["pos"] = Vector2(20.0, 0.0)
	return {"estado": estado, "casa": casa, "arquero": e_arq}


## La diferencia de utilidad entre reventarla y darla corto. Positiva =
## el motor prefiere sacarla.
##
## Se mide la BRECHA y no cual gana: en una escena armada a mano el
## pelotazo gana casi siempre por otros motivos (los companeros quedan
## lejos), asi que mirar al ganador no distingue nada. La brecha si.
func _brecha(inteligencia: int, invasores: int, semilla: int) -> float:
	var d := _escena(inteligencia, invasores, semilla)
	var jug := MotorEspacial._dict_jugador(
		d["estado"], d["casa"], int(d["arquero"]["jugador_id"]))
	if jug.is_empty():
		return 0.0
	var mejor_largo := -INF
	var mejor_corto := -INF
	for o in MotorEspacial.evaluar_opciones(d["estado"], d["arquero"], jug):
		if str(o["tipo"]) == "pase_largo":
			mejor_largo = maxf(mejor_largo, float(o["utilidad"]))
		elif str(o["tipo"]) == "pase":
			mejor_corto = maxf(mejor_corto, float(o["utilidad"]))
	if mejor_largo == -INF or mejor_corto == -INF:
		return 0.0
	return mejor_largo - mejor_corto


func _promedio_brecha(inteligencia: int, invasores: int) -> float:
	var suma := 0.0
	var n := 40
	for i in range(n):
		suma += _brecha(inteligencia, invasores, SEED + i)
	return suma / float(n)


func _test_el_arquero_lucido_la_revienta() -> void:
	print("=== Con rivales en su tercio, al lucido le pesa mas sacarla ===")
	var lucido := _promedio_brecha(95, 3)
	var limitado := _promedio_brecha(10, 3)
	if lucido <= limitado:
		print("FALLA: lucido %.2f, limitado %.2f; el lucido tendria que preferirlo mas." % [
			lucido, limitado])
		return
	print("OK: con 3 rivales encima, al lucido reventarla le rinde %.2f mas que darla corto, y al limitado %.2f." % [
		lucido, limitado])


func _test_sin_rivales_cerca_reparte_tranquilo() -> void:
	print("
=== Sin nadie cerca, la presion no le mueve la decision ===")
	var presionado := _promedio_brecha(95, 3)
	var tranquilo := _promedio_brecha(95, 0)
	if presionado <= tranquilo:
		print("FALLA: presionado %.2f, tranquilo %.2f; la presion tendria que empujarlo a sacarla." % [
			presionado, tranquilo])
		return
	print("OK: presionado %.2f contra %.2f tranquilo: la diferencia son los rivales." % [
		presionado, tranquilo])
