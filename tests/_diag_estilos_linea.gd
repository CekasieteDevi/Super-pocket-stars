extends SceneTree

## Donde se para cada estilo cuando NO tiene la pelota.
##
## Se mide la distancia media de los 10 de campo al arco PROPIO mientras
## el rival tiene la pelota. Presion alta tendria que dar el numero mas
## alto (linea adelantada) y Defensivo el mas bajo.

const SEED := 9090
const PARTIDOS := 8


func _init() -> void:
	print("estilo             | linea propia (m del arco) | recuperaciones en campo rival")
	for estilo in Estilos.LISTA:
		_medir(estilo)
	quit()


func _medir(estilo: String) -> void:
	var suma := 0.0
	var muestras := 0
	var robos_arriba := 0
	var robos := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		casa.estilo = estilo
		visita.estilo = "Contragolpe"
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

		var tenia_local := true
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			MotorEspacial._tick(estado, false)
			var poseedor: int = int(estado["pelota"]["poseedor_id"])
			if poseedor == -1 or not estado["jugadores"].has(poseedor):
				continue
			var local_tiene: bool = bool(estado["jugadores"][poseedor]["equipo_local"])
			# Recuperacion: la pelota cambio de manos hacia nosotros.
			if local_tiene and not tenia_local:
				robos += 1
				if estado["jugadores"][poseedor]["pos"].x > 0.0:
					robos_arriba += 1
			tenia_local = local_tiene
			if local_tiene:
				continue
			# El rival la tiene: donde esta parada nuestra gente.
			for id in estado["jugadores"]:
				var e: Dictionary = estado["jugadores"][id]
				if not e["equipo_local"] or str(e["rol"]) == "ARQ":
					continue
				suma += e["pos"].x + MotorEspacial.MEDIO_LARGO
				muestras += 1

	print("%-18s | %25.1f | %d de %d (%.0f%%)" % [
		estilo, suma / maxf(muestras, 1), robos_arriba, robos,
		100.0 * robos_arriba / maxf(robos, 1)])
