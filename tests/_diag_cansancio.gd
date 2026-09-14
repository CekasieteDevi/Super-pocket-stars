extends SceneTree

## Medicion de la etapa 5 (docs/plan_realismo_simulacion.md): con que
## resistencia terminan los titulares, en los DOS motores, y cuanto
## depende de lo que corrio cada uno. No es un test: no falla, mide.
##
## Por partido y por motor:
## - resistencia final media de los once iniciales, por rol del slot;
## - dispersion entre los jugadores de campo;
## - cambios por cansancio;
## - correlacion entre metros recorridos y energia perdida (solo espacial:
##   el abstracto no tiene coordenadas).
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_cansancio.gd -- partidos=20

const SEED := 55100
const PARTIDOS := 12
const DIVISIONES := [0, 4, 9]
const ROLES := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]

var partidos := PARTIDOS


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos = maxi(1, int(partes[1]))
	print("## Cansancio por motor - semilla %d, %d partidos por division" % [SEED, partidos])
	print("%-4s %-9s %6s %6s %6s %6s  %s" % ["div", "motor", "media", "desvio", "cambios", "corr", "por rol"])
	var total := {"espacial": {}, "abstracto": {}}
	for d in DIVISIONES:
		for motor in ["espacial", "abstracto"]:
			var acum := {"media": 0.0, "desvio": 0.0, "cambios": 0.0, "corr": 0.0, "goles": 0.0,
				"carga": 0.0, "reserva_baja_pct": 0.0}
			var por_rol := {}
			var n_rol := {}
			for i in range(partidos):
				var m := _medir(d, motor, SEED + d * 1000 + i * 7)
				for k in acum:
					acum[k] += float(m[k]) / float(partidos)
				for r in m["por_rol"]:
					por_rol[r] = float(por_rol.get(r, 0.0)) + float(m["por_rol"][r])
					n_rol[r] = int(n_rol.get(r, 0)) + int(m["n_rol"][r])
			var texto := []
			for r in ROLES:
				if n_rol.has(r):
					texto.append("%s %.1f" % [r, 100.0 * float(por_rol[r]) / float(n_rol[r])])
			print("D%-3d %-9s %6.1f %6.2f %6.2f %6.2f  %s  goles %.2f  carga %.1f s  reserva<umbral %.1f%%" % [
				d + 1, motor, 100.0 * acum["media"], 100.0 * acum["desvio"], acum["cambios"],
				acum["corr"], "  ".join(texto), acum["goles"], acum["carga"], acum["reserva_baja_pct"]])
			for k in acum:
				total[motor][k] = float(total[motor].get(k, 0.0)) + acum[k] / float(DIVISIONES.size())
	for motor in total:
		print("todas %-9s media %.1f  desvio %.2f  cambios %.2f  corr %.2f  goles %.2f" % [
			motor, 100.0 * total[motor]["media"], 100.0 * total[motor]["desvio"],
			total[motor]["cambios"], total[motor]["corr"], total[motor]["goles"]])
	quit()


func _medir(division: int, motor: String, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(division),
		"Uruguay", NivelDivision.realizacion(division))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(division),
		"Uruguay", NivelDivision.realizacion(division))
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = semilla
	var res: Dictionary
	if motor == "espacial":
		res = MotorEspacial.simular(a, b, rng_p, true)
	else:
		res = MatchEngine.simular(a, b, rng_p)

	var cambios := 0
	for ev in res["eventos"]:
		if str(ev.get("tipo", "")) == "cambio" and str(ev.get("resultado", "")) == "cansancio":
			cambios += 1

	# Recorrido por clave, del ultimo fotograma donde aparece cada uno: el
	# que salio no esta en el ultimo del partido.
	var recorrido := {}
	if motor == "espacial":
		for fg in res["fotogramas"]:
			for jf in fg["jugadores"]:
				recorrido[int(jf["id"])] = float(jf.get("recorrido", 0.0))

	var valores := []
	var xs := []
	var ys := []
	var por_rol := {}
	var n_rol := {}
	for par in [[a, true], [b, false]]:
		var equipo: Team = par[0]
		var slots := Formaciones.slots(equipo.formacion)
		for i in range(equipo.jugadores.size()):
			var j: Dictionary = equipo.jugadores[i]
			var rol: String = str(slots[i]["rol"]) if i < slots.size() else str(j["posicion"])
			var r: float = equipo.resistencia_pct(int(j["id"]))
			por_rol[rol] = float(por_rol.get(rol, 0.0)) + r
			n_rol[rol] = int(n_rol.get(rol, 0)) + 1
			if rol == "ARQ":
				continue
			valores.append(r)
			var clave := MotorEspacial.clave_de(j["id"], par[1])
			if recorrido.has(clave):
				xs.append(float(recorrido[clave]))
				ys.append(float(equipo.fatiga_acumulada.get(int(j["id"]), 1.0)) - r)
	var media := 0.0
	for v in valores:
		media += float(v)
	media /= maxf(float(valores.size()), 1.0)
	var var_ := 0.0
	for v in valores:
		var_ += pow(float(v) - media, 2.0)
	var_ /= maxf(float(valores.size()), 1.0)
	var todos := 0.0
	var n := 0
	for r in por_rol:
		todos += float(por_rol[r])
		n += int(n_rol[r])
	# Etapa 5: carga media por jugador-partido (segundos equivalentes a
	# punta) y fraccion de ticks con la reserva por debajo del umbral. El
	# motor viejo y el abstracto no la publican: quedan en cero.
	var st_e: Dictionary = res.get("stats", {}).get("esfuerzo", {})
	var ticks_j: float = float(st_e.get("ticks_jugador", 0))
	# Once puestos por lado: el que entra completa la carga del que salio.
	var carga: float = float(st_e.get("carga", 0.0)) / 22.0
	return {
		"carga": carga,
		"reserva_baja_pct": 100.0 * float(st_e.get("ticks_reserva_baja", 0)) / maxf(ticks_j, 1.0),
		"media": todos / maxf(float(n), 1.0),
		"desvio": sqrt(var_),
		"cambios": cambios,
		"corr": _correlacion(xs, ys),
		"goles": float(res["goles_local"]) + float(res["goles_visitante"]),
		"por_rol": por_rol, "n_rol": n_rol,
	}


func _correlacion(xs: Array, ys: Array) -> float:
	if xs.size() < 3:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in range(xs.size()):
		mx += float(xs[i])
		my += float(ys[i])
	mx /= xs.size()
	my /= ys.size()
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(xs.size()):
		sxy += (float(xs[i]) - mx) * (float(ys[i]) - my)
		sxx += pow(float(xs[i]) - mx, 2.0)
		syy += pow(float(ys[i]) - my, 2.0)
	if sxx <= 0.0 or syy <= 0.0:
		return 0.0
	return sxy / sqrt(sxx * syy)
