extends SceneTree

## Etapa 4 del plan de realismo: el ritmo es del EQUIPO. Con el rival
## cerrado se circula, con un carril liberado se acelera, y la misma
## pareja de pases no puede devolversela para siempre sin avanzar.

const SEED := 4410

var fallos := 0


func _armar_estado(rng: RandomNumberGenerator) -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 0)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	return MotorEspacial.crear_estado(casa, visita, rng)


## Una escena de ataque con la pelota en los pies de un MC.
func _escena(semilla: int, ataca_local: bool, pelota: Vector2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var estado := _armar_estado(rng)
	var portador := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == ataca_local and str(e["rol"]) == "MC":
			portador = int(id)
			break
	estado["jugadores"][portador]["pos"] = pelota
	estado["pelota"]["pos"] = pelota
	estado["pelota"]["poseedor_id"] = portador
	estado["pelota"]["ticks_con_pelota"] = 8
	estado["ultimo_equipo_con_pelota"] = ataca_local
	MotorEspacial._calcular_linea_offside(estado)
	return estado


## Tapa al poseedor: mete a los diez rivales de campo delante de el, en
## abanico, y despeja a los companeros lejos. Es "el rival cerrado".
func _cerrar_el_frente(estado: Dictionary, ataca_local: bool, pelota: Vector2) -> void:
	var signo := 1.0 if ataca_local else -1.0
	var i := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) == ataca_local:
			continue
		if str(e["rol"]) == "ARQ":
			continue
		e["pos"] = Vector2(pelota.x + signo * (5.0 + float(i % 3) * 3.0),
				pelota.y + float(i - 5) * 2.2)
		i += 1
	# Los companeros, todos lejos y detras: ningun apoyo libre adelantado.
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) != ataca_local or int(id) == int(estado["pelota"]["poseedor_id"]):
			continue
		if str(e["rol"]) == "ARQ":
			continue
		e["pos"] = Vector2(pelota.x - signo * 14.0, e["pos"].y)


## Deja el frente libre: los rivales de campo, al fondo.
func _abrir_el_frente(estado: Dictionary, ataca_local: bool) -> void:
	var signo := 1.0 if ataca_local else -1.0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) == ataca_local or str(e["rol"]) == "ARQ":
			continue
		e["pos"] = Vector2(MotorEspacial.MEDIO_LARGO * signo - signo * 6.0, e["pos"].y)


func _init() -> void:
	_test_rival_cerrado_produce_circulacion()
	_test_carril_liberado_produce_aceleracion()
	_test_la_fase_no_oscila()
	_test_la_transicion_gana_sobre_el_plazo()
	_test_la_perdida_reinicia_el_ritmo()
	_test_circulacion_premia_el_apoyo_seguro()
	_test_aceleracion_premia_el_pase_progresivo()
	_test_el_ajuste_esta_acotado()
	_test_la_devolucion_repetida_pierde_utilidad()
	_test_la_devolucion_bajo_presion_no_se_castiga()
	_test_el_avance_borra_el_conteo_de_la_pareja()
	_test_circulacion_conduce_mas_despacio()
	_test_el_ritmo_es_estable()
	_test_no_hay_bucles_eternos_en_partidos()
	print("\nFALLOS=%d" % fallos)
	quit()


func _falla(texto: String) -> void:
	fallos += 1
	print("FALLA: " + texto)


func _test_rival_cerrado_produce_circulacion() -> void:
	print("=== Rival cerrado: circulacion, para los dos lados ===")
	for lado in [true, false]:
		var signo := 1.0 if lado else -1.0
		var pelota := Vector2(6.0 * signo, 3.0)
		var estado := _escena(SEED, lado, pelota)
		_cerrar_el_frente(estado, lado, pelota)
		MotorEspacial._planificar_ritmo(estado)
		var fase := MotorEspacial.fase_de_ritmo(estado, lado)
		if fase != MotorEspacial.FASE_CIRCULACION:
			_falla("atacando %s con el frente tapado la fase fue '%s'." % [
					"el local" if lado else "la visita", fase])
		else:
			print("OK: atacando %s el frente tapado da circulacion (espacio %.2f, apoyos %d)." % [
					"el local" if lado else "la visita",
					float(estado["ritmo"]["espacio"]), int(estado["ritmo"]["apoyos"])])


