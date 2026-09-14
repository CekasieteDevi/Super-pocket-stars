extends SceneTree

## Etapa 3 del plan de realismo: control y orientacion corporal. El cuerpo
## gira con velocidad limitada, recibir de espaldas o un pase fuerte cuesta
## mas, el control malo deja la pelota suelta y disputable, y girar 180
## grados con la pelota exige tiempo.

const SEED := 3310

var fallos := 0


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		print("FALLA: " + texto)
		fallos += 1


func _armar_estado(semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = ""
	visita.clima_partido = ""
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	return MotorEspacial.crear_estado(casa, visita, rng)


## La clave del primero de ese equipo con alguno de los roles pedidos, en
## orden de preferencia. No todas las formaciones tienen extremos o enganche.
func _de_rol(estado: Dictionary, local: bool, rol: String, excluir: Array = []) -> int:
	var preferidos: Array = [rol, "DC", "MCO", "EXT", "MC", "LAT", "DFC"]
	for r in preferidos:
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if bool(e["equipo_local"]) == local and str(e["rol"]) == r and not excluir.has(int(id)):
				return int(id)
	return -1


## Un MC con la pelota en el medio y los rivales de campo lejos: sin presion.
func _escena(semilla: int, local: bool) -> Dictionary:
	var estado := _armar_estado(semilla)
	var clave := _de_rol(estado, local, "MC")
	var signo := 1.0 if local else -1.0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) != local and str(e["rol"]) != "ARQ":
			e["pos"] = Vector2(signo * 40.0, e["pos"].y)
	estado["jugadores"][clave]["pos"] = Vector2.ZERO
	estado["pelota"]["pos"] = Vector2.ZERO
	estado["pelota"]["poseedor_id"] = clave
	estado["pelota"]["en_vuelo"] = false
	MotorEspacial._calcular_linea_offside(estado)
	return {"estado": estado, "clave": clave, "signo": signo}


func _jugador(estado: Dictionary, clave: int) -> Dictionary:
	var e: Dictionary = estado["jugadores"][clave]
	return MotorEspacial._dict_jugador(estado, MotorEspacial._equipo_de(estado, e["equipo_local"]), e["jugador_id"])


func _restaurar_pesos() -> void:
	MotorEspacial._pesos_control_cache = {}
	MotorEspacial.pesos_control()


func _init() -> void:
	_test_el_giro_esta_limitado_por_agilidad()
	_test_quieto_mira_la_pelota()
	_test_de_frente_contra_de_espaldas()
	_test_fuerte_contra_suave()
	_test_la_demora_reemplaza_la_espera_vieja()
	_test_la_decision_espera_la_demora()
	_test_control_alto_mejora_la_distribucion()
	_test_una_tirada_por_recepcion()
	_test_el_toque_largo_queda_disputable()
	_test_girar_180_exige_tiempo()
	_test_sin_opciones_no_se_bloquea()
	_test_saque_y_suplente_se_orientan()
	_test_vista_con_y_sin_orientacion()
	_test_partidos_completos()
	print("\nFALLOS=%d" % fallos)
	quit()


func _test_el_giro_esta_limitado_por_agilidad() -> void:
	print("=== El giro esta limitado por la agilidad ===")
	var lento := {"orientacion": Vector2(1, 0), "giro": MotorEspacial._giro_de({"atributos": {"agilidad": 5}})}
	var rapido := {"orientacion": Vector2(1, 0), "giro": MotorEspacial._giro_de({"atributos": {"agilidad": 95}})}
	var ticks := []
	var peor_exceso := 0.0
	for e in [lento, rapido]:
		var n := 0
		while MotorEspacial.orientacion_de(e).dot(Vector2(-1, 0)) < 0.9999 and n < 50:
			var antes: Vector2 = MotorEspacial.orientacion_de(e)
			MotorEspacial.girar_hacia(e, Vector2(-1, 0.001))
			var giro_tick: float = absf(antes.angle_to(MotorEspacial.orientacion_de(e)))
			peor_exceso = maxf(peor_exceso, giro_tick - float(e["giro"]) * MotorEspacial.TICK_SEG)
			n += 1
		ticks.append(n)
	_ok(ticks[1] < ticks[0] and peor_exceso < 0.0001,
		"media vuelta: %d ticks con agilidad 5 (%.1f rad/s) y %d con 95 (%.1f rad/s); ningun tick gira de mas" % [
			ticks[0], float(lento["giro"]), ticks[1], float(rapido["giro"])])
	var quieto := {"orientacion": Vector2(0, 1), "giro": 6.0}
	MotorEspacial.girar_hacia(quieto, Vector2.ZERO)
	var o: Vector2 = quieto["orientacion"]
	_ok(o == Vector2(0, 1) and not is_nan(o.x) and not is_nan(o.y),
		"un vector nulo no cambia la orientacion ni la deja en NaN")
	var sin_campo := {"equipo_local": false}
	_ok(MotorEspacial.orientacion_de(sin_campo) == Vector2(-1, 0),
		"un dict sin orientacion mira al arco que ataca")


