extends SceneTree

## Mantenimiento como costo fijo real (no un % del neto que se va a rojo
## si gastaste de más en sueldos) — feedback de playtesting: comprar
## jugadores caros no debería inflar el "gasto en mantenimiento". Correr
## con: godot --headless --script tests/test_economia_mantenimiento.gd

const SEED := 4242


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_mantenimiento_no_depende_de_sueldos(rng)
	_test_mantenimiento_estable_con_neto_muy_negativo(rng)

	quit()


func _test_mantenimiento_no_depende_de_sueldos(rng: RandomNumberGenerator) -> void:
	print("=== Mantenimiento: mismo aporte con sueldos bajos o altos ===")
	var equipo_barato := Team.generar("Barato", rng, 0)
	var equipo_caro := Team.generar("Caro", rng, 1000)

	for id in equipo_caro.sueldos:
		equipo_caro.sueldos[id] *= 20.0  # simula haber fichado carisimo

	Economia.procesar_temporada(equipo_barato, 10, 20)
	Economia.procesar_temporada(equipo_caro, 10, 20)

	var ok: bool = is_equal_approx(equipo_barato.presupuesto_temporada["mantenimiento"], Economia.RESERVA_MANTENIMIENTO)
	ok = ok and is_equal_approx(equipo_caro.presupuesto_temporada["mantenimiento"], Economia.RESERVA_MANTENIMIENTO)

	if ok:
		print("OK: el aporte a Mantenimiento es el mismo (%s) tenga el club sueldos altos o bajos." % Economia.formato_dinero(Economia.RESERVA_MANTENIMIENTO))
	else:
		print("FALLA: barato=%s caro=%s" % [equipo_barato.presupuesto_temporada["mantenimiento"], equipo_caro.presupuesto_temporada["mantenimiento"]])


func _test_mantenimiento_estable_con_neto_muy_negativo(rng: RandomNumberGenerator) -> void:
	print("\n=== Mantenimiento no se va a rojo aunque el neto de la temporada sea muy negativo ===")
	var equipo := Team.generar("Endeudado", rng, 2000)
	for id in equipo.sueldos:
		equipo.sueldos[id] *= 100.0  # neto claramente negativo

	var caja_mantenimiento_antes: float = equipo.caja["mantenimiento"]
	var informe := Economia.procesar_temporada(equipo, 20, 20)

	var ok: bool = informe["neto"] < 0.0  # confirmamos que efectivamente es un caso de neto negativo
	ok = ok and equipo.caja["mantenimiento"] > caja_mantenimiento_antes  # y aun asi mantenimiento sumo, no resto
	ok = ok and is_equal_approx(equipo.caja["mantenimiento"] - caja_mantenimiento_antes, Economia.RESERVA_MANTENIMIENTO)

	if ok:
		print("OK: con neto %s, Mantenimiento igual sumo su reserva fija de %s." % [Economia.formato_dinero(informe["neto"]), Economia.formato_dinero(Economia.RESERVA_MANTENIMIENTO)])
	else:
		print("FALLA: neto=%s mantenimiento antes=%s despues=%s" % [informe["neto"], caja_mantenimiento_antes, equipo.caja["mantenimiento"]])