func _test_carril_liberado_produce_aceleracion() -> void:
	print("=== Carril liberado: aceleracion ===")
	for lado in [true, false]:
		var signo := 1.0 if lado else -1.0
		var pelota := Vector2(6.0 * signo, 3.0)
		var estado := _escena(SEED, lado, pelota)
		_abrir_el_frente(estado, lado)
		MotorEspacial._planificar_ritmo(estado)
		var fase := MotorEspacial.fase_de_ritmo(estado, lado)
		if fase != MotorEspacial.FASE_ACELERACION:
			_falla("atacando %s con el carril libre la fase fue '%s'." % [
					"el local" if lado else "la visita", fase])
		else:
			print("OK: atacando %s el carril libre da aceleracion (espacio %.2f)." % [
					"el local" if lado else "la visita", float(estado["ritmo"]["espacio"])])


func _test_la_fase_no_oscila() -> void:
	print("=== La fase se sostiene el plazo entero ===")
	var pelota := Vector2(6.0, 3.0)
	var estado := _escena(SEED, true, pelota)
	_cerrar_el_frente(estado, true, pelota)
	MotorEspacial._planificar_ritmo(estado)
	var inicial := MotorEspacial.fase_de_ritmo(estado, true)
	# Se abre el frente de golpe: la fase no puede cambiar hasta que venza.
	_abrir_el_frente(estado, true)
	var cambios := 0
	for i in range(MotorEspacial.TICKS_RITMO - 1):
		estado["tick"] = int(estado["tick"]) + 1
		MotorEspacial._planificar_ritmo(estado)
		if MotorEspacial.fase_de_ritmo(estado, true) != inicial:
			cambios += 1
	if cambios != 0:
		_falla("la fase cambio %d veces dentro del plazo de %d ticks." % [
				cambios, MotorEspacial.TICKS_RITMO])
	else:
		estado["tick"] = int(estado["tick"]) + 1
		MotorEspacial._planificar_ritmo(estado)
		var despues := MotorEspacial.fase_de_ritmo(estado, true)
		if despues == inicial:
			_falla("vencido el plazo la fase siguio en '%s' con el frente ya libre." % despues)
		else:
			print("OK: '%s' se sostuvo %d ticks y al vencer paso a '%s'." % [
					inicial, MotorEspacial.TICKS_RITMO, despues])


func _test_la_transicion_gana_sobre_el_plazo() -> void:
	print("=== La transicion interrumpe el plazo ===")
	var pelota := Vector2(6.0, 3.0)
	var estado := _escena(SEED, true, pelota)
	_cerrar_el_frente(estado, true, pelota)
	MotorEspacial._planificar_ritmo(estado)
	if MotorEspacial.fase_de_ritmo(estado, true) != MotorEspacial.FASE_CIRCULACION:
		_falla("la escena de partida no era circulacion.")
		return
	# Recuperacion: el equipo local acaba de robarla.
	estado["transicion_local"] = true
	estado["transicion_hasta"] = int(estado["tick"]) + int(
			MotorEspacial.SEGUNDOS_TRANSICION / MotorEspacial.TICK_SEG)
	estado["tick"] = int(estado["tick"]) + 1
	MotorEspacial._planificar_ritmo(estado)
	if MotorEspacial.fase_de_ritmo(estado, true) != MotorEspacial.FASE_TRANSICION:
		_falla("con la ventana de transicion abierta la fase fue '%s'." %
				MotorEspacial.fase_de_ritmo(estado, true))
	else:
		print("OK: la transicion corta el plazo de la fase anterior.")


func _test_la_perdida_reinicia_el_ritmo() -> void:
	print("=== La perdida reinicia progreso y parejas ===")
	var pelota := Vector2(6.0, 3.0)
	var estado := _escena(SEED, true, pelota)
	MotorEspacial._planificar_ritmo(estado)
	MotorEspacial._anotar_pase_de_ritmo(estado, 1, 2)
	if MotorEspacial._veces_de_la_pareja(estado, 1, 2) != 1.0:
		_falla("la pareja no se anoto.")
		return
	# Se la queda un rival.
	var rival := -1
	for id in estado["jugadores"]:
		if not bool(estado["jugadores"][id]["equipo_local"]):
			rival = int(id)
			break
	estado["pelota"]["poseedor_id"] = rival
	estado["pelota"]["pos"] = estado["jugadores"][rival]["pos"]
	estado["tick"] = int(estado["tick"]) + 1
	MotorEspacial._planificar_ritmo(estado)
	if MotorEspacial.fase_de_ritmo(estado, true) != "":
		_falla("despues de la perdida el local seguia teniendo fase.")
	elif MotorEspacial._veces_de_la_pareja(estado, 1, 2) != 0.0:
		_falla("la pareja sobrevivio al cambio de manos.")
	else:
		print("OK: el cambio de manos borra fase, progreso y parejas.")


