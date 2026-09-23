extends SceneTree

## Etapa 5 del plan de realismo: el cansancio sale de lo que corre cada
## uno. Correr gasta la reserva de sprint y la resistencia; caminar
## devuelve la reserva pero no la resistencia; las pausas no cobran; el
## suplente entra con su propia condicion; y los cambios por cansancio
## siguen funcionando.

const SEED := 5510

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
	# Clima fijo: el factor de energia del clima no tiene que meterse en las
	# comparaciones entre escenas.
	casa.clima_partido = ""
	visita.clima_partido = ""
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	return MotorEspacial.crear_estado(casa, visita, rng)


## Un MC del lado pedido, para moverlo solo mientras los otros 21 quedan
## quietos.
func _un_mc(estado: Dictionary, local: bool) -> int:
	var claves: Array = estado["jugadores"].keys()
	claves.sort()
	for id in claves:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) == local and str(e["rol"]) == "MC":
			return int(id)
	return -1


## Corre `ticks` ticks a un jugador ida y vuelta entre dos puntos, con el
## factor dado, y cobra el esfuerzo en cada uno como lo hace el motor.
func _correr(estado: Dictionary, clave: int, ticks: int, factor: float, en_juego: bool = true) -> void:
	var e: Dictionary = estado["jugadores"][clave]
	var a := Vector2(-30.0, e["pos"].y)
	var b := Vector2(30.0, e["pos"].y)
	var hacia := b
	for i in range(ticks):
		if e["pos"].distance_to(hacia) < 1.0:
			hacia = a if hacia == b else b
		MotorEspacial._mover_hacia(e, hacia, factor)
		MotorEspacial._contabilizar_esfuerzo(estado, en_juego)


func _resistencia(estado: Dictionary, clave: int) -> float:
	var e: Dictionary = estado["jugadores"][clave]
	var equipo: Team = estado["home"] if bool(e["equipo_local"]) else estado["away"]
	return equipo.resistencia_pct(int(e["jugador_id"]))


func _init() -> void:
	_test_sprint_gasta_mas_que_caminar()
	_test_caminar_devuelve_reserva_no_resistencia()
	_test_pausa_no_desgasta()
	_test_transito_no_cobra()
	_test_capacidad_gradual()
	_test_reserva_baja_frena_la_punta()
	_test_rangos()
	_test_entretiempo_acotado()
	_test_suplente_con_su_condicion()
	_test_duelo_no_mira_la_rapidez()
	_test_no_toca_el_rng()
	_test_partidos_completos()
	print("FALLOS=%d" % fallos)
	quit()


func _test_sprint_gasta_mas_que_caminar() -> void:
	for local in [true, false]:
		var sprint := _armar_estado(SEED)
		var camina := _armar_estado(SEED)
		var c1 := _un_mc(sprint, local)
		var c2 := _un_mc(camina, local)
		_correr(sprint, c1, 80, 1.0)
		_correr(camina, c2, 80, 0.3)
		var r1: float = float(sprint["jugadores"][c1]["reserva"])
		var r2: float = float(camina["jugadores"][c2]["reserva"])
		var p1: float = 1.0 - _resistencia(sprint, c1)
		var p2: float = 1.0 - _resistencia(camina, c2)
		_ok(r1 < r2 - 0.3 and p1 > p2 * 3.0,
			"(%s) 20 s sprintando dejan reserva %.2f y pierden %.4f; caminando %.2f y %.4f" % [
				"local" if local else "visita", r1, p1, r2, p2])


func _test_caminar_devuelve_reserva_no_resistencia() -> void:
	var estado := _armar_estado(SEED + 1)
	var c := _un_mc(estado, true)
	_correr(estado, c, 120, 1.0)
	var reserva_cansado: float = float(estado["jugadores"][c]["reserva"])
	var resist_cansado := _resistencia(estado, c)
	_correr(estado, c, 160, 0.25)
	var reserva_despues: float = float(estado["jugadores"][c]["reserva"])
	var resist_despues := _resistencia(estado, c)
	_ok(reserva_despues > reserva_cansado + 0.3 and resist_despues <= resist_cansado,
		"caminar 40 s sube la reserva de %.2f a %.2f y la resistencia no vuelve (%.4f -> %.4f)" % [
			reserva_cansado, reserva_despues, resist_cansado, resist_despues])


