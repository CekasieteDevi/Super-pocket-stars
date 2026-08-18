extends SceneTree

## Cuenta las acciones fisicas que el motor expone por fotograma. Sirve
## para verificar que la animacion tiene con que trabajar: si patea sale
## ~0, la vista nunca va a mostrar un remate.

const SEMILLA := 20260818


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	var local := Team.generar("Atletico Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)

	var conteo := {}
	var claves := {}
	for f in r["fotogramas"]:
		for a in f.get("acciones", []):
			conteo[a["accion"]] = int(conteo.get(a["accion"], 0)) + 1
			claves[a["clave"]] = true
	print("fotogramas: %d" % r["fotogramas"].size())
	for k in conteo:
		print("  %s: %d" % [k, conteo[k]])
	print("  jugadores distintos con accion: %d" % claves.size())

	# Sin fotogramas no se paga nada: el array tiene que quedar vacio.
	rng.seed = SEMILLA
	var l2 := Team.generar("Atletico Prueba", rng)
	var v2 := Team.generar("Deportivo Banco", rng, 1000)
	var r2 := MotorEspacial.simular(l2, v2, rng, false)
	print("sin fotogramas -> %d-%d (mismo que %d-%d)" % [
		r2["goles_local"], r2["goles_visitante"], r["goles_local"], r["goles_visitante"]])
	quit()
