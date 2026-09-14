extends SceneTree

## Linea de base del realismo del MotorEspacial (docs/plan_realismo_simulacion.md,
## etapa 0). No es un test: no falla nunca, mide. Imprime una tabla por
## escenario y escribe el detalle partido por partido a CSV y JSON, para
## poder comparar contra la misma corrida despues de cada etapa.
##
## Corre cada partido dos veces con la MISMA semilla: sin fotogramas y con
## fotogramas. Los dos tienen que dar el mismo marcador (invariante 2 del
## plan) y el costo por partido se informa separado.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_realismo.gd
##   ... --script tests/_diag_realismo.gd -- partidos=8 salida=user://base_etapa0

const SEED := 77100
const PARTIDOS := 6

## Division de A, division de B, etiqueta. Indice 0 = primera. B mas abajo
## = A favorito. El plan pide divisiones 1, 5 y 10, parejos y desparejos,
## y la desigualdad para los dos lados.
const ESCENARIOS := [
	{"a": 0, "b": 0, "etiqueta": "D1 parejo"},
	{"a": 0, "b": 3, "etiqueta": "D1 favorito"},
	{"a": 3, "b": 0, "etiqueta": "D1 tapado"},
	{"a": 4, "b": 4, "etiqueta": "D5 parejo"},
	{"a": 4, "b": 7, "etiqueta": "D5 favorito"},
	{"a": 9, "b": 9, "etiqueta": "D10 parejo"},
	{"a": 9, "b": 6, "etiqueta": "D10 tapado"},
]

## Estilos enfrentados, para que la base cubra planes distintos y no solo
## el que salga por azar de Team.generar.
const ESTILOS := [
	["Tiki taka", "Juego directo"],
	["Presion alta", "Contragolpe"],
]

var partidos_por_celda := PARTIDOS
var ruta_salida := "user://diag_realismo"


func _init() -> void:
	_leer_argumentos()
	var filas: Array = []
	print("## Linea de base de realismo - semilla %d, %d partidos por celda" % [
		SEED, partidos_por_celda])
	print("## revision: %s" % _revision())
	print("")
	print("%-14s %-24s %5s %5s %6s %6s %6s %5s %5s %6s %6s %6s %5s %5s %5s %6s %6s %6s" % [
		"escenario", "estilos", "goles", "tiros", "pos%", "contr%", "parad%",
		"pases", "perd", "posdur", "altas", "lineas", "falt", "amar", "roja",
		"resist", "ms", "msfg"])
	for esc in ESCENARIOS:
		for par in ESTILOS:
			var celda := _correr_celda(esc, par, filas)
			print("%-14s %-24s %5.2f %5.1f %6.1f %6.1f %6.1f %5.1f %5.1f %6.2f %6.2f %6.1f %5.1f %5.2f %5.2f %6.1f %6.0f %6.0f" % [
				esc["etiqueta"], "%s/%s" % [par[0], par[1]],
				celda["goles"], celda["tiros"], celda["posesion_pct"],
				celda["controlada_pct"], celda["pelota_parada_pct"],
				celda["pases"], celda["perdidas"],
				celda["duracion_posesion_seg"], celda["recuperaciones_altas"],
				celda["separacion_lineas_m"],
				celda["faltas"], celda["amarillas"], celda["rojas"],
				celda["resistencia_final_pct"], celda["ms_sin_fotogramas"],
				celda["ms_con_fotogramas"]])
	_resumir_invariante(filas)
	_escribir(filas)
	quit()


func _leer_argumentos() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() != 2:
			continue
		match partes[0]:
			"partidos": partidos_por_celda = maxi(1, int(partes[1]))
			"salida": ruta_salida = partes[1]


## El codigo contra el que se midio. Sin esto un informe viejo no se puede
## atar a un estado del repositorio y deja de servir para comparar.
func _revision() -> String:
	var salida: Array = []
	var codigo := OS.execute("git", ["rev-parse", "--short", "HEAD"], salida, true)
	if codigo != 0 or salida.is_empty():
		return "desconocida"
	return String(salida[0]).strip_edges()