func _test_pausa_no_desgasta() -> void:
	var estado := _armar_estado(SEED + 2)
	var c := _un_mc(estado, false)
	_correr(estado, c, 120, 1.0)
	var antes := _resistencia(estado, c)
	var carga_antes: float = float(estado["esfuerzo_stats"]["carga"])
	var reserva_antes: float = float(estado["jugadores"][c]["reserva"])
	# Juego detenido: trota a su marca, como en _tick con `detenido`.
	_correr(estado, c, 40, MotorEspacial.FACTOR_TROTE_PARADO, false)
	# Festejo y silbato: todos quietos.
	for id in estado["jugadores"]:
		estado["jugadores"][id]["rapidez"] = 0.0
	for i in range(20):
		MotorEspacial._contabilizar_esfuerzo(estado, false)
	# Tanda de penales: aunque el tick corra, no se cobra.
	estado["en_tanda"] = true
	_correr(estado, c, 40, 1.0, true)
	estado["en_tanda"] = false
	_ok(_resistencia(estado, c) == antes and float(estado["esfuerzo_stats"]["carga"]) == carga_antes,
		"las pausas, el festejo y la tanda no cobran resistencia (%.4f) ni carga" % antes)
	_ok(float(estado["jugadores"][c]["reserva"]) != reserva_antes,
		"en la pausa la reserva sigue moviendose (%.2f -> %.2f)" % [
			reserva_antes, float(estado["jugadores"][c]["reserva"])])


func _test_transito_no_cobra() -> void:
	var estado := _armar_estado(SEED + 3)
	var c := _un_mc(estado, true)
	MotorEspacial._empezar_salida(estado, c)
	var antes := _resistencia(estado, c)
	_correr(estado, c, 60, 1.0)
	_ok(_resistencia(estado, c) == antes and float(estado["jugadores"][c].get("esfuerzo", 0.0)) == 0.0,
		"el que sale de la cancha no paga lo que camina hasta el lateral")


func _test_capacidad_gradual() -> void:
	var w := MotorEspacial.pesos_esfuerzo()
	var previa := -1.0
	var salto_max := 0.0
	var monotona := true
	for i in range(101):
		var cap := MotorEspacial.capacidad_de_sprint({"reserva": float(i) / 100.0})
		if previa >= 0.0:
			if cap < previa - 1e-6:
				monotona = false
			salto_max = maxf(salto_max, absf(cap - previa))
		previa = cap
	var vacia := MotorEspacial.capacidad_de_sprint({"reserva": 0.0})
	var llena := MotorEspacial.capacidad_de_sprint({"reserva": 1.0})
	var umbral := MotorEspacial.capacidad_de_sprint({"reserva": float(w["reserva_para_frenar"])})
	_ok(monotona and salto_max < 0.01 and is_equal_approx(vacia, float(w["piso_sprint"]))
			and llena == 1.0 and umbral == 1.0,
		"la capacidad sube sin escalones de %.2f (vacia) a 1 (desde %.2f de reserva); mayor salto %.4f" % [
			vacia, float(w["reserva_para_frenar"]), salto_max])


func _test_reserva_baja_frena_la_punta() -> void:
	var estado := _armar_estado(SEED + 4)
	var c := _un_mc(estado, true)
	var e: Dictionary = estado["jugadores"][c]
	var punta: float = float(e["vel_max"])
	var piso: float = float(MotorEspacial.pesos_esfuerzo()["piso_sprint"])
	var maxima_llena := 0.0
	var maxima_vacia := 0.0
	var trote_lleno := 0.0
	var trote_vacio := 0.0
	for caso in [["llena", 1.0], ["vacia", 0.0]]:
		for factor in [1.0, MotorEspacial.FACTOR_TROTE_PARADO]:
			e["pos"] = Vector2(-40.0, 0.0)
			e["vel"] = Vector2.ZERO
			e["rapidez"] = 0.0
			var maxima := 0.0
			for i in range(24):
				e["reserva"] = float(caso[1])
				MotorEspacial._mover_hacia(e, Vector2(40.0, 0.0), factor)
				maxima = maxf(maxima, float(e["rapidez"]))
			if factor == 1.0:
				if caso[0] == "llena":
					maxima_llena = maxima
				else:
					maxima_vacia = maxima
			elif caso[0] == "llena":
				trote_lleno = maxima
			else:
				trote_vacio = maxima
	_ok(is_equal_approx(maxima_llena, punta) and maxima_vacia <= punta * piso + 1e-4
			and maxima_vacia > punta * piso - 0.05,
		"con la reserva vacia la punta cae de %.2f a %.2f m/s (piso %.2f)" % [maxima_llena, maxima_vacia, piso])
	_ok(is_equal_approx(trote_lleno, trote_vacio),
		"el trote no nota la reserva: %.2f contra %.2f m/s" % [trote_lleno, trote_vacio])


