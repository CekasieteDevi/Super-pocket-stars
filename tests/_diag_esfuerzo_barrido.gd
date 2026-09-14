extends SceneTree

## Barrido de los pesos de la etapa 5 (seccion `esfuerzo` de
## utility_pesos.json). No es un test: mide. Pisa la cache de
## MotorEspacial.pesos_esfuerzo con cada combinacion y juega los mismos
## partidos, asi que las columnas se comparan entre si.
##
## Mide la resistencia final media (con arqueros), la fraccion de ticks con
## la reserva por debajo del umbral, la carga por jugador y los goles.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_esfuerzo_barrido.gd -- partidos=3

const SEED := 55900
const DIVISIONES := [0, 4, 9]

## Cada fila pisa solo las claves que nombra; el resto queda del json.
## `multiplicador_desgaste` es de la seccion `fisica` y se pisa ahi.
const COMBINACIONES := [
	{"multiplicador_desgaste": 12.0, "desgaste_por_segundo": 0.0, "recuperacion_entretiempo": 0.0, "piso_sprint": 1.0},
	{"piso_sprint": 1.0},
	{},
]

var partidos := 3


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos = maxi(1, int(partes[1]))
	var base: Dictionary = MotorEspacial.pesos_esfuerzo().duplicate()
	var fisica: Dictionary = MotorEspacial.pesos()["fisica"]
	var multiplicador_json: float = float(fisica["multiplicador_desgaste"])
	print("## Barrido de esfuerzo - semilla %d, %d partidos por division" % [SEED, partidos])
	for combinacion in COMBINACIONES:
		var w: Dictionary = base.duplicate()
		# La seccion fisica es la cache compartida: se restituye en cada fila
		# para que una combinacion no herede el multiplicador de la anterior.
		fisica["multiplicador_desgaste"] = multiplicador_json
		for clave in combinacion:
			if clave == "multiplicador_desgaste":
				fisica[clave] = combinacion[clave]
			else:
				w[clave] = combinacion[clave]
		MotorEspacial._pesos_esfuerzo_cache = w
		var acum := {"resist": 0.0, "baja": 0.0, "carga": 0.0, "goles": 0.0, "tiros": 0.0, "faltas": 0.0, "robos": 0.0}
		var n := 0
		for d in DIVISIONES:
			for i in range(partidos):
				var m := _medir(d, SEED + d * 1000 + i * 7)
				for k in acum:
					acum[k] += float(m[k])
				n += 1
		print("%-70s resist %.1f  reserva<umbral %.1f%%  carga %.1f s  goles %.2f  tiros %.1f  faltas %.2f  robos %.1f" % [
			str(combinacion), 100.0 * acum["resist"] / n, 100.0 * acum["baja"] / n,
			acum["carga"] / n, acum["goles"] / n, acum["tiros"] / n, acum["faltas"] / n, acum["robos"] / n])
	quit()


func _medir(division: int, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(division),
		"Uruguay", NivelDivision.realizacion(division))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(division),
		"Uruguay", NivelDivision.realizacion(division))
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = semilla
	var res := MotorEspacial.simular(a, b, rng_p)
	var st: Dictionary = res["stats"]["esfuerzo"]
	var total := 0.0
	var cuenta := 0
	for equipo in [a, b]:
		for j in equipo.jugadores:
			total += equipo.resistencia_pct(int(j["id"]))
			cuenta += 1
	return {
		"resist": total / maxf(float(cuenta), 1.0),
		"baja": float(st["ticks_reserva_baja"]) / maxf(float(st["ticks_jugador"]), 1.0),
		"carga": float(st["carga"]) / 22.0,
		"goles": float(res["goles_local"]) + float(res["goles_visitante"]),
		"tiros": float(res["stats"]["tiros"]["home"]) + float(res["stats"]["tiros"]["away"]),
		"faltas": float(res["stats"]["faltas"]),
		"robos": float(res["stats"]["robos"]["intentos"]),
	}
