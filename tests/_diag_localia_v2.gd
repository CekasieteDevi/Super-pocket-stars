extends SceneTree

## Medición de los modificadores de equipo (MatchEngine._bloques_equipo: local,
## forma, armonía, racha, familiaridad...) en cada motor. Mismos clubes y misma
## semilla en los tres. Mide la diferencia de gol del local y qué pasa cuando
## el local tiene `extra` puntos de armonía y racha a favor.
## Argumentos (después de `--`): `partidos=N` (300), `division=N` (4),
## `motor=v2|abstracto|espacial`, `armonia=X` (la del local; la del visitante,
## la opuesta), `racha=N` (la del local), `k=X` (pisa nivel.puntos_por_modificador
## de data/fisica_v2.json en memoria).

const SEED := 20261601


func _init() -> void:
	var partidos := 300
	var division := 4
	var motor := "v2"
	var armonia := NAN
	var racha := -1
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = int(p[1])
			"division": division = int(p[1])
			"motor": motor = p[1]
			"armonia": armonia = float(p[1])
			"racha": racha = int(p[1])
			"k": FisicaV2.datos()["nivel"]["puntos_por_modificador"] = float(p[1])
	var dif := 0.0
	var dif2 := 0.0
	var goles := 0.0
	var puntos := 0.0
	var ventaja := 0.0
	for n in partidos:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var home: Team = Team.generar("Local", rng, 0, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		var away: Team = Team.generar("Visitante", rng, 1000, NivelDivision.potencial(division), "Uruguay",
			NivelDivision.realizacion(division))
		if not is_nan(armonia):
			home.armonia = armonia
			away.armonia = -armonia
		if racha >= 0:
			home.racha = racha
			away.racha = 0
		var r: Dictionary
		match motor:
			"abstracto": r = MatchEngine.simular(home, away, rng)
			"espacial": r = _espacial(home, away, rng)
			_: r = MotorV2.simular(home, away, rng)
		# Con los equipos como quedaron armados para el partido (local, forma, clima).
		var azar := RandomNumberGenerator.new()
		azar.seed = SEED + n
		ventaja += MatchEngine.modificador_de_equipo(home, away, azar) - MatchEngine.modificador_de_equipo(away, home, azar)
		var d := float(int(r["goles_local"]) - int(r["goles_visitante"]))
		dif += d
		dif2 += d * d
		goles += float(int(r["goles_local"]) + int(r["goles_visitante"]))
		puntos += 3.0 if d > 0.0 else (1.0 if d == 0.0 else 0.0)
	var p := float(partidos)
	var media := dif / p
	var error := sqrt(maxf(dif2 / p - media * media, 0.0) / p)
	print("%s D%d armonia %s racha %d: dif del local %+.2f ± %.2f, puntos del local %.2f, goles %.2f, modificador del local %+.1f puntos de duelo (%d partidos)" % [
		motor, division + 1, "normal" if is_nan(armonia) else "%+.0f" % armonia, racha, media, error, puntos / p, goles / p, ventaja / p, partidos])
	quit()


func _espacial(home: Team, away: Team, rng: RandomNumberGenerator) -> Dictionary:
	var script: GDScript = load("res://core/motor_espacial.gd")
	return script.simular(home, away, rng)
