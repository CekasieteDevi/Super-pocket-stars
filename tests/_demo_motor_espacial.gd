extends SceneTree

## Demo/medición del MVP del motor espacial (docs/motor_espacial.md §7).
## No es un test de regresión: no imprime OK/FALLA, imprime números para
## decidir si el MVP sirve. Acá es donde se MIDE el presupuesto de
## rendimiento de §6, que hasta ahora era cálculo a mano.

const SEED := 20260816
const N_PARTIDOS := 20


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	print("=== MVP motor espacial — %d partidos ===" % N_PARTIDOS)
	print("TICK_SEG=%.2f  ticks/mitad=%d  ticks/partido=%d" % [
		MotorEspacial.TICK_SEG, MotorEspacial.TICKS_POR_MITAD, MotorEspacial.TICKS_POR_MITAD * 2])

	var total_goles := 0
	var total_ms := 0
	var total_tiros := 0
	var total_pases := 0
	var decisiones := {}
	var posesion_home := 0
	var posesion_total := 0
	var dists := []
	var robos_int := 0
	var robos_gan := 0
	var pase_det := {}
	var goles_partido := []
	var amarillas := 0
	var rojas := 0
	var cambios := 0
	var reinicios := {}

	for i in range(N_PARTIDOS):
		var home := Team.generar("Home%d" % i, rng)
		var away := Team.generar("Away%d" % i, rng)
		var t0 := Time.get_ticks_msec()
		var r := MotorEspacial.simular(home, away, rng, false)
		var ms := Time.get_ticks_msec() - t0
		total_ms += ms

		var gl: int = r["goles_local"]
		var gv: int = r["goles_visitante"]
		total_goles += gl + gv
		goles_partido.append(gl + gv)
		var s: Dictionary = r["stats"]
		total_tiros += int(s["tiros"]["home"]) + int(s["tiros"]["away"])
		total_pases += int(s["pases"]["home"]) + int(s["pases"]["away"])
		posesion_home += int(s["posesion"]["home"])
		posesion_total += int(s["posesion"]["home"]) + int(s["posesion"]["away"])
		for k in s["decisiones"]:
			decisiones[k] = decisiones.get(k, 0) + int(s["decisiones"][k])
		dists.append_array(s["dist_tiros"])
		for k in s["reinicios"]:
			reinicios[k] = float(reinicios.get(k, 0.0)) + float(s["reinicios"][k]) / N_PARTIDOS
		for ev in r["eventos"]:
			if ev["tipo"] == "tarjeta":
				if ev["resultado"] == "amarilla":
					amarillas += 1
				else:
					rojas += 1
			elif ev["tipo"] == "cambio":
				cambios += 1
		robos_int += int(s["robos"]["intentos"])
		robos_gan += int(s["robos"]["ganados"])
		for k in s["pase_detalle"]:
			pase_det[k] = pase_det.get(k, 0) + int(s["pase_detalle"][k])

		print("  %s %d-%d %s  (%d ms, %d eventos)" % [
			home.nombre, gl, gv, away.nombre, ms, r["eventos"].size()])

	print("\n--- Rendimiento ---")
	print("Promedio por partido: %.0f ms" % (float(total_ms) / N_PARTIDOS))
	print("Temporada de 38 fechas estimada: %.1f s" % (float(total_ms) / N_PARTIDOS * 38.0 / 1000.0))

	print("\n--- Balance ---")
	print("Goles por partido (los dos equipos): %.2f" % (float(total_goles) / N_PARTIDOS))
	goles_partido.sort()
	print("  mediana %d, minimo %d, maximo %d (objetivo real: ~2.8 de media)" % [
		goles_partido[goles_partido.size() / 2], goles_partido[0], goles_partido[-1]])
	print("Tiros por partido: %.1f" % (float(total_tiros) / N_PARTIDOS))
	print("Pases completados por partido: %.1f" % (float(total_pases) / N_PARTIDOS))
	if posesion_total > 0:
		print("Posesion local: %.1f%%" % (float(posesion_home) / posesion_total * 100.0))
	print("Tarjetas por partido: %.1f amarillas, %.2f rojas (real: ~3.5 y ~0.1). Cambios: %.1f" % [
		float(amarillas) / N_PARTIDOS, float(rojas) / N_PARTIDOS, float(cambios) / N_PARTIDOS])
	print("Pases: %s" % str(pase_det))
	print("Reinicios por partido: %s" % str(reinicios))
	print("Quites intentados por partido: %.1f (ganados %.1f, %.0f%%)" % [
		float(robos_int) / N_PARTIDOS, float(robos_gan) / N_PARTIDOS,
		float(robos_gan) / maxf(robos_int, 1) * 100.0])
	if not dists.is_empty():
		dists.sort()
		var suma := 0.0
		for d in dists:
			suma += d
		var cerca := 0
		for d in dists:
			if d < 12.0:
				cerca += 1
		print("Distancia de remate: media %.1fm, mediana %.1fm, %.0f%% desde menos de 12m" % [
			suma / dists.size(), dists[dists.size() / 2], float(cerca) / dists.size() * 100.0])

	print("\n--- Decisiones tomadas (utility + softmax) ---")
	var total_dec := 0
	for k in decisiones:
		total_dec += int(decisiones[k])
	for k in decisiones:
		print("  %s: %d (%.1f%%)" % [k, decisiones[k], float(decisiones[k]) / total_dec * 100.0])

	print("\n--- Costo de los fotogramas (1 partido con render) ---")
	var home2 := Team.generar("ConRender", rng)
	var away2 := Team.generar("ConRender2", rng)
	var t1 := Time.get_ticks_msec()
	var r2 := MotorEspacial.simular(home2, away2, rng, true)
	print("Con fotogramas: %d ms, %d fotogramas" % [Time.get_ticks_msec() - t1, r2["fotogramas"].size()])

	quit()