func _test_quieto_mira_la_pelota() -> void:
	print("=== Quieto mira la pelota, corriendo sigue la carrera ===")
	for local in [true, false]:
		var esc := _escena(SEED, local)
		var estado: Dictionary = esc["estado"]
		var otro := _de_rol(estado, local, "DC", [esc["clave"]])
		var e: Dictionary = estado["jugadores"][otro]
		e["pos"] = Vector2(0.0, 20.0)
		e["rapidez"] = 0.0
		e["orientacion"] = Vector2(0, 1)
		for i in range(8):
			MotorEspacial._mirar_la_pelota(estado)
		var hacia_pelota: float = MotorEspacial.orientacion_de(e).dot(Vector2(0, -1))
		var corredor := _de_rol(estado, local, "EXT", [esc["clave"], otro])
		var c: Dictionary = estado["jugadores"][corredor]
		c["pos"] = Vector2(-10.0, -20.0)
		c["vel"] = Vector2.ZERO
		c["rapidez"] = 0.0
		c["orientacion"] = Vector2(0, 1)
		for i in range(12):
			MotorEspacial._mover_hacia(c, Vector2(-10.0, 30.0))
			MotorEspacial._mirar_la_pelota(estado)
		var sigue: float = MotorEspacial.orientacion_de(c).dot(Vector2(0, 1))
		_ok(hacia_pelota > 0.999 and sigue > 0.999,
			"(%s) el quieto termina mirando la pelota (%.3f) y el que corre sigue mirando su carrera (%.3f)" % [
				"local" if local else "visita", hacia_pelota, sigue])


func _test_de_frente_contra_de_espaldas() -> void:
	print("=== Recibir de frente contra de espaldas, misma escena ===")
	for local in [true, false]:
		var esc := _escena(SEED, local)
		var estado: Dictionary = esc["estado"]
		var clave: int = esc["clave"]
		var signo: float = esc["signo"]
		var e: Dictionary = estado["jugadores"][clave]
		var jugador := _jugador(estado, clave)
		jugador["atributos"]["control"] = 10
		var equipo := MotorEspacial._equipo_de(estado, local)
		# El pase viene de atras hacia el arco rival.
		var vel := Vector2(signo * 18.0, 0.0)
		e["orientacion"] = Vector2(-signo, 0.0)
		var frente := MotorEspacial.dificultad_de_recepcion(estado, e, vel, 0.0)
		e["orientacion"] = Vector2(signo, 0.0)
		var espaldas := MotorEspacial.dificultad_de_recepcion(estado, e, vel, 0.0)
		var d_fr: float = frente["dificultad"]
		var d_es: float = espaldas["dificultad"]
		var dem_fr := MotorEspacial.demora_de_control(jugador, equipo, d_fr)
		var dem_es := MotorEspacial.demora_de_control(jugador, equipo, d_es)
		var p_fr := MotorEspacial.prob_toque_largo(jugador, d_fr)
		var p_es := MotorEspacial.prob_toque_largo(jugador, d_es)
		_ok(d_es > d_fr + 0.19 and dem_es > dem_fr and p_es > p_fr,
			"(%s) dificultad %.2f de frente y %.2f de espaldas; demora %d y %d ticks; toque largo %.3f y %.3f" % [
				"local" if local else "visita", d_fr, d_es, dem_fr, dem_es, p_fr, p_es])


