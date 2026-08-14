class_name Economia
extends RefCounted

## Economía del club — Fase 6 (GDD §9.1). Procesamiento a nivel temporada
## (todavía no hay calendario semanal para ingresos partido a partido):
## entradas + sponsor + premio por posición como ingreso, sueldos +
## mantenimiento como egreso, repartido en los 4 presupuestos fijos.

## §15 decisión 2 / §9.1: Fichajes 60% / Contratos 20% / Mejoras 10% del
## NETO LIBRE (ingresos - sueldos - mantenimiento fijo), reescalado a que
## sumen 100% entre estos tres — Mantenimiento salió del reparto (ver
## RESERVA_MANTENIMIENTO más abajo): comprar jugadores más caros no debería
## hacer que el presupuesto de mantenimiento del club se vaya a números
## rojos, es un costo administrativo fijo (cancha, luz), no una inversión
## que dependa de la actividad del mercado.
const PRESUPUESTO_PORCENTAJES := {
	"fichajes": 60.0 / 90.0, "contratos": 20.0 / 90.0, "mejoras": 10.0 / 90.0,
}
## Las 4 categorías reales de la caja del club — a diferencia de
## PRESUPUESTO_PORCENTAJES (solo 3, las que se reparten del neto),
## Mantenimiento se repone con RESERVA_MANTENIMIENTO, no con un porcentaje.
const CATEGORIAS_CAJA := ["fichajes", "contratos", "mejoras", "mantenimiento"]

## PRECIO_ENTRADA calibrado (feedback de playtesting: "gané $797,000 en
## división 10 cuando un jugador de media 75 cuesta $170,000") — con
## $80 la entrada, un club de división baja con reputación ~45 sacaba
## ~$800,000 de ingresos por temporada contra un jugador MEDIANO del
## propio plantel valuado en ~$17,500: una desproporción de ~45x que
## dejaba a cualquier club de división baja nadando en plata en vez de
## sentirse pobre. Bajado a $12 (de $80): el mismo club ahora saca
## ~$140,000-195,000 por temporada, con el neto rondando cero para los
## clubes de asistencia floja y positivo pero ajustado para el resto —
## una temporada entera de ahorro no te compra la división entera, pero
## sí un par de refuerzos reales si administrás bien.
const PARTIDOS_DE_LOCAL := 19
const AFORO_BASE := 800
const PRECIO_ENTRADA := 12.0
const SPONSOR_BASE := 15000.0
const MANTENIMIENTO_FIJO := 25000.0
## Reserva de Mantenimiento que se repone CADA temporada, siempre igual —
## a diferencia de los otros tres presupuestos, no depende del neto de la
## temporada. La usan las multas de Liga por no presentarte con el mínimo
## de jugadores disponibles (§14).
const RESERVA_MANTENIMIENTO := 12500.0
const PREMIO_POR_POSICION := {1: 50000.0, 2: 30000.0, 3: 15000.0}

## Si la caja total queda por debajo de -20% del valor del plantel, quiebra.
const UMBRAL_QUIEBRA := -0.2


static func _fila_vacia_caja() -> Dictionary:
	var c := {}
	for categoria in CATEGORIAS_CAJA:
		c[categoria] = 0.0
	return c


