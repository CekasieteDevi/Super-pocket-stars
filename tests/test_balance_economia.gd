extends SceneTree

## Balance de economía (feedback de playtesting con un diagnóstico manual):
## el sueldo se recalcula al renovar contrato, la reputación responde más
## rápido al rendimiento, y el valor de plantel es menos volátil por el
## contrato restante. Correr con:
## godot --headless --script tests/test_balance_economia.gd

const SEED := 8484


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_sueldo_sube_al_renovar_si_el_jugador_mejoro(rng)
	_test_sueldo_protegido_tambien_se_actualiza(rng)
	_test_reputacion_responde_mas_rapido(rng)
	_test_valor_menos_sensible_al_contrato(rng)

	quit()


func _test_sueldo_sube_al_renovar_si_el_jugador_mejoro(rng: RandomNumberGenerator) -> void:
	print("=== El sueldo se recalcula al renovar (sube si el jugador mejoro) ===")
	var liga := Liga.new()
	liga.inicializar(["ClubA", "ClubB"], rng, 0)
	var equipo: Team = liga.equipos[0]

	var jugador: Dictionary = equipo.jugadores[0]
	var id: int = jugador["id"]
	var sueldo_antes: float = equipo.sueldos[id]

	# Simula una gran mejora (progresion de varias temporadas). Llama a
	# _renovar_contrato() directo en vez de _avanzar_contratos() -- esta
	# ultima decide primero, al azar, si el club de la IA renueva o deja
	# ir al jugador (según edad), y ese resultado no es lo que este test
	# quiere probar; probar la renovación en sí no debería depender de
	# que la tirada de "se queda o se va" caiga de un lado en particular.
	jugador["media"] = min(99.0, jugador["media"] + 30.0)
	liga._renovar_contrato(equipo, id, jugador, rng)

	var sueldo_despues: float = equipo.sueldos[id]

	if sueldo_despues > sueldo_antes:
		print("OK: sueldo subio de %s a %s tras renovar con el jugador mejorado." % [Economia.formato_dinero(sueldo_antes), Economia.formato_dinero(sueldo_despues)])
	else:
		print("FALLA: antes=%s despues=%s" % [sueldo_antes, sueldo_despues])


func _test_sueldo_protegido_tambien_se_actualiza(rng: RandomNumberGenerator) -> void:
	print("\n=== Tambien pasa para el equipo protegido (jugador humano) ===")
	var liga := Liga.new()
	liga.inicializar(["Protegido", "Rival"], rng, 1000)
	var equipo: Team = liga.equipos[0]

	var jugador: Dictionary = equipo.jugadores[0]
	var id: int = jugador["id"]
	var sueldo_antes: float = equipo.sueldos[id]
	jugador["media"] = min(99.0, jugador["media"] + 30.0)
	equipo.contratos[id] = 1

	liga._avanzar_contratos(equipo, rng, true)

	var sueldo_despues: float = equipo.sueldos[id]

	if sueldo_despues > sueldo_antes and equipo.contratos[id] >= 2:
		print("OK: el sueldo del equipo protegido tambien se actualiza al renovar (%s -> %s)." % [Economia.formato_dinero(sueldo_antes), Economia.formato_dinero(sueldo_despues)])
	else:
		print("FALLA: antes=%s despues=%s contrato=%s" % [sueldo_antes, sueldo_despues, equipo.contratos[id]])


func _test_reputacion_responde_mas_rapido(rng: RandomNumberGenerator) -> void:
	print("\n=== La reputacion responde mas rapido a un campeonato sostenido ===")
	var equipo := Team.generar("ClubCampeon", rng, 2000)
	equipo.reputacion = 50.0

	for temporada in range(5):
		Economia.procesar_temporada(equipo, 1, 20)  # 1er puesto, 5 temporadas seguidas

	var ganancia: float = equipo.reputacion - 50.0

	# Con la formula vieja (x0.05), 5 temporadas de 1er puesto daban ~2.4
	# puntos. Con la nueva (x0.25) tiene que ser notoriamente mas.
	if ganancia > 8.0:
		print("OK: 5 temporadas de 1er puesto subieron la reputacion %.2f puntos (antes hubiera sido ~2.4)." % ganancia)
	else:
		print("FALLA: gano solo %.2f puntos en 5 temporadas de 1er puesto." % ganancia)


func _test_valor_menos_sensible_al_contrato(rng: RandomNumberGenerator) -> void:
	print("\n=== El valor de mercado es menos sensible al contrato restante ===")
	var jugador := PlayerGenerator.generate(0, rng, "MC")

	var valor_contrato_corto := ValorJugador.calcular(jugador, 50.0, 1)
	var valor_contrato_largo := ValorJugador.calcular(jugador, 50.0, 4)
	var swing: float = (valor_contrato_largo - valor_contrato_corto) / valor_contrato_corto

	# Con la formula vieja (0.4 a 1.1), el mismo jugador podia casi
	# duplicar de valor (swing ~83%) solo por renovar. Ahora tiene que ser
	# bastante mas moderado.
	if swing < 0.40:
		print("OK: pasar de contrato=1 a contrato=4 cambia el valor solo %.0f%% (antes ~83%%)." % (swing * 100.0))
	else:
		print("FALLA: el swing sigue siendo %.0f%%." % (swing * 100.0))
