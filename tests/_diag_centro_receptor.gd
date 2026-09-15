extends SceneTree

## A quien le cuelga el centro el que centra, y que sale segun el receptor.
## Cada centro de juego abierto se sigue hasta que cae: si lo gana el que
## ataca, si termina en cabezazo y si termina en gol.

const SEED := 4400
const PARTIDOS := 60
## Cuatro segundos: el centro vuela y el cabezazo tarda en llegar al arco.
const TICKS_SEGUIMIENTO := 16


func _init() -> void:
	var t := {"por_rol": {}, "goles": 0, "centros": 0}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		_correr(casa, visita, r2, t)
	print("centros de juego abierto: %.2f por partido" % [float(t["centros"]) / PARTIDOS])
	for rol in t["por_rol"]:
		var r: Dictionary = t["por_rol"][rol]
		var n: int = maxi(int(r["n"]), 1)
		print("  a %-4s %4.0f%%  ganado %3.0f%%  cabezazo %3.0f%%  gol %3.0f%%  presion %.2f  aereo %.0f  |y| %.1f" % [
			rol, 100.0 * r["n"] / maxf(t["centros"], 1), 100.0 * r["ganado"] / n, 100.0 * r["cabezazo"] / n,
			100.0 * r["gol"] / n, r["presion"] / n, r["aereo"] / n, r["y"] / n])
	print("goles por partido: %.2f" % [float(t["goles"]) / PARTIDOS])
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
	var pendientes := []
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		for _k in range(MotorEspacial.TICKS_POR_MITAD):
			var ganados_antes := int(estado["centros"].get("ganados", 0))
			var cabezazos_antes := int(estado["centros"].get("cabezazos", 0))
			var goles_antes := home.goles + away.goles
			estado["ultima_decision"] = {}
			MotorEspacial._tick(estado, false)
			for p in pendientes:
				var r: Dictionary = t["por_rol"][p["rol"]]
				if int(estado["centros"].get("ganados", 0)) > ganados_antes and not p.has("ganado"):
					p["ganado"] = true
					r["ganado"] += 1
				if int(estado["centros"].get("cabezazos", 0)) > cabezazos_antes and not p.has("cabezazo"):
					p["cabezazo"] = true
					r["cabezazo"] += 1
				if home.goles + away.goles > goles_antes and not p.has("gol"):
					p["gol"] = true
					r["gol"] += 1
			var siguen := []
			for p in pendientes:
				if int(estado["tick"]) - int(p["tick"]) < TICKS_SEGUIMIENTO:
					siguen.append(p)
			pendientes = siguen

			var d = estado.get("ultima_decision", {})
			if d == null or d.is_empty() or str(d["tipo"]) != "centro":
				continue
			var obj := int(estado["pelota"].get("destino_id", -1))
			if obj == -1:
				continue
			var e: Dictionary = estado["jugadores"][obj]
			var rol := str(e["rol"])
			var r: Dictionary = t["por_rol"].get(rol, {"n": 0, "ganado": 0, "cabezazo": 0, "gol": 0,
				"presion": 0.0, "aereo": 0.0, "y": 0.0})
			r["n"] += 1
			r["presion"] += MotorEspacial.presion_normalizada(estado, e["pos"], e["equipo_local"])
			var equipo: Team = home if e["equipo_local"] else away
			var j := MotorEspacial._dict_jugador(estado, equipo, e["jugador_id"])
			r["aereo"] += float(j["atributos"]["cabezazo"]) * 0.6 + float(j["atributos"]["salto"]) * 0.4
			r["y"] += absf(e["pos"].y)
			t["por_rol"][rol] = r
			t["centros"] += 1
			pendientes.append({"rol": rol, "tick": estado["tick"]})
	t["goles"] += home.goles + away.goles