func _test_fuerte_contra_suave() -> void:
	print("=== Pase fuerte contra pase suave ===")
	var esc := _escena(SEED, true)
	var estado: Dictionary = esc["estado"]
	var e: Dictionary = estado["jugadores"][esc["clave"]]
	e["orientacion"] = Vector2(-1, 0)
	var f: Dictionary = MotorEspacial.pesos()["fisica"]
	var suave := MotorEspacial.dificultad_de_recepcion(estado, e, Vector2(float(f["vel_pase_min"]), 0), 0.0)
	var fuerte := MotorEspacial.dificultad_de_recepcion(estado, e, Vector2(float(f["vel_pase_max"]), 0), 0.0)
	var alto := MotorEspacial.dificultad_de_recepcion(estado, e, Vector2(float(f["vel_pase_min"]), 0), float(f["altura_centro"]))
	_ok(float(fuerte["dificultad"]) > float(suave["dificultad"]) + 0.29
			and float(alto["dificultad"]) > float(suave["dificultad"]) + 0.19,
		"dificultad %.2f con el pase mas suave, %.2f con el mas fuerte y %.2f con el suave que viene alto" % [
			float(suave["dificultad"]), float(fuerte["dificultad"]), float(alto["dificultad"])])
	var jugador := _jugador(estado, esc["clave"])
	_ok(MotorEspacial.prob_toque_largo(jugador, 0.0) == 0.0,
		"con dificultad cero nadie hace un toque largo")
	# La presion del rival encima tambien suma.
	var rival := _de_rol(estado, false, "DFC")
	estado["jugadores"][rival]["pos"] = Vector2(1.5, 0.0)
	var presionado := MotorEspacial.dificultad_de_recepcion(estado, e, Vector2(float(f["vel_pase_min"]), 0), 0.0)
	_ok(float(presionado["dificultad"]) > float(suave["dificultad"]),
		"un rival a 1,5 m sube la dificultad de %.2f a %.2f" % [
			float(suave["dificultad"]), float(presionado["dificultad"])])


func _test_la_demora_reemplaza_la_espera_vieja() -> void:
	print("=== La demora reemplaza la espera vieja, no se le suma ===")
	var esc := _escena(SEED + 1, true)
	var estado: Dictionary = esc["estado"]
	MotorEspacial._pesos_control_cache["demora_facil"] = 1.0
	MotorEspacial._pesos_control_cache["demora_dificil"] = 1.0
	var iguales := 0
	var total := 0
	for local in [true, false]:
		var equipo := MotorEspacial._equipo_de(estado, local)
		for estilo in ["Tiki taka", "Juego directo", "Contragolpe"]:
			equipo.estilo = estilo
			for id in estado["jugadores"]:
				var e: Dictionary = estado["jugadores"][id]
				if bool(e["equipo_local"]) != local:
					continue
				var jugador := _jugador(estado, int(id))
				for d in [0.0, 0.5, 1.0]:
					total += 1
					if MotorEspacial.demora_de_control(jugador, equipo, d) == MotorEspacial.cadencia_de_decision(jugador, equipo):
						iguales += 1
	_restaurar_pesos()
	_ok(iguales == total,
		"con factor 1 la demora da la espera vieja en %d de %d casos (22 jugadores, 3 estilos, 3 dificultades)" % [iguales, total])
	var jugador := _jugador(estado, esc["clave"])
	var equipo := MotorEspacial._equipo_de(estado, true)
	var cad := MotorEspacial.cadencia_de_decision(jugador, equipo)
	var facil := MotorEspacial.demora_de_control(jugador, equipo, 0.0)
	var dificil := MotorEspacial.demora_de_control(jugador, equipo, 1.0)
	_ok(facil <= cad and dificil >= cad and dificil < cad * 2 + 1,
		"cadencia %d: la recepcion facil demora %d y la dificil %d, sin sumar las dos esperas" % [cad, facil, dificil])


