extends SceneTree

## Fase 7 (copas domésticas) — GDD §10: "copa interna de división + copa
## nacional entre todas las divisiones, partido único".
## Correr con: godot --headless --script tests/test_phase7_copas.gd
##
## Qué verificamos:
##   1. Copa Nacional (128 clasificados): termina en un campeón real, en la
##      cantidad de rondas esperada (128 -> 64 -> ... -> 1 = 7 rondas).
##   2. Copas de División (16 clasificados cada una): las 10 terminan en
##      campeón, en 4 rondas cada una (16 -> 8 -> 4 -> 2 -> 1).
##   3. Ninguna ronda repite un mismo equipo en dos partidos a la vez.

const SEED := 4242


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var piramide := Piramide.generar(rng)

	var t0 := Time.get_ticks_msec()
	var copa_nacional := Copas.jugar_copa_nacional(piramide, rng)
	var t1 := Time.get_ticks_msec()
	_test_copa_nacional(copa_nacional, piramide, t1 - t0)

	var t2 := Time.get_ticks_msec()
	var copas_division := Copas.jugar_copas_de_division(piramide, rng)
	var t3 := Time.get_ticks_msec()
	_test_copas_de_division(copas_division, piramide, t3 - t2)

	quit()


func _test_copa_nacional(copa: Copa, piramide: Piramide, ms: int) -> void:
	print("=== Copa Nacional (128 clasificados) ===")
	print("Tiempo: %d ms" % ms)
	print("Rondas jugadas: %d (esperado 7)" % copa.historial.size())
	print("Campeon: %s" % (copa.campeon.nombre if copa.campeon else "NINGUNO"))

	var ok := copa.campeon != null and copa.historial.size() == 7
	if ok:
		print("OK: la Copa Nacional termino con campeon en 7 rondas.")
	else:
		print("FALLA: se esperaba campeon en 7 rondas.")

	var todos_los_nombres := {}
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			todos_los_nombres[equipo.nombre] = true
	if copa.campeon != null and todos_los_nombres.has(copa.campeon.nombre):
		print("OK: el campeon es uno de los clubes reales de la piramide.")
	else:
		print("FALLA: el campeon no aparece entre los clubes de la piramide.")

	_verificar_sin_repetidos(copa)


func _test_copas_de_division(copas: Array, piramide: Piramide, ms: int) -> void:
	print("\n=== Copas de Division (16 clasificados cada una) ===")
	print("Tiempo total (10 copas): %d ms" % ms)

	var ok := true
	for d in range(copas.size()):
		var copa: Copa = copas[d]
		if copa.campeon == null or copa.historial.size() != 4:
			ok = false
			print("FALLA %s: campeon=%s rondas=%d" % [copa.nombre, copa.campeon, copa.historial.size()])
		_verificar_sin_repetidos(copa)
	if ok:
		print("OK: las 10 copas de division terminaron con campeon en 4 rondas cada una.")

	print("Campeones:")
	for copa in copas:
		print("  %s: %s" % [copa.nombre, copa.campeon.nombre])


func _verificar_sin_repetidos(copa: Copa) -> void:
	for ronda in copa.historial:
		var vistos := {}
		for partido in ronda:
			for nombre in [partido["local"], partido["visitante"]]:
				if vistos.has(nombre):
					print("FALLA en %s: %s aparece dos veces en la misma ronda." % [copa.nombre, nombre])
				vistos[nombre] = true
