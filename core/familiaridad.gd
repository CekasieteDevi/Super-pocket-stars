class_name Familiaridad
extends RefCounted

## §7.4.5: familiaridad táctica (0-100). Cada táctica se entrena, y una
## táctica NUEVA rinde mal hasta que el equipo la asimila.
##
## Es la pieza que le pone precio a cambiar de plan. Hasta ahora elegir
## formación y estilo era gratis: se podía mirar al rival, cambiar a la
## formación que mejor le calza y volver a la anterior la fecha siguiente,
## sin costo. Con esto, cambiar cuesta —arrancás en frío— y quedarte
## fiel a un plan rinde. Es exactamente lo que pide el GDD: "excelente
## para forzar decisiones".
##
## Qué cuenta como "una táctica": el PAR formación + estilo. Son las dos
## mitades de la misma decisión —cómo te parás y cómo jugás— y separarlas
## dejaba escapar el caso obvio: cambiar de 4-4-2 a 4-3-3 manteniendo
## "presión alta" es un plan nuevo aunque el estilo no se haya movido.

## Modificador #11 del §8.4: de −8 (táctica nueva) a +5 (dominada).
const MODIFICADOR_MIN := -8.0
const MODIFICADOR_MAX := 5.0

## El nivel en el que el modificador es CERO. No es 50: por debajo de esto
## la táctica todavía te está costando. Con 60, un plan recién estrenado
## necesita unas cuantas fechas antes de dejar de restar, que es el punto
## de la mecánica.
const NEUTRO := 60.0
const MAXIMO := 100.0

## Con lo que arranca la táctica con la que se genera el club: el plantel
## viene jugando así desde antes de que empiece la partida. Arrancar todos
## en 0 haría que la primera media temporada fuera un castigo sin decisión
## detrás.
const INICIAL := 70.0

## Cuánto asimila el equipo por partido jugado con esa táctica.
##
## Calibrado para que estrenar de cero cueste ~8 fechas de 38 hasta dejar
## de restar. Con 4 eran 15, casi media temporada, y ahí la mecánica deja
## de forzar una decisión y pasa a prohibir el cambio: nadie experimenta
## nunca, que es lo contrario de lo que se buscaba.
const GANANCIA_PARTIDO := 7.5

## Extra si el foco de equipo de la semana es el táctico (§7.4.2). Es la
## forma de comprar familiaridad más rápido, a costa de no entrenar otra
## cosa.
const GANANCIA_FOCO_TACTICO := 3.0

## Lo que queda de la ganancia una vez pasado NEUTRO.
##
## Con ganancia plana, cualquier equipo saltaba de 70 a 100 en cuatro
## fechas y el +5 de "táctica dominada" pasaba a ser el estado normal de
## los 200 clubes en vez de un logro. Frenando arriba, dominar un plan
## lleva casi una temporada entera de fidelidad — y eso es lo que se está
## premiando.
const FRENO_SOBRE_NEUTRO := 0.25

## Lo que se oxida por fecha una táctica que NO estás usando. Lento a
## propósito: volver a un plan viejo tiene que ser más barato que
## estrenar uno, si no nadie experimenta nunca.
const OLVIDO_POR_FECHA := 0.5

## Qué fracción se arrastra desde una táctica conocida que comparte la
## formación o el estilo — ver `_semilla`.
const TRASPASO_MITAD := 0.35


## La táctica es el par formación + estilo.
static func clave(formacion: String, estilo: String) -> String:
	return "%s|%s" % [formacion, estilo]


static func clave_actual(equipo: Team) -> String:
	return clave(equipo.formacion, equipo.estilo)


## Cuánto conoce el equipo la táctica que tiene puesta hoy, 0-100. Una que
## nunca jugó arranca en 0 y por eso resta el máximo.
static func nivel(equipo: Team) -> float:
	var k := clave_actual(equipo)
	if equipo.familiaridad.has(k):
		return float(equipo.familiaridad[k])
	return _semilla(equipo, k)


