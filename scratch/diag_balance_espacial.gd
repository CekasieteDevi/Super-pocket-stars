extends SceneTree

## Barrido corto del motor visible. Mismos planteles, ida y vuelta y semilla.

const MUESTRAS := 100
const SEMILLA := 271000
const FORMACION := "4-2-3-1"
const CRUCES := [
	["Tiki taka", "Presión alta"],
	["Contragolpe", "Presión alta"],
	["Contragolpe", "Defensivo"],
]

func _init() -> void:
	print("motor=espacial muestras=%d cruces=%d" % [MUESTRAS, CRUCES.size()])
	print("A vs B | goles A | goles B | dif A-B | vict A | empates | vict B")
	for cruce in CRUCES:
		_medir(str(cruce[0]), str(cruce[1]))
	quit()

func _par(semilla: int, estilo_a: String, estilo_b: String, a_local: bool) -> Dictionary:
	var rng_equipos := RandomNumberGenerator.new()
	rng_equipos.seed = semilla
	var a := Team.generar("A", rng_equipos, 0)
	var b := Team.cargar(a.guardar())
	b.nombre = "B"
	b.abreviacion = "B"
	for equipo in [a, b]:
		equipo.formacion = FORMACION
		equipo.familiaridad = {}
	a.familiaridad[Familiaridad.clave(FORMACION, estilo_a)] = 100.0
	b.familiaridad[Familiaridad.clave(FORMACION, estilo_b)] = 100.0
	a.estilo = estilo_a
	b.estilo = estilo_b
	a.local = a_local
	b.local = not a_local
	var rng_partido := RandomNumberGenerator.new()
	rng_partido.seed = semilla * 19
	var home: Team = a if a_local else b
	var away: Team = b if a_local else a
	var r := MotorEspacial.simular(home, away, rng_partido, false)
	return {
		"a": int(r["goles_local"] if a_local else r["goles_visitante"]),
		"b": int(r["goles_visitante"] if a_local else r["goles_local"]),
	}

func _medir(a: String, b: String) -> void:
	var ga := 0
	var gb := 0
	var va := 0
	var e := 0
	var vb := 0
	for i in range(MUESTRAS):
		for r in [_par(SEMILLA + i, a, b, true), _par(SEMILLA + i, a, b, false)]:
			ga += int(r["a"])
			gb += int(r["b"])
			if int(r["a"]) > int(r["b"]): va += 1
			elif int(r["a"]) < int(r["b"]): vb += 1
			else: e += 1
	var n := MUESTRAS * 2
	print("%-14s vs %-14s | %.3f | %.3f | %+.3f | %3d | %3d | %3d" % [
		a, b, float(ga) / n, float(gb) / n, float(ga - gb) / n, va, e, vb])
