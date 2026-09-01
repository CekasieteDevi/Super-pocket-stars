extends SceneTree

## Que hace un jugador que tiene la pelota EN SU PROPIA AREA con rivales
## encima. El reporte: "si agarran la pelota y hay rivales cerca, quiero
## que la revienten", y "siempre siempre" la regalan.

const SEED := 5252
const PARTIDOS := 40


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var elegidas := {}
	var casos := 0
	var presiones := []

	for i in range(PARTIDOS):
		var r := RandomNumberGenerator.new()
		r.seed = SEED + i
		var casa := Team.generar("Casa", r, 0)
		var visita := Team.generar("Visita", r, 400)
		casa.reset_partido()
		visita.reset_partido()
		casa.local = true
		visita.local = false
		casa.clima_partido = Clima.generar(r)
		visita.clima_partido = casa.clima_partido
		casa.arbitro_partido = Arbitro.generar(r)
		visita.arbitro_partido = casa.arbitro_partido
		var estado := MotorEspacial.crear_estado(casa, visita, r)
		MotorEspacial._reiniciar_desde_medio(estado, true, 1)

		for t in range(MotorEspacial.TICKS_POR_MITAD):
			# ANTES del tick: quien tiene la pelota y donde.
			var poseedor: int = int(estado["pelota"]["poseedor_id"])
			var mira := false
			var e := {}
			if poseedor != -1 and estado["jugadores"].has(poseedor):
				e = estado["jugadores"][poseedor]
				var arco_propio := MotorEspacial.arco_propio(bool(e["equipo_local"]))
				# En su propia area grande.
				mira = absf(arco_propio.x - e["pos"].x) <= 22.0 and absf(e["pos"].y) <= 22.0
			var presion_ahora := 0.0
			if mira:
				presion_ahora = MotorEspacial.presion_normalizada(
					estado, e["pos"], bool(e["equipo_local"]))
			var antes: Dictionary = estado["decisiones"].duplicate()
			MotorEspacial._tick(estado, false)
			if not mira:
				continue
			# Que decision se sumo en este tick.
			for tipo in estado["decisiones"]:
				if int(estado["decisiones"][tipo]) > int(antes.get(tipo, 0)):
					elegidas[tipo] = int(elegidas.get(tipo, 0)) + 1
					casos += 1
					presiones.append(presion_ahora)

	print("Con la pelota en su PROPIA AREA, %d decisiones:" % casos)
	var claves := elegidas.keys()
	claves.sort_custom(func(a, b): return int(elegidas[a]) > int(elegidas[b]))
	for tipo in claves:
		print("  %-12s %4d   %5.1f%%" % [
			tipo, int(elegidas[tipo]), 100.0 * int(elegidas[tipo]) / maxf(casos, 1)])
	var suma := 0.0
	for p in presiones:
		suma += float(p)
	print("\npresion media en esos casos: %.2f   (despeje pide %.2f)" % [
		suma / maxf(presiones.size(), 1),
		float(MotorEspacial.pesos()["fisica"]["presion_despeje"])])
	var altas := 0
	for p in presiones:
		if float(p) >= float(MotorEspacial.pesos()["fisica"]["presion_despeje"]):
			altas += 1
	print("casos que superan el umbral de presion: %d de %d (%.0f%%)" % [
		altas, presiones.size(), 100.0 * altas / maxf(presiones.size(), 1)])
	quit()
