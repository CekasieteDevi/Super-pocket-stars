extends SceneTree

## Que elige el que lleva la pelota cuando esta LIBRE.
##
## Mide el reclamo: con camino hacia el arco rival, el motor elige pase
## hacia atras en vez de seguir. Reparte la masa de probabilidad del
## softmax entre conducir, gambetear, rematar, pasarla adelante y pasarla
## atras, por banda de avance de cancha.
##
## La tabla B aisla el caso de la imagen: el poseedor es el mas
## adelantado, o sea NO tiene ningun companero por delante. Ahi conducir
## compite solo contra pases hacia atras.
##
## No sortea: lee las utilidades y la temperatura de la decision real y
## calcula la probabilidad de cada opcion. Asi la medicion no depende de
## la suerte de la semilla.

const SEED := 4400
const PARTIDOS := 12
const PRESION_MAXIMA := 0.35
## Bandas de avance de cancha: 0 = arco propio, 1 = arco rival.
const BANDAS := [0.0, 0.35, 0.50, 0.65, 1.01]
const CLASES := ["conducir", "gambeta", "tiro", "pase_adelante", "pase_atras", "otras"]

## Contadores del partido entero (tabla C), sin filtro de presion ni zona.
var _pases_atras := 0
var _pases_total := 0
var _gambetas := 0
var _con_gambeta := 0
var _decisiones := 0
var _prob_gambeta := 0.0


func _init() -> void:
	for division in [9, 4, 0]:
		var a_masa := _tabla_vacia()
		var a_casos := _ceros()
		var b_masa := _tabla_vacia()
		var b_casos := _ceros()
		for i in range(PARTIDOS):
			var r1 := RandomNumberGenerator.new()
			r1.seed = SEED + i
			var loc := Team.generar("A", r1, 0, NivelDivision.potencial(division),
				"Uruguay", NivelDivision.realizacion(division))
			var vis := Team.generar("B", r1, 400, NivelDivision.potencial(division),
				"Uruguay", NivelDivision.realizacion(division))
			var r2 := RandomNumberGenerator.new()
			r2.seed = SEED + i
			_correr(loc, vis, r2, a_masa, a_casos, b_masa, b_casos)
		print("--- division %d --- (presion <= %.2f)" % [division + 1, PRESION_MAXIMA])
		_imprimir("A: todas", a_masa, a_casos)
		_imprimir("B: sin companero por delante", b_masa, b_casos)
		print("  C: pases EJECUTADOS en todo el partido (sin filtro de presion)")
		print("    hacia atras: %5.1f%%   gambetas por partido: %.1f" % [
			100.0 * float(_pases_atras) / maxf(float(_pases_total), 1.0),
			float(_gambetas) / PARTIDOS])
		print("    pases por partido: %.1f   gambetas / pases: %.2f%%" % [
			float(_pases_total) / PARTIDOS,
			100.0 * float(_gambetas) / maxf(float(_pases_total), 1.0)])
		print("    D: la opcion gambeta APARECE en %5.1f%% de las decisiones (%d de %d);" % [
			100.0 * float(_con_gambeta) / maxf(float(_decisiones), 1.0), _con_gambeta, _decisiones])
		print("       cuando aparece, se lleva %5.1f%% de la probabilidad" % [
			100.0 * _prob_gambeta / maxf(float(_con_gambeta), 1.0)])
		_pases_atras = 0
		_pases_total = 0
		_gambetas = 0
		_con_gambeta = 0
		_decisiones = 0
		_prob_gambeta = 0.0
	quit()


func _tabla_vacia() -> Array:
	var t := []
	for b in range(BANDAS.size() - 1):
		var fila := {}
		for c in CLASES:
			fila[c] = 0.0
		t.append(fila)
	return t


func _ceros() -> Array:
	var t := []
	for b in range(BANDAS.size() - 1):
		t.append(0)
	return t


func _imprimir(titulo: String, masa: Array, casos: Array) -> void:
	print("  %s" % titulo)
	print("    avance      |  casos | conducir | gambeta |   tiro | p.adel | p.atras")
	for bi in range(BANDAS.size() - 1):
		var n: int = casos[bi]
		if n == 0:
			continue
		var m: Dictionary = masa[bi]
		print("    %.2f-%.2f | %6d |   %5.1f%% |  %5.1f%% | %5.1f%% | %5.1f%% |  %5.1f%%" % [
			BANDAS[bi], BANDAS[bi + 1], n,
			100.0 * m["conducir"] / n, 100.0 * m["gambeta"] / n, 100.0 * m["tiro"] / n,
			100.0 * m["pase_adelante"] / n, 100.0 * m["pase_atras"] / n])


