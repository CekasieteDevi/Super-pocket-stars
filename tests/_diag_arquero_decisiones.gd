extends SceneTree

## Medicion de la etapa 6 del plan de realismo: arqueros con decisiones.
## No es un test: no falla nunca, mide.
##
## Corre la misma grilla que tests/_diag_realismo.gd (divisiones, estilos,
## semillas) y cuenta lo que mueve el arquero: tiros al arco, atajadas,
## corners, centros descolgados, distancia a su linea y, si el motor los
## publica, las salidas y los rechazos. Los contadores nuevos se leen con
## get(): una copia del motor anterior a la etapa no los trae, y la misma
## corrida sirve para medir el "antes".
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_arquero_decisiones.gd -- partidos=12

const SEED := 77100
const REALISMO := preload("res://tests/_diag_realismo.gd")

var partidos_por_celda := 6


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos_por_celda = maxi(1, int(partes[1]))
	var total := {}
	var partidos := 0
	var rotos := 0
	var desde := Time.get_ticks_msec()
	for esc in REALISMO.ESCENARIOS:
		for par in REALISMO.ESTILOS:
			for i in range(partidos_por_celda):
				var semilla := SEED + i * 13
				var sin_fg := _simular(esc, par, semilla, false)
				var con_fg := _simular(esc, par, semilla, true)
				if int(sin_fg["goles_local"]) != int(con_fg["goles_local"]) \
						or int(sin_fg["goles_visitante"]) != int(con_fg["goles_visitante"]) \
						or int(sin_fg["stats"]["tiros"]["home"]) != int(con_fg["stats"]["tiros"]["home"]):
					rotos += 1
				var m := _metricas(sin_fg)
				m.merge(_metricas_de_fotogramas(con_fg["fotogramas"]))
				for k in m:
					total[k] = float(total.get(k, 0.0)) + float(m[k])
				partidos += 1
	print("## Arqueros - semilla %d, %d partidos (%d por celda), %.0f s" % [
		SEED, partidos, partidos_por_celda, (Time.get_ticks_msec() - desde) / 1000.0])
	var claves: Array = total.keys()
	claves.sort()
	for k in claves:
		print("%-28s %9.3f" % [k, float(total[k]) / float(partidos)])
	print("")
	print("conversion_al_arco          %9.3f" % (float(total.get("goles_juego", 0.0)) / maxf(float(total.get("tiros_al_arco", 0.0)), 1.0)))
	print("descolgados_por_centro      %9.3f" % (float(total.get("centros_descolgados", 0.0)) / maxf(float(total.get("centros_caidos", 0.0)), 1.0)))
	if total.has("arq_duelos"):
		print("cobertura_media_en_duelo    %9.3f" % (float(total["arq_cobertura_suma"]) / maxf(float(total["arq_duelos"]), 1.0)))
	print("fotogramas que no coinciden: %d" % rotos)
	quit()


func _simular(esc: Dictionary, estilos: Array, semilla: int, con_fotogramas: bool) -> Dictionary:
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
	return MotorEspacial.simular(a, b, rng_partido, con_fotogramas)


## Denominador: todo es por partido.
func _metricas(res: Dictionary) -> Dictionary:
	var st: Dictionary = res["stats"]
	var m := {
		"goles": float(res["goles_local"]) + float(res["goles_visitante"]),
		"tiros": float(st["tiros"]["home"]) + float(st["tiros"]["away"]),
		"corners": float(st["reinicios"].get("corner", 0)),
		"centros_caidos": float(st["centros"].get("caidos", 0)),
		"centros_descolgados": float(st["centros"].get("descolgado", 0)),
		"pases": float(st["pases"]["home"]) + float(st["pases"]["away"]),
	}
	var tiros_al_arco := 0.0
	var atajadas := 0.0
	var goles_juego := 0.0
	var saques_arco := 0.0
	for e in res["eventos"]:
		var tipo := str(e.get("tipo", ""))
		if tipo == "tiro_puerta":
			tiros_al_arco += 1.0
			if str(e.get("resultado", "")) == "gol":
				goles_juego += 1.0
			else:
				atajadas += 1.0
		elif tipo == "saque_arco":
			saques_arco += 1.0
	m["tiros_al_arco"] = tiros_al_arco
	m["atajadas"] = atajadas
	m["goles_juego"] = goles_juego
	m["saques_arco"] = saques_arco
	# Contadores de la etapa 6. Ausentes en el motor anterior.
	var arq: Dictionary = st.get("arqueros", {})
	for k in arq:
		m["arq_" + str(k)] = float(arq[k])
	return m


## Distancia del arquero a su linea, fotograma por fotograma, y cuanto del
## partido pasa lejos. Es lo que vigila tests/test_posicion_del_arquero.gd.
func _metricas_de_fotogramas(fotogramas: Array) -> Dictionary:
	var suma := 0.0
	var muestras := 0
	var lejos := 0
	for f in fotogramas:
		for j in f["jugadores"]:
			if str(j["rol"]) != "ARQ":
				continue
			var linea: float = -MotorEspacial.MEDIO_LARGO if bool(j["equipo_local"]) else MotorEspacial.MEDIO_LARGO
			var d: float = absf(float(j["x"]) - linea)
			suma += d
			muestras += 1
			if d > 10.0:
				lejos += 1
	return {
		"arq_dist_linea_m": suma / maxf(float(muestras), 1.0),
		"arq_pct_lejos": 100.0 * float(lejos) / maxf(float(muestras), 1.0),
	}