## Cuánto arrastra una táctica que todavía no jugaste desde otra que SÍ
## sabés y con la que comparte una mitad.
##
## Sin esto, cambiar solo el estilo manteniendo la formación costaba
## exactamente lo mismo que rehacer el plan entero, y eso no es cierto:
## el equipo ya sabe pararse: lo que está aprendiendo es a jugar distinto
## desde esa parada. Un cambio chico tiene que costar menos que uno
## grande, si no la única jugada racional es no tocar nada nunca.
static func _semilla(equipo: Team, k: String) -> float:
	var partes := k.split("|")
	if partes.size() < 2:
		return 0.0
	var mejor := 0.0
	for otra in equipo.familiaridad:
		var p: PackedStringArray = str(otra).split("|")
		if p.size() < 2:
			continue
		if p[0] == partes[0] or p[1] == partes[1]:
			mejor = maxf(mejor, float(equipo.familiaridad[otra]) * TRASPASO_MITAD)
	return mejor


## De nivel a puntos porcentuales. Dos tramos rectos que se cruzan en
## NEUTRO, para que el castigo de estrenar sea más pronunciado que el
## premio de dominar: bajar de 60 a 0 cuesta 8, subir de 60 a 100 da 5.
static func modificador_de_nivel(n: float) -> float:
	var v := clampf(n, 0.0, MAXIMO)
	if v <= NEUTRO:
		return lerpf(MODIFICADOR_MIN, 0.0, v / NEUTRO)
	return lerpf(0.0, MODIFICADOR_MAX, (v - NEUTRO) / (MAXIMO - NEUTRO))


static func modificador(equipo: Team) -> float:
	return modificador_de_nivel(nivel(equipo))


## Arranca al club con su táctica de siempre ya asimilada.
static func inicial(formacion: String, estilo: String) -> Dictionary:
	return {clave(formacion, estilo): INICIAL}


## Se llama UNA vez por equipo por fecha jugada. La táctica usada sube; el
## resto se oxida despacio.
static func despues_de_partido(equipo: Team) -> void:
	var actual := clave_actual(equipo)
	var ganancia := _ganancia(equipo, nivel(equipo))

	for k in equipo.familiaridad.keys():
		if k == actual:
			continue
		equipo.familiaridad[k] = maxf(
			0.0, float(equipo.familiaridad[k]) - OLVIDO_POR_FECHA)

	# `nivel` y no `get`: la primera vez que jugás una táctica hay que
	# partir de lo que arrastra de las que ya sabés, no de cero.
	equipo.familiaridad[actual] = minf(MAXIMO, nivel(equipo) + ganancia)


## Texto para la UI: en qué está y qué le hace al equipo.
static func etiqueta(equipo: Team) -> String:
	var n := nivel(equipo)
	var m := modificador(equipo)
	return "%s · %s   %d/100   (%+.1f en los duelos)" % [
		equipo.formacion, equipo.estilo, int(round(n)), m]


## Lo que se asimila en una fecha, desde el nivel `n`. Entero hasta
## NEUTRO y frenado por encima — ver FRENO_SOBRE_NEUTRO.
static func _ganancia(equipo: Team, n: float) -> float:
	var g := GANANCIA_PARTIDO
	if equipo.foco_equipo == "tactico":
		g += GANANCIA_FOCO_TACTICO
	return g if n < NEUTRO else g * FRENO_SOBRE_NEUTRO


## Cuántas fechas le faltan a la táctica actual para dejar de restar. 0 si
## ya no resta. Es el dato con el que se decide si vale la pena cambiar.
static func fechas_para_neutro(equipo: Team) -> int:
	var n := nivel(equipo)
	if n >= NEUTRO:
		return 0
	return int(ceil((NEUTRO - n) / _ganancia(equipo, n)))
