extends SceneTree

## OJO: este diag midio la amortiguacion ANTES de que existiera en el
## motor. Hoy ValorJugador.media_salarial ya la aplica, asi que las
## columnas amortiguadas de aca la aplican DOS VECES y sus numeros ya no
## son los del juego. Queda por la historia de como se eligio el 0.35;
## para medir el estado actual usar tests/_diag_masa_salarial.gd.

## ¿Amortiguar el sueldo contra la media de la division rompe el balance
## que ya esta calibrado? Mide masa salarial contra ingresos en las diez
## divisiones, con la formula de hoy y con la amortiguada, en temporada 1
## y despues de SEIS temporadas de progresion.

const SEED := 777
const AMORTIGUACION := 0.5
const TEMPORADAS := 6


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	_reporte(piramide, "TEMPORADA 1 (recien generada)")
	for t in range(TEMPORADAS):
		piramide.jugar_temporada(rng)
		piramide.fin_de_temporada(rng, null, t)
	_reporte(piramide, "TEMPORADA %d" % (TEMPORADAS + 1))
	quit()


func _reporte(piramide: Piramide, titulo: String) -> void:
	print("")
	print("=== %s ===" % titulo)
	print("div | media once | ingresos | sueldos hoy | %ing | amort ref fija | %ing | amort ref viva | %ing | mas caro hoy | fija | viva")
	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var suma_ing := 0.0
		var suma_hoy := 0.0
		var suma_amort := 0.0
		var suma_media := 0.0
		var arriba := 0
		var total := 0
		var caro_hoy := 0.0
		var caro_amort := 0.0
		var caro_vivo := 0.0
		var suma_vivo := 0.0
		# Ref VIVA: la media real del plantel promedio de la division esta
		# temporada, no la constante de generacion. Asi la inflacion de
		# media que trae la progresion no infla la masa salarial: lo que se
		# paga es destacar sobre tu categoria, no un numero absoluto.
		var ref_viva := 0.0
		var cuenta_ref := 0
		for e0 in liga.equipos:
			for j0 in e0.todos_los_jugadores():
				ref_viva += float(j0["media"])
				cuenta_ref += 1
		ref_viva /= maxf(float(cuenta_ref), 1.0)
		for i in range(n):
			var e: Team = liga.equipos[i]
			var informe := Economia.calcular_temporada(e, i + 1, n, d)
			suma_ing += float(informe["ingresos"])
			suma_media += e.media_equipo()
			for j in e.todos_los_jugadores():
				var hoy := Economia.sueldo_de_ficha(j, 3)
				var amort := _amortiguado(j, 3, d)
				var vivo := _con_ref(j, 3, ref_viva)
				suma_hoy += hoy
				suma_amort += amort
				suma_vivo += vivo
				total += 1
				if float(j["media"]) > NivelDivision.media_de(d):
					arriba += 1
				if hoy > caro_hoy:
					caro_hoy = hoy
					caro_amort = amort
					caro_vivo = vivo
		print("%3d | %10.1f | %8s | %11s | %3.0f%% | %14s | %3.0f%% | %14s | %3.0f%% | %12s | %s | %s" % [
			d + 1, suma_media / n,
			Economia.formato_dinero(suma_ing / n),
			Economia.formato_dinero(suma_hoy / n), suma_hoy / suma_ing * 100.0,
			Economia.formato_dinero(suma_amort / n), suma_amort / suma_ing * 100.0,
			Economia.formato_dinero(suma_vivo / n), suma_vivo / suma_ing * 100.0,
			Economia.formato_dinero(caro_hoy), Economia.formato_dinero(caro_amort),
			Economia.formato_dinero(caro_vivo)])


func _amortiguado(jugador: Dictionary, anios: int, division: int) -> float:
	var ref: float = NivelDivision.media_de(division)
	var media: float = float(jugador["media"])
	if media <= ref:
		return Economia.sueldo_de_ficha(jugador, anios)
	var copia := jugador.duplicate()
	copia["media"] = ref + (media - ref) * AMORTIGUACION
	return Economia.sueldo_de_ficha(copia, anios)


func _con_ref(jugador: Dictionary, anios: int, ref: float) -> float:
	var media: float = float(jugador["media"])
	if media <= ref:
		return Economia.sueldo_de_ficha(jugador, anios)
	var copia := jugador.duplicate()
	copia["media"] = ref + (media - ref) * AMORTIGUACION
	return Economia.sueldo_de_ficha(copia, anios)
