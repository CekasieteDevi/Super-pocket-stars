extends SceneTree

## ¿El ánimo hace bola de nieve? Ganar sube el ánimo y, si el ánimo
## entra al duelo (Motivacion.modificador), el ánimo alto ayuda a ganar.
## Si el lazo se cierra, los de arriba se despegan y los de abajo se
## hunden: la tabla se estira y el ánimo se clava en los extremos.
##
## Se mide lo mismo antes y después de tocar: cuánto se separa el
## primero del último, el desvío de los puntos, y dónde termina el ánimo
## de los tres de arriba y los tres de abajo.

const SEED := 2026
const DIVISIONES := [0, 4, 9]
const SEMILLAS := 4


func _init() -> void:
	for div in DIVISIONES:
		var brecha := 0.0
		var desvio := 0.0
		var animo_arriba := 0.0
		var animo_abajo := 0.0
		var clavados_arriba := 0.0
		var hundidos := 0.0
		var total_jugadores := 0.0
		for s in range(SEMILLAS):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + s
			var piramide := Piramide.generar(rng)
			var liga: Liga = piramide.divisiones[div]
			for fecha in range(liga.fixture.size()):
				liga.jugar_fecha(fecha, rng, null)
				liga.avanzar_dias(7)

			var orden: Array = liga.tabla_ordenada()
			var pts: Array = []
			for nombre in orden:
				pts.append(float(liga.tabla[nombre]["pts"]))
			brecha += pts[0] - pts[pts.size() - 1]
			desvio += _desvio(pts)
			animo_arriba += _animo_promedio(liga, orden.slice(0, 3))
			animo_abajo += _animo_promedio(liga, orden.slice(orden.size() - 3))
			for e in liga.equipos:
				for j in e.todos_los_jugadores():
					var a: float = e.animo.get(j["id"], 50.0)
					total_jugadores += 1.0
					if a >= 90.0:
						clavados_arriba += 1.0
					if a <= AgentesLibres.ANIMO_DE_RUPTURA:
						hundidos += 1.0
		print("division %d | brecha 1ro-ultimo %.1f pts | desvio %.2f | animo top3 %.1f | animo bottom3 %.1f | >=90: %.1f%% | <=25: %.1f%%" % [
			div + 1, brecha / SEMILLAS, desvio / SEMILLAS,
			animo_arriba / SEMILLAS, animo_abajo / SEMILLAS,
			100.0 * clavados_arriba / total_jugadores, 100.0 * hundidos / total_jugadores])
	quit()


func _desvio(valores: Array) -> float:
	var media := 0.0
	for v in valores:
		media += v
	media /= valores.size()
	var suma := 0.0
	for v in valores:
		suma += (v - media) * (v - media)
	return sqrt(suma / valores.size())


func _animo_promedio(liga: Liga, nombres: Array) -> float:
	var total := 0.0
	var n := 0.0
	for e in liga.equipos:
		if not nombres.has(e.nombre):
			continue
		for j in e.todos_los_jugadores():
			total += e.animo.get(j["id"], 50.0)
			n += 1.0
	return total / maxf(n, 1.0)