func _test_la_decision_espera_la_demora() -> void:
	print("=== El poseedor decide recien al cumplir la demora ===")
	var resultados := []
	for demora in [-1, 5]:
		var esc := _escena(SEED + 2, true)
		var estado: Dictionary = esc["estado"]
		var clave: int = esc["clave"]
		var jugador := _jugador(estado, clave)
		var cad := MotorEspacial.cadencia_de_decision(jugador, MotorEspacial._equipo_de(estado, true))
		var esperado: int = demora if demora > 0 else cad
		var primera := -1
		for ticks in range(0, 12):
			var e: Dictionary = estado["jugadores"][clave]
			e["pos"] = Vector2.ZERO
			e["orientacion"] = Vector2(1, 0)
			var pelota: Dictionary = estado["pelota"]
			pelota["poseedor_id"] = clave
			pelota["en_vuelo"] = false
			pelota["pos"] = Vector2.ZERO
			pelota["ticks_con_pelota"] = ticks
			if demora > 0:
				pelota["control"] = {"clave": clave, "demora": demora}
			else:
				pelota.erase("control")
			estado.erase("ultima_decision")
			MotorEspacial._decidir_y_ejecutar(estado)
			if estado.has("ultima_decision"):
				primera = ticks
				break
		resultados.append([esperado, primera])
	_ok(resultados[0][0] == resultados[0][1] and resultados[1][0] == resultados[1][1],
		"sin control pendiente decide en el tick %d (cadencia %d); con demora 5, en el tick %d" % [
			resultados[0][1], resultados[0][0], resultados[1][1]])


func _test_control_alto_mejora_la_distribucion() -> void:
	print("=== Control alto mejora la distribucion en muchas semillas ===")
	var medidas := {}
	for control in [15, 95]:
		var esc := _escena(SEED + 3, true)
		var estado: Dictionary = esc["estado"]
		var clave: int = esc["clave"]
		_jugador(estado, clave)["atributos"]["control"] = control
		var toques := 0
		var demora := 0
		var limpias := 0
		for s in range(600):
			estado["rng"].seed = 90000 + s
			var e: Dictionary = estado["jugadores"][clave]
			e["pos"] = Vector2.ZERO
			e["orientacion"] = Vector2(1, 0)
			var pelota: Dictionary = estado["pelota"]
			pelota["poseedor_id"] = clave
			pelota["en_vuelo"] = false
			pelota["pos"] = Vector2.ZERO
			pelota.erase("control")
			MotorEspacial._controlar_recepcion(estado, clave, {"vel": Vector2(20.0, 0.0), "altura": 0.0})
			if int(pelota["poseedor_id"]) == -1:
				toques += 1
			else:
				limpias += 1
				demora += int(pelota["control"]["demora"])
		medidas[control] = {"toques": toques, "demora": float(demora) / maxf(float(limpias), 1.0)}
	_ok(int(medidas[95]["toques"]) < int(medidas[15]["toques"]) and float(medidas[95]["demora"]) < float(medidas[15]["demora"]),
		"600 recepciones de espaldas: control 15 hace %d toques largos y demora %.2f ticks; control 95, %d y %.2f" % [
			int(medidas[15]["toques"]), float(medidas[15]["demora"]),
			int(medidas[95]["toques"]), float(medidas[95]["demora"])])
	_ok(int(medidas[95]["toques"]) > 0,
		"el control alto tambien puede fallar (%d de 600)" % int(medidas[95]["toques"]))


func _test_una_tirada_por_recepcion() -> void:
	print("=== Una sola tirada por recepcion ===")
	var esc := _escena(SEED + 4, true)
	var estado: Dictionary = esc["estado"]
	var clave: int = esc["clave"]
	var rng: RandomNumberGenerator = estado["rng"]
	var copia := RandomNumberGenerator.new()
	copia.seed = rng.seed
	copia.state = rng.state
	MotorEspacial._pesos_control_cache["malo_max"] = 0.0
	MotorEspacial._controlar_recepcion(estado, clave, {"vel": Vector2(15.0, 0.0), "altura": 0.0})
	copia.randf()
	_ok(rng.state == copia.state, "un control limpio consume exactamente una tirada del RNG del partido")
	_restaurar_pesos()

	# Un pase de verdad que llega lejos del receptor: rueda varios ticks hasta
	# sus pies y la recepcion se resuelve una sola vez.
	var esc2 := _escena(SEED + 5, true)
	var e2: Dictionary = esc2["estado"]
	var pasador: int = esc2["clave"]
	var receptor := _de_rol(e2, true, "MCO", [pasador])
	e2["jugadores"][receptor]["pos"] = Vector2(14.0, 6.0)
	MotorEspacial._lanzar_pase(e2, e2["jugadores"][pasador], receptor, _jugador(e2, pasador), Vector2(14.0, 0.0))
	var ticks := 0
	while bool(e2["pelota"]["en_vuelo"]) and ticks < 30:
		MotorEspacial._avanzar_pelota(e2)
		ticks += 1
	var st: Dictionary = e2.get("control_stats", {})
	_ok(int(st.get("recepciones", 0)) == 1 and ticks > 1,
		"un pase que rueda %d ticks hasta el receptor cuenta %d recepcion" % [ticks, int(st.get("recepciones", 0))])


