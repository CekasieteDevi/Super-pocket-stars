extends SceneTree

## Cuanto tarda y como cierra un cruce a eliminacion directa jugado entero
## con el motor espacial: cuantos van a alargue, cuantos a penales, y
## cuantos fotogramas cuesta cada instancia.

const SEED := 4242
const CRUCES := 60


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var noventa := 0
	var alargue := 0
	var penales := 0
	var fot_90 := 0
	var fot_extra := 0
	var pateados := 0
	var convertidos := 0
	var arranque := Time.get_ticks_msec()

	for i in range(CRUCES):
		var casa := Team.generar("Casa %d" % i, rng, i * 100)
		var visita := Team.generar("Visita %d" % i, rng, 50000 + i * 100)
		Alineacion.arreglar(casa)
		Alineacion.arreglar(visita)
		var r := MotorEspacial.simular(casa, visita, rng, true, true)
		var d := str(r["definicion"])
		match d:
			"90 minutos": noventa += 1
			"alargue": alargue += 1
			"penales": penales += 1
		if d == "90 minutos":
			fot_90 += r["fotogramas"].size()
		else:
			fot_extra += r["fotogramas"].size()
		var pen: Dictionary = r.get("penales", {})
		if not pen.is_empty():
			for t in pen["tandas"]:
				pateados += 1
				if bool(t["gol"]):
					convertidos += 1

	print("cruces=%d  90'=%d  alargue=%d  penales=%d" % [CRUCES, noventa, alargue, penales])
	if noventa > 0:
		print("fotogramas promedio 90' = %.0f" % (float(fot_90) / noventa))
	if noventa < CRUCES:
		print("fotogramas promedio con alargue/penales = %.0f" % (float(fot_extra) / (CRUCES - noventa)))
	if pateados > 0:
		print("penales de tanda: %d pateados, %.1f%% convertidos" % [
			pateados, 100.0 * convertidos / pateados])
	print("tiempo total = %.1f s" % ((Time.get_ticks_msec() - arranque) / 1000.0))
	quit()
