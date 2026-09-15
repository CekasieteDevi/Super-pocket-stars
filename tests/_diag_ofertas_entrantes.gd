extends SceneTree

## Medicion, no test: cuantas ofertas de compra le llegan al club del
## jugador en una ventana de pases, y por quien.
##
## Se plantan dos cracks en un club de division baja: uno con la media de
## dos divisiones mas arriba + 2 y uno de elite (media de primera + 3).
## La pregunta es la del "Messi en tercera": si nadie oferta por ellos, el
## mercado entrante no esta mirando a quien vale la pena.
##
## Cada oferta queda abierta DIAS_ABIERTA dias, igual que en una partida:
## mientras tanto bloquea nuevas ofertas por el mismo jugador.

const SEED := 8181
const DIAS_VENTANA := 90
const DIAS_ABIERTA := 5
const CORRIDAS := 10


func _init() -> void:
	var inicio := Time.get_ticks_msec()
	for division in [2, 6]:
		_medir(division)
	print("ms totales: %d" % (Time.get_ticks_msec() - inicio))
	quit()


func _medir(division: int) -> void:
	var total := 0
	var por_crack := 0
	var por_elite := 0
	var titulares := 0
	var banco := 0
	var reservas := 0
	var sin_valor := 0
	var suma_diferencia := 0.0
	for corrida in range(CORRIDAS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + corrida
		var piramide := Piramide.generar(rng)
		var gs = load("res://game/game_state.gd").new()
		gs.piramide = piramide
		gs.rng = rng
		gs.temporada_actual = 1
		gs.division_jugador = division
		gs.equipo_jugador = piramide.divisiones[division].equipos[0]
		gs._sembrar_presupuestos()
		var mio: Team = gs.equipo_jugador
		var crack: Dictionary = mio.jugadores[10]
		crack["media"] = NivelDivision.media_de(maxi(division - 2, 0)) + 2.0
		crack["edad"] = 25
		var id_crack := int(crack["id"])
		var elite: Dictionary = mio.jugadores[8]
		elite["media"] = NivelDivision.media_de(0) + 3.0
		elite["edad"] = 25
		var id_elite := int(elite["id"])
		var media_club := mio.media_equipo()

		var nacida := {}
		for dia in range(DIAS_VENTANA):
			for o in mio.ofertas.duplicate():
				if dia - int(nacida[int(o["id"])]) >= DIAS_ABIERTA:
					mio.ofertas.erase(o)
			for o in Ofertas.generar_entrantes(mio, piramide, rng, 1, division):
				nacida[int(o["id"])] = dia
				total += 1
				var id := int(o["jugador_id"])
				var donde := Mercado.ubicar(mio, id)
				var j: Dictionary = donde["jugador"]
				suma_diferencia += float(j["media"]) - media_club
				if id == id_crack:
					por_crack += 1
				elif id == id_elite:
					por_elite += 1
				if mio.jugadores.has(j):
					titulares += 1
				elif mio.banco.has(j):
					banco += 1
				else:
					reservas += 1
				if float(j["media"]) < media_club - 5.0:
					sin_valor += 1
		gs.free()

	var n := float(CORRIDAS)
	print("Division %d (%d corridas de %d dias):" % [division + 1, CORRIDAS, DIAS_VENTANA])
	print("  ofertas por ventana: %.1f" % (float(total) / n))
	print("  por el crack: %.1f | por el de elite: %.1f" % [por_crack / n, por_elite / n])
	print("  titulares %.1f | banco %.1f | reservas %.1f" % [
		titulares / n, banco / n, reservas / n])
	print("  por jugadores 5+ puntos bajo la media del club: %.1f" % (sin_valor / n))
	if total > 0:
		print("  media del ofertado - media del club: %+.1f" % (suma_diferencia / float(total)))