func _test_el_toque_largo_queda_disputable() -> void:
	print("=== El toque largo deja la pelota suelta y disputable ===")
	var ganadores := {"propio": 0, "rival": 0, "nadie": 0}
	var peor_distancia := 0.0
	var adjudicada := 0
	for local in [true, false]:
		for s in range(30):
			var esc := _escena(SEED + 10 + s, local)
			var estado: Dictionary = esc["estado"]
			var clave: int = esc["clave"]
			var signo: float = esc["signo"]
			var rival := _de_rol(estado, not local, "DFC")
			estado["jugadores"][rival]["pos"] = Vector2(0.0, 3.0)
			MotorEspacial._pesos_control_cache["malo_max"] = 10.0
			MotorEspacial._controlar_recepcion(estado, clave, {"vel": Vector2(signo * 22.0, 0.0), "altura": 0.0})
			_restaurar_pesos()
			var pelota: Dictionary = estado["pelota"]
			if int(pelota["poseedor_id"]) != -1:
				adjudicada += 1
				continue
			peor_distancia = maxf(peor_distancia, Vector2.ZERO.distance_to(pelota["destino_pos"]))
			var n := 0
			while int(pelota["poseedor_id"]) == -1 and n < 40:
				MotorEspacial._tick(estado, false)
				n += 1
			var dueno: int = int(pelota["poseedor_id"])
			if dueno == -1 or int(estado.get("detenido", 0)) > 0:
				ganadores["nadie"] += 1
			elif bool(estado["jugadores"][dueno]["equipo_local"]) == local:
				ganadores["propio"] += 1
			else:
				ganadores["rival"] += 1
	var maximo: float = float(MotorEspacial.pesos_control()["toque_largo_max"])
	_ok(adjudicada == 0 and peor_distancia <= maximo + 0.01,
		"60 toques largos: ninguno queda en los pies de nadie y el mas largo va a %.1f m (tope %.1f)" % [peor_distancia, maximo])
	_ok(int(ganadores["propio"]) > 0 and int(ganadores["rival"]) > 0,
		"la pelota suelta la recupera el receptor o su equipo %d veces y el rival %d (sin dueno %d)" % [
			int(ganadores["propio"]), int(ganadores["rival"]), int(ganadores["nadie"])])


func _test_girar_180_exige_tiempo() -> void:
	print("=== Girar 180 grados con la pelota exige tiempo ===")
	for local in [true, false]:
		var esc := _escena(SEED + 6, local)
		var estado: Dictionary = esc["estado"]
		var clave: int = esc["clave"]
		var signo: float = esc["signo"]
		var e: Dictionary = estado["jugadores"][clave]
		var adelante := _de_rol(estado, local, "DC", [clave])
		estado["jugadores"][adelante]["pos"] = Vector2(signo * 18.0, 0.0)
		var atras := _de_rol(estado, local, "DFC", [clave, adelante])
		estado["jugadores"][atras]["pos"] = Vector2(-signo * 15.0, 0.0)
		e["orientacion"] = Vector2(-signo, 0.0)
		var jugador := _jugador(estado, clave)
		var opciones := MotorEspacial.evaluar_opciones(estado, e, jugador)
		var quedan := MotorEspacial._opciones_orientadas(estado, opciones, e)
		var tiene_adelante := false
		var tiene_atras := false
		var tiene_conducir := false
		for op in quedan:
			if int(op.get("objetivo_id", -1)) == adelante:
				tiene_adelante = true
			if int(op.get("objetivo_id", -1)) == atras:
				tiene_atras = true
			if str(op["tipo"]) == "conducir":
				tiene_conducir = true
		var necesita := MotorEspacial.ticks_para_girar(e, Vector2(signo, 0.0))
		var n := 0
		while MotorEspacial.ticks_para_girar(e, Vector2(signo, 0.0)) > 0 and n < 20:
			MotorEspacial.girar_hacia(e, Vector2(signo, 0.0))
			n += 1
		var despues := MotorEspacial._opciones_orientadas(estado, MotorEspacial.evaluar_opciones(estado, e, jugador), e)
		var vuelve := false
		for op in despues:
			if int(op.get("objetivo_id", -1)) == adelante:
				vuelve = true
		_ok(not tiene_adelante and tiene_atras and tiene_conducir and necesita > 0 and n == necesita and vuelve,
			"(%s) de espaldas al arco no juega al 9 (%d de %d opciones quedan) pero si al central y conduce; gira en %d ticks (estimados %d) y el pase al 9 vuelve" % [
				"local" if local else "visita", quedan.size(), opciones.size(), n, necesita])