func _correr_celda(esc: Dictionary, estilos: Array, filas: Array) -> Dictionary:
	var acumulado := {}
	for i in range(partidos_por_celda):
		var fila := _medir_partido(esc, estilos, i)
		filas.append(fila)
		for clave in fila:
			if typeof(fila[clave]) == TYPE_FLOAT or typeof(fila[clave]) == TYPE_INT:
				acumulado[clave] = float(acumulado.get(clave, 0.0)) + float(fila[clave])
	var celda := {}
	for clave in acumulado:
		celda[clave] = acumulado[clave] / float(partidos_por_celda)
	return celda


## Un partido medido dos veces con la misma semilla. La simulacion muta el
## Team, asi que cada corrida arma un plantel nuevo desde cero.
func _medir_partido(esc: Dictionary, estilos: Array, indice: int) -> Dictionary:
	var semilla := SEED + indice * 13

	var sin_fg := _simular(esc, estilos, semilla, false)
	var con_fg := _simular(esc, estilos, semilla, true)

	var fila := {
		"escenario": esc["etiqueta"],
		"division_a": esc["a"] + 1,
		"division_b": esc["b"] + 1,
		"estilo_a": estilos[0],
		"estilo_b": estilos[1],
		"semilla": semilla,
		"coincide_con_fotogramas": _coinciden(sin_fg["res"], con_fg["res"]),
	}
	fila.merge(_metricas_de_stats(sin_fg))
	fila.merge(_metricas_de_fotogramas(con_fg["res"]["fotogramas"]))
	fila["ms_sin_fotogramas"] = sin_fg["ms"]
	fila["ms_con_fotogramas"] = con_fg["ms"]
	return fila


func _simular(esc: Dictionary, estilos: Array, semilla: int, con_fotogramas: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(esc["a"]),
		"Uruguay", NivelDivision.realizacion(esc["a"]))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(esc["b"]),
		"Uruguay", NivelDivision.realizacion(esc["b"]))
	# El estilo se fija DESPUES de generar: Team.generar lo sortea y de ahi
	# sale la formacion, asi que pisarlo antes no cambiaria el plantel.
	a.estilo = estilos[0]
	b.estilo = estilos[1]
	var rng_partido := RandomNumberGenerator.new()
	rng_partido.seed = semilla
	var desde := Time.get_ticks_usec()
	var res := MotorEspacial.simular(a, b, rng_partido, con_fotogramas)
	var ms := float(Time.get_ticks_usec() - desde) / 1000.0
	return {"res": res, "ms": ms, "a": a, "b": b}


## Invariante 2 del plan: el render no decide ni consume azar.
func _coinciden(uno: Dictionary, otro: Dictionary) -> bool:
	return int(uno["goles_local"]) == int(otro["goles_local"]) \
		and int(uno["goles_visitante"]) == int(otro["goles_visitante"]) \
		and int(uno["stats"]["tiros"]["home"]) == int(otro["stats"]["tiros"]["home"]) \
		and int(uno["stats"]["tiros"]["away"]) == int(otro["stats"]["tiros"]["away"])


func _resumir_invariante(filas: Array) -> void:
	var rotas: Array = []
	for fila in filas:
		if not bool(fila["coincide_con_fotogramas"]):
			rotas.append("%s %s/%s semilla=%d" % [
				fila["escenario"], fila["estilo_a"], fila["estilo_b"], int(fila["semilla"])])
	print("")
	if rotas.is_empty():
		print("Fotogramas: los %d partidos dan el mismo resultado con y sin render." % filas.size())
	else:
		print("Fotogramas: %d de %d partidos NO coinciden con y sin render:" % [
			rotas.size(), filas.size()])
		for r in rotas:
			print("  - %s" % r)


