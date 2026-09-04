extends SceneTree

## Desde donde se le pega al arco en un tiro libre, y con que `tiros_libres`
## lo hace el que patea.
##
## La pregunta: el atributo tiene que decidir el ALCANCE. Un pateador de
## 99 se anima desde lejos; uno de 1 solo desde el borde del area. Si la
## decision no lo mira, los dos patean desde la misma distancia.

const SEED := 4400
const PARTIDOS := 40
const BANDAS := [0.0, 25.0, 50.0, 75.0, 101.0]


func _init() -> void:
	var directos := 0
	var dist_total := 0.0
	var dist_max := 0.0
	var por_banda := {}
	var centros := 0
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := _correr(casa, visita, r2, por_banda)
		directos += int(res[0])
		dist_total += res[1]
		dist_max = maxf(dist_max, res[2])
		centros += int(res[3])
	print("libres directos: %.2f por partido (los dos equipos), a %.1f m de media, maximo %.1f m" % [
		float(directos) / PARTIDOS, dist_total / maxf(float(directos), 1.0), dist_max])
	print("centros de falta: %.2f por partido" % [float(centros) / PARTIDOS])
	print("  quien patea el directo, por su `tiros_libres`:")
	for b in range(BANDAS.size() - 1):
		var fila: Array = por_banda.get(b, [0, 0.0])
		if int(fila[0]) == 0:
			continue
		print("    attr %3.0f-%3.0f | %3d patadas | desde %.1f m de media" % [
			BANDAS[b], BANDAS[b + 1], int(fila[0]), float(fila[1]) / float(fila[0])])
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator, por_banda: Dictionary) -> Array:
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
	var n := 0
	var suma := 0.0
	var maxima := 0.0
	var centros := 0
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
			var tipo := str(bp["tipo"])
			if tipo == "centro":
				centros += 1
				continue
			if tipo != "directo":
				continue
			var ataca: bool = bool(bp["ataca_local"])
			var d: float = float(bp["pos"].distance_to(MotorEspacial.arco_rival(ataca)))
			n += 1
			suma += d
			maxima = maxf(maxima, d)
			# Con que atributo lo patea.
			var ej := int(bp.get("ejecutor", -1))
			if not estado["jugadores"].has(ej):
				continue
			var eq := MotorEspacial._equipo_de(estado, ataca)
			var j := MotorEspacial._dict_jugador(estado, eq, estado["jugadores"][ej]["jugador_id"])
			if j.is_empty():
				continue
			var attr: float = float(j["atributos"]["tiros_libres"])
			for b in range(BANDAS.size() - 1):
				if attr >= float(BANDAS[b]) and attr < float(BANDAS[b + 1]):
					if not por_banda.has(b):
						por_banda[b] = [0, 0.0]
					por_banda[b][0] = int(por_banda[b][0]) + 1
					por_banda[b][1] = float(por_banda[b][1]) + d
	return [n, suma, maxima, centros]
