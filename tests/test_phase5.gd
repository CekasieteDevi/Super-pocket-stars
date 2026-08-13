extends SceneTree

## Fase 5 del roadmap (GDD §13, §7, §2.3, §3): progresión, entrenamiento,
## energía, lesiones, ánimo. Correr con:
## godot --headless --script tests/test_phase5.gd
##
## Qué verificamos:
##   1. Lesiones: ocurren a un ritmo creíble (ni cero ni una epidemia) y se
##      recuperan con los días.
##   2. Progresión: los jóvenes suben de media en promedio, los veteranos bajan.
##   3. Ánimo: se mueve con los resultados y no se sale de [0,100].
##   4. Energía: la fatiga acumulada se resiente con partidos seguidos.

const N_EQUIPOS := 20
const SEED := 555


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var nombres := []
	for i in range(N_EQUIPOS):
		nombres.append("Club %02d" % (i + 1))

	var liga := Liga.new()
	liga.inicializar(nombres, rng)

	_test_lesiones_y_energia(liga, rng)

	var nombres_ordenados := liga.tabla_ordenada()
	var mejor_nombre: String = nombres_ordenados[0]
	var peor_nombre: String = nombres_ordenados[nombres_ordenados.size() - 1]

	_test_progresion(liga, rng)
	_test_animo(liga, mejor_nombre, peor_nombre)

	quit()


func _test_lesiones_y_energia(liga: Liga, rng: RandomNumberGenerator) -> void:
	print("=== Lesiones y energia durante una temporada (380 partidos) ===")
	var jugador_seguido: Dictionary = liga.equipos[0].jugadores[3]  # un LAT cualquiera
	var equipo_seguido: Team = liga.equipos[0]
	var resistencia_minima_vista := 1.0

	var nuevas_lesiones := 0
	var recuperaciones := 0

	for idx in range(liga.fixture.size()):
		var lesionados_antes := {}
		for equipo in liga.equipos:
			for id in equipo.lesiones:
				lesionados_antes[str(equipo.nombre, "_", id)] = true

		liga.jugar_fecha(idx, rng)
		resistencia_minima_vista = min(resistencia_minima_vista, equipo_seguido.resistencia_pct(jugador_seguido["id"]))

		for equipo in liga.equipos:
			for id in equipo.lesiones:
				var clave = str(equipo.nombre, "_", id)
				if not lesionados_antes.has(clave):
					nuevas_lesiones += 1

		for equipo in liga.equipos:
			recuperaciones += equipo.avanzar_dias(7).size()

	var lesionados_al_final := 0
	for equipo in liga.equipos:
		lesionados_al_final += equipo.lesiones.size()

	print("Nuevas lesiones en la temporada (380 partidos, 20 equipos x 11 = 220 jugadores): %d" % nuevas_lesiones)
	print("Promedio de lesiones nuevas por jugador en la temporada: %.2f" % (float(nuevas_lesiones) / 220.0))
	print("Recuperaciones registradas en la temporada: %d" % recuperaciones)
	print("Jugadores todavia lesionados al terminar la temporada: %d" % lesionados_al_final)
	print("Menor resistencia vista en un jugador seguido durante un partido: %.2f" % resistencia_minima_vista)


## §7.1: 15-35 sigue creciendo (aunque despacito de 33 a 35), 36-37 es meseta,
## recien 38+ declina. "Joven"/"veterano" se clasifica por la edad DESPUES de
## envejecer un año (la que decide si ese jugador creció o declinó), y se
## compara jugador por jugador para no mezclar generaciones distintas.
func _test_progresion(liga: Liga, rng: RandomNumberGenerator) -> void:
	print("\n=== Progresion: antes/despues de nueva_temporada() ===")

	# Todos arrancaron con edad 18-35, asi que nadie entra en declive (38+)
	# en una sola temporada. Envejecemos 4 temporadas de mas (sin jugar
	# partidos, la progresion no depende del resultado) para que algunos
	# veteranos lleguen a la zona de declive y se pueda medir de verdad.
	for i in range(4):
		liga.nueva_temporada(rng)

	var snapshot := []  # [{media_antes, jugador}]
	for equipo in liga.equipos:
		for j in equipo.jugadores:
			snapshot.append({"media_antes": j["media"], "jugador": j})

	liga.nueva_temporada(rng)

	var deltas_jovenes := []
	var deltas_declive := []
	for entry in snapshot:
		var j: Dictionary = entry["jugador"]
		var delta: float = j["media"] - entry["media_antes"]
		if j["edad"] <= 35:
			deltas_jovenes.append(delta)
		elif j["edad"] >= 38:
			deltas_declive.append(delta)
		# 36-37: meseta, no se mide (esperable ~0 de cambio neto)

	var delta_prom_jovenes := _promedio(deltas_jovenes)
	var delta_prom_declive := _promedio(deltas_declive)
	print("Jugadores en crecimiento (edad final <=35): %d, delta de media promedio %+.2f" % [deltas_jovenes.size(), delta_prom_jovenes])
	print("Jugadores en declive (edad final >=38): %d, delta de media promedio %+.2f" % [deltas_declive.size(), delta_prom_declive])

	if delta_prom_jovenes > 0.0:
		print("OK: en crecimiento, la media promedio sube.")
	else:
		print("FALLA: se esperaba que subiera la media promedio en crecimiento.")
	if delta_prom_declive < 0.0:
		print("OK: en declive, la media promedio baja.")
	else:
		print("FALLA: se esperaba que bajara la media promedio en declive.")

	print("Fixture y tabla de la temporada nueva: %d fechas, %d equipos en tabla" % [liga.fixture.size(), liga.tabla.size()])


func _test_animo(liga: Liga, mejor_nombre: String, peor_nombre: String) -> void:
	print("\n=== Animo al cabo de la temporada (equipos segun la tabla ya jugada) ===")
	var mejor_equipo: Team = null
	var peor_equipo: Team = null
	for equipo in liga.equipos:
		if equipo.nombre == mejor_nombre:
			mejor_equipo = equipo
		if equipo.nombre == peor_nombre:
			peor_equipo = equipo

	print("Animo promedio del plantel de %s (1° de la tabla anterior): %.1f" % [mejor_equipo.nombre, _promedio_dict(mejor_equipo.animo)])
	print("Animo promedio del plantel de %s (ultimo de la tabla anterior): %.1f" % [peor_equipo.nombre, _promedio_dict(peor_equipo.animo)])

	var fuera_de_rango := 0
	for equipo in liga.equipos:
		for id in equipo.animo:
			var a: float = equipo.animo[id]
			if a < 0.0 or a > 100.0:
				fuera_de_rango += 1
	if fuera_de_rango == 0:
		print("OK: ningun animo se sale de [0, 100].")
	else:
		print("FALLA: %d valores de animo fuera de rango." % fuera_de_rango)


func _promedio(valores: Array) -> float:
	if valores.is_empty():
		return 0.0
	var total := 0.0
	for v in valores:
		total += v
	return total / valores.size()


func _promedio_dict(d: Dictionary) -> float:
	if d.is_empty():
		return 0.0
	var total := 0.0
	for k in d:
		total += d[k]
	return total / d.size()