func _test_circulacion_premia_el_apoyo_seguro() -> void:
	print("=== Circulacion: apoyo corto y libre, con el camino cerrado ===")
	var cerrado := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_CIRCULACION, "pase", 0.0, 12.0, 0.9, false, 0.1)
	var abierto := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_CIRCULACION, "pase", 0.0, 12.0, 0.9, false, 0.95)
	var lejano := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_CIRCULACION, "pase", 0.0, 40.0, 0.9, false, 0.1)
	if cerrado <= 0.0:
		_falla("con el camino cerrado el apoyo seguro no gano nada (%.3f)." % cerrado)
	elif abierto >= cerrado:
		_falla("con el camino abierto el premio no se apago (%.3f contra %.3f)." % [abierto, cerrado])
	elif lejano >= cerrado:
		_falla("un pase de 40 m cobro el premio de apoyo corto (%.3f)." % lejano)
	else:
		print("OK: apoyo corto y libre +%.3f con el camino cerrado, +%.3f con el abierto." % [
				cerrado, abierto])
	var cambio := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_CIRCULACION, "pase_largo", 0.0, 45.0, 0.8, true, 0.1)
	if cambio <= 0.0:
		_falla("el cambio de frente no gano nada en circulacion (%.3f)." % cambio)
	else:
		print("OK: el cambio de frente suma +%.3f en circulacion." % cambio)


func _test_aceleracion_premia_el_pase_progresivo() -> void:
	print("=== Aceleracion: conduccion, hueco y pase que gana metros ===")
	var hueco := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_ACELERACION, "pase_hueco", 15.0, 20.0, 0.8, false, 0.5)
	var atras := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_ACELERACION, "pase", -10.0, 12.0, 0.9, false, 0.5)
	var adelante := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_ACELERACION, "pase", 15.0, 12.0, 0.9, false, 0.5)
	var conduce := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_ACELERACION, "conducir", 0.0, 0.0, 0.0, false, 0.9)
	if hueco <= 0.0 or adelante <= 0.0 or conduce <= 0.0:
		_falla("aceleracion no premio hueco (%.3f), pase adelante (%.3f) o conduccion (%.3f)." % [
				hueco, adelante, conduce])
	elif atras > 0.0:
		_falla("aceleracion premio un pase hacia atras (%.3f)." % atras)
	else:
		print("OK: hueco +%.3f, pase adelante +%.3f, conduccion +%.3f, pase atras %.3f." % [
				hueco, adelante, conduce, atras])
	# La transicion no suma nada: ya la cobra el termino `transicion`.
	var en_transicion := MotorEspacial._ajuste_de_ritmo(
			MotorEspacial.FASE_TRANSICION, "pase_hueco", 15.0, 20.0, 0.8, false, 0.9)
	if en_transicion != 0.0:
		_falla("la transicion cobro ajuste de ritmo (%.3f): se estaria pagando dos veces." % en_transicion)
	else:
		print("OK: en transicion el ajuste de ritmo es cero.")


func _test_el_ajuste_esta_acotado() -> void:
	print("=== El ajuste nunca pasa el tope ===")
	var tope: float = float(MotorEspacial.pesos_ritmo()["tope"])
	var peor := 0.0
	for fase in [MotorEspacial.FASE_CIRCULACION, MotorEspacial.FASE_ACELERACION]:
		for tipo in ["pase", "pase_largo", "pase_hueco", "conducir"]:
			for adelante in [-30.0, 0.0, 60.0]:
				for dist in [1.0, 12.0, 60.0]:
					for libertad in [0.0, 0.5, 1.0]:
						for cambio in [true, false]:
							for camino in [0.0, 0.5, 1.0]:
								var a: float = MotorEspacial._ajuste_de_ritmo(
										fase, tipo, adelante, dist, libertad, cambio, camino)
								peor = maxf(peor, absf(a))
	if peor > tope + 0.0001:
		_falla("un ajuste llego a %.3f, por encima del tope %.3f." % [peor, tope])
	else:
		print("OK: el peor ajuste de 1296 combinaciones es %.3f, con tope %.3f." % [peor, tope])


