class_name MotorV2
extends RefCounted

## Etapa 8 del Motor V2 (docs/motor_v2.md): el puente entre el motor nuevo y el
## resto del juego. `simular` juega el partido entero sin vista y devuelve lo
## mismo que MotorEspacial.simular: marcador, goleadores, eventos para el
## relato y las estadísticas, y los equipos (Team) con sus tarjetas, lesiones,
## cambios y energía del partido. En vez de fotogramas devuelve la receta
## (CerebroV2.receta): con ella la pantalla arma el mismo partido y lo juega
## de nuevo para mirarlo.
##
## El motor (C++) solo cuenta lo que pasó en la cancha. Todo lo que es del
## club (suspensiones, qué lesión, quién está en cancha) se anota acá.

## Pasos de 1/60 s que puede durar un partido (20 minutos de verdad; dura
## unos 5). Pasado esto quedó colgado.
const PASOS_TOPE := 60 * 60 * 20
## CanchitaV2Nativa.registro_pases: `tipo` (DEC_* del cerebro) y `resultado`.
const TIPO_DESPEJE := 7
const PASE_COMPLETO := 0
const PASE_OTRO := 1
const PASE_CORTE := 3
## CanchitaV2Nativa.registro_remates: `resultado` y `golpe`.
const RESULTADOS_REMATE := ["gol", "atajado", "palo", "bloqueado", "afuera", "otro"]
const GOLPE_EFECTO := 2
const GOLPE_CABEZA := 4
## `detalle` del evento "saque": qué parada fue (PARADAS del motor).
const PARADA_CORNER := 4


## Los mismos argumentos y el mismo resultado que MotorEspacial.simular. Con
## `definicion_directa` y empate a los 90 se juega el alargue y, si sigue
## empatado, la tanda.
static func simular(home: Team, away: Team, rng: RandomNumberGenerator,
		_con_fotogramas: bool = false, definicion_directa: bool = false) -> Dictionary:
	# El mismo arranque (y las mismas tiradas del rng) que MotorEspacial y
	# MatchEngine.
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false
	home.forma_partido = clamp(rng.randfn(0.0, 4.0), -10.0, 10.0)
	away.forma_partido = clamp(rng.randfn(0.0, 4.0), -10.0, 10.0)
	home.clima_partido = Clima.generar(rng)
	away.clima_partido = home.clima_partido
	home.arbitro_partido = Arbitro.generar(rng)
	away.arbitro_partido = home.arbitro_partido

	var receta := CerebroV2.receta(home, away, int(rng.randi()), true, definicion_directa,
		home.calidad_cancha, home.clima_partido, definicion_directa)
	var c: Object = CerebroV2.armar_de_receta(receta)
	var pasos := 0
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < PASOS_TOPE:
		c.simular(600)
		pasos += 600
	return _resultado(c, home, away, rng, receta)


## La receta que viaja en el lugar de los fotogramas ({} si son fotogramas del
## motor espacial o no hay nada).
static func receta_de(fotogramas: Array) -> Dictionary:
	if fotogramas.size() == 1 and (fotogramas[0] as Dictionary).has("receta_v2"):
		return fotogramas[0]["receta_v2"]
	return {}


