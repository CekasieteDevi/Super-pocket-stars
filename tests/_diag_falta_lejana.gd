extends SceneTree

## Desde donde se cobran las faltas a favor y en que tipo caen. El tipo
## decide quien sube al area: `corner` y `centro` cargan el area, `corto`
## y `directo` no mandan a nadie.
##
## Sirve para dimensionar el punto 2: cuantas de las `corto` estan lo
## bastante cerca como para colgarlas al area.
##
## OJO: el tipo `corto` lo comparten la falta lejana, el LATERAL y el
## SAQUE DE ARCO — los tres llaman a _detener_juego con el mismo nombre.
## Aca se separan por geometria: el lateral sale de la linea de touch
## (|y| casi 34) y el saque de arco de la propia area, o sea a mas de 90 m
## del arco rival. Lo que queda son las faltas de verdad.

const SEED := 4400
const PARTIDOS := 12
## Bandas de distancia al arco rival, en metros.
const BANDAS := [0.0, 25.0, 38.0, 50.0, 60.0, 75.0, 200.0]


func _init() -> void:
	var conteo := {}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		_correr(casa, visita, r2, conteo)
	print("faltas del local por tipo y distancia al arco rival (%d partidos)" % PARTIDOS)
	print("  distancia   | corto | centro | directo")
	for b in range(BANDAS.size() - 1):
		var fila: Dictionary = conteo.get(b, {})
		if fila.is_empty():
			continue
		print("  %5.0f-%5.0f | %5d | %6d | %7d" % [
			BANDAS[b], BANDAS[b + 1],
			int(fila.get("corto", 0)), int(fila.get("centro", 0)),
			int(fila.get("directo", 0))])
	var total := 0
	var cortos := 0
	for b in conteo:
		for t in conteo[b]:
			total += int(conteo[b][t])
			if t == "corto":
				cortos += int(conteo[b][t])
	print("total %d faltas (%.1f por partido), de las cuales %d cortas" % [
		total, float(total) / PARTIDOS, cortos])
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator, conteo: Dictionary) -> void:
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
	var visto := false
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			MotorEspacial._tick(estado, false)
			var bp = estado.get("balon_parado", null)
			if bp == null or not (bp as Dictionary).has("pos"):
				visto = false
				continue
			if visto:
				continue
			visto = true
			var tipo := str(bp.get("tipo", ""))
			if tipo == "corner" or not bool(bp.get("ataca_local", true)):
				continue
			var punto: Vector2 = bp["pos"]
			var d: float = punto.distance_to(MotorEspacial.arco_rival(true))
			if tipo == "corto":
				if absf(punto.y) >= 33.0:
					continue  # lateral
				if d > 90.0:
					continue  # saque de arco
			for b in range(BANDAS.size() - 1):
				if d >= float(BANDAS[b]) and d < float(BANDAS[b + 1]):
					if not conteo.has(b):
						conteo[b] = {}
					conteo[b][tipo] = int(conteo[b].get(tipo, 0)) + 1