## Lo que el motor ya publica en stats, mas el estado final del Team.
## Denominador: todo es POR PARTIDO salvo donde el nombre dice pct.
func _metricas_de_stats(corrida: Dictionary) -> Dictionary:
	var res: Dictionary = corrida["res"]
	var st: Dictionary = res["stats"]
	var a: Team = corrida["a"]
	var b: Team = corrida["b"]
	var pos: Dictionary = st["posesion"]
	var pos_total := maxf(float(pos["home"]) + float(pos["away"]), 1.0)
	var robos: Dictionary = st["robos"]
	var pd: Dictionary = st["pase_detalle"]
	# Etapa 3: los fotogramas viejos y el motor antes de la etapa no traen
	# `control`, asi que todo se lee con get() y da cero.
	var ctl: Dictionary = st.get("control", {})
	var recepciones := float(ctl.get("recepciones", 0))
	var limpias := recepciones - float(ctl.get("toques_largos", 0))
	return {
		# Recepciones de pase controladas por un jugador de campo, y cuantas
		# terminaron en toque largo. Por partido.
		"recepciones": recepciones,
		"toques_largos": float(ctl.get("toques_largos", 0)),
		# Dificultad media por recepcion (0 a 1).
		"dificultad_media": float(ctl.get("dificultad", 0.0)) / maxf(recepciones, 1.0),
		# Demora de control media sobre la cadencia vieja, en los controles
		# limpios. 1 = la primera decision sale cuando salia antes.
		"demora_sobre_cadencia": float(ctl.get("demora", 0)) / maxf(float(ctl.get("cadencia", 0)), 1.0),
		"demora_media_ticks": float(ctl.get("demora", 0)) / maxf(limpias, 1.0),
		"goles": float(res["goles_local"]) + float(res["goles_visitante"]),
		"goles_local": float(res["goles_local"]),
		"goles_visitante": float(res["goles_visitante"]),
		"tiros": float(st["tiros"]["home"]) + float(st["tiros"]["away"]),
		# Posesion del LOCAL sobre los ticks con dueño. No incluye la
		# pelota libre: esa se mide aparte, en controlada_pct.
		"posesion_pct": 100.0 * float(pos["home"]) / pos_total,
		"pases": float(st["pases"]["home"]) + float(st["pases"]["away"]),
		# Pelota perdida: robos que gano el rival mas pases que no
		# llegaron. Es el conteo de cuantas veces se corto una posesion
		# por error propio o merito ajeno.
		"perdidas": float(robos["ganados"]) + float(pd["interceptado_vuelo"])
			+ float(pd["rival_llego_antes"]) + float(pd["fuera"]),
		"pases_intentados": float(pd["intentos"]),
		"faltas": float(st["faltas"]),
		"penales": float(st["penales"]),
		"offsides": float(st["offsides"]),
		"amarillas": float(_contar(a.amarillas_partido)) + float(_contar(b.amarillas_partido)),
		"rojas": float(a.expulsados_partido.size()) + float(b.expulsados_partido.size()),
		"ticks": float(st["ticks"]),
		# Energia promedio con la que terminaron los once que empezaron. Es
		# el sintoma de cansancio que existe hoy; la etapa 5 lo reemplaza
		# por esfuerzo real.
		"resistencia_final_pct": 100.0 * 0.5 * (_resistencia_media(a) + _resistencia_media(b)),
		"mitades_cortadas": float(st["cortadas"].size()),
	}


func _contar(cuentas: Dictionary) -> int:
	var total := 0
	for id in cuentas:
		total += int(cuentas[id])
	return total


func _resistencia_media(equipo: Team) -> float:
	var total := 0.0
	for j in equipo.jugadores:
		total += equipo.resistencia_pct(int(j["id"]))
	return total / maxf(float(equipo.jugadores.size()), 1.0)


