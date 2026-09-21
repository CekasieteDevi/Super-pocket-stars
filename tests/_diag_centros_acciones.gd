extends SceneTree

const PARTIDOS := 100
const SEMILLA := 9261

func _init() -> void:
	var total := {}
	var centros_totales := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEMILLA + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var partido_rng := RandomNumberGenerator.new()
		partido_rng.seed = SEMILLA + 10000 + i
		var resultado := MotorEspacial.simular(casa, visita, partido_rng)
		var centros: Dictionary = resultado["stats"].get("centros", {})
		centros_totales += int(centros.get("intentos", 0))
		for tipo in centros.get("por_tipo", {}):
			var fila: Dictionary = total.get(tipo, {})
			for accion in centros["por_tipo"][tipo]:
				fila[accion] = int(fila.get(accion, 0)) + int(centros["por_tipo"][tipo][accion])
			total[tipo] = fila

	print("PARTIDOS=%d" % PARTIDOS)
	print("CENTROS_TOTALES=%d (%.2f por partido)" % [centros_totales, float(centros_totales) / PARTIDOS])
	for tipo in [MotorEspacial.TIPO_CENTRO_ALTO, MotorEspacial.TIPO_CENTRO_MEDIO]:
		var fila: Dictionary = total.get(tipo, {})
		var cantidad := 0
		for accion in fila:
			cantidad += int(fila[accion]) if accion != "intentos" else 0
		print("%s=%d (%.2f por partido)" % [tipo.to_upper(), int(fila.get("intentos", 0)), float(fila.get("intentos", 0)) / PARTIDOS])
		for accion in fila:
			if accion == "intentos":
				continue
			print("  %-15s %4d (%.2f por partido; %.1f%% de %s)" % [
				action_label(accion), int(fila[accion]), float(fila[accion]) / PARTIDOS,
				100.0 * float(fila[accion]) / maxf(float(fila.get("intentos", 0)), 1.0), tipo])
	quit()

func action_label(accion: String) -> String:
	return accion
