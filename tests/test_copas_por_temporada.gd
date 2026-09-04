extends SceneTree

## Las copas de una temporada a la otra, por el camino de verdad
## (GameState._cerrar_temporada -> _armar_copas). El test de al lado
## (test_clasificacion_copas.gd) mide la clasificación sola; este mide que
## la partida la use: que la foto de las tablas se saque antes del reset,
## que los cuadros nuevos salgan de esa foto, y que el objetivo de
## directiva no pida copa cuando el club no clasificó.
##
## Correr con: godot --path . --headless --script tests/test_copas_por_temporada.gd

const SEED := 7711

var fallos := 0


func _init() -> void:
	# El autoload GameState no existe en modo --script, y SIN meterlo en el
	# arbol: _ready() cargaria la partida guardada del usuario.
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(SEED, "Club Prueba")

	_test_temporada_uno(gs)
	_test_cierre(gs)

	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Cuantos clubes hay en el cuadro de una copa recien sorteada.
func _en_el_cuadro(copa: Copa) -> int:
	return copa.partidos_pendientes.size() * 2 + copa.equipos_con_bye.size()


func _test_temporada_uno(gs) -> void:
	print("=== Temporada 1: cuadros al empezar la partida ===")
	_ok(_en_el_cuadro(gs.copa_nacional) == 128,
		"el Rey arranca con 128 clubes (fueron %d)." % _en_el_cuadro(gs.copa_nacional))
	_ok(gs.copa_nacional.equipos_con_bye.is_empty(), "el Rey no reparte pases libres.")
	var sin_bye := true
	var todas_16 := true
	for copa in gs.copas_division:
		if not copa.equipos_con_bye.is_empty():
			sin_bye = false
		if _en_el_cuadro(copa) != 16:
			todas_16 = false
	_ok(todas_16, "las 10 copas de division arrancan con 16 clubes.")
	_ok(sin_bye, "ninguna copa de division reparte pases libres.")
	_ok(gs.posiciones_temporada_anterior.is_empty(),
		"la temporada 1 no tiene tabla anterior (clasifica por reputacion).")


func _test_cierre(gs) -> void:
	print("\n=== Cierre de temporada: la foto de las tablas arma las copas nuevas ===")
	# La temporada entera de las 10 divisiones, con el motor abstracto: lo
	# que le importa a este test es que las tablas queden LLENAS antes del
	# cierre, no como se jugo cada partido.
	gs.piramide.jugar_temporada(gs.rng)
	var tabla_jugador: Array = gs.liga_jugador().tabla_ordenada()
	var puesto := tabla_jugador.find(gs.equipo_jugador.nombre) + 1
	var division_jugada: int = gs.division_jugador + 1
	var cupos := ClasificacionCopas.cupos_de(gs.division_jugador)
	print("Tu club salio %d° en la Division %d (cupos al Rey: %d)." % [puesto, division_jugada, cupos])

	gs._cerrar_temporada()

	_ok(gs.posiciones_temporada_anterior.size() == 200,
		"la foto guarda a los 200 clubes (guardo %d)." % gs.posiciones_temporada_anterior.size())
	_ok(int(gs.posiciones_temporada_anterior[gs.equipo_jugador.nombre]["posicion"]) == puesto,
		"la foto tiene tu puesto real de la temporada que se jugo.")

	_ok(_en_el_cuadro(gs.copa_nacional) == 128,
		"el Rey de la temporada 2 arranca con 128 (fueron %d)." % _en_el_cuadro(gs.copa_nacional))
	_ok(gs.copa_nacional.equipos_con_bye.is_empty(), "el Rey de la temporada 2 no reparte pases libres.")

	# Cada division tiene que aportar EXACTAMENTE sus cupos, contando por
	# la division donde cada club jugo (no donde esta ahora: los ascensos
	# ya corrieron).
	var por_division := {}
	for equipo in _clubes_del_cuadro(gs.copa_nacional):
		var fila: Dictionary = gs.posiciones_temporada_anterior.get(equipo.nombre, {})
		var d := int(fila.get("division", 0))
		por_division[d] = int(por_division.get(d, 0)) + 1
	var cupos_ok := true
	for d in range(10):
		if int(por_division.get(d + 1, 0)) != ClasificacionCopas.cupos_de(d):
			cupos_ok = false
			print("  Division %d aporto %d, esperado %d" % [
				d + 1, int(por_division.get(d + 1, 0)), ClasificacionCopas.cupos_de(d)])
	_ok(cupos_ok, "cada division aporta sus cupos al Rey de la temporada 2.")

	# Los clasificados de una division son los PRIMEROS de esa division,
	# no clubes sueltos: el peor clasificado no puede estar por debajo del
	# cupo.
	var peor_puesto := 0
	for equipo in _clubes_del_cuadro(gs.copa_nacional):
		var fila: Dictionary = gs.posiciones_temporada_anterior.get(equipo.nombre, {})
		if int(fila.get("division", 0)) == division_jugada:
			peor_puesto = maxi(peor_puesto, int(fila.get("posicion", 99)))
	_ok(peor_puesto == cupos,
		"de tu division entraron los primeros %d (el peor clasificado salio %d°)." % [cupos, peor_puesto])

	# Y lo que le pasa a TU club es coherente con eso.
	var clasificaste: bool = gs.copa_nacional.participa(gs.equipo_jugador)
	_ok(clasificaste == (puesto <= cupos),
		"tu club %s al Rey, como manda su puesto." % ("clasifica" if clasificaste else "no clasifica"))

	var aviso := ""
	for n in gs.noticias:
		if str(n["texto"]).begins_with("COPA DEL REY:"):
			aviso = str(n["texto"])
			break
	_ok(aviso != "", "el cierre deja el aviso de clasificacion al Rey.")
	print("Aviso: %s" % aviso)
	if aviso != "":
		var dice_adentro: bool = aviso.contains("clasifica (")
		_ok(dice_adentro == clasificaste, "el aviso dice lo mismo que el cuadro.")

	# Sin cupo, el objetivo de directiva no puede pedir rondas de copa.
	var categoria := str(gs.equipo_jugador.objetivo_temporada.get("categoria", ""))
	print("Objetivo nuevo: %s (%s)" % [
		categoria, gs.equipo_jugador.objetivo_temporada.get("descripcion", "")])
	if not clasificaste:
		_ok(categoria != "copa", "sin cupo en el Rey, el objetivo no es de copa.")
	else:
		_ok(true, "con cupo en el Rey el objetivo puede ser de copa (no se fuerza).")


func _clubes_del_cuadro(copa: Copa) -> Array:
	var salida := []
	for p in copa.partidos_pendientes:
		salida.append(p[0])
		salida.append(p[1])
	salida.append_array(copa.equipos_con_bye)
	return salida
