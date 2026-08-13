extends SceneTree

## Integración del flujo real de GameState — Fase 9/10: jugar la pirámide
## entera fecha a fecha (como hace la UI) y cerrar una temporada completa
## (copas + internacional + ascensos/descensos + cantera + noticias).
## No se puede instanciar el autoload GameState en modo --script (los
## autoloads no se cargan fuera de una ejecución normal del juego), así
## que este test reproduce exactamente la misma secuencia de llamadas que
## game/game_state.gd para validar la integración sin la capa de UI.
##
## Correr con: godot --headless --script tests/test_gamestate_flujo.gd

const DIVISION_INICIAL := 9
const DIAS_ENTRE_FECHAS := 7
const SEED := 2026


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var piramide := Piramide.generar(rng)
	var confederacion := Confederacion.generar(piramide, rng)
	var equipo_jugador: Team = piramide.divisiones[DIVISION_INICIAL].equipos[0]
	var division_jugador := DIVISION_INICIAL
	var noticias := []

	print("=== Jugando la temporada 1 completa, fecha a fecha en las 10 divisiones ===")
	var n_fechas: int = piramide.divisiones[division_jugador].fixture.size()
	var t0 := Time.get_ticks_msec()

	for fecha in range(n_fechas):
		for d in range(piramide.divisiones.size()):
			var liga: Liga = piramide.divisiones[d]
			if d == division_jugador:
				liga.jugar_fecha(fecha, rng, equipo_jugador)
			else:
				liga.jugar_fecha(fecha, rng)
			liga.avanzar_dias(DIAS_ENTRE_FECHAS)

	var t1 := Time.get_ticks_msec()
	print("Tiempo de la temporada (10 divisiones x %d fechas): %d ms" % [n_fechas, t1 - t0])

	_test_todas_las_divisiones_jugaron(piramide)

	print("\n=== Cerrando la temporada (copas + internacional + ascensos/descensos + cantera) ===")
	var copa_nacional := Copas.jugar_copa_nacional(piramide, rng)
	var copas_division := Copas.jugar_copas_de_division(piramide, rng)
	var resultado_internacional := confederacion.jugar_temporada_internacional(rng)

	noticias.append("COPA NACIONAL: campeón %s" % copa_nacional.campeon.nombre)
	for i in range(copas_division.size()):
		noticias.append("COPA DIVISIÓN %d: campeón %s" % [i + 1, copas_division[i].campeon.nombre])

	var resultado_piramide := piramide.fin_de_temporada(rng)
	for m in resultado_piramide["movimientos"]:
		if m["equipo"] == equipo_jugador.nombre:
			noticias.append("%s: %s (división %d → división %d)" % [equipo_jugador.nombre, m["tipo"], m["de_division"], m["a_division"]])

	for liga in piramide.divisiones:
		for n in liga.noticias:
			noticias.append(n)
		liga.noticias.clear()

	var nueva_division := -1
	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(equipo_jugador):
			nueva_division = d
			break

	_test_cierre_temporada(piramide, resultado_internacional, nueva_division, equipo_jugador, noticias)
	_test_cantera(equipo_jugador)

	quit()


func _test_todas_las_divisiones_jugaron(piramide: Piramide) -> void:
	print("\n=== Integridad: las 10 divisiones jugaron una temporada real ===")
	var ok := true
	for d in range(piramide.divisiones.size()):
		var liga: Liga = piramide.divisiones[d]
		var total_pj := 0
		for nombre in liga.tabla:
			total_pj += liga.tabla[nombre]["pj"]
		if total_pj == 0:
			ok = false
			print("FALLA: division %d nunca jugo (todo en 0)." % (d + 1))
	if ok:
		print("OK: las 10 divisiones tienen partidos jugados, no solo la del jugador.")


func _test_cierre_temporada(piramide: Piramide, resultado_internacional: Dictionary, nueva_division: int,
		equipo_jugador: Team, noticias: Array) -> void:
	print("\n=== Resultado del cierre de temporada ===")

	var ok_divisiones := true
	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.size() != 20:
			ok_divisiones = false
	print("Las 10 divisiones siguen en 20 equipos: %s" % ("OK" if ok_divisiones else "FALLA"))

	print("El equipo del jugador quedo en division: %d" % (nueva_division + 1))
	if nueva_division >= 0:
		print("OK: se pudo localizar al equipo del jugador en la piramide despues de los movimientos.")
	else:
		print("FALLA: no se encontro al equipo del jugador en ninguna division.")

	for copa_nombre in ["campeones", "guerreros", "emergentes"]:
		var campeon: Team = resultado_internacional[copa_nombre]["campeon"]
		print("Copa Internacional (%s): campeon %s" % [copa_nombre, campeon.nombre if campeon else "NINGUNO"])

	print("Noticias generadas en el cierre: %d" % noticias.size())
	for i in range(min(5, noticias.size())):
		print("  " + noticias[i])
	if noticias.size() > 0:
		print("OK: el cierre de temporada genero noticias.")
	else:
		print("FALLA: no se genero ninguna noticia en el cierre.")


func _test_cantera(equipo_jugador: Team) -> void:
	print("\n=== Cantera del equipo del jugador tras el cierre ===")
	print("Juveniles en cantera: %d (esperado 3, la camada anual)" % equipo_jugador.cantera.size())
	if equipo_jugador.cantera.size() == 3:
		print("OK: se genero la camada anual para el equipo del jugador.")
	else:
		print("FALLA: se esperaban 3 juveniles nuevos.")
