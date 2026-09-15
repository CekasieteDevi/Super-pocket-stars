extends SceneTree

## §4.2: con un rival metido en su propio tercio, el arquero la manda
## lejos en vez de repartirla corto. Es una regla, no un peso.
##
## Viene de verlo jugando: el arquero atajaba, se la daba a un central con
## delanteros encima, se la sacaban en la puerta del area y le pegaban al
## arco, una y otra vez.

const SEED := 8800

var fallos := 0


func _init() -> void:
	_test_el_arquero_lucido_la_revienta()
	_test_sin_rivales_cerca_reparte_tranquilo()
	_test_el_estilo_decide_como_sale()
	for arquero_local in [true, false]:
		_test_sale_a_una_pelota_favorable(arquero_local)
		_test_no_sale_si_el_atacante_llega_antes(arquero_local)
		_test_la_salida_fallida_deja_el_arco_expuesto(arquero_local)
		_test_vuelve_de_a_poco(arquero_local)
	_test_decidir_no_consume_azar()
	print("\nFALLOS=%d" % fallos)
	quit()


## Arma la escena: arquero con la pelota, `invasores` rivales metidos en
## su tercio, y sus companeros a distancia de pase.
func _escena(inteligencia: int, invasores: int, semilla: int, estilo := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	if estilo != "":
		casa.estilo = estilo
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
		# El arquero rival no cuenta como invasor: no va a cortar ningun pase.
		if metidos < invasores and str(e["rol"]) != "ARQ":
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
func _brecha(inteligencia: int, invasores: int, semilla: int, estilo := "") -> float:
	var d := _escena(inteligencia, invasores, semilla, estilo)
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


## Los tipos de opcion que le quedan al arquero en la escena.
func _tipos(inteligencia: int, invasores: int, semilla: int) -> Dictionary:
	var d := _escena(inteligencia, invasores, semilla)
	var jug := MotorEspacial._dict_jugador(
		d["estado"], d["casa"], int(d["arquero"]["jugador_id"]))
	var tipos := {}
	for o in MotorEspacial.evaluar_opciones(d["estado"], d["arquero"], jug):
		tipos[str(o["tipo"])] = true
	return tipos


## Con un solo rival en su tercio la revienta, sea lucido o limitado. Antes
## lo decidia la inteligencia, y el limitado regalaba la pelota en la
## puerta del area (tests/_diag_arquero_regala.gd).
func _test_el_arquero_lucido_la_revienta() -> void:
	print("=== Con un rival en su tercio, ningun arquero sale jugando corto ===")
	for inteligencia in [10, 95]:
		for i in range(20):
			var tipos := _tipos(inteligencia, 1, SEED + i)
			if tipos.has("pase") or tipos.has("pase_hueco"):
				fallos += 1
				print("FALLA: inteligencia %d, semilla %d: todavia puede darla corto %s." % [
					inteligencia, SEED + i, tipos.keys()])
				return
			if not tipos.has("despeje"):
				fallos += 1
				print("FALLA: inteligencia %d, semilla %d: no tiene el despeje %s." % [
					inteligencia, SEED + i, tipos.keys()])
				return
	print("OK: con un rival encima, lucido y limitado solo pueden despejar o tirar el pelotazo.")


func _test_sin_rivales_cerca_reparte_tranquilo() -> void:
	print("\n=== Sin nadie cerca, puede salir jugando corto ===")
	for i in range(20):
		var tipos := _tipos(60, 0, SEED + i)
		if not tipos.has("pase"):
			fallos += 1
			print("FALLA: semilla %d: sin rivales cerca no tiene el pase corto %s." % [
				SEED + i, tipos.keys()])
			return
	print("OK: sin rivales en su tercio le queda el pase corto.")


## Etapa 6, punto 6: la salida la decide el sistema de pases de siempre, con
## el estilo encima. Un equipo de Juego directo la saca larga con mas ganas
## que uno de Tiki taka, sin nadie apretando.
func _test_el_estilo_decide_como_sale() -> void:
	print("\n=== El estilo del equipo decide como sale el arquero ===")
	var suma_directo := 0.0
	var suma_tiki := 0.0
	for i in range(40):
		suma_directo += _brecha(60, 0, SEED + 300 + i, "Juego directo")
		suma_tiki += _brecha(60, 0, SEED + 300 + i, "Tiki taka")
	var directo := suma_directo / 40.0
	var tiki := suma_tiki / 40.0
	if directo <= tiki:
		fallos += 1
		print("FALLA: Juego directo %.2f, Tiki taka %.2f; el directo tendria que preferir mas el pelotazo." % [directo, tiki])
		return
	print("OK: sin presion, sacarla larga le rinde %.2f a Juego directo y %.2f a Tiki taka." % [directo, tiki])


# ---------------------------------------------------------------------------
# Etapa 6: salidas del arquero
# ---------------------------------------------------------------------------

## Punto a `metros` de la linea del arco que defiende el arquero, hacia el
## campo. Asi la misma escena se arma para los dos lados de la cancha.
func _punto(arquero_local: bool, metros: float, y: float) -> Vector2:
	var arco := MotorEspacial.arco_propio(arquero_local)
	return Vector2(arco.x - signf(arco.x) * metros, y)


## Juego abierto sin nadie cerca del area: el arquero en su lugar, sus
## companeros lejos arriba y los rivales a 45 m. Cada caso mueve a quien
## necesita.
func _escena_abierta(arquero_local: bool, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	for equipo in [casa, visita]:
		equipo.reset_partido()
		equipo.clima_partido = "despejado"
	casa.local = true
	visita.local = false
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	estado["detenido"] = 0
	estado["quietos"] = 0
	estado["balon_parado"] = {}
	var arquero := -1
	var atacantes := []
	var companeros := 0
	var claves: Array = estado["jugadores"].keys()
	claves.sort()
	for id in claves:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) == arquero_local:
			if str(e["rol"]) == "ARQ":
				arquero = id
				e["pos"] = _punto(arquero_local, 2.8, 0.0)
				# El mismo arquero de los dos lados: los planteles se sortean
				# distinto y la escena espejada no tiene que comparar atributos.
				e["vel_max"] = 7.0
				e["aceleracion"] = 4.0
			else:
				e["pos"] = _punto(arquero_local, 60.0, -25.0 + companeros * 5.0)
				companeros += 1
		else:
			e["pos"] = _punto(arquero_local, 45.0, -25.0 + atacantes.size() * 5.0)
			if str(e["rol"]) != "ARQ":
				atacantes.append(id)
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
	return {"estado": estado, "arquero": arquero, "atacantes": atacantes}


## Un pase rival en viaje de `desde` a `hasta`, dirigido a `receptor`.
func _lanzar_pase_rival(d: Dictionary, arquero_local: bool, desde: Vector2, hasta: Vector2, receptor: int) -> void:
	var estado: Dictionary = d["estado"]
	var p: Dictionary = estado["pelota"]
	p["poseedor_id"] = -1
	p["en_vuelo"] = true
	p["pos"] = desde
	p["origen_pos"] = desde
	p["destino_pos"] = hasta
	p["vel"] = (hasta - desde).normalized() * 18.0
	p["destino_id"] = receptor
	p["es_pase"] = true
	p["es_centro"] = false
	p["es_remate"] = false
	p["altura_max"] = 0.0
	p["pasador_local"] = not arquero_local
	p["pasador_id"] = int(estado["jugadores"][d["atacantes"][1]]["jugador_id"])
	p["attr_pasador"] = "pases"
	p["pases_pasador"] = 50.0


## Corre la escena y devuelve que intencion tuvo el arquero en el primer
## tick, si termino con la pelota y el paso mas largo que dio.
func _jugar(d: Dictionary, ticks: int) -> Dictionary:
	var estado: Dictionary = d["estado"]
	var clave: int = d["arquero"]
	var e: Dictionary = estado["jugadores"][clave]
	var primera := ""
	var tipos := []
	var paso_max := 0.0
	var sale := false
	for t in range(ticks):
		var antes: Vector2 = e["pos"]
		MotorEspacial._tick(estado, false)
		paso_max = maxf(paso_max, antes.distance_to(e["pos"]))
		# El reloj ya avanzo al cerrar el tick: la intencion se lee del plan
		# guardado y no de intencion_arquero, que pide la del tick en curso.
		var plan: Dictionary = estado.get("arqueros", {}).get(clave, {})
		tipos.append(str(plan.get("tipo", "")))
		if t == 0:
			primera = str(plan.get("tipo", ""))
		if int(estado["pelota"]["poseedor_id"]) == clave:
			sale = true
			break
		if int(estado["pelota"]["poseedor_id"]) != -1:
			break
	return {"primera": primera, "tipos": tipos, "la_tiene": sale, "paso_max": paso_max,
		"poseedor": int(estado["pelota"]["poseedor_id"])}


func _test_sale_a_una_pelota_favorable(arquero_local: bool) -> void:
	print("\n=== Sale a cortar el pase al hueco que le queda a el (arquero local=%s) ===" % arquero_local)
	var d := _escena_abierta(arquero_local, SEED + 500)
	var receptor: int = d["atacantes"][0]
	d["estado"]["jugadores"][receptor]["pos"] = _punto(arquero_local, 33.0, 8.0)
	_lanzar_pase_rival(d, arquero_local, _punto(arquero_local, 33.0, 0.0), _punto(arquero_local, 9.0, 2.0), receptor)
	var e: Dictionary = d["estado"]["jugadores"][d["arquero"]]
	var tope: float = float(e["vel_max"]) * MotorEspacial.TICK_SEG + 0.01
	var r := _jugar(d, 20)
	if r["primera"] != "interceptar":
		fallos += 1
		print("FALLA: con el atacante a 24 m de la pelota, la primera intencion fue '%s'." % r["primera"])
		return
	if not bool(r["la_tiene"]):
		fallos += 1
		print("FALLA: salio a cortarla y no se quedo con la pelota (poseedor %d)." % r["poseedor"])
		return
	if float(r["paso_max"]) > tope:
		fallos += 1
		print("FALLA: dio un paso de %.2f m en un tick; su tope es %.2f." % [r["paso_max"], tope])
		return
	print("OK: sale a interceptar, llega corriendo (paso maximo %.2f m) y se queda con la pelota." % r["paso_max"])


func _test_no_sale_si_el_atacante_llega_antes(arquero_local: bool) -> void:
	print("\n=== No sale si el atacante llega antes (arquero local=%s) ===" % arquero_local)
	var d := _escena_abierta(arquero_local, SEED + 500)
	var receptor: int = d["atacantes"][0]
	d["estado"]["jugadores"][receptor]["pos"] = _punto(arquero_local, 12.0, 3.0)
	_lanzar_pase_rival(d, arquero_local, _punto(arquero_local, 33.0, 0.0), _punto(arquero_local, 9.0, 2.0), receptor)
	var r := _jugar(d, 20)
	if (r["tipos"] as Array).has("interceptar"):
		fallos += 1
		print("FALLA: salio a cortar un pase que el atacante tenia a 3 m (%s)." % [r["tipos"]])
		return
	if bool(r["la_tiene"]):
		fallos += 1
		print("FALLA: se quedo con una pelota a la que no salio.")
		return
	print("OK: con el atacante a 3 m de la pelota no sale; intenciones %s." % [r["tipos"]])


## El remate de un atacante contra el arquero en su lugar y contra el
## arquero que salio a cortar al otro lado y no llego.
func _goles_contra(arquero_local: bool, pos_arquero: Vector2) -> Dictionary:
	var goles := 0
	var cobertura := 0.0
	for i in range(200):
		var d := _escena_abierta(arquero_local, SEED + 700)
		var estado: Dictionary = d["estado"]
		var clave: int = d["atacantes"][0]
		var tirador: Dictionary = estado["jugadores"][clave]
		tirador["pos"] = _punto(arquero_local, 14.0, -6.0)
		estado["jugadores"][d["arquero"]]["pos"] = pos_arquero
		estado["pelota"]["en_vuelo"] = false
		estado["pelota"]["poseedor_id"] = clave
		estado["pelota"]["pos"] = tirador["pos"]
		estado["registro_remates"] = []
		estado["rng"].seed = SEED + 7000 + i
		var equipo: Team = estado["home"] if not arquero_local else estado["away"]
		var jugador := MotorEspacial._dict_jugador(estado, equipo, int(tirador["jugador_id"]))
		# Mismo tirador y mismo arquero de los dos lados: sin esto la escena
		# espejada enfrenta a jugadores distintos y compara atributos.
		jugador["atributos"]["tiro"] = 60
		var arq: Dictionary = (estado["away"] if not arquero_local else estado["home"]).arquero()
		for atributo in ["reflejos", "estirada", "agarre"]:
			arq["atributos"][atributo] = 60
		cobertura = MotorEspacial.cobertura_arquero(estado, tirador["pos"], not arquero_local)
		MotorEspacial._resolver_tiro(estado, tirador, jugador)
		if str(estado["registro_remates"][0]["resultado"]) == "gol":
			goles += 1
	return {"goles": goles, "cobertura": cobertura}


func _test_la_salida_fallida_deja_el_arco_expuesto(arquero_local: bool) -> void:
	print("\n=== La salida fallida deja el arco expuesto (arquero local=%s) ===" % arquero_local)
	var en_su_lugar := _goles_contra(arquero_local, _punto(arquero_local, 2.8, -1.0))
	var afuera := _goles_contra(arquero_local, _punto(arquero_local, 9.0, 8.0))
	if float(afuera["cobertura"]) >= float(en_su_lugar["cobertura"]):
		fallos += 1
		print("FALLA: salido tapa %.2f del arco y en su lugar %.2f." % [afuera["cobertura"], en_su_lugar["cobertura"]])
		return
	if int(afuera["goles"]) <= int(en_su_lugar["goles"]):
		fallos += 1
		print("FALLA: 200 remates dan %d goles con el arquero salido y %d en su lugar." % [
			afuera["goles"], en_su_lugar["goles"]])
		return
	print("OK: 200 remates desde 14 m: %d goles con el arquero en su lugar (tapa %.2f), %d con el arquero salido (tapa %.2f)." % [
		en_su_lugar["goles"], en_su_lugar["cobertura"], afuera["goles"], afuera["cobertura"]])


func _test_vuelve_de_a_poco(arquero_local: bool) -> void:
	print("\n=== Despues de salir vuelve corriendo, sin saltos (arquero local=%s) ===" % arquero_local)
	var d := _escena_abierta(arquero_local, SEED + 900)
	var estado: Dictionary = d["estado"]
	var clave: int = d["arquero"]
	var e: Dictionary = estado["jugadores"][clave]
	e["pos"] = _punto(arquero_local, 14.0, 7.0)
	# Viene de una salida: la pelota ya la tiene un rival lejos.
	estado["arqueros"] = {clave: {"tipo": "interceptar", "destino": e["pos"], "tick": -1,
		"origen": Vector2.ZERO, "fin": Vector2.ZERO}}
	var rival: int = d["atacantes"][0]
	estado["jugadores"][rival]["pos"] = _punto(arquero_local, 70.0, 0.0)
	estado["pelota"]["en_vuelo"] = false
	estado["pelota"]["poseedor_id"] = rival
	estado["pelota"]["pos"] = estado["jugadores"][rival]["pos"]
	estado["pelota"]["ticks_con_pelota"] = 1
	var tope: float = float(e["vel_max"]) * MotorEspacial.TICK_SEG + 0.01
	var inicio: float = (e["pos"] as Vector2).distance_to(_punto(arquero_local, 2.8, 0.0))
	var tipos := []
	var paso_max := 0.0
	for t in range(24):
		var antes: Vector2 = e["pos"]
		MotorEspacial._tick(estado, false)
		paso_max = maxf(paso_max, antes.distance_to(e["pos"]))
		tipos.append(str(estado["arqueros"][clave]["tipo"]))
	var fin: float = (e["pos"] as Vector2).distance_to(_punto(arquero_local, 2.8, 0.0))
	if tipos[0] != "volver" or tipos[-1] != "sostener":
		fallos += 1
		print("FALLA: la vuelta se etiqueto %s." % [tipos])
		return
	if paso_max > tope:
		fallos += 1
		print("FALLA: dio un paso de %.2f m en un tick; su tope es %.2f." % [paso_max, tope])
		return
	if fin >= inicio - 8.0:
		fallos += 1
		print("FALLA: en 6 s paso de %.1f a %.1f m de su arco." % [inicio, fin])
		return
	print("OK: vuelve de %.1f a %.1f m de su lugar con pasos de hasta %.2f m; 'volver' %d ticks y despues 'sostener'." % [
		inicio, fin, paso_max, tipos.count("volver")])


func _test_decidir_no_consume_azar() -> void:
	print("\n=== Decidir la salida no consume azar ===")
	var d := _escena_abierta(true, SEED + 500)
	var receptor: int = d["atacantes"][0]
	d["estado"]["jugadores"][receptor]["pos"] = _punto(true, 33.0, 8.0)
	_lanzar_pase_rival(d, true, _punto(true, 33.0, 0.0), _punto(true, 9.0, 2.0), receptor)
	var rng: RandomNumberGenerator = d["estado"]["rng"]
	var antes := rng.state
	MotorEspacial._planificar_arqueros(d["estado"], false)
	var plan: Dictionary = d["estado"]["arqueros"][d["arquero"]]
	MotorEspacial._planificar_arqueros(d["estado"], false)
	var otra: Dictionary = d["estado"]["arqueros"][d["arquero"]]
	if rng.state != antes:
		fallos += 1
		print("FALLA: planificar a los arqueros movio el RNG.")
		return
	if str(plan["tipo"]) != str(otra["tipo"]) or plan["destino"] != otra["destino"]:
		fallos += 1
		print("FALLA: dos planificaciones de la misma foto dieron %s y %s." % [plan, otra])
		return
	print("OK: la misma foto da la misma intencion (%s) y el RNG queda igual." % plan["tipo"])