## Lee el partido terminado, anota en los equipos lo que pasó y arma el
## resultado.
static func _resultado(c: Object, home: Team, away: Team, rng: RandomNumberGenerator, receta: Dictionary) -> Dictionary:
	var equipos := [home, away]
	var plantel := {}
	for e in 2:
		for j in (equipos[e] as Team).todos_los_jugadores():
			plantel[int(j["id"])] = {"jugador": j, "lado": e}
	var eventos := []
	var log := []
	var goles_log := []
	var remates: Array = c.registro_remates()

	eventos.append(_evento(0, 0.0, "saque_inicial", home, away, {}, "1"))
	var tanda := {"goles": [0, 0], "tandas": []}
	var alargue := false
	# El último periodo que se jugó (0 primer tiempo ... 3 segundo del alargue).
	var ultimo_periodo := 0
	for ev in c.eventos():
		# El partido suspendido anota un fin de tiempo con otro detalle: no cuenta.
		if str(ev["tipo"]) == "fin_tiempo" and int(ev["detalle"]) <= 3:
			ultimo_periodo = maxi(ultimo_periodo, int(ev["detalle"]))
	for ev in c.eventos():
		var e := int(ev["equipo"])
		var equipo: Team = equipos[e]
		var rival: Team = equipos[1 - e]
		var id := int(ev["jugador"])
		var quien: Dictionary = plantel[id]["jugador"] if plantel.has(id) else {}
		var paso := int(ev["paso"])
		var minuto := float(ev["minuto"])
		match str(ev["tipo"]):
			"saque":
				if int(ev["detalle"]) == PARADA_CORNER:
					eventos.append(_evento(paso, minuto, "corner", equipo, rival, quien, ""))
			"gol":
				var asistente := int(ev["otro"])
				var gol := {"minuto": int(minuto), "equipo": equipo.nombre, "jugador_id": id if not quien.is_empty() else -1,
					"asistencia_id": asistente if plantel.has(asistente) else -1}
				if quien.is_empty():
					gol["autogol"] = true
				goles_log.append(gol)
				var penal := int(ev["detalle"]) == 1
				var linea := _evento(paso, minuto, "penal" if penal else "tiro_puerta", equipo, rival, quien, "gol")
				linea["asistencia_clave"] = _clave(asistente, e) if plantel.has(asistente) else -1
				linea["tecnica"] = _tecnica_del_gol(remates, id, paso)
				if quien.is_empty():
					linea["autogol"] = true
				eventos.append(linea)
				log.append("min %d - %s de %s (%s)" % [int(minuto), "PENAL: gol" if penal else "GOL", _nombre(quien), equipo.nombre])
			"falta":
				eventos.append(_evento(paso, minuto, "falta", equipo, rival, quien, "penal" if int(ev["detalle"]) == 1 else ""))
			"amarilla":
				equipo.amarillas_partido[id] = int(equipo.amarillas_partido.get(id, 0)) + 1
				eventos.append(_evento(paso, minuto, "tarjeta", equipo, rival, quien, "amarilla"))
				log.append("min %d - TARJETA AMARILLA (%s) - %s" % [int(minuto), equipo.nombre, str(quien.get("posicion", ""))])
			"roja":
				var doble := int(ev["detalle"]) == 1
				if doble:
					equipo.amarillas_partido[id] = int(equipo.amarillas_partido.get(id, 0)) + 1
				equipo.expulsados_partido[id] = true
				equipo.suspendidos[id] = int(equipo.suspendidos.get(id, 0)) + 1
				eventos.append(_evento(paso, minuto, "tarjeta", equipo, rival, quien, "roja_doble_amarilla" if doble else "roja"))
				log.append("min %d - TARJETA ROJA%s (%s) - %s" % [int(minuto), " (doble amarilla)" if doble else "",
					equipo.nombre, str(quien.get("posicion", ""))])
			"offside":
				eventos.append(_evento(paso, minuto, "offside", equipo, rival, quien, ""))
			"lesion":
				if not quien.is_empty() and not equipo.esta_lesionado(id):
					var lesion := Lesiones.sortear(quien, rng)
					if not lesion.is_empty():
						equipo.lesionar(id, lesion["tipo"], lesion["dias"])
						var linea_l := _evento(paso, minuto, "lesion", equipo, rival, quien, "")
						linea_l["lesion"] = str(lesion["tipo"])
						eventos.append(linea_l)
						log.append("min %d - LESION (%s) - %s: %s" % [int(minuto), equipo.nombre, _nombre(quien), lesion["tipo"]])
			"cambio":
				var entra := int(ev["otro"])
				equipo.sustituir(id, entra)
				var motivo := "lesion" if int(ev["detalle"]) == 1 else "cansancio"
				var linea_c := _evento(paso, minuto, "cambio", equipo, rival, quien, motivo)
				linea_c["saliente_id"] = id
				linea_c["entrante_id"] = entra
				linea_c["equipo_local"] = e == 0
				linea_c["saliente_clave"] = _clave(id, e)
				linea_c["entrante_clave"] = _clave(entra, e)
				eventos.append(linea_c)
				log.append("min %d - CAMBIO (%s) - sale %s (%s)" % [int(minuto), equipo.nombre, str(quien.get("posicion", "")), motivo])
			"fin_tiempo":
				# `detalle`: el periodo que terminó (0 a 3). Si después se jugó
				# otro, arranca con su saque: "2" el segundo tiempo, "3" y "4"
				# los del alargue.
				var termino := int(ev["detalle"])
				if termino < ultimo_periodo:
					if termino == 1:
						alargue = true
					eventos.append(_evento(paso, minuto, "saque_inicial", home, away, {}, str(termino + 2)))
			"penal_tanda":
				if tanda["tandas"].is_empty():
					eventos.append(_evento(paso, minuto, "tanda_arranca", home, away, {}, ""))
				var adentro := int(ev["detalle"]) == 1
				if adentro:
					tanda["goles"][e] += 1
				tanda["tandas"].append({"equipo": equipo.nombre, "jugador_id": id,
					"jugador_posicion": str(quien.get("posicion", "")), "gol": adentro})
				var linea_p := _evento(paso, minuto, "penal_tanda", equipo, rival, quien, "gol" if adentro else "atajado")
				linea_p["tanda_local"] = tanda["goles"][0]
				linea_p["tanda_visitante"] = tanda["goles"][1]
				eventos.append(linea_p)

	_eventos_de_remates(remates, equipos, plantel, eventos)
	_eventos_de_pases(c.registro_pases(), equipos, plantel, eventos)
	eventos.sort_custom(func(a, b): return int(a["paso"]) < int(b["paso"]))

	var goles: PackedInt32Array = c.get_goles()
	home.goles = int(goles[0])
	away.goles = int(goles[1])
	# La energía con la que terminó cada uno (el que salió, con la que se fue).
	var energias: Dictionary = c.energias_por_id()
	for id in energias:
		if plantel.has(int(id)):
			(equipos[int(plantel[int(id)]["lado"])] as Team).resistencia[int(id)] = float(energias[id])

	var estado: Dictionary = c.get_estado()
	var minuto_final := int(float(estado["minuto"]))
	# Con muchos expulsados el motor suspende el partido: el mismo 3-0 que dan
	# los otros dos motores.
	var cancelado := bool(estado["suspendido"]) and MatchEngine.cancelar_si_falta_gente(home, away, minuto_final, log, eventos)
	if cancelado:
		goles_log = []
	var definicion := "alargue" if alargue else "90 minutos"
	var penales := {}
	if not tanda["tandas"].is_empty() and not cancelado:
		definicion = "penales"
		penales = {"ganador": home if tanda["goles"][0] > tanda["goles"][1] else away,
			"goles_local": tanda["goles"][0], "goles_visitante": tanda["goles"][1], "tandas": tanda["tandas"]}
	var cuenta: Dictionary = c.contadores()
	return {
		"goles_local": home.goles,
		"goles_visitante": away.goles,
		"log": log,
		"goles_log": goles_log,
		"cancelado": cancelado,
		"definicion": definicion,
		"penales": penales,
		"eventos": eventos,
		# El motor nuevo no deja fotogramas: la pantalla vuelve a jugar la
		# receta. Va en el lugar de los fotogramas (una lista con un solo
		# elemento) porque ese es el dato que la liga, las copas y GameState ya
		# llevan hasta la pantalla; `receta_de` la saca de ahí.
		"fotogramas": [{"receta_v2": receta}],
		"receta_v2": receta,
		# §7.3: el motor nuevo todavía no cuenta qué entrenó cada uno con lo que
		# hizo; reparte por puesto y minutos, como el motor abstracto.
		"xp": {"home": MatchEngine.xp_estimada(home), "away": MatchEngine.xp_estimada(away)},
		"stats": {
			"pasos": int(estado["paso"]),
			"posesion": [float(cuenta["posesion_0"]), float(cuenta["posesion_1"])],
			"tiros": [int(cuenta["remates_0"]), int(cuenta["remates_1"])],
			"faltas": int(cuenta["faltas_0"]) + int(cuenta["faltas_1"]),
			"offsides": int(cuenta["offsides_cobrados_0"]) + int(cuenta["offsides_cobrados_1"]),
			"penales": int(cuenta["penales"]),
			"pases": int(cuenta["pases"]) - int(cuenta["pases_despeje"]),
			"correcciones": int(cuenta["correcciones"]),
		},
	}