func _test_la_devolucion_repetida_pierde_utilidad() -> void:
	print("=== La devolucion repetida sin avanzar pierde utilidad ===")
	var pelota := Vector2(6.0, 3.0)
	var estado := _escena(SEED, true, pelota)
	_cerrar_el_frente(estado, true, pelota)
	MotorEspacial._planificar_ritmo(estado)
	var poseedor: Dictionary = estado["jugadores"][int(estado["pelota"]["poseedor_id"])]
	var companero := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) and str(e["rol"]) != "ARQ" and int(id) != int(poseedor["clave"]):
			companero = int(id)
			break
	# Doce ticks sin avanzar un metro: la posesion esta trabada.
	estado["tick"] = int(estado["tick"]) + int(MotorEspacial.pesos_ritmo()["estancada_ticks"])
	if not MotorEspacial._posesion_estancada(estado, 0.1):
		_falla("doce ticks sin avanzar y sin presion no dieron posesion estancada.")
		return
	if MotorEspacial._posesion_estancada(estado, 0.9):
		_falla("con presion 0.9 la posesion igual dio estancada.")
		return
	estado["ultimo_pase"] = {
		"de": int(estado["jugadores"][companero]["jugador_id"]), "a": int(poseedor["clave"]),
		"local": true,
	}
	var castigo: float = float(MotorEspacial.pesos_ritmo()["devolucion_castigo"])
	var antes = _utilidad_del_pase_a(estado, poseedor, companero)
	for i in range(3):
		MotorEspacial._anotar_pase_de_ritmo(estado, companero, int(poseedor["clave"]))
	var despues = _utilidad_del_pase_a(estado, poseedor, companero)
	if antes == null or despues == null:
		_falla("no se pudo evaluar el pase al companero.")
	elif float(despues) >= float(antes) - castigo:
		_falla("tres devoluciones no bajaron la utilidad (%.3f contra %.3f)." % [despues, antes])
	else:
		print("OK: tres devoluciones bajan la utilidad de %.3f a %.3f." % [antes, despues])


func _test_la_devolucion_bajo_presion_no_se_castiga() -> void:
	print("=== Con presion encima, devolverla sigue valiendo ===")
	var estado := _escena(SEED, true, Vector2(6.0, 3.0))
	MotorEspacial._planificar_ritmo(estado)
	estado["tick"] = int(estado["tick"]) + 40
	var w := MotorEspacial.pesos_ritmo()
	if MotorEspacial._posesion_estancada(estado, float(w["estancada_presion"]) + 0.1):
		_falla("por encima del umbral de presion la posesion dio estancada.")
	else:
		print("OK: por encima de presion %.2f no se castiga ninguna devolucion." % float(w["estancada_presion"]))


func _test_el_avance_borra_el_conteo_de_la_pareja() -> void:
	print("=== Avanzar borra el conteo de la pareja ===")
	var estado := _escena(SEED, true, Vector2(0.0, 0.0))
	MotorEspacial._planificar_ritmo(estado)
	MotorEspacial._anotar_pase_de_ritmo(estado, 1, 2)
	MotorEspacial._anotar_pase_de_ritmo(estado, 1, 2)
	if MotorEspacial._veces_de_la_pareja(estado, 1, 2) != 2.0:
		_falla("no se anotaron las dos devoluciones.")
		return
	# La jugada gana metros hacia el arco rival.
	var avance: float = float(MotorEspacial.pesos_ritmo()["estancada_avance"]) + 2.0
	estado["pelota"]["pos"] = Vector2(avance, 0.0)
	estado["tick"] = int(estado["tick"]) + 1
	MotorEspacial._planificar_ritmo(estado)
	if MotorEspacial._veces_de_la_pareja(estado, 1, 2) != 0.0:
		_falla("avanzar %.1f m no borro el conteo." % avance)
	else:
		print("OK: avanzar %.1f m borra el conteo de la pareja." % avance)


