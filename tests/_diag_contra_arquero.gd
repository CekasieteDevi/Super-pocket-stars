extends SceneTree

## Medicion: que hace el arquero con la pelota cuando la recupera en
## juego y que sale de eso. No es un test: no falla nunca, mide.
##
## Viene de la jugada de Courtois: ataja, los extremos ya arrancaron y la
## tira larga al espacio por delante de Vinicius. El motor no dejaba al
## arquero tirar al hueco (ver _diag_arquero_regala.gd).
##
## Solo cuenta las posesiones del arquero que arrancan con cambio de
## posesion (atajada, centro descolgado), que son las que abren la ventana
## de transicion. El saque de arco frena el juego y no abre contra.
## Para cada una mira:
##  - que eligio el arquero
##  - si el equipo la pierde en su propio tercio antes de 10 s
##  - si el equipo remata o hace gol antes de 15 s / 20 s
##  - si le hacen un gol antes de 20 s
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_contra_arquero.gd -- partidos=3

const SEED := 77100
const REALISMO := preload("res://tests/_diag_realismo.gd")
const TERCIO_M := 35.0
const VENTANA_PERDIDA_TICKS := 40
const VENTANA_TIRO_TICKS := 60
const VENTANA_GOL_TICKS := 80

var partidos_por_celda := 3


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos_por_celda = maxi(1, int(partes[1]))
	var total := {}
	var partidos := 0
	var desde := Time.get_ticks_msec()
	for esc in REALISMO.ESCENARIOS:
		for par in REALISMO.ESTILOS:
			for i in range(partidos_por_celda):
				var res := _simular(esc, par, SEED + i * 13)
				var m := _medir(res["fotogramas"])
				m["goles"] = float(res["goles_local"]) + float(res["goles_visitante"])
				for k in m:
					total[k] = float(total.get(k, 0.0)) + float(m[k])
				partidos += 1
	print("## Contra del arquero - semilla %d, %d partidos, %.0f s" % [
		SEED, partidos, (Time.get_ticks_msec() - desde) / 1000.0])
	var claves: Array = total.keys()
	claves.sort()
	for k in claves:
		print("%-32s %9.3f" % [k, float(total[k]) / float(partidos)])
	var pos := maxf(float(total.get("posesiones", 0.0)), 1.0)
	print("")
	for k in ["perdida_en_tercio", "tiro_a_favor_15s", "gol_a_favor_20s", "gol_en_contra_20s"]:
		print("pct_%-28s %9.1f" % [k, 100.0 * float(total.get(k, 0.0)) / pos])
	quit()


func _simular(esc: Dictionary, estilos: Array, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(esc["a"]),
		"Uruguay", NivelDivision.realizacion(esc["a"]))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(esc["b"]),
		"Uruguay", NivelDivision.realizacion(esc["b"]))
	a.estilo = estilos[0]
	b.estilo = estilos[1]
	var rng_partido := RandomNumberGenerator.new()
	rng_partido.seed = semilla
	return MotorEspacial.simular(a, b, rng_partido, true)


func _medir(fotogramas: Array) -> Dictionary:
	var m := {"posesiones": 0.0, "perdida_en_tercio": 0.0, "tiro_a_favor_15s": 0.0,
		"gol_a_favor_20s": 0.0, "gol_en_contra_20s": 0.0}
	var n := fotogramas.size()
	var i := 0
	# Equipo del ultimo jugador de campo que tuvo la pelota: si es el rival,
	# la posesion del arquero arranca con un cambio de posesion.
	var ultimo_local = null
	while i < n:
		var f: Dictionary = fotogramas[i]
		var pid: int = int(f["pelota"]["poseedor_id"])
		var j := _jugador(f, pid)
		if j.is_empty():
			i += 1
			continue
		var local: bool = bool(j["equipo_local"])
		if str(j["rol"]) != "ARQ" or int(f.get("detenido", 0)) > 0:
			ultimo_local = local
			i += 1
			continue
		var recupera: bool = ultimo_local != null and bool(ultimo_local) != local
		var k := i
		var tipo := "?"
		while k < n and int(fotogramas[k]["pelota"]["poseedor_id"]) == pid:
			var d = fotogramas[k].get("decision", null)
			if d != null and str(d.get("jugador_rol", "")) == "ARQ":
				tipo = str(d["tipo"])
			k += 1
		# La decision queda en el fotograma del tick en que la suelta, que ya
		# no lo tiene como poseedor.
		if k < n:
			var d_suelta = fotogramas[k].get("decision", null)
			if d_suelta != null and str(d_suelta.get("jugador_rol", "")) == "ARQ":
				tipo = str(d_suelta["tipo"])
		ultimo_local = local
		if recupera:
			m["posesiones"] += 1.0
			_seguir(fotogramas, k, local, f, tipo, m)
		i = k
	return m


func _seguir(fotogramas: Array, k: int, local: bool, f0: Dictionary, tipo: String, m: Dictionary) -> void:
	var n := fotogramas.size()
	m["elige_" + tipo] = float(m.get("elige_" + tipo, 0.0)) + 1.0
	var perdida := false
	for t in range(k, mini(n, k + VENTANA_PERDIDA_TICKS)):
		var ft: Dictionary = fotogramas[t]
		var p2: int = int(ft["pelota"]["poseedor_id"])
		if p2 == -1 or int(ft.get("detenido", 0)) > 0:
			continue
		var j2 := _jugador(ft, p2)
		if j2.is_empty() or bool(j2["equipo_local"]) == local:
			continue
		var arco_x := -MotorEspacial.MEDIO_LARGO if local else MotorEspacial.MEDIO_LARGO
		if absf(float(ft["pelota"]["x"]) - arco_x) <= TERCIO_M:
			perdida = true
		break
	if perdida:
		m["perdida_en_tercio"] += 1.0
		m["perdida_tras_" + tipo] = float(m.get("perdida_tras_" + tipo, 0.0)) + 1.0
	# Remate propio: decision "tiro" tomada por un companero. El poseedor
	# que remata figura en el fotograma anterior al de la decision.
	for t in range(maxi(k, 1), mini(n, k + VENTANA_TIRO_TICKS)):
		var d = fotogramas[t].get("decision", null)
		if d == null or str(d.get("tipo", "")) != "tiro":
			continue
		var tirador := _jugador(fotogramas[t - 1], int(fotogramas[t - 1]["pelota"]["poseedor_id"]))
		if not tirador.is_empty() and bool(tirador["equipo_local"]) == local:
			m["tiro_a_favor_15s"] += 1.0
			m["tiro_tras_" + tipo] = float(m.get("tiro_tras_" + tipo, 0.0)) + 1.0
			break
	if n == 0 or k >= n:
		return
	var fin := mini(n - 1, k + VENTANA_GOL_TICKS)
	var propio := "home" if local else "away"
	var ajeno := "away" if local else "home"
	if int(fotogramas[fin]["goles"][propio]) > int(f0["goles"][propio]):
		m["gol_a_favor_20s"] += 1.0
		m["gol_tras_" + tipo] = float(m.get("gol_tras_" + tipo, 0.0)) + 1.0
	if int(fotogramas[fin]["goles"][ajeno]) > int(f0["goles"][ajeno]):
		m["gol_en_contra_20s"] += 1.0


func _jugador(f: Dictionary, clave: int) -> Dictionary:
	if clave == -1:
		return {}
	for j in f["jugadores"]:
		if int(j["id"]) == clave:
			return j
	return {}
