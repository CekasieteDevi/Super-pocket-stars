extends SceneTree

## §7.4.1: ¿elegir la carga es una decision de verdad? Se corre la MISMA
## temporada con el mismo equipo en cada uno de los cinco escalones y se
## mira que gana y que pierde: puntos, lesiones y crecimiento.

const TEMPORADAS := 3
const DIVISION := 4


func _init() -> void:
	print("=== %d temporadas, mismo equipo, cinco cargas ===" % TEMPORADAS)
	print("carga         | puntos/temp | lesiones/temp | crecimiento de media")
	for nivel in CargaEntrenamiento.NIVELES:
		var r := _correr(nivel)
		print("%-13s | %11.1f | %13.1f | %+.2f" % [
			CargaEntrenamiento.ETIQUETAS[nivel], r["puntos"], r["lesiones"], r["media"]])
	quit()


func _correr(nivel: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[DIVISION]
	var yo: Team = liga.equipos[0]
	yo.carga_entrenamiento = nivel
	var inicial := yo.media_equipo()
	var puntos := 0.0
	var lesiones := 0.0

	for t in range(TEMPORADAS):
		for fecha in range(liga.fixture.size()):
			liga.jugar_fecha(fecha, rng, yo)
			# Semana apretada cada 4 fechas, como en GameState.
			if (fecha + 1) % 4 == 0:
				liga.avanzar_dias(3)
				liga.avanzar_dias(4)
			else:
				liga.avanzar_dias(7)
			lesiones += float(yo.lesiones.size())
		puntos += float(liga.tabla[yo.nombre]["pts"])
		for e in liga.equipos:
			for j in e.todos_los_jugadores():
				Progresion.aplicar_temporada(j, rng, 1.0,
					Instalaciones.factor_entrenamiento(e) * e.factor_carga_temporada())
			e.reiniciar_carga()
			e.recalcular_capitan()
		for nombre in liga.tabla:
			liga.tabla[nombre]["pts"] = 0
	return {
		"puntos": puntos / TEMPORADAS,
		"lesiones": lesiones / TEMPORADAS,
		"media": yo.media_equipo() - inicial,
	}
