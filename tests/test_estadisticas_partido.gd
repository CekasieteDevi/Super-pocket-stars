extends SceneTree

## Estadísticas post-partido (posesión/tiros/pases) calculadas a partir de
## los "eventos" que ya devuelve MatchEngine.simular() — sin tocar el motor.
## Correr con: godot --headless --script tests/test_estadisticas_partido.gd

const SEED := 8181


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_sin_eventos_da_50_50(rng)
	_test_cuenta_pases_tiros_y_posesion_correctamente(rng)
	_test_tarjetas_y_cambios_no_afectan_las_estadisticas(rng)
	_test_integracion_con_un_partido_real(rng)

	quit()


func _test_sin_eventos_da_50_50(rng: RandomNumberGenerator) -> void:
	print("=== Sin eventos (partido vacio), posesion 50/50 y todo lo demas en cero ===")
	var stats := EstadisticasPartido.calcular([], "Home", "Away")
	var ok: bool = is_equal_approx(stats["Home"]["posesion_pct"], 50.0) and is_equal_approx(stats["Away"]["posesion_pct"], 50.0)
	ok = ok and stats["Home"]["tiros"] == 0 and stats["Home"]["pases_intentados"] == 0
	if ok:
		print("OK: 50/50 y ceros.")
	else:
		print("FALLA: %s" % [stats])


func _test_cuenta_pases_tiros_y_posesion_correctamente(rng: RandomNumberGenerator) -> void:
	print("\n=== Cuenta pases/tiros/posesion a partir de una lista de eventos armada a mano ===")
	var eventos := [
		{"equipo": "Home", "tipo": "pase", "resultado": "avanza"},
		{"equipo": "Home", "tipo": "pase", "resultado": "avanza"},
		{"equipo": "Home", "tipo": "pase", "resultado": "pierde"},
		{"equipo": "Home", "tipo": "gambeta", "resultado": "tira"},
		{"equipo": "Home", "tipo": "tiro_puerta", "resultado": "gol"},
		{"equipo": "Away", "tipo": "pase", "resultado": "pierde"},
		{"equipo": "Away", "tipo": "tiro", "resultado": "afuera"},
		{"equipo": "Away", "tipo": "rebote", "resultado": "atajada"},
	]
	var stats := EstadisticasPartido.calcular(eventos, "Home", "Away")

	var ok := true
	ok = ok and stats["Home"]["pases_intentados"] == 3 and stats["Home"]["pases_completados"] == 2
	ok = ok and stats["Home"]["tiros"] == 1 and stats["Home"]["tiros_al_arco"] == 1
	ok = ok and stats["Away"]["pases_intentados"] == 1 and stats["Away"]["pases_completados"] == 0
	ok = ok and stats["Away"]["tiros"] == 2 and stats["Away"]["tiros_al_arco"] == 1  # "tiro" (afuera) no cuenta al arco, "rebote" si
	# acciones: Home tiene 5 (3 pase + 1 gambeta + 1 tiro_puerta), Away tiene 3 (1 pase + 1 tiro + 1 rebote) -> 5/8 = 62.5%
	ok = ok and is_equal_approx(stats["Home"]["posesion_pct"], 62.5)
	ok = ok and is_equal_approx(stats["Away"]["posesion_pct"], 37.5)

	if ok:
		print("OK: pases 3/2, tiros 1/1 para Home; pases 1/0, tiros 2/1 para Away; posesion 62.5/37.5.")
	else:
		print("FALLA: %s" % [stats])


func _test_tarjetas_y_cambios_no_afectan_las_estadisticas(rng: RandomNumberGenerator) -> void:
	print("\n=== Tarjetas y cambios no cuentan como accion ofensiva ni tocan la posesion ===")
	var eventos := [
		{"equipo": "Home", "tipo": "pase", "resultado": "avanza"},
		{"equipo": "Home", "tipo": "tarjeta", "resultado": "amarilla"},
		{"equipo": "Away", "tipo": "cambio", "resultado": "cansancio"},
	]
	var stats := EstadisticasPartido.calcular(eventos, "Home", "Away")
	if stats["Home"]["acciones"] == 1 and stats["Away"]["acciones"] == 0 and is_equal_approx(stats["Home"]["posesion_pct"], 100.0):
		print("OK: tarjeta/cambio ignorados, Home 100%% de posesion con su unico pase.")
	else:
		print("FALLA: %s" % [stats])


func _test_integracion_con_un_partido_real(rng: RandomNumberGenerator) -> void:
	print("\n=== Con un partido real de MatchEngine, la posesion suma 100 y hay al menos un tiro ===")
	var home := Team.generar("HomeReal", rng, 0)
	var away := Team.generar("AwayReal", rng, 100)
	var r := MatchEngine.simular(home, away, rng, false)
	var stats := EstadisticasPartido.calcular(r["eventos"], home.nombre, away.nombre)

	var suma_posesion: float = stats[home.nombre]["posesion_pct"] + stats[away.nombre]["posesion_pct"]
	var total_tiros: int = stats[home.nombre]["tiros"] + stats[away.nombre]["tiros"]
	if is_equal_approx(suma_posesion, 100.0) and total_tiros > 0:
		print("OK: posesion %.1f/%.1f (suma 100), %d tiros totales." % [stats[home.nombre]["posesion_pct"], stats[away.nombre]["posesion_pct"], total_tiros])
	else:
		print("FALLA: suma_posesion=%.1f total_tiros=%d" % [suma_posesion, total_tiros])

# Nota: no hay un test acá comparando posesión promedio entre estilos
# enfrentados (ej. Tiki taka vs Presión alta) — se probó, pero con
# equipos generados al azar la calidad de las líneas medias varía tanto
# entre sí (independientemente del estilo) que el efecto del choque de
# estilos en la posesión queda enterrado en el ruido incluso con
# cientos de muestras. Que el choque de estilos afecta el resultado
# real del partido ya está probado de forma mucho más directa y estable
# en tests/test_estilos.gd (comparación de goles). Este archivo se limita
# a probar que EstadisticasPartido cuenta bien lo que ya pasó.
