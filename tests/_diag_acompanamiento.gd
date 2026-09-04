extends SceneTree

## Quien acompaña el ataque. Con la pelota de tu equipo metida en el
## tercio rival, mide a que distancia del arco rival esta parado cada rol
## y cuantos jugadores hay dentro del area.
##
## El reclamo: los MC dan el pase a los DC/EXT y se quedan clavados donde
## estan; solo los tres de arriba entran al area.

const SEED := 4400
const PARTIDOS := 8
## Avance de la pelota a partir del cual se considera que el equipo esta
## atacando de verdad (0 = arco propio, 1 = arco rival).
const AVANCE_ATAQUE := 0.65
const ROLES := ["DFC", "LAT", "MC", "MCO", "EXT", "DC"]


func _init() -> void:
	for estilo in ["Tiki taka", "Contragolpe", "Defensivo", "Presión alta"]:
		var dist := {}
		var en_area := {}
		for r in ROLES:
			dist[r] = [0.0, 0]
			en_area[r] = 0
		var muestras := 0
		for i in range(PARTIDOS):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i
			var casa := Team.generar("A", rng, 0)
			var visita := Team.generar("B", rng, 400)
			# La formacion sale del estilo AL GENERAR el club, asi que
			# pisar solo `estilo` despues dejaba los puestos de la
			# formacion sorteada: por eso antes no aparecia ningun MCO,
			# que solo existe en el 4-2-3-1. Los roles en cancha salen de
			# los SLOTS de la formacion (ver _armar_jugadores), asi que
			# fijar las dos cosas alcanza.
			casa.estilo = estilo
			casa.formacion = Formaciones.para_estilo(estilo)
			visita.estilo = "Tiki taka"
			visita.formacion = Formaciones.para_estilo("Tiki taka")
			var r2 := RandomNumberGenerator.new()
			r2.seed = SEED + i
			muestras += _correr(casa, visita, r2, dist, en_area)
		print("--- %s (%s) --- (%d situaciones de ataque)" % [
			estilo, Formaciones.para_estilo(estilo), muestras])
		if muestras == 0:
			continue
		print("  rol  | al arco rival | en el area")
		for r in ROLES:
			var par: Array = dist[r]
			if int(par[1]) == 0:
				continue
			print("  %-4s |     %5.1f m   |   %.2f" % [
				r, float(par[0]) / float(par[1]),
				float(en_area[r]) / float(muestras)])
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator,
		dist: Dictionary, en_area: Dictionary) -> int:
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
	var muestras := 0
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			MotorEspacial._tick(estado, false)
			# Solo se mide al equipo local, y solo cuando ataca: asi el
			# estilo que se barre es siempre el mismo.
			var pelota: Dictionary = estado["pelota"]
			var duenio: int = int(pelota.get("poseedor_id", -1))
			if duenio == -1 or not bool(estado["jugadores"][duenio]["equipo_local"]):
				continue
			if MotorEspacial.valor_posicion(pelota["pos"], true) < AVANCE_ATAQUE:
				continue
			muestras += 1
			var arco := MotorEspacial.arco_rival(true)
			for id in estado["jugadores"]:
				var e: Dictionary = estado["jugadores"][id]
				if not e["equipo_local"]:
					continue
				var rol: String = e["rol"]
				if not dist.has(rol):
					continue
				dist[rol][0] += e["pos"].distance_to(arco)
				dist[rol][1] += 1
				if MotorEspacial._en_el_area(e["pos"], true):
					en_area[rol] += 1
	return muestras