func _test_sin_opciones_no_se_bloquea() -> void:
	print("=== Sin opciones orientadas gira y vuelve a decidir: no se bloquea ===")
	for local in [true, false]:
		var estado := _armar_estado(SEED + 7)
		var arq := _de_rol(estado, local, "ARQ")
		var signo := 1.0 if local else -1.0
		var e: Dictionary = estado["jugadores"][arq]
		e["pos"] = Vector2(-signo * 48.0, 0.0)
		e["orientacion"] = Vector2(-signo, 0.0)
		# Todos los companeros derecho adelante: ninguno entra en el cono del
		# arquero que mira su propio arco.
		var fila := 0
		for id in estado["jugadores"]:
			var c: Dictionary = estado["jugadores"][id]
			if bool(c["equipo_local"]) == local and int(id) != arq:
				c["pos"] = Vector2(-signo * 30.0, float(fila % 5 - 2) * 1.5)
				fila += 1
		var pelota: Dictionary = estado["pelota"]
		pelota["poseedor_id"] = arq
		pelota["pos"] = e["pos"]
		pelota["en_vuelo"] = false
		var jugador := _jugador(estado, arq)
		var cad := MotorEspacial.cadencia_de_decision(jugador, MotorEspacial._equipo_de(estado, local))
		pelota["ticks_con_pelota"] = cad
		MotorEspacial._calcular_linea_offside(estado)
		var llamadas := 0
		var espero := false
		while int(pelota["poseedor_id"]) == arq and not bool(pelota["en_vuelo"]) and llamadas < 12:
			MotorEspacial._decidir_y_ejecutar(estado)
			if llamadas == 0 and int(pelota.get("control", {}).get("demora", -1)) == cad + 1:
				espero = true
			pelota["ticks_con_pelota"] = int(pelota["ticks_con_pelota"]) + 1
			llamadas += 1
		_ok(espero and llamadas >= 2 and llamadas <= 4 and (bool(pelota["en_vuelo"]) or int(pelota["poseedor_id"]) != arq),
			"(%s) el arquero de espaldas no juega en el primer tick, gira, y la juega en la llamada %d" % [
				"local" if local else "visita", llamadas])


func _test_saque_y_suplente_se_orientan() -> void:
	print("=== Saque del medio y suplente arrancan orientados ===")
	var estado := _armar_estado(SEED + 8)
	for id in estado["jugadores"]:
		estado["jugadores"][id]["orientacion"] = Vector2(0, 1)
	MotorEspacial._reiniciar_desde_medio(estado, true)
	var bien := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if MotorEspacial.orientacion_de(e) == MotorEspacial.orientacion_inicial(bool(e["equipo_local"])):
			bien += 1
	_ok(bien == estado["jugadores"].size(), "en el saque del medio %d de %d miran al arco que atacan" % [
		bien, estado["jugadores"].size()])
	var casa: Team = estado["home"]
	var mc := _de_rol(estado, true, "MC")
	var sale: int = int(estado["jugadores"][mc]["jugador_id"])
	estado["jugadores"][mc]["orientacion"] = Vector2(0, -1)
	var entra := {}
	for j in casa.banco:
		if not casa.en_cancha.has(j["id"]):
			entra = j
			break
	entra["atributos"]["agilidad"] = 91
	casa.sustituir(sale, int(entra["id"]))
	MotorEspacial._sincronizar_cambios(estado, true)
	var e_nuevo: Dictionary = estado["jugadores"].get(MotorEspacial.clave_de(entra["id"], true), {})
	_ok(not e_nuevo.is_empty() and MotorEspacial.orientacion_de(e_nuevo) == Vector2(1, 0)
			and is_equal_approx(float(e_nuevo["giro"]), MotorEspacial._giro_de(entra)),
		"el suplente entra mirando al arco rival y gira con su propia agilidad (%.2f rad/s)" % float(e_nuevo.get("giro", 0.0)))