## Lo que solo se ve tick a tick: cuanto tiempo la pelota tiene dueño,
## cuanto dura cada posesion, cuantas recuperaciones son altas y cuanto
## del partido es pelota parada.
func _metricas_de_fotogramas(fotogramas: Array) -> Dictionary:
	var abiertos := 0
	var parados := 0
	var con_dueno := 0
	var posesiones := 0
	var ticks_con_dueno := 0
	var recuperaciones_altas := 0
	var recorrido_total := 0.0
	# Separacion entre lineas del equipo que NO tiene la pelota: cuanto hay
	# entre el centro de su linea de atras y el de su linea de arriba. Es
	# lo que mide si el bloque se estira (etapa 2).
	var separacion_suma := 0.0
	var separacion_muestras := 0
	var poseedor_previo := -1
	var equipo_previo := 0  # 0 = nadie todavia, 1 = local, -1 = visitante
	for fg in fotogramas:
		if int(fg.get("detenido", 0)) > 0:
			parados += 1
			continue
		abiertos += 1
		var poseedor: int = int(fg["pelota"]["poseedor_id"])
		if poseedor == -1:
			poseedor_previo = -1
			continue
		var equipo := 0
		for j in fg["jugadores"]:
			if int(j["id"]) == poseedor:
				equipo = 1 if bool(j["equipo_local"]) else -1
				break
		if equipo == 0:
			continue
		con_dueno += 1
		ticks_con_dueno += 1
		var sep := _separacion_de_lineas(fg, equipo == 1)
		if sep >= 0.0:
			separacion_suma += sep
			separacion_muestras += 1
		if poseedor != poseedor_previo:
			if equipo != equipo_previo:
				# Cambio de dueño: arranca una posesion nueva.
				posesiones += 1
				# Recuperacion alta: se recupera en campo rival. x > 0 es
				# la mitad del visitante (el arco que ataca el local).
				var x: float = float(fg["pelota"]["x"])
				if (equipo == 1 and x > 0.0) or (equipo == -1 and x < 0.0):
					recuperaciones_altas += 1
				equipo_previo = equipo
			poseedor_previo = poseedor
	# El recorrido ya lo acumula el motor por jugador; el ultimo fotograma
	# trae el total del partido.
	if not fotogramas.is_empty():
		for j in fotogramas[-1]["jugadores"]:
			recorrido_total += float(j.get("recorrido", 0.0))
	var totales := maxf(float(abiertos + parados), 1.0)
	return {
		"fotogramas": float(fotogramas.size()),
		# Del juego abierto, que fraccion tiene la pelota controlada por
		# alguien. El resto es pelota libre: en vuelo o disputada.
		"controlada_pct": 100.0 * float(con_dueno) / maxf(float(abiertos), 1.0),
		"pelota_parada_pct": 100.0 * float(parados) / totales,
		"posesiones": float(posesiones),
		# Segundos reales de simulacion, no minutos mostrados.
		"duracion_posesion_seg": float(ticks_con_dueno) * MotorEspacial.TICK_SEG
			/ maxf(float(posesiones), 1.0),
		"recuperaciones_altas": float(recuperaciones_altas),
		"separacion_lineas_m": separacion_suma / maxf(float(separacion_muestras), 1.0),
		"recorrido_total_m": recorrido_total,
	}


## Cuanto mide el bloque del equipo que defiende: distancia en x entre la
## media de su linea de atras (DFC, LAT) y la de arriba (EXT, DC). -1 si
## al fotograma le falta alguna de las dos lineas.
func _separacion_de_lineas(fg: Dictionary, ataca_local: bool) -> float:
	var atras := 0.0
	var n_atras := 0
	var arriba := 0.0
	var n_arriba := 0
	for j in fg["jugadores"]:
		if bool(j["equipo_local"]) == ataca_local:
			continue
		var rol: String = str(j["rol"])
		if rol == "DFC" or rol == "LAT":
			atras += float(j["x"])
			n_atras += 1
		elif rol == "EXT" or rol == "DC":
			arriba += float(j["x"])
			n_arriba += 1
	if n_atras == 0 or n_arriba == 0:
		return -1.0
	return absf(arriba / float(n_arriba) - atras / float(n_atras))


func _escribir(filas: Array) -> void:
	if filas.is_empty():
		return
	var columnas: Array = filas[0].keys()
	var csv := FileAccess.open(ruta_salida + ".csv", FileAccess.WRITE)
	if csv != null:
		csv.store_line(",".join(columnas))
		for fila in filas:
			var celdas: Array = []
			for c in columnas:
				celdas.append(str(fila[c]))
			csv.store_line(",".join(celdas))
		csv.close()
	var json := FileAccess.open(ruta_salida + ".json", FileAccess.WRITE)
	if json != null:
		json.store_string(JSON.stringify({
			"semilla": SEED,
			"partidos_por_celda": partidos_por_celda,
			"revision": _revision(),
			"tick_seg": MotorEspacial.TICK_SEG,
			"ticks_por_mitad": MotorEspacial.TICKS_POR_MITAD,
			"escenarios": ESCENARIOS,
			"estilos": ESTILOS,
			"filas": filas,
		}, "  "))
		json.close()
	print("")
	print("Escrito: %s y %s" % [
		ProjectSettings.globalize_path(ruta_salida + ".csv"),
		ProjectSettings.globalize_path(ruta_salida + ".json")])