## Un evento con el formato de MotorEspacial y MatchEngine (lo leen
## RelatoPartido y EstadisticasPartido), más `paso`: el paso del motor en que
## pasó, para que la pantalla lo cuente a tiempo.
static func _evento(paso: int, minuto: float, tipo: String, equipo: Team, rival: Team, jugador: Dictionary,
		resultado: String) -> Dictionary:
	var ev := {"paso": paso, "minuto": int(minuto), "tipo": tipo, "equipo": equipo.nombre, "rival": rival.nombre,
		"jugador_posicion": str(jugador.get("posicion", "")), "resultado": resultado}
	if not jugador.is_empty():
		ev["jugador_id"] = int(jugador["id"])
		ev["clave"] = MotorEspacial.clave_de(int(jugador["id"]), equipo.local)
	return ev


static func _clave(id: int, lado: int) -> int:
	return MotorEspacial.clave_de(id, lado == 0)


static func _nombre(jugador: Dictionary) -> String:
	return "%s %s" % [jugador.get("nombre", "?"), jugador.get("apellido", "")] if not jugador.is_empty() else "en contra"


## Con qué gesto fue el gol: el del último remate de ese jugador antes del gol.
static func _tecnica_del_gol(remates: Array, id: int, paso: int) -> String:
	for k in range(remates.size() - 1, -1, -1):
		var r: Dictionary = remates[k]
		if int(r["paso"]) <= paso and int(r["pateador_id"]) == id:
			return "cabezazo" if int(r["golpe"]) == GOLPE_CABEZA else ""
	return ""


