extends SceneTree

## Quien pierde plata y por que. Interesa sobre todo el club que DESCIENDE
## de una division cara a una barata con el plantel puesto.

const TEMPORADAS := 6


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var p := Piramide.generar(rng)
	for t in range(TEMPORADAS):
		for liga in p.divisiones:
			for fecha in range(liga.fixture.size()):
				liga.jugar_fecha(fecha, rng, null)
				liga.avanzar_dias(7)
		p.fin_de_temporada(rng, null, t)

	print("=== Temporada %d: neto por club ===" % TEMPORADAS)
	print("div | en rojo | neto medio | peor neto | sueldos medios | ingresos medios")
	for d in range(p.divisiones.size()):
		var liga: Liga = p.divisiones[d]
		var rojo := 0
		var suma := 0.0
		var peor := 0.0
		var sueldos := 0.0
		var ingresos := 0.0
		for i in range(liga.equipos.size()):
			var e: Team = liga.equipos[i]
			var r := Economia.procesar_temporada(e, i + 1, liga.equipos.size(), liga.division)
			var neto: float = float(r["neto"])
			if neto < 0.0:
				rojo += 1
			suma += neto
			peor = minf(peor, neto)
			sueldos += float(r["sueldos"])
			ingresos += float(r["ingresos"])
		var n := float(liga.equipos.size())
		print("%3d | %7d | %10s | %9s | %14s | %s" % [
			d + 1, rojo, Economia.formato_dinero(suma / n), Economia.formato_dinero(peor),
			Economia.formato_dinero(sueldos / n), Economia.formato_dinero(ingresos / n)])
	quit()
