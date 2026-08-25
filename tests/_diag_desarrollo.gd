extends SceneTree

## §7.3: ¿el equipo del usuario se desarrolla al mismo ritmo que si lo
## resolviera el motor abstracto? Sus partidos usan MotorEspacial (XP
## real) y los del resto MatchEngine (XP estimada). Si no coincidieran, el
## desbalance NO se promedia como los goles: se acumula temporada a
## temporada.
##
## La comparacion es la MISMA liga corrida dos veces con la misma semilla,
## una siguiendo al equipo 0 y otra sin seguir a nadie. Asi lo unico que
## cambia es el motor que resolvio sus partidos. Comparar ese equipo
## contra el promedio de la liga NO sirve: la diferencia sale del perfil
## de edades y genetica de ese plantel, no del motor.

const TEMPORADAS := 5
const DIVISION := 4


func _init() -> void:
	print("=== Mismo equipo, %d temporadas, con y sin motor espacial ===" % TEMPORADAS)
	var suma := 0.0
	for semilla in [8080, 1234, 5150]:
		var con := _correr(true, semilla)
		var sin := _correr(false, semilla)
		suma += con - sin
		print("  semilla %d:  espacial %+.2f  |  abstracto %+.2f  |  dif %+.2f" % [
			semilla, con, sin, con - sin])
	print("  diferencia media: %+.2f de media de plantel en %d temporadas" % [suma / 3.0, TEMPORADAS])
	quit()


func _correr(seguir: bool, semilla: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[DIVISION]
	var yo: Team = liga.equipos[0]
	var inicial := yo.media_equipo()
	for t in range(TEMPORADAS):
		for fecha in range(liga.fixture.size()):
			liga.jugar_fecha(fecha, rng, yo if seguir else null)
			liga.avanzar_dias(7)
		for e in liga.equipos:
			for j in e.todos_los_jugadores():
				Progresion.aplicar_temporada(j, rng)
			e.recalcular_capitan()
	return yo.media_equipo() - inicial
