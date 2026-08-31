extends SceneTree

## Cuanto camina cada uno para acomodarse en un tiro libre, y cuanto le
## falta cuando llega el momento del saque.

const SEED := 7710


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, true, 1)

	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	var pos := Vector2(arco.x + hacia * 24.0, 3.0)
	MotorEspacial._tiro_libre(estado, pos, true, 24)

	print("defensores (los que tienen que armar la barrera y marcar):")
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] or str(e["rol"]) == "ARQ":
			continue
		print("  %-4s puesto_barrera=%2d | de su marca a %.1f m" % [
			str(e["rol"]), int(e.get("puesto_barrera", -1)),
			float(e["pos"].distance_to(e.get("marca", e["pos"])))])

	var ticks: int = MotorEspacial.TICKS_CONGELADO_FALTA \
		+ int(MotorEspacial.TICKS_DETENIDO["falta"]) - 1
	for t in range(ticks):
		MotorEspacial._tick(estado, false)
	print("\ndespues de %d ticks (%.1f s):" % [ticks, ticks * MotorEspacial.TICK_SEG])
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] or str(e["rol"]) == "ARQ":
			continue
		print("  %-4s puesto_barrera=%2d | le falta %.1f m" % [
			str(e["rol"]), int(e.get("puesto_barrera", -1)),
			float(e["pos"].distance_to(e.get("marca", e["pos"])))])
	quit()