func _test_vista_con_y_sin_orientacion() -> void:
	print("=== La vista usa la orientacion con el jugador quieto ===")
	var quieto := Vector2(0.01, 0.0)
	var viejo := {"id": 1, "x": 0.0, "y": 0.0}
	var nuevo := {"id": 1, "x": 0.0, "y": 0.0, "ox": -1.0, "oy": 0.0}
	var corre := Vector2(2.0, 0.0)
	_ok(VistaPartido._direccion_de_jugador(viejo, quieto) == VistaPartido._direccion(quieto)
			and VistaPartido._direccion_de_jugador(nuevo, quieto) == VistaPartido._direccion(Vector2(-1, 0))
			and VistaPartido._direccion_de_jugador(nuevo, corre) == VistaPartido._direccion(corre),
		"fotograma viejo sin orientacion dibuja igual que antes; quieto mira hacia `ox,oy`; corriendo manda el avance")


func _test_partidos_completos() -> void:
	print("=== Partidos completos ===")
	var toques := 0
	var recepciones := 0
	var coinciden := 0
	var fotogramas_malos := 0
	var peor_racha := 0
	var partidos := 6
	for i in range(partidos):
		var corridas := []
		for con_fg in [false, true]:
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + 100 + i
			var a := Team.generar("A", rng, 0, NivelDivision.potencial(i % 3 * 4), "Uruguay", NivelDivision.realizacion(i % 3 * 4))
			var b := Team.generar("B", rng, 400, NivelDivision.potencial(i % 3 * 4), "Uruguay", NivelDivision.realizacion(i % 3 * 4))
			var rng_p := RandomNumberGenerator.new()
			rng_p.seed = SEED + 100 + i
			corridas.append(MotorEspacial.simular(a, b, rng_p, con_fg))
		var sin: Dictionary = corridas[0]
		var con: Dictionary = corridas[1]
		if int(sin["goles_local"]) == int(con["goles_local"]) and int(sin["goles_visitante"]) == int(con["goles_visitante"]) \
				and str(sin["stats"]["tiros"]) == str(con["stats"]["tiros"]) \
				and str(sin["stats"]["control"]) == str(con["stats"]["control"]):
			coinciden += 1
		toques += int(sin["stats"]["control"].get("toques_largos", 0))
		recepciones += int(sin["stats"]["control"].get("recepciones", 0))
		var racha := 0
		var previo := -2
		for fg in con["fotogramas"]:
			var ids := {}
			for j in fg["jugadores"]:
				ids[int(j["id"])] = true
				var o := Vector2(float(j.get("ox", 0.0)), float(j.get("oy", 0.0)))
				if absf(o.length() - 1.0) > 0.001:
					fotogramas_malos += 1
			var dueno: int = int(fg["pelota"]["poseedor_id"])
			if dueno != -1 and not ids.has(dueno):
				fotogramas_malos += 1
			if dueno != -1 and dueno == previo and int(fg.get("detenido", 0)) == 0:
				racha += 1
			else:
				racha = 0
			previo = dueno
			peor_racha = maxi(peor_racha, racha)
	_ok(coinciden == partidos, "%d de %d partidos dan lo mismo con y sin fotogramas, control incluido" % [coinciden, partidos])
	_ok(fotogramas_malos == 0, "ningun fotograma trae una orientacion sin normalizar ni un poseedor fuera de la cancha")
	_ok(toques > 0 and recepciones > 100,
		"%d recepciones y %d toques largos en %d partidos" % [recepciones, toques, partidos])
	_ok(peor_racha < 120, "la posesion mas larga de un mismo jugador en juego dura %d ticks: nadie queda trabado" % peor_racha)