func _test_rangos() -> void:
	var estado := _armar_estado(SEED + 5)
	var c := _un_mc(estado, false)
	var peor_reserva_fuera := false
	var e: Dictionary = estado["jugadores"][c]
	for bloque in range(40):
		_correr(estado, c, 100, 1.0 if bloque % 2 == 0 else 0.0)
		var r: float = float(e["reserva"])
		if r < 0.0 or r > 1.0:
			peor_reserva_fuera = true
	var resist := _resistencia(estado, c)
	var todas_en_rango := true
	for equipo in [estado["home"], estado["away"]]:
		for j in equipo.todos_los_jugadores():
			var v: float = equipo.resistencia_pct(int(j["id"]))
			if v < 0.55 or v > 1.0:
				todas_en_rango = false
	_ok(not peor_reserva_fuera and todas_en_rango and resist >= 0.55,
		"4000 ticks alternando piques y descanso: reserva en [0,1] y resistencia %.3f, nunca bajo 0,55" % resist)


func _test_entretiempo_acotado() -> void:
	var estado := _armar_estado(SEED + 6)
	var casa: Team = estado["home"]
	var w := MotorEspacial.pesos_esfuerzo()
	var ids := []
	for j in casa.jugadores:
		ids.append(int(j["id"]))
	# Tres situaciones: arranco fresco y perdio mucho, arranco con fatiga de
	# la semana y perdio poco, y no perdio nada.
	casa.fatiga_acumulada[ids[1]] = 1.0
	casa.resistencia[ids[1]] = 0.60
	casa.fatiga_acumulada[ids[2]] = 0.80
	casa.resistencia[ids[2]] = 0.79
	casa.fatiga_acumulada[ids[3]] = 0.90
	casa.resistencia[ids[3]] = 0.90
	MotorEspacial._recuperar_entretiempo(estado)
	var r1 := casa.resistencia_pct(ids[1])
	var r2 := casa.resistencia_pct(ids[2])
	var r3 := casa.resistencia_pct(ids[3])
	_ok(is_equal_approx(r1, 0.60 + float(w["tope_entretiempo"]))
			and is_equal_approx(r2, 0.79 + 0.01 * float(w["recuperacion_entretiempo"]))
			and r2 <= 0.80 and r3 == 0.90,
		"el entretiempo devuelve %.3f con tope, %.4f de lo poco perdido y nada al que no perdio" % [
			r1 - 0.60, r2 - 0.79])
	# Y el partido completo lo aplica una sola vez, antes del segundo tiempo.
	var llenas := true
	estado["jugadores"][_un_mc(estado, true)]["reserva"] = 0.1
	MotorEspacial._llenar_reservas(estado)
	for id in estado["jugadores"]:
		if float(estado["jugadores"][id]["reserva"]) != 1.0:
			llenas = false
	_ok(llenas, "el arranque de cada periodo llena la reserva de los 22")


func _test_suplente_con_su_condicion() -> void:
	var estado := _armar_estado(SEED + 7)
	var casa: Team = estado["home"]
	var c := _un_mc(estado, true)
	_correr(estado, c, 200, 1.0)
	var sale: int = int(estado["jugadores"][c]["jugador_id"])
	var entra := {}
	for j in casa.banco:
		if not casa.en_cancha.has(j["id"]):
			entra = j
			break
	casa.resistencia[int(entra["id"])] = 0.93
	casa.sustituir(sale, int(entra["id"]))
	MotorEspacial._sincronizar_cambios(estado, true)
	var clave := MotorEspacial.clave_de(entra["id"], true)
	var e: Dictionary = estado["jugadores"].get(clave, {})
	_ok(not e.is_empty() and float(e["reserva"]) == 1.0
			and int(e["energia"]) == int(entra["atributos"]["energia"])
			and casa.resistencia_pct(int(entra["id"])) == 0.93,
		"el suplente entra con reserva llena, su energia y su resistencia (0,93), no la del que sale (%.3f)" % [
			casa.resistencia_pct(sale)])


## El contacto y la corrida tienen responsables distintos: el duelo cobra lo
## mismo este quieto o lanzado.
func _test_duelo_no_mira_la_rapidez() -> void:
	var perdidas := []
	for rapidez in [0.0, 8.5]:
		var estado := _armar_estado(SEED + 8)
		var casa: Team = estado["home"]
		var visita: Team = estado["away"]
		var a: Dictionary = casa.jugadores[5]
		var d: Dictionary = visita.jugadores[5]
		for id in estado["jugadores"]:
			estado["jugadores"][id]["rapidez"] = rapidez
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		MotorEspacial._duelo_simple(a, "control", casa, d, "quite", visita, 30, rng)
		perdidas.append(1.0 - casa.resistencia_pct(int(a["id"])))
	_ok(perdidas[0] > 0.0 and is_equal_approx(perdidas[0], perdidas[1]),
		"el duelo cobra %.4f quieto y %.4f lanzado" % [perdidas[0], perdidas[1]])


