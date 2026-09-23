extends SceneTree

## Medición, no test. Qué remate sale de un centro ganado en el área y a
## qué distancia de la pelota estaba el atacante. Un remate aéreo desde
## lejos obliga a que la pelota ruede por el piso hasta él.
const SEED := 9261
const PARTIDOS := 100


func _init() -> void:
	var goles := 0
	var remates := {}
	var distancias: Array = []
	var por_accion := {}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var partido_rng := RandomNumberGenerator.new()
		partido_rng.seed = SEED + 10000 + i
		var res := MotorEspacial.simular(casa, visita, partido_rng)
		goles += int(res["goles_local"]) + int(res["goles_visitante"])
		var centros: Dictionary = res["stats"].get("centros", {})
		for tipo in centros.get("por_tipo", {}):
			for accion in centros["por_tipo"][tipo]:
				remates[accion] = int(remates.get(accion, 0)) + int(centros["por_tipo"][tipo][accion])
		distancias.append_array(centros.get("distancia_remate", []))
		for accion in centros.get("remate_lejos", {}):
			por_accion[accion] = int(por_accion.get(accion, 0)) + int(centros["remate_lejos"][accion])
	distancias.sort()
	print("GOLES=%d (%.2f por partido)" % [goles, float(goles) / PARTIDOS])
	print("ACCIONES_CENTRO ", remates)
	if not distancias.is_empty():
		print("DIST_ATACANTE n=%d p50=%.2f p75=%.2f p90=%.2f max=%.2f" % [distancias.size(),
			distancias[distancias.size() / 2], distancias[distancias.size() * 3 / 4],
			distancias[distancias.size() * 9 / 10], distancias[-1]])
	print("REMATE_LEJOS ", por_accion)
	quit()
