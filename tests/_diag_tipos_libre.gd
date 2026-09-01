extends SceneTree

## Como se clasifican las faltas a favor: directo (se remata), centro (se
## cuelga al area) o corto (se juega). El reporte: "nunca sube nadie a
## recibir un centro de una falta".

const SEED := 7373


func _init() -> void:
	var cuenta := {}
	var por_distancia := {}
	for i in range(400):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var arco := MotorEspacial.arco_rival(true)
		var hacia: float = -1.0 if arco.x > 0.0 else 1.0
		var dist: float = rng.randf_range(16.0, 60.0)
		var punto := Vector2(arco.x + hacia * dist,
			rng.randf_range(-28.0, 28.0))
		var f: Dictionary = MotorEspacial.pesos()["fisica"]
		var tipo := "corto"
		if MotorEspacial.factor_geometria(punto, true) >= float(f["geometria_minima_tiro_libre"]):
			tipo = "directo"
		elif punto.distance_to(arco) <= float(f["dist_libre_al_area"]):
			tipo = "centro"
		cuenta[tipo] = int(cuenta.get(tipo, 0)) + 1
		var banda := "%d-%d m" % [int(dist / 10) * 10, int(dist / 10) * 10 + 10]
		if not por_distancia.has(banda):
			por_distancia[banda] = {}
		por_distancia[banda][tipo] = int(por_distancia[banda].get(tipo, 0)) + 1

	print("De 400 faltas a favor entre 16 y 60 m del arco:")
	for t in ["directo", "centro", "corto"]:
		print("  %-8s %4d   %5.1f%%" % [t, int(cuenta.get(t, 0)), 100.0 * int(cuenta.get(t, 0)) / 400.0])
	print("\npor distancia:")
	var bandas := por_distancia.keys()
	bandas.sort()
	for b in bandas:
		var partes := []
		for t in ["directo", "centro", "corto"]:
			if por_distancia[b].has(t):
				partes.append("%s %d" % [t, int(por_distancia[b][t])])
		print("  %-10s %s" % [b, "  ".join(partes)])
	print("\ndist_libre_al_area = %.0f m" % float(MotorEspacial.pesos()["fisica"]["dist_libre_al_area"]))
	quit()