func _test_no_toca_el_rng() -> void:
	var estado := _armar_estado(SEED + 9)
	var c := _un_mc(estado, true)
	var rng: RandomNumberGenerator = estado["rng"]
	var antes := rng.state
	_correr(estado, c, 50, 1.0)
	MotorEspacial._recuperar_entretiempo(estado)
	_ok(rng.state == antes, "cobrar el esfuerzo y el entretiempo no mueven el RNG")


## Partidos completos: mismo resultado y misma energia con y sin fotogramas,
## correr mas cansa mas, y los cambios por cansancio siguen saliendo.
func _test_partidos_completos() -> void:
	var iguales := true
	var cambios := 0
	var xs := []
	var ys := []
	var reserva_baja := 0
	var ticks_j := 0
	for i in range(8):
		var semilla := SEED + 100 + i * 11
		var corridas := []
		for con_fg in [false, true]:
			var rng := RandomNumberGenerator.new()
			rng.seed = semilla
			var a := Team.generar("A", rng, 0, NivelDivision.potencial(9), "Uruguay", NivelDivision.realizacion(9))
			var b := Team.generar("B", rng, 400, NivelDivision.potencial(9), "Uruguay", NivelDivision.realizacion(9))
			a.config_cambios = "descanso"
			b.config_cambios = "descanso"
			var rng_p := RandomNumberGenerator.new()
			rng_p.seed = semilla
			var res := MotorEspacial.simular(a, b, rng_p, con_fg)
			var energia := []
			for equipo in [a, b]:
				for j in equipo.todos_los_jugadores():
					energia.append(snappedf(equipo.resistencia_pct(int(j["id"])), 0.000001))
			corridas.append({"res": res, "energia": energia, "a": a, "b": b})
		var s: Dictionary = corridas[0]
		var f: Dictionary = corridas[1]
		if int(s["res"]["goles_local"]) != int(f["res"]["goles_local"]) \
				or int(s["res"]["goles_visitante"]) != int(f["res"]["goles_visitante"]) \
				or s["energia"] != f["energia"]:
			iguales = false
		for ev in s["res"]["eventos"]:
			if str(ev.get("tipo", "")) == "cambio" and str(ev.get("resultado", "")) == "cansancio":
				cambios += 1
		var st: Dictionary = s["res"]["stats"]["esfuerzo"]
		reserva_baja += int(st["ticks_reserva_baja"])
		ticks_j += int(st["ticks_jugador"])
		# Recorrido del ultimo fotograma en que aparece cada uno contra la
		# energia que perdio. Solo jugadores de campo.
		var recorrido := {}
		for fg in f["res"]["fotogramas"]:
			for jf in fg["jugadores"]:
				recorrido[int(jf["id"])] = [float(jf["recorrido"]), str(jf["rol"])]
		for par in [[f["a"], true], [f["b"], false]]:
			var equipo: Team = par[0]
			for j in equipo.jugadores:
				var clave := MotorEspacial.clave_de(j["id"], par[1])
				if not recorrido.has(clave) or recorrido[clave][1] == "ARQ":
					continue
				xs.append(recorrido[clave][0])
				ys.append(1.0 - equipo.resistencia_pct(int(j["id"])))
	_ok(iguales, "8 partidos dan el mismo marcador y la misma energia de los 22 con y sin fotogramas")
	_ok(cambios > 0, "con config descanso salen %d cambios por cansancio en 8 partidos de decima" % cambios)
	var corr := _correlacion(xs, ys)
	# 0,2 y no 0,3: con 8 partidos la correlacion depende mucho de la
	# semilla. Medido con el motor del 2026-09-22 (gambeta solo en contacto):
	# 0,27 / 0,38 / 0,42 / 0,28 con las semillas 5510 / 1111 / 2222 / 3333.
	# Con 160 jugadores, r > 0,2 ya es una relacion clara (p < 0,01).
	_ok(corr > 0.2, "correr mas cansa mas: correlacion %.2f entre metros y energia perdida (%d jugadores)" % [
		corr, xs.size()])
	var pct := 100.0 * float(reserva_baja) / maxf(float(ticks_j), 1.0)
	_ok(pct > 0.5 and pct < 20.0,
		"la reserva baja aparece pero no se come el partido: %.1f%% de los ticks de jugador" % pct)


func _correlacion(xs: Array, ys: Array) -> float:
	var n := xs.size()
	if n < 3:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in range(n):
		mx += float(xs[i])
		my += float(ys[i])
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(n):
		sxy += (float(xs[i]) - mx) * (float(ys[i]) - my)
		sxx += pow(float(xs[i]) - mx, 2.0)
		syy += pow(float(ys[i]) - my, 2.0)
	if sxx <= 0.0 or syy <= 0.0:
		return 0.0
	return sxy / sqrt(sxx * syy)
