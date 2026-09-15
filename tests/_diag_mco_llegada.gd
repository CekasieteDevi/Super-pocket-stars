extends SceneTree

## Con la pelota abierta en el ultimo tramo, ¿por que el MCO y el 9 no estan
## en el area? Separa donde los pone el ancla de su rol, adonde apunta el
## desmarque que les repartio el equipo y donde estan de verdad.

const SEED := 4400
const PARTIDOS := 20


func _init() -> void:
	var t := {}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		_correr(casa, visita, r2, t)
	for rol in t:
		var r: Dictionary = t[rol]
		var n: int = maxi(int(r["n"]), 1)
		print("%s (%d ticks): ancla a %.1f m, desmarque a %.1f m, esta a %.1f m del fondo" % [
			rol, n, r["ancla"] / n, r["plan"] / maxf(r["n_plan"], 1), r["pos"] / n])
		print("  planes: %s" % str(r["tipos"]))
	quit()


func _correr(home: Team, away: Team, rng: RandomNumberGenerator, t: Dictionary) -> void:
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
		for _k in range(MotorEspacial.TICKS_POR_MITAD):
			MotorEspacial._tick(estado, false)
			var quien: int = int(estado["pelota"].get("poseedor_id", -1))
			if quien == -1 or not estado["jugadores"].has(quien):
				continue
			var q: Dictionary = estado["jugadores"][quien]
			var local: bool = q["equipo_local"]
			var arco := MotorEspacial.arco_rival(local)
			if absf(q["pos"].y) < 11.0 or absf(arco.x - q["pos"].x) >= MotorEspacial.ULTIMO_TRAMO_BANDA:
				continue
			for id in estado["jugadores"]:
				var e: Dictionary = estado["jugadores"][id]
				if e["equipo_local"] != local or not e["rol"] in ["MCO", "DC"]:
					continue
				var equipo: Team = home if local else away
				var ancla: Dictionary = MotorEspacial._ancla_de_rol(estado, e, equipo, true)
				var r: Dictionary = t.get(e["rol"], {"n": 0, "ancla": 0.0, "plan": 0.0, "n_plan": 0, "pos": 0.0, "tipos": {}})
				r["n"] += 1
				r["ancla"] += absf(arco.x - ancla["punto"].x)
				r["pos"] += absf(arco.x - e["pos"].x)
				var plan: Dictionary = estado.get("desmarques", {}).get(id, {})
				var tipo := "ninguno"
				if not plan.is_empty():
					tipo = str(plan["tipo"])
					for marca in ["pase_atras", "relevo_nueve", "nueve_baja", "diagonal_extremo"]:
						if bool(plan.get(marca, false)):
							tipo += "+" + marca
					r["plan"] += absf(arco.x - plan["destino"].x)
					r["n_plan"] += 1
				r["tipos"][tipo] = int(r["tipos"].get(tipo, 0)) + 1
				t[e["rol"]] = r
