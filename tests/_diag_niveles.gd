extends SceneTree

## ¿La calibración del motor espacial vale para cualquier nivel de equipo,
## o solo para el que salió por casualidad en el demo? Mide goles/remates
## a distintas medias de plantel, y ademas con equipos DESPAREJOS, que es
## el caso que mas se da en una liga real.

const N := 20


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	# Primero: que media tienen los equipos que usa el demo (los mismos
	# que genera Liga.inicializar para cualquier division).
	var medias := []
	for i in range(30):
		var t := Team.generar("X%d" % i, rng)
		medias.append(_media_equipo(t))
	medias.sort()
	var suma := 0.0
	for m in medias:
		suma += m
	print("=== Equipos que genera Liga.inicializar (los del demo) ===")
	print("media de plantel: promedio %.1f, minimo %.1f, maximo %.1f" % [
		suma / medias.size(), medias[0], medias[-1]])

	print("\n=== Mismo nivel en los dos equipos ===")
	for objetivo in [35, 50, 65, 80]:
		_probar(rng, objetivo, objetivo)

	print("\n=== Desparejos (el caso normal en una liga) ===")
	_probar(rng, 45, 65)
	_probar(rng, 40, 75)

	# LA comparacion que importa: el partido del jugador lo resuelve el
	# motor espacial y los del resto de la liga el abstracto. Si dan
	# numeros distintos, la tabla del jugador queda con otra escala de
	# goles a favor/en contra que la de sus rivales.
	# El caso de verdad: equipos naturales, los que arma Liga.inicializar.
	print("\n=== Espacial vs abstracto con equipos NATURALES (el caso real) ===")
	var ge := 0
	var ga := 0
	var te := 0
	var ta := 0
	for i in range(40):
		var s := 7000 + i
		var r1 := RandomNumberGenerator.new()
		r1.seed = s
		var h1 := Team.generar("H", r1, 0)
		var a1 := Team.generar("A", r1, 1000)
		var re := MotorEspacial.simular(h1, a1, r1, false)
		ge += int(re["goles_local"]) + int(re["goles_visitante"])
		te += int(re["stats"]["tiros"]["home"]) + int(re["stats"]["tiros"]["away"])

		var r2 := RandomNumberGenerator.new()
		r2.seed = s
		var h2 := Team.generar("H", r2, 0)
		var a2 := Team.generar("A", r2, 1000)
		var ra := MatchEngine.simular(h2, a2, r2, false)
		ga += int(ra["goles_local"]) + int(ra["goles_visitante"])
	print("  espacial %.2f goles (%.1f remates) | abstracto %.2f goles" % [
		float(ge) / 40.0, float(te) / 40.0, float(ga) / 40.0])

	print("\n=== Espacial vs abstracto (mismos equipos, misma semilla) ===")
	for objetivo in [40, 55, 70]:
		var g_esp := 0
		var g_abs := 0
		for i in range(N):
			var s := 5000 + i
			var r1 := RandomNumberGenerator.new()
			r1.seed = s
			var h1 := Team.generar("H", r1, 0, objetivo)
			var a1 := Team.generar("A", r1, 1000, objetivo)
			var re := MotorEspacial.simular(h1, a1, r1, false)
			g_esp += int(re["goles_local"]) + int(re["goles_visitante"])

			var r2 := RandomNumberGenerator.new()
			r2.seed = s
			var h2 := Team.generar("H", r2, 0, objetivo)
			var a2 := Team.generar("A", r2, 1000, objetivo)
			var ra := MatchEngine.simular(h2, a2, r2, false)
			g_abs += int(ra["goles_local"]) + int(ra["goles_visitante"])
		print("  potencial %d -> espacial %.2f goles | abstracto %.2f goles" % [
			objetivo, float(g_esp) / N, float(g_abs) / N])


static func _media_equipo(t: Team) -> float:
	var suma := 0.0
	for j in t.jugadores:
		suma += float(j["media"])
	return suma / t.jugadores.size()


func _probar(rng: RandomNumberGenerator, pot_home: int, pot_away: int) -> void:
	var goles_h := 0
	var goles_a := 0
	var tiros := 0
	var pases := 0
	var intentos := 0
	var media_h := 0.0
	var media_a := 0.0
	for i in range(N):
		var home := Team.generar("H%d" % i, rng, 0, pot_home)
		var away := Team.generar("A%d" % i, rng, 1000, pot_away)
		media_h += _media_equipo(home)
		media_a += _media_equipo(away)
		var r := MotorEspacial.simular(home, away, rng, false)
		goles_h += int(r["goles_local"])
		goles_a += int(r["goles_visitante"])
		var s: Dictionary = r["stats"]
		tiros += int(s["tiros"]["home"]) + int(s["tiros"]["away"])
		pases += int(s["pases"]["home"]) + int(s["pases"]["away"])
		intentos += int(s["pase_detalle"]["intentos"])
	var acierto: float = float(pases) / maxf(intentos, 1) * 100.0
	print("  media %.0f vs %.0f -> %.2f-%.2f goles (%.2f total) | %.1f remates | %.0f pases al %.0f%%" % [
		media_h / N, media_a / N,
		float(goles_h) / N, float(goles_a) / N, float(goles_h + goles_a) / N,
		float(tiros) / N, float(pases) / N, acierto])