## Los remates que no fueron gol (el gol sale del evento "gol", que también
## cuenta los penales y los goles en contra).
static func _eventos_de_remates(remates: Array, equipos: Array, plantel: Dictionary, eventos: Array) -> void:
	for r in remates:
		var resultado: String = RESULTADOS_REMATE[clampi(int(r["resultado"]), 0, RESULTADOS_REMATE.size() - 1)]
		var id := int(r["pateador_id"])
		if resultado == "gol" or not plantel.has(id):
			continue
		var e := int(r["equipo"])
		var quien: Dictionary = plantel[id]["jugador"]
		var ev: Dictionary
		match resultado:
			"atajado":
				ev = _evento(int(r["paso"]), float(r["minuto"]), "tiro_puerta", equipos[e], equipos[1 - e], quien, "atajada")
			"palo", "bloqueado":
				ev = _evento(int(r["paso"]), float(r["minuto"]), "tiro", equipos[e], equipos[1 - e], quien, resultado)
			_:
				ev = _evento(int(r["paso"]), float(r["minuto"]), "tiro", equipos[e], equipos[1 - e], quien, "afuera")
		ev["tecnica"] = "cabezazo" if int(r["golpe"]) == GOLPE_CABEZA else ""
		ev["con_efecto"] = int(r["golpe"]) == GOLPE_EFECTO
		eventos.append(ev)


## Cada pase es un evento "pase": "avanza" si llega a un compañero, "pierde" si
## lo corta un rival (el relato lo cuenta) y "se_pierde" si no lo toca nadie.
static func _eventos_de_pases(pases: Array, equipos: Array, plantel: Dictionary, eventos: Array) -> void:
	for p in pases:
		if int(p["tipo"]) == TIPO_DESPEJE or not plantel.has(int(p["pateador_id"])):
			continue
		var e := int(p["equipo"])
		var pasador: Dictionary = plantel[int(p["pateador_id"])]["jugador"]
		var resultado := int(p["resultado"])
		# El minuto sale del paso: el pase no lleva el reloj.
		var ev: Dictionary
		if resultado == PASE_COMPLETO or resultado == PASE_OTRO:
			ev = _evento(int(p["paso"]), 0.0, "pase", equipos[e], equipos[1 - e], pasador, "avanza")
		elif resultado == PASE_CORTE and plantel.has(int(p["toca_id"])):
			var corta: Dictionary = plantel[int(p["toca_id"])]["jugador"]
			ev = _evento(int(p["paso_fin"]), 0.0, "pase", equipos[e], equipos[1 - e], {}, "pierde")
			ev["jugador_posicion"] = str(corta.get("posicion", ""))
			ev["clave"] = _clave(int(corta["id"]), 1 - e)
			ev["pasador_clave"] = _clave(int(pasador["id"]), e)
			ev["corte"] = true
		else:
			ev = _evento(int(p["paso"]), 0.0, "pase", equipos[e], equipos[1 - e], pasador, "se_pierde")
		eventos.append(ev)