func _correr(home: Team, away: Team, rng: RandomNumberGenerator,
		a_masa: Array, a_casos: Array, b_masa: Array, b_casos: Array) -> void:
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false
	home.forma_partido = 0.0
	away.forma_partido = 0.0
	home.clima_partido = Clima.generar(rng)
	away.clima_partido = home.clima_partido
	home.arbitro_partido = Arbitro.generar(rng)
	away.arbitro_partido = home.arbitro_partido
	var estado := MotorEspacial.crear_estado(home, away, rng)
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		estado["ultima_decision"] = {}
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			MotorEspacial._tick(estado, false)
			var d = estado.get("ultima_decision", {})
			if d == null or d.is_empty():
				continue
			estado["ultima_decision"] = {}
			var tipo := str(d["tipo"])
			if tipo == "gambeta":
				_gambetas += 1
			# El pase se acaba de lanzar en este tick: la pelota todavia
			# tiene el origen y el destino con que salio.
			if tipo in ["pase", "pase_hueco", "pase_largo"]:
				var pelota: Dictionary = estado["pelota"]
				var local: bool = bool(pelota["pasador_local"])
				var avance: float = MotorEspacial.valor_posicion(pelota["destino_pos"], local) 					- MotorEspacial.valor_posicion(pelota["origen_pos"], local)
				_pases_total += 1
				if avance < 0.0:
					_pases_atras += 1
			_medir_gambeta(d)
			_contar(d, a_masa, a_casos, b_masa, b_casos)


func _contar(d: Dictionary, a_masa: Array, a_casos: Array,
		b_masa: Array, b_casos: Array) -> void:
	var opciones: Array = d["opciones"]
	var mi_valor := -1.0
	for o in opciones:
		if o["tipo"] == "conducir":
			mi_valor = float(o["detalle"]["mi_valor"])
	# Sin opcion de conducir es el arquero: no entra en la pregunta.
	if mi_valor < 0.0 or float(d["presion"]) > PRESION_MAXIMA:
		return
	var bi := -1
	for b in range(BANDAS.size() - 1):
		if mi_valor >= float(BANDAS[b]) and mi_valor < float(BANDAS[b + 1]):
			bi = b
	if bi == -1:
		return

	var temp: float = float(d["temperatura"])
	var max_u := -INF
	for o in opciones:
		max_u = maxf(max_u, float(o["utilidad"]))
	var suma := 0.0
	var exps := []
	for o in opciones:
		var e: float = exp((float(o["utilidad"]) - max_u) / temp)
		exps.append(e)
		suma += e

	var hay_adelante := false
	for o in opciones:
		if _clase(o) == "pase_adelante":
			hay_adelante = true
	for i in range(opciones.size()):
		var c := _clase(opciones[i])
		a_masa[bi][c] += exps[i] / suma
		if not hay_adelante:
			b_masa[bi][c] += exps[i] / suma
	a_casos[bi] += 1
	if not hay_adelante:
		b_casos[bi] += 1


## Cada cuanto la opcion de encarar siquiera existe, y cuanta
## probabilidad se lleva cuando existe. Va sobre TODAS las decisiones, sin
## el filtro de presion de las tablas A y B.
func _medir_gambeta(d: Dictionary) -> void:
	var opciones: Array = d["opciones"]
	_decisiones += 1
	var hay := false
	for o in opciones:
		if str(o["tipo"]) == "gambeta":
			hay = true
	if not hay:
		return
	_con_gambeta += 1
	var temp: float = float(d["temperatura"])
	var max_u := -INF
	for o in opciones:
		max_u = maxf(max_u, float(o["utilidad"]))
	var suma := 0.0
	var p := 0.0
	for o in opciones:
		var e: float = exp((float(o["utilidad"]) - max_u) / temp)
		suma += e
		if str(o["tipo"]) == "gambeta":
			p += e
	_prob_gambeta += p / suma


func _clase(o: Dictionary) -> String:
	var tipo := str(o["tipo"])
	if tipo in ["conducir", "gambeta", "tiro"]:
		return tipo
	if tipo == "pase" or tipo == "pase_hueco":
		return "pase_adelante" if float(o["detalle"]["progreso"]) > 0.0 else "pase_atras"
	return "otras"
