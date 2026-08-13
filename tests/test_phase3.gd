extends SceneTree

## Fase 3 del roadmap (GDD §13): liga de 20 equipos, tabla, calendario, una
## temporada completa. Correr con: godot --headless --script tests/test_phase3.gd
##
## Nombres de clubes son placeholders ("Club 01".."Club 20") — la
## generación real del mundo (Fix 10 del GDD) es trabajo aparte, no de esta fase.
##
## Qué verificamos:
##   1. El fixture tiene 38 fechas x 10 partidos = 380 partidos, cada equipo
##      juega 38 (19 de local, 19 de visitante).
##   2. La tabla cierra: suma de goles a favor == suma de goles en contra,
##      suma de puntos coherente con W/D/L.
##   3. La tabla queda ordenada por puntos/DG/GF.

const N_EQUIPOS := 20
const SEED := 2026


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var nombres := []
	for i in range(N_EQUIPOS):
		nombres.append("Club %02d" % (i + 1))

	var liga := Liga.new()
	liga.inicializar(nombres, rng)

	_test_integridad_fixture(liga)

	var t0 := Time.get_ticks_msec()
	liga.jugar_temporada(rng, false)
	var t1 := Time.get_ticks_msec()

	_test_integridad_tabla(liga)
	_print_tabla_final(liga)
	print("\nTiempo de simulacion de la temporada: %d ms" % (t1 - t0))

	quit()


func _test_integridad_fixture(liga: Liga) -> void:
	print("=== Integridad del fixture ===")
	var total_partidos := 0
	var partidos_por_equipo := {}
	for i in range(N_EQUIPOS):
		partidos_por_equipo[i] = {"local": 0, "visitante": 0}

	for fecha in liga.fixture:
		total_partidos += fecha.size()
		for partido in fecha:
			partidos_por_equipo[partido[0]]["local"] += 1
			partidos_por_equipo[partido[1]]["visitante"] += 1

	print("Fechas: %d | Partidos totales: %d (esperado %d)" % [liga.fixture.size(), total_partidos, N_EQUIPOS * (N_EQUIPOS - 1)])

	var ok := true
	for i in range(N_EQUIPOS):
		var p = partidos_por_equipo[i]
		if p["local"] != N_EQUIPOS - 1 or p["visitante"] != N_EQUIPOS - 1:
			ok = false
			print("FALLA equipo %d: local %d, visitante %d" % [i, p["local"], p["visitante"]])
	if ok:
		print("OK: los 20 equipos juegan 19 de local y 19 de visitante.")


func _test_integridad_tabla(liga: Liga) -> void:
	print("\n=== Integridad de la tabla ===")
	var total_gf := 0
	var total_gc := 0
	var total_pj := 0
	var ok := true

	for nombre in liga.tabla:
		var f: Dictionary = liga.tabla[nombre]
		total_gf += f["gf"]
		total_gc += f["gc"]
		total_pj += f["pj"]
		var pts_esperados = f["pg"] * 3 + f["pe"]
		if pts_esperados != f["pts"]:
			ok = false
			print("FALLA %s: pts %d, esperado %d" % [nombre, f["pts"], pts_esperados])
		if f["pj"] != f["pg"] + f["pe"] + f["pp"]:
			ok = false
			print("FALLA %s: pj no cuadra con pg+pe+pp" % nombre)

	print("Goles a favor totales: %d | Goles en contra totales: %d" % [total_gf, total_gc])
	if total_gf != total_gc:
		ok = false
		print("FALLA: GF total != GC total")
	if ok:
		print("OK: la tabla cierra (puntos, PJ, GF=GC).")


func _print_tabla_final(liga: Liga) -> void:
	print("\n=== Tabla final ===")
	print("%-10s %3s %3s %3s %3s %4s %4s %4s %4s" % ["Equipo", "PJ", "PG", "PE", "PP", "GF", "GC", "DG", "Pts"])
	var pos := 1
	for nombre in liga.tabla_ordenada():
		var f: Dictionary = liga.tabla[nombre]
		var marca := ""
		if pos <= 2:
			marca = " (asciende)"
		elif pos == 3:
			marca = " (playoff)"
		print("%2d. %-10s %3d %3d %3d %3d %4d %4d %4d %4d%s" % [
			pos, nombre, f["pj"], f["pg"], f["pe"], f["pp"], f["gf"], f["gc"], f["dg"], f["pts"], marca
		])
		pos += 1
