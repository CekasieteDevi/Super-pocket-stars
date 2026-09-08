extends SceneTree

## OJO: este diag midio la amortiguacion ANTES de que existiera en el
## motor. Hoy ValorJugador.media_salarial ya la aplica, asi que las
## columnas amortiguadas de aca la aplican DOS VECES y sus numeros ya no
## son los del juego. Queda por la historia de como se eligio el 0.35;
## para medir el estado actual usar tests/_diag_masa_salarial.gd.

## Barrido de la amortiguacion del sueldo contra la media FIJA de la
## division (NivelDivision.media_de). Mide masa salarial / ingresos en
## temporada 1 (donde la calibracion de hoy esta sana) y en la 7 (donde
## revienta). El valor bueno es el que deja la 7 parecida a la 1.

const SEED := 777
const TEMPORADAS := 6
const VALORES := [1.0, 0.5, 0.35, 0.25]


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	_reporte(piramide, "TEMPORADA 1")
	for t in range(TEMPORADAS):
		piramide.jugar_temporada(rng)
		piramide.fin_de_temporada(rng, null, t)
	_reporte(piramide, "TEMPORADA %d" % (TEMPORADAS + 1))
	quit()


func _reporte(piramide: Piramide, titulo: String) -> void:
	print("")
	print("=== %s — masa salarial como %% de los ingresos ===" % titulo)
	var cabecera := "div | media once |"
	for v in VALORES:
		cabecera += " amort %.2f |" % v
	print(cabecera + " crack (media, sueldo hoy -> amort 0.35)")
	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var suma_ing := 0.0
		var suma_media := 0.0
		var sumas := {}
		for v in VALORES:
			sumas[v] = 0.0
		var crack := {}
		var crack_sueldo := 0.0
		for i in range(n):
			var e: Team = liga.equipos[i]
			suma_ing += float(Economia.calcular_temporada(e, i + 1, n, d)["ingresos"])
			suma_media += e.media_equipo()
			for j in e.todos_los_jugadores():
				var s := Economia.sueldo_de_ficha(j, 3)
				for v in VALORES:
					sumas[v] += _amortiguado(j, 3, d, float(v))
				if s > crack_sueldo:
					crack_sueldo = s
					crack = j
		var fila := "%3d | %10.1f |" % [d + 1, suma_media / n]
		for v in VALORES:
			fila += " %8.0f%% |" % (sumas[v] / suma_ing * 100.0)
		print(fila + " media %d, %s -> %s" % [
			int(crack["media"]), Economia.formato_dinero(crack_sueldo),
			Economia.formato_dinero(_amortiguado(crack, 3, d, 0.35))])


func _amortiguado(jugador: Dictionary, anios: int, division: int, k: float) -> float:
	var ref: float = NivelDivision.media_de(division)
	var media: float = float(jugador["media"])
	if media <= ref or k >= 1.0:
		return Economia.sueldo_de_ficha(jugador, anios)
	var copia := jugador.duplicate()
	copia["media"] = ref + (media - ref) * k
	return Economia.sueldo_de_ficha(copia, anios)
