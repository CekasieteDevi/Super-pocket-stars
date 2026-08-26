extends SceneTree

## Cuanto mueve el foco de equipo. Misma liga, misma semilla, corrida una
## vez por area: interesa que cada area suba LO SUYO y baje el resto, y
## que ninguna sea gratis ni dominante.

const TEMPORADAS := 4
const DIVISION := 4


func _init() -> void:
	print("=== %d temporadas, liga entera, un area por corrida ===" % TEMPORADAS)
	print("area          | media | fisicos | tecnicos | defensivos | mentales | pel.parada")
	for area in FocoEquipo.AREAS:
		var r := _correr(area)
		print("%-13s | %+5.2f | %+7.2f | %+8.2f | %+10.2f | %+8.2f | %+9.2f" % [
			FocoEquipo.ETIQUETAS[area], r["media"], r["fisico"], r["tecnico"],
			r["defensivo"], r["tactico"], r["pelota_parada"]])
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


func _correr(area: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[DIVISION]
	for e in liga.equipos:
		e.foco_equipo = area

	var antes := {}
	for a in FocoEquipo.AREAS:
		if a != FocoEquipo.GENERAL:
			antes[a] = _promedio(liga, FocoEquipo.atributos_de(a))
	var media0 := 0.0
	for e in liga.equipos:
		media0 += e.media_equipo()
	media0 /= float(liga.equipos.size())

	for t in range(TEMPORADAS):
		for fecha in range(liga.fixture.size()):
			liga.jugar_fecha(fecha, rng, null)
			liga.avanzar_dias(7)
		for e in liga.equipos:
			var mult := FocoEquipo.multiplicadores(e.reparto_foco(), PlayerGenerator.get_all_attributes())
			for j in e.todos_los_jugadores():
				Progresion.aplicar_temporada(j, rng, 1.0,
					Instalaciones.factor_entrenamiento(e) * e.factor_carga_temporada(), "", mult)
			e.reiniciar_carga()

	var r := {}
	for a in antes:
		r[a] = _promedio(liga, FocoEquipo.atributos_de(a)) - antes[a]
	var media1 := 0.0
	for e in liga.equipos:
		media1 += e.media_equipo()
	media1 /= float(liga.equipos.size())
	r["media"] = media1 - media0
	return r
