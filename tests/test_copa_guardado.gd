extends SceneTree

## Una copa a mitad de temporada tiene que sobrevivir un guardar/cargar
## con su cuadro intacto: perder el sorteo al cargar la partida seria
## inaceptable para el jugador. Copa guarda NOMBRES y relocaliza los
## equipos en la piramide al cargar, igual que Confederacion.
## Correr con: godot --headless --script tests/test_copa_guardado.gd

const SEED := 6161


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	_test_round_trip_a_mitad_de_copa(piramide, rng)
	_test_se_puede_seguir_jugando(piramide, rng)
	_test_campeon_sobrevive(piramide, rng)
	quit()


func _copa_de_division(piramide: Piramide, rng: RandomNumberGenerator, rondas: int) -> Copa:
	var c := Copa.iniciar("Copa Test", piramide.divisiones[0].equipos.duplicate(), rng)
	for i in range(rondas):
		if c.campeon == null:
			c.jugar_siguiente_ronda(rng)
	return c


func _test_round_trip_a_mitad_de_copa(piramide: Piramide, rng: RandomNumberGenerator) -> void:
	print("=== El cuadro sobrevive un guardar/cargar a mitad de copa ===")
	var c := _copa_de_division(piramide, rng, 2)
	var cargada := Copa.cargar(JSON.parse_string(JSON.stringify(c.guardar())), piramide)

	var ok: bool = cargada.nombre == c.nombre
	ok = ok and cargada.historial.size() == c.historial.size()
	ok = ok and cargada.partidos_pendientes.size() == c.partidos_pendientes.size()
	ok = ok and cargada.equipos_con_bye.size() == c.equipos_con_bye.size()
	# Y los MISMOS cruces, no una cantidad parecida.
	for i in range(c.partidos_pendientes.size()):
		ok = ok and cargada.partidos_pendientes[i][0].nombre == c.partidos_pendientes[i][0].nombre
		ok = ok and cargada.partidos_pendientes[i][1].nombre == c.partidos_pendientes[i][1].nombre
	if ok:
		print("OK: %d rondas jugadas, %d cruces pendientes, %d con bye, todo igual." % [
			cargada.historial.size(), cargada.partidos_pendientes.size(), cargada.equipos_con_bye.size()])
	else:
		print("FALLA: %d/%d rondas, %d/%d cruces" % [
			cargada.historial.size(), c.historial.size(),
			cargada.partidos_pendientes.size(), c.partidos_pendientes.size()])


func _test_se_puede_seguir_jugando(piramide: Piramide, rng: RandomNumberGenerator) -> void:
	print("\n=== La copa cargada se puede seguir jugando hasta el final ===")
	var c := _copa_de_division(piramide, rng, 1)
	var cargada := Copa.cargar(JSON.parse_string(JSON.stringify(c.guardar())), piramide)
	var vueltas := 0
	while cargada.campeon == null and vueltas < 20:
		cargada.jugar_siguiente_ronda(rng)
		vueltas += 1
	if cargada.campeon != null:
		print("OK: siguio hasta consagrar a %s en %d rondas mas." % [cargada.campeon.nombre, vueltas])
	else:
		print("FALLA: no llego a campeon en %d rondas" % vueltas)


func _test_campeon_sobrevive(piramide: Piramide, rng: RandomNumberGenerator) -> void:
	print("\n=== Una copa ya terminada conserva su campeon ===")
	var c := _copa_de_division(piramide, rng, 20)
	var cargada := Copa.cargar(JSON.parse_string(JSON.stringify(c.guardar())), piramide)
	if c.campeon != null and cargada.campeon != null and cargada.campeon.nombre == c.campeon.nombre:
		print("OK: campeon %s conservado." % cargada.campeon.nombre)
	else:
		print("FALLA: original=%s cargado=%s" % [
			c.campeon.nombre if c.campeon else "null",
			cargada.campeon.nombre if cargada.campeon else "null"])
