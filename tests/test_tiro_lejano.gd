extends SceneTree

## BUG-007: compara decisiones y recepciones reales del remate, con escenas
## emparejadas. El diagnóstico de liga verifica el balance por separado.
const SEED := 7007
const MUESTRAS := 1000
var fallos := 0


func _init() -> void:
	for local in [true, false]:
		_test_decision(local)
		_test_punteria(local)
	_test_observabilidad()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _comprobar(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion: fallos += 1


func _escena(local: bool, distancia: float, tiro: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	for equipo in [casa, visita]:
		for jugador in equipo.jugadores:
			for atributo in jugador["atributos"]:
				jugador["atributos"][atributo] = 50.0
		equipo.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, local, 1)
	var atacante: Dictionary = (casa if local else visita).jugadores.back()
	atacante["atributos"]["tiro"] = tiro
	var clave := MotorEspacial.clave_de(atacante["id"], local)
	var poseedor: Dictionary = estado["jugadores"][clave]
	for id in estado["jugadores"]:
		# La prueba mide puntería, sin defensores bloqueando la trayectoria.
		estado["jugadores"][id]["pos"] = Vector2(0.0, 30.0)
	poseedor["pos"] = MotorEspacial.arco_rival(local) + Vector2(-distancia if local else distancia, 0.0)
	estado["pelota"]["pos"] = poseedor["pos"]
	estado["pelota"]["poseedor_id"] = clave
	return {"estado": estado, "poseedor": poseedor, "jugador": atacante,
		"casa": casa, "visita": visita}


func _opcion_tiro(escena: Dictionary) -> Dictionary:
	for opcion in MotorEspacial.evaluar_opciones(escena["estado"], escena["poseedor"], escena["jugador"]):
		if opcion["tipo"] == "tiro": return opcion
	return {}


func _test_decision(local: bool) -> void:
	var escena := _escena(local, 20.0, 40.0)
	var flojo := _opcion_tiro(escena)
	escena["jugador"]["atributos"]["tiro"] = 90.0
	var bueno := _opcion_tiro(escena)
	_comprobar(not flojo.is_empty() and not bueno.is_empty()
		and is_equal_approx(float(flojo.get("utilidad", -1)), float(bueno.get("utilidad", -2))),
		"el alcance no aumenta la utilidad desde el mismo punto; local=%s" % local)
	escena["poseedor"]["pos"] = MotorEspacial.arco_rival(local) + Vector2(-30.0 if local else 30.0, 0.0)
	var lejano := _opcion_tiro(escena)
	escena["jugador"]["atributos"]["tiro"] = 20.0
	_comprobar(not lejano.is_empty() and _opcion_tiro(escena).is_empty(),
		"el buen tiro conserva el recurso lejano; poco alcance no lo habilita")
	_comprobar(float(lejano.get("utilidad", INF)) < float(bueno.get("utilidad", -INF)),
		"acercarse al arco vale más que rematar de lejos")


func _medir(local: bool, distancia: float, tiro: float) -> Dictionary:
	var escena := _escena(local, distancia, tiro)
	var plantilla: Dictionary = escena["estado"]
	var puerta := 0
	var goles := 0
	for indice in range(MUESTRAS):
		escena["casa"].reset_partido()
		escena["visita"].reset_partido()
		var estado := plantilla.duplicate(true)
		estado["rng"].seed = SEED + indice
		var poseedor: Dictionary = estado["jugadores"][escena["poseedor"]["clave"]]
		MotorEspacial._resolver_tiro(estado, poseedor, escena["jugador"])
		var resultado := str(estado["pelota"].get("remate", {}).get("tipo", ""))
		if resultado in ["gol", "atajada"]: puerta += 1
		if resultado == "gol": goles += 1
	return {"puerta": float(puerta) / MUESTRAS, "goles": float(goles) / MUESTRAS}


func _test_punteria(local: bool) -> void:
	# La escena no tiene a nadie cerca: presion cero. Desde la etapa 9 la
	# presion se centra en su media (presion_referencia), asi que presion cero
	# suma punteria en TODAS las distancias y el tope de 0,85 aplasta la
	# diferencia de cerca. Esta prueba mide la distancia sola: la presion se
	# neutraliza y se prueba aparte en test_contexto_ocasion.gd.
	var resolucion: Dictionary = MotorEspacial.pesos()["tiro_resolucion"]
	var referencia = resolucion.get("presion_referencia", 0.0)
	resolucion["presion_referencia"] = 0.0
	var bajo_cerca := _medir(local, 10.0, 20.0)
	var bajo_lejos := _medir(local, 28.0, 20.0)
	var alto_cerca := _medir(local, 10.0, 90.0)
	var alto_lejos := _medir(local, 28.0, 90.0)
	resolucion["presion_referencia"] = referencia
	print("PUNTERIA local=%s bajo=%s/%s alto=%s/%s (cerca/lejos)" % [
		local, bajo_cerca, bajo_lejos, alto_cerca, alto_lejos])
	_comprobar(bajo_lejos["puerta"] < bajo_cerca["puerta"] and alto_lejos["puerta"] < alto_cerca["puerta"],
		"alejarse reduce precisión con ambos niveles de tiro")
	_comprobar(alto_lejos["puerta"] < alto_cerca["puerta"] * 0.8
		and bajo_lejos["puerta"] < bajo_cerca["puerta"] * 0.65,
		"la distancia tiene un coste material incluso para el buen rematador")
	_comprobar(bajo_cerca["puerta"] - bajo_lejos["puerta"] > alto_cerca["puerta"] - alto_lejos["puerta"],
		"poco tiro pierde más precisión con los metros")
	_comprobar(alto_lejos["puerta"] > bajo_lejos["puerta"] + 0.15,
		"la técnica distingue la precisión desde lejos en mil semillas")
	_comprobar(alto_lejos["goles"] > bajo_lejos["goles"] and alto_lejos["goles"] < alto_cerca["goles"],
		"el buen rematador conserva goles lejanos, con menor conversión que cerca")


func _partido(fotogramas: bool, diagnostico: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	rng.seed = SEED
	var resultado := MotorEspacial.simular(casa, visita, rng, fotogramas, false, diagnostico)
	resultado["azar_final"] = rng.state
	return resultado


func _test_observabilidad() -> void:
	var normal := _partido(false, false)
	var diagnostico := _partido(false, true)
	var visual := _partido(true, true)
	var registro: Array = diagnostico["stats"]["registro_remates"]
	var tiros := 0
	var goles := 0
	for evento in diagnostico["eventos"]:
		if evento["tipo"] in ["tiro", "tiro_puerta"]:
			tiros += 1
			if evento.get("resultado", "") == "gol": goles += 1
	var goles_registrados := 0
	for remate in registro:
		if remate["resultado"] == "gol": goles_registrados += 1
	_comprobar(registro.size() > 0 and registro.size() == diagnostico["stats"]["dist_tiros"].size()
		and registro.size() == tiros and goles_registrados == goles,
		"cada intento y gol no penal tiene una sola fila de diagnóstico")
	for resultado in [normal, diagnostico, visual]:
		resultado.erase("fotogramas")
		resultado["stats"].erase("registro_remates")
	_comprobar(normal == diagnostico and normal == visual,
		"diagnóstico y fotogramas conservan eventos, estadísticas, XP y RNG")
