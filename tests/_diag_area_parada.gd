extends SceneTree

## Cuanta gente hay DENTRO DEL AREA en el momento de ejecutar una pelota
## parada, por tipo de jugada y por estilo del equipo que ataca.
##
## El reclamo: en la vida real a una pelota parada van muchos al area, y
## en el juego no pasa. El corner ya reparte segun el estilo
## (Estilos.SUBEN_AL_CORNER); la pregunta es si eso llega a la cancha y
## que pasa con los tiros libres.

const SEED := 4400
const PARTIDOS := 12
const TIPOS := ["corner", "centro", "directo", "corto"]


func _init() -> void:
	for estilo in ["Físico", "Presión alta", "Tiki taka", "Contragolpe"]:
		var dentro := {}
		var casos := {}
		var resumen := [0, 0.0, 0]
		for t in TIPOS:
			dentro[t] = 0
			casos[t] = 0
		for i in range(PARTIDOS):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i
			var casa := Team.generar("A", rng, 0)
			var visita := Team.generar("B", rng, 400)
			casa.estilo = estilo
			casa.formacion = Formaciones.para_estilo(estilo)
			visita.estilo = "Tiki taka"
			visita.formacion = Formaciones.para_estilo("Tiki taka")
			var r2 := RandomNumberGenerator.new()
			r2.seed = SEED + i
			_correr(casa, visita, r2, dentro, casos, resumen)
		print("--- %s --- (sube al corner: %d)" % [
			estilo, Estilos.suben_al_corner(estilo)])
		for t in TIPOS:
			if int(casos[t]) == 0:
				print("  %-8s | sin casos" % t)
				continue
			print("  %-8s | %3d jugadas | %.1f atacantes en el area" % [
				t, int(casos[t]), float(dentro[t]) / float(casos[t])])
		if int(resumen[2]) > 0:
			print('    corner: se MANDAN %.1f al area y les falta %.1f m para llegar' % [
				float(resumen[0]) / float(resumen[2]), resumen[1] / maxf(float(resumen[0]), 1.0)])
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator,
		dentro: Dictionary, casos: Dictionary, resumen: Array) -> void:
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false
	home.forma_partido = 0.0
	away.forma_partido = 0.0
	home.clima_partido = Clima.generar(rng)
	away.clima_partido = home.clima_partido
	home.arbitro_partido = Arbitro.generar(rng)
	away.arbitro_partido = home.arbitro_partido
	var estado := MotorEspacial.crear_estado(home, away, rng)
	# Para no contar dos veces la misma jugada.
	var contada := false
	var mandados := 0
	var deuda := 0.0
	var tandas := 0
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			var bp = estado.get("balon_parado", null)
			# El tick que la ejecuta es aquel en que `detenido` llega a 0,
			# asi que se cuenta justo antes: es la foto del saque.
			if bp != null and int(estado.get("detenido", 0)) <= 1 and not contada:
				contada = true
				var tipo := str(bp.get("tipo", ""))
				# Solo se mide al local, que es el que lleva el estilo.
				if dentro.has(tipo) and bool(bp.get("ataca_local", true)):
					casos[tipo] = int(casos[tipo]) + 1
					var n := 0
					for id in estado["jugadores"]:
						var e: Dictionary = estado["jugadores"][id]
						if not e["equipo_local"] or str(e["rol"]) == "ARQ":
							continue
						if MotorEspacial._en_el_area(e["pos"], true):
							n += 1
					dentro[tipo] = int(dentro[tipo]) + n
					if tipo == 'corner':
						var asignados := 0
						var falta := 0.0
						for id2 in estado['jugadores']:
							var e2: Dictionary = estado['jugadores'][id2]
							if not e2['equipo_local']:
								continue
							if int(e2.get('sube_al_area', -1)) != 1:
								continue
							asignados += 1
							falta += float(e2['pos'].distance_to(e2.get('marca', e2['pos'])))
						mandados += asignados
						deuda += falta
						tandas += 1
			resumen[0] = resumen[0] + mandados
			resumen[1] = resumen[1] + deuda
			resumen[2] = resumen[2] + tandas
			mandados = 0
			deuda = 0.0
			tandas = 0
			if bp == null:
				contada = false
			MotorEspacial._tick(estado, false)
