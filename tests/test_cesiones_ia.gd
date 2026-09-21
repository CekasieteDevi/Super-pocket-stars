extends SceneTree

## Cesiones entre clubes de la IA (Cesiones.ronda_ia): cumplen las reglas
## que les ponen limite, y el prestamo queda anotado en los dos clubes.

const SEED := 8282
const DIAS := 90
const DIVISION_PROPIA := 6

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var gs = load("res://game/game_state.gd").new()
	gs.piramide = piramide
	gs.rng = rng
	gs.temporada_actual = 1
	gs.division_jugador = DIVISION_PROPIA
	gs.equipo_jugador = piramide.divisiones[DIVISION_PROPIA].equipos[0]
	gs._sembrar_presupuestos()
	var mio: Team = gs.equipo_jugador

	# Titular AL MOMENTO de cederlo. El once cambia hasta dentro de una
	# misma ronda: el cedido que llega desplaza a un titular al banco, y
	# ese ya es suplente. Por eso no cuenta el club que recibio antes en
	# la ronda.
	var titular_cedido := false
	var hechas := []
	for dia in range(DIAS):
		var titulares := {}
		for liga in piramide.divisiones:
			for e in liga.equipos:
				for j in e.jugadores:
					titulares[int(j["id"])] = true
		var recibieron := {}
		for h in Cesiones.ronda_ia(piramide, rng, 1, mio, 1.0 + dia / 365.0):
			if not recibieron.has(h["dueno"]) and titulares.has(int(h["jugador"]["id"])):
				titular_cedido = true
			recibieron[h["pide"]] = true
			hechas.append(h)

	_comprobar(hechas.size() > 0, "hay cesiones entre clubes de la IA (%d)" % hechas.size())
	var toca_mio := false
	var viejo := false
	var sin_registro := false
	var sube := false
	for h in hechas:
		var dueno: Team = h["dueno"]
		var pide: Team = h["pide"]
		var id := int(h["jugador"]["id"])
		toca_mio = toca_mio or dueno == mio or pide == mio
		viejo = viejo or int(h["jugador"]["edad"]) > Cesiones.EDAD_MAX_CEDIBLE_IA
		sin_registro = sin_registro or not dueno.prestados_afuera.has(id) \
			or not pide.prestados_propios.has(id)
		sube = sube or pide.division_actual < dueno.division_actual
	_comprobar(not toca_mio, "tu club no cede ni recibe por la ronda de la IA")
	_comprobar(not titular_cedido, "ningun titular se cede")
	_comprobar(not viejo, "solo se ceden jugadores de hasta %d años" % Cesiones.EDAD_MAX_CEDIBLE_IA)
	_comprobar(not sin_registro, "el prestamo queda anotado en el dueño y en el que lo recibe")
	_comprobar(not sube, "nadie cede a un club de division mas alta")

	var corto := false
	var pasado := false
	for liga in piramide.divisiones:
		for e in liga.equipos:
			if e == mio:
				continue
			corto = corto or e.todos_los_jugadores().size() < Liga.MINIMO_DISPONIBLES + 1
			pasado = pasado or e.prestados_afuera.size() > Cesiones.CEDIDOS_IA_MAX
	_comprobar(not corto, "ningun club queda con menos de %d jugadores" % (Liga.MINIMO_DISPONIBLES + 1))
	_comprobar(not pasado, "ningun club tiene mas de %d cedidos" % Cesiones.CEDIDOS_IA_MAX)
	gs.free()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _comprobar(ok: bool, texto: String) -> void:
	if ok:
		print("OK: " + texto)
	else:
		fallos += 1
		print("FALLA: " + texto)
