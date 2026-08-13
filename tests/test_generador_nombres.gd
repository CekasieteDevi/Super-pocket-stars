extends SceneTree

## Fix 10: GeneradorNombres (clubes y jugadores) + integracion con
## Piramide.generar() y PlayerGenerator.generate(). Correr con:
## godot --headless --script tests/test_generador_nombres.gd

const SEED := 9090


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_nombre_club_sin_repetir(rng)
	_test_nombre_jugador_no_vacio(rng)
	_test_jugador_generado_tiene_nombre(rng)
	_test_piramide_200_clubes_nombres_unicos(rng)

	quit()


func _test_nombre_club_sin_repetir(rng: RandomNumberGenerator) -> void:
	print("=== GeneradorNombres.nombre_club: no repite dentro del mismo pool ===")
	var usados := {}
	var nombres := []
	for i in range(50):
		nombres.append(GeneradorNombres.nombre_club(rng, usados))

	var unicos := {}
	for n in nombres:
		unicos[n] = true

	if unicos.size() == nombres.size():
		print("OK: 50 nombres de club generados, todos distintos.")
	else:
		print("FALLA: se repitieron nombres de club.")


func _test_nombre_jugador_no_vacio(rng: RandomNumberGenerator) -> void:
	print("\n=== GeneradorNombres.nombre_jugador: nombre y apellido no vacios ===")
	var identidad := GeneradorNombres.nombre_jugador(rng)
	if identidad["nombre"] != "" and identidad["apellido"] != "":
		print("OK: %s %s" % [identidad["nombre"], identidad["apellido"]])
	else:
		print("FALLA: %s" % [identidad])


func _test_jugador_generado_tiene_nombre(rng: RandomNumberGenerator) -> void:
	print("\n=== PlayerGenerator.generate(): el jugador trae nombre/apellido ===")
	var jugador := PlayerGenerator.generate(0, rng)
	if jugador.has("nombre") and jugador.has("apellido") and jugador["nombre"] != "" and jugador["apellido"] != "":
		print("OK: %s %s (%s)" % [jugador["nombre"], jugador["apellido"], jugador["posicion"]])
	else:
		print("FALLA: %s" % [jugador])


func _test_piramide_200_clubes_nombres_unicos(rng: RandomNumberGenerator) -> void:
	print("\n=== Piramide.generar(): 200 clubes, todos con nombre distinto ===")
	var piramide := Piramide.generar(rng)

	var nombres := {}
	var total := 0
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			total += 1
			nombres[equipo.nombre] = nombres.get(equipo.nombre, 0) + 1

	var repetidos := []
	for n in nombres:
		if nombres[n] > 1:
			repetidos.append(n)

	if total == 200 and repetidos.is_empty():
		print("OK: 200 clubes, todos con nombre unico.")
	else:
		print("FALLA: total=%d repetidos=%s" % [total, repetidos])
