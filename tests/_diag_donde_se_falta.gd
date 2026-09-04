extends SceneTree

## Donde se cometen las faltas, contra donde se JUEGA.
##
## La pregunta: por que casi no hay faltas dentro de los 22 m del arco.
## Hay dos explicaciones posibles y esto las separa — que se juegue poco
## ahi, o que se falte poco por cada minuto que se juega ahi.
##
## La ultima columna es la que contesta: faltas cada 1000 ticks de juego
## en esa banda. Si es pareja, el problema es que la pelota no llega; si
## cae cerca del arco, es que ahi se falta menos.

const SEED := 4400
const PARTIDOS := 25
## Distancia al arco que ATACA el que tiene la pelota.
const BANDAS := [0.0, 16.5, 22.0, 30.0, 40.0, 55.0, 200.0]


func _init() -> void:
	var ticks := {}
	var faltas := {}
	var penales := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		penales += _correr(casa, visita, r2, ticks, faltas)
	print("donde se juega y donde se falta (%d partidos, los dos equipos)" % PARTIDOS)
	print("  distancia al arco | ticks de juego | faltas | faltas/1000 ticks")
	for b in range(BANDAS.size() - 1):
		var t: int = int(ticks.get(b, 0))
		if t == 0:
			continue
		var fl: int = int(faltas.get(b, 0))
		print("  %5.0f - %5.0f m   | %14d | %6d | %.2f" % [
			BANDAS[b], BANDAS[b + 1], t, fl, 1000.0 * float(fl) / float(t)])
	print("penales cobrados: %.2f por partido" % [float(penales) / PARTIDOS])
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator,
		ticks: Dictionary, faltas: Dictionary) -> int:
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
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			# Donde esta la pelota ANTES del tick, y de quien es: la falta
			# que salga de este tick se comete ahi.
			var duenio: int = int(estado["pelota"].get("poseedor_id", -1))
			var banda := -1
			if duenio != -1 and estado["jugadores"].has(duenio):
				var e: Dictionary = estado["jugadores"][duenio]
				var d: float = e["pos"].distance_to(
					MotorEspacial.arco_rival(bool(e["equipo_local"])))
				for b in range(BANDAS.size() - 1):
					if d >= float(BANDAS[b]) and d < float(BANDAS[b + 1]):
						banda = b
			var faltas_antes: int = int(estado.get("faltas", 0))
			MotorEspacial._tick(estado, false)
			if banda == -1:
				continue
			ticks[banda] = int(ticks.get(banda, 0)) + 1
			if int(estado.get("faltas", 0)) > faltas_antes:
				faltas[banda] = int(faltas.get(banda, 0)) + 1
	return int(estado.get("penales", 0))