## Procesa una temporada terminada para un club. posicion_tabla es 1-indexado.
static func procesar_temporada(equipo: Team, posicion_tabla: int, total_equipos: int) -> Dictionary:
	var asistencia: float = AFORO_BASE * Instalaciones.factor_aforo(equipo) * (0.3 + clamp(equipo.reputacion, 0.0, 100.0) / 100.0 * 0.7)
	var ingreso_entradas: float = PARTIDOS_DE_LOCAL * asistencia * PRECIO_ENTRADA
	var ingreso_sponsor: float = SPONSOR_BASE + (total_equipos - posicion_tabla) * 1000.0
	var premio: float = PREMIO_POR_POSICION.get(posicion_tabla, 0.0)
	var ingresos: float = ingreso_entradas + ingreso_sponsor + premio

	var total_sueldos := 0.0
	for id in equipo.sueldos:
		total_sueldos += equipo.sueldos[id]
	var egresos: float = total_sueldos + MANTENIMIENTO_FIJO

	var neto: float = ingresos - egresos
	for categoria in PRESUPUESTO_PORCENTAJES:
		var asignado: float = neto * PRESUPUESTO_PORCENTAJES[categoria]
		equipo.caja[categoria] += asignado
		equipo.presupuesto_temporada[categoria] = asignado
	# Mantenimiento no sale del neto (que ya lo restó una vez como costo fijo
	# más arriba, en egresos) — se repone con una reserva fija, siempre
	# igual, para que gastar de más en sueldos no lo mande a números rojos.
	equipo.caja["mantenimiento"] += RESERVA_MANTENIMIENTO
	equipo.presupuesto_temporada["mantenimiento"] = RESERVA_MANTENIMIENTO
	# Foto de la caja justo despues de repartir el ingreso y antes de que el
	# mercado (que corre a continuacion en el mismo cierre) gaste nada —
	# sirve para que la UI pueda mostrar cuanto se gasto de cada categoria
	# esta temporada (caja_al_cierre - caja_actual).
	equipo.caja_al_cierre = equipo.caja.duplicate()

	# Reputación: sube en la mitad de arriba de la tabla, baja en la de
	# abajo — a un ritmo que se note en un puñado de temporadas de verdad
	# buenas o malas (con 0.05 anterior, ganar el campeonato todas las
	# temporadas tardaba ~90 temporadas en mover la reputación 40 puntos;
	# con 0.25, tarda ~18, todavía gradual pero perceptible). Simplificado
	# hasta que existan sponsors/prensa reales (§10.5).
	var relativo: float = (float(total_equipos) / 2.0) - posicion_tabla
	equipo.reputacion = clamp(equipo.reputacion + relativo * 0.25, 0.0, 100.0)

	# Todo el plantel activo (titulares+banco, §14), no solo los 11
	# titulares -- el banco es un activo real del club (podría venderse),
	# y contarlo de menos hacía que el umbral de quiebra fuera mucho más
	# fácil de cruzar de lo que debería para cualquier club con un banco
	# de valor.
	var valor_plantel := 0.0
	for j in equipo.todos_los_jugadores():
		valor_plantel += ValorJugador.calcular(j, equipo.animo.get(j["id"], 50.0), equipo.contratos.get(j["id"], 1))

	var caja_total := 0.0
	for categoria in equipo.caja:
		caja_total += equipo.caja[categoria]
	equipo.quebrado = valor_plantel > 0.0 and caja_total < UMBRAL_QUIEBRA * valor_plantel

	return {
		"ingresos": ingresos, "egresos": egresos, "neto": neto,
		"sueldos": total_sueldos, "mantenimiento": MANTENIMIENTO_FIJO,
		"caja_total": caja_total, "valor_plantel": valor_plantel, "quebrado": equipo.quebrado,
	}


## Sueldo anual sugerido para un jugador recién fichado o generado: una
## fracción de su valor de mercado, como es habitual en fútbol. Bajado de
## 0.15 a 0.10 junto con el ajuste de PRECIO_ENTRADA (feedback de
## playtesting, ver más arriba): con 0.15, la masa salarial crecía más
## rápido que el ingreso (que tiene techo — reputación tarda en subir y
## la asistencia nunca pasa de 1.0x) a medida que los jugadores mejoraban
## con la progresión, empujando a cada vez más clubes a números rojos
## temporada tras temporada. Con 0.10 el neto promedio de la pirámide se
## mantiene sano varias temporadas seguidas en vez de derrumbarse.
static func sueldo_sugerido(valor: float) -> float:
	return valor * 0.10


## "$1234567.8" -> "$1,234,568" (redondeado). Para que los montos se lean
## de un vistazo en vez de tener que contar ceros.
static func formato_dinero(valor: float) -> String:
	var negativo := valor < 0.0
	var entero := int(round(abs(valor)))
	var digitos := str(entero)
	var con_comas := ""
	var contador := 0
	for i in range(digitos.length() - 1, -1, -1):
		con_comas = digitos[i] + con_comas
		contador += 1
		if contador % 3 == 0 and i != 0:
			con_comas = "," + con_comas
	return ("-$" if negativo else "$") + con_comas