func _test_circulacion_conduce_mas_despacio() -> void:
	print("=== Pausar es conducir despacio, no congelarse ===")
	var pelota := Vector2(6.0, 3.0)
	var recorridos := {}
	for fase in [MotorEspacial.FASE_CIRCULACION, MotorEspacial.FASE_ACELERACION]:
		var estado := _escena(SEED, true, pelota)
		_cerrar_el_frente(estado, true, pelota)
		MotorEspacial._planificar_ritmo(estado)
		estado["ritmo"]["fase"] = fase
		estado["ritmo"]["hasta"] = 99999
		var poseedor: Dictionary = estado["jugadores"][int(estado["pelota"]["poseedor_id"])]
		var desde: Vector2 = poseedor["pos"]
		for i in range(8):
			MotorEspacial._conducir(estado, poseedor)
		recorridos[fase] = desde.distance_to(poseedor["pos"])
	var lento: float = float(recorridos[MotorEspacial.FASE_CIRCULACION])
	var rapido: float = float(recorridos[MotorEspacial.FASE_ACELERACION])
	if lento <= 0.0:
		_falla("en circulacion el poseedor no se movio nada: eso es congelar el partido.")
	elif lento >= rapido:
		_falla("circulacion no condujo mas despacio (%.2f m contra %.2f m)." % [lento, rapido])
	else:
		print("OK: ocho ticks conduciendo, %.2f m en circulacion contra %.2f m fuera de ella." % [
				lento, rapido])


func _test_el_ritmo_es_estable() -> void:
	print("=== La misma escena da la misma fase ===")
	var distintas := 0
	for semilla in [SEED, SEED + 7, SEED + 13, SEED + 29]:
		var pelota := Vector2(6.0, 3.0)
		var a := _escena(semilla, true, pelota)
		var b := _escena(semilla, true, pelota)
		MotorEspacial._planificar_ritmo(a)
		MotorEspacial._planificar_ritmo(b)
		if MotorEspacial.fase_de_ritmo(a, true) != MotorEspacial.fase_de_ritmo(b, true):
			distintas += 1
	if distintas > 0:
		_falla("%d de 4 escenas dieron fases distintas al repetirlas." % distintas)
	else:
		print("OK: 4 escenas repetidas dos veces dan la misma fase.")


func _test_no_hay_bucles_eternos_en_partidos() -> void:
	print("=== Partidos completos: las tres fases aparecen y no hay bucle ===")
	var totales := {}
	var partidos := 8
	for i in range(partidos):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i * 31
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 3)
		var res := MotorEspacial.simular(casa, visita, rng, false)
		var s: Dictionary = res.get("stats", {}).get("ritmo", {})
		for k in s:
			totales[k] = int(totales.get(k, 0)) + int(s[k])
	var circ: int = int(totales.get(MotorEspacial.FASE_CIRCULACION, 0))
	var acel: int = int(totales.get(MotorEspacial.FASE_ACELERACION, 0))
	var tran: int = int(totales.get(MotorEspacial.FASE_TRANSICION, 0))
	var ticks: int = circ + acel + tran
	if circ == 0 or acel == 0 or tran == 0:
		_falla("en %d partidos alguna fase no aparecio nunca (circ %d, acel %d, tran %d)." % [
				partidos, circ, acel, tran])
	elif float(circ) / float(maxi(ticks, 1)) > 0.75:
		_falla("la circulacion se comio el %.0f%% de los ticks: el partido se traba." % [
				100.0 * float(circ) / float(ticks)])
	else:
		print("OK: %d ticks con dueno — circulacion %.0f%%, aceleracion %.0f%%, transicion %.0f%%." % [
				ticks, 100.0 * float(circ) / float(ticks), 100.0 * float(acel) / float(ticks),
				100.0 * float(tran) / float(ticks)])
	var atras: int = int(totales.get("atras_sin_presion", 0))
	var dev: int = int(totales.get("devolucion", 0))
	var con_p: int = int(totales.get("atras_con_presion", 0))
	print("OK: por partido — %.1f pases atras sin presion, %.1f devoluciones, %.1f atras con presion." % [
			float(atras) / float(partidos), float(dev) / float(partidos),
			float(con_p) / float(partidos)])


## Utilidad ya ponderada del pase al companero pedido, o null si esa
## opcion no existe en la escena.
func _utilidad_del_pase_a(estado: Dictionary, poseedor: Dictionary, companero: int):
	var equipo: Team = estado["home"] if bool(poseedor["equipo_local"]) else estado["away"]
	var jugador := MotorEspacial._dict_jugador(estado, equipo, int(poseedor["jugador_id"]))
	for o in MotorEspacial.evaluar_opciones(estado, poseedor, jugador):
		if str(o["tipo"]) == "pase" and int(o.get("objetivo_id", -1)) == companero:
			return float(o["utilidad"])
	return null
