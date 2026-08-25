extends SceneTree

## Comparacion pareada: la MITAD de la liga entrena en A y la otra mitad
## en B, mismo fixture y misma semilla. Se comparan los puntos promedio
## de cada grupo. Con 10 equipos por grupo y varias temporadas el ruido
## baja a algo legible, cosa que un solo equipo nunca da.
##
## Se corre dos veces con los grupos invertidos para que la fuerza inicial
## de los equipos (unos son mejores que otros) se cancele.

const TEMPORADAS := 4
const DIVISION := 4


func _init() -> void:
	var a := "brutal"
	var b := "recuperacion"
	print("=== %s vs %s, %d temporadas, grupos invertidos ===" % [a, b, TEMPORADAS])
	var d1 := _correr(a, b)
	var d2 := _correr(b, a)
	# d1: pares=A, impares=B. d2: pares=B, impares=A.
	var pts_a: float = (d1["pares_pts"] + d2["impares_pts"]) / 2.0
	var pts_b: float = (d1["impares_pts"] + d2["pares_pts"]) / 2.0
	var les_a: float = (d1["pares_les"] + d2["impares_les"]) / 2.0
	var les_b: float = (d1["impares_les"] + d2["pares_les"]) / 2.0
	var med_a: float = (d1["pares_med"] + d2["impares_med"]) / 2.0
	var med_b: float = (d1["impares_med"] + d2["pares_med"]) / 2.0
	print("%-14s | puntos/temp %6.2f | lesiones/temp %5.2f | media final %+.2f" % [a, pts_a, les_a, med_a])
	print("%-14s | puntos/temp %6.2f | lesiones/temp %5.2f | media final %+.2f" % [b, pts_b, les_b, med_b])
	print("diferencia     | puntos %+.2f | lesiones %+.2f | media %+.2f" % [
		pts_a - pts_b, les_a - les_b, med_a - med_b])
	quit()


func _correr(carga_pares: String, carga_impares: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[DIVISION]
	for i in range(liga.equipos.size()):
		liga.equipos[i].carga_entrenamiento = carga_pares if i % 2 == 0 else carga_impares

	var media0 := {}
	for e in liga.equipos:
		media0[e.nombre] = e.media_equipo()
	var pts := {}
	var les := {}
	var activas := {}
	for e in liga.equipos:
		pts[e.nombre] = 0.0
		les[e.nombre] = 0.0
		activas[e.nombre] = {}

	for t in range(TEMPORADAS):
		for fecha in range(liga.fixture.size()):
			liga.jugar_fecha(fecha, rng, null)
			for e in liga.equipos:
				var prev: Dictionary = activas[e.nombre]
				for id in e.lesiones:
					if not prev.has(id):
						les[e.nombre] += 1.0
				var ahora := {}
				for id in e.lesiones:
					ahora[id] = true
				activas[e.nombre] = ahora
			if (fecha + 1) % 4 == 0:
				liga.avanzar_dias(3)
				liga.avanzar_dias(4)
			else:
				liga.avanzar_dias(7)
		for e in liga.equipos:
			pts[e.nombre] += float(liga.tabla[e.nombre]["pts"])
			for j in e.todos_los_jugadores():
				Progresion.aplicar_temporada(j, rng, 1.0,
					Instalaciones.factor_entrenamiento(e) * e.factor_carga_temporada())
			e.liberar_veteranos_de_cantera()
			e.generar_camada(rng, Instalaciones.cantidad_camada(e))
			e.reiniciar_carga()
			e.recalcular_capitan()
		for nombre in liga.tabla:
			liga.tabla[nombre]["pts"] = 0

	var r := {"pares_pts": 0.0, "impares_pts": 0.0, "pares_les": 0.0, "impares_les": 0.0,
		"pares_med": 0.0, "impares_med": 0.0}
	var n := 0.0
	for i in range(liga.equipos.size()):
		var e: Team = liga.equipos[i]
		var k := "pares" if i % 2 == 0 else "impares"
		r[k + "_pts"] += pts[e.nombre]
		r[k + "_les"] += les[e.nombre]
		r[k + "_med"] += e.media_equipo() - media0[e.nombre]
		if i % 2 == 0:
			n += 1.0
	for k in r:
		r[k] = r[k] / n / (float(TEMPORADAS) if k.ends_with("_pts") or k.ends_with("_les") else 1.0)
	return r
