extends SceneTree

## Cuanto mueven los ejercicios el crecimiento. Misma liga, misma
## semilla, corrida una vez por combinacion: interesa que cada ejercicio
## suba LO SUYO y baje el resto, y que ninguno sea gratis ni dominante.

const TEMPORADAS := 4
const DIVISION := 4

const CORRIDAS := [
	["libre", "libre"],
	["correr", "libre"], ["rondo", "libre"], ["obstaculos", "libre"], ["gimnasio", "libre"],
	["libre", "penales"], ["libre", "tiros_libres"], ["libre", "centros"],
	["libre", "jugadas_armadas"], ["libre", "presion"],
	["correr", "presion"],
]


func _init() -> void:
	var grupos: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/attribute_groups.json"))
	print("=== %d temporadas, liga entera, una combinacion por corrida ===" % TEMPORADAS)
	print("ejercicios                   | media | propios | fisicos | tecnicos | defensivos | mentales")
	for par in CORRIDAS:
		var r := _correr(par, grupos)
		print("%-28s | %+5.2f | %+7.2f | %+7.2f | %+8.2f | %+10.2f | %+8.2f" % [
			"%s + %s" % par, r["media"], r["propios"], r["fisicos"], r["tecnicos"],
			r["defensivos"], r["mentales"]])
	quit()


func _promedio(liga: Liga, attrs: Array) -> float:
	var total := 0.0
	var n := 0.0
	for e in liga.equipos:
		for j in e.todos_los_jugadores():
			for a in attrs:
				total += float(j["atributos"][a])
				n += 1.0
	return total / max(1.0, n)


func _correr(par: Array, grupos: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[DIVISION]
	for e in liga.equipos:
		e.ejercicio_fisico = par[0]
		e.ejercicio_tactico = par[1]

	var medidos := {"propios": Entrenamiento.atributos_de(par[0]) + Entrenamiento.atributos_de(par[1])}
	for g in ["fisicos", "tecnicos", "defensivos", "mentales"]:
		medidos[g] = grupos[g]
	var antes := {}
	for k in medidos:
		antes[k] = _promedio(liga, medidos[k]) if not (medidos[k] as Array).is_empty() else 0.0
	var media0 := 0.0
	for e in liga.equipos:
		media0 += e.media_equipo()
	media0 /= float(liga.equipos.size())

	for t in range(TEMPORADAS):
		for fecha in range(liga.fixture.size()):
			liga.jugar_fecha(fecha, rng, null)
			liga.avanzar_dias(7)
		for e in liga.equipos:
			var mult := Entrenamiento.multiplicadores(e.reparto_ejercicios(), PlayerGenerator.get_all_attributes())
			for j in e.todos_los_jugadores():
				Progresion.aplicar_temporada(j, rng, 1.0,
					Instalaciones.factor_entrenamiento(e) * e.factor_carga_temporada(), mult)
			e.reiniciar_carga()

	var r := {}
	for k in medidos:
		r[k] = (_promedio(liga, medidos[k]) - antes[k]) if not (medidos[k] as Array).is_empty() else 0.0
	var media1 := 0.0
	for e in liga.equipos:
		media1 += e.media_equipo()
	media1 /= float(liga.equipos.size())
	r["media"] = media1 - media0
	return r
