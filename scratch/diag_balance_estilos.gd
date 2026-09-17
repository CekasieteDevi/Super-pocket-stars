extends SceneTree

## Barrido de balance de estilos.
## Compara cada par con planteles equivalentes, ida y vuelta y misma semilla.
## Usa MatchEngine para obtener una muestra grande sin mezclar movimiento con
## la ventaja explícita de la matriz de estilos.

const MUESTRAS := 200
const SEMILLA := 170000
const FORMACION := "4-2-3-1"

func _init() -> void:
	print("muestras=%d formacion=%s familiaridad=100" % [MUESTRAS, FORMACION])
	print("A vs B | dif goles A-B | goles A | goles B | vict A | empates | vict B | esperado")
	for i in range(Estilos.LISTA.size()):
		for j in range(i + 1, Estilos.LISTA.size()):
			_medir(Estilos.LISTA[i], Estilos.LISTA[j])
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
	# Misma semilla en ida y vuelta: el azar del partido se empareja.
	rng_partido.seed = semilla * 17
	var home: Team = a if a_local else b
	var away: Team = b if a_local else a
	var r := MatchEngine.simular(home, away, rng_partido, false)
	var goles_a: int = int(r["goles_local"] if a_local else r["goles_visitante"])
	var goles_b: int = int(r["goles_visitante"] if a_local else r["goles_local"])
	return {"a": goles_a, "b": goles_b}

func _esperado(a: String, b: String) -> String:
	var ma := Estilos.modificador(a, b)
	var mb := Estilos.modificador(b, a)
	if ma != 0.0 or mb != 0.0:
		return "%s %+.0f / %s %+.0f" % [a, ma, b, mb]
	return "neutro"

func _medir(a: String, b: String) -> void:
	var goles_a := 0
	var goles_b := 0
	var vict_a := 0
	var empates := 0
	var vict_b := 0
	for i in range(MUESTRAS):
		var ida := _par(SEMILLA + i, a, b, true)
		var vuelta := _par(SEMILLA + i, a, b, false)
		for r in [ida, vuelta]:
			goles_a += int(r["a"])
			goles_b += int(r["b"])
			if int(r["a"]) > int(r["b"]):
				vict_a += 1
			elif int(r["a"]) < int(r["b"]):
				vict_b += 1
			else:
				empates += 1
	var partidos := MUESTRAS * 2
	print("%-14s vs %-14s | %+.3f | %.3f | %.3f | %3d | %3d | %3d | %s" % [
		a, b, float(goles_a - goles_b) / partidos,
		float(goles_a) / partidos, float(goles_b) / partidos,
		vict_a, empates, vict_b, _esperado(a, b)])
