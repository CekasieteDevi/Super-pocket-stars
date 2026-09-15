extends SceneTree

## Medicion: cuantos goles salen de que el arquero la reparte corto en la
## puerta del area. No es un test: no falla nunca, mide.
##
## Viene de verlo jugando: el arquero ataja, se la da a un central, los
## delanteros cortan el pase y le pegan al arco. Una y otra vez.
##
## Recorre los fotogramas y arma cada POSESION DEL ARQUERO (desde que la
## tiene hasta que la suelta). Para cada una mira:
##  - que eligio el arquero (pase, pase_largo, despeje)
##  - si el equipo la pierde en su propio tercio antes de 10 s
##  - si le hacen un gol antes de 20 s
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_arquero_regala.gd -- partidos=6

const SEED := 77100
const REALISMO := preload("res://tests/_diag_realismo.gd")
const TERCIO_M := 35.0
const VENTANA_PERDIDA_TICKS := 40
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
	print("## Arquero regala - semilla %d, %d partidos, %.0f s" % [
		SEED, partidos, (Time.get_ticks_msec() - desde) / 1000.0])
	var claves: Array = total.keys()
	claves.sort()
	for k in claves:
		print("%-32s %9.3f" % [k, float(total[k]) / float(partidos)])
	var pos := maxf(float(total.get("posesiones", 0.0)) + float(total.get("saques_arco", 0.0)), 1.0)
	print("")
	print("pct_perdida_en_tercio           %9.1f" % (100.0 * float(total.get("perdida_en_tercio", 0.0)) / pos))
	print("pct_gol_en_contra_20s           %9.1f" % (100.0 * float(total.get("gol_en_contra_20s", 0.0)) / pos))
	print("pct_goles_regalados             %9.1f" % (100.0 * float(total.get("gol_tras_perdida", 0.0)) / maxf(float(total.get("goles", 0.0)), 1.0)))
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
	var m := {"posesiones": 0.0, "perdida_en_tercio": 0.0, "gol_en_contra_20s": 0.0, "gol_tras_perdida": 0.0}
	var n := fotogramas.size()
	var i := 0
	var arq_previo := -1
	while i < n:
		var f: Dictionary = fotogramas[i]
		# El saque de arco no deja al arquero como poseedor en ningun
		# fotograma: la toma y la juega en el mismo tick. Se sigue desde el
		# evento hasta que se reanuda.
		for ev in f.get("eventos", []):
			if str(ev.get("tipo", "")) == "saque_arco":
				var local_s: bool = str(ev["equipo"]) == "A"
				var r := i + 1
				while r < n and int(fotogramas[r].get("detenido", 0)) > 0:
					r += 1
				m["saques_arco"] = float(m.get("saques_arco", 0.0)) + 1.0
				_seguir(fotogramas, r + 1, local_s, int(f["goles"]["away" if local_s else "home"]), "saque", m)
		var pid: int = int(f["pelota"]["poseedor_id"])
		var j := _jugador(f, pid)
		if j.is_empty() or str(j["rol"]) != "ARQ" or pid == arq_previo:
			if pid != -1:
				arq_previo = pid if (not j.is_empty() and str(j["rol"]) == "ARQ") else -1
			i += 1
			continue
		arq_previo = pid
		var local: bool = bool(j["equipo_local"])
		var goles_antes: int = int(f["goles"]["away" if local else "home"])
		m["posesiones"] += 1.0
		# Avanzar hasta que la suelta y guardar que eligio.
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
		_seguir(fotogramas, k, local, goles_antes, tipo, m)
		i = k
	return m


## Desde que el arquero la suelta: si el equipo la pierde en su tercio y si
## le hacen un gol en la ventana.
func _seguir(fotogramas: Array, k: int, local: bool, goles_antes: int, tipo: String, m: Dictionary) -> void:
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
	if n == 0:
		return
	var fin := mini(n - 1, k + VENTANA_GOL_TICKS)
	if int(fotogramas[fin]["goles"]["away" if local else "home"]) > goles_antes:
		m["gol_en_contra_20s"] += 1.0
		m["gol_tras_" + tipo] = float(m.get("gol_tras_" + tipo, 0.0)) + 1.0
		if perdida:
			m["gol_tras_perdida"] += 1.0


func _jugador(f: Dictionary, clave: int) -> Dictionary:
	if clave == -1:
		return {}
	for j in f["jugadores"]:
		if int(j["id"]) == clave:
			return j
	return {}
