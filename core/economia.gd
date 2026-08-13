class_name Economia
extends RefCounted

## Economía del club — Fase 6 (GDD §9.1). Procesamiento a nivel temporada
## (todavía no hay calendario semanal para ingresos partido a partido):
## entradas + sponsor + premio por posición como ingreso, sueldos +
## mantenimiento como egreso, repartido en los 4 presupuestos fijos.

## §15 decisión 2 / §9.1: Fichajes 60% / Contratos 20% / Mejoras 10% / Mantenimiento 10%.
const PRESUPUESTO_PORCENTAJES := {
	"fichajes": 0.60, "contratos": 0.20, "mejoras": 0.10, "mantenimiento": 0.10,
}

## Calibrado para que la masa salarial (sueldo ~15% del valor de mercado,
## ValorJugador.VALOR_BASE=50000) sea una fracción realista de los ingresos
## de un club de división baja, no un redondeo despreciable.
const PARTIDOS_DE_LOCAL := 19
const AFORO_BASE := 800
const PRECIO_ENTRADA := 80.0
const SPONSOR_BASE := 15000.0
const MANTENIMIENTO_FIJO := 25000.0
const PREMIO_POR_POSICION := {1: 50000.0, 2: 30000.0, 3: 15000.0}

## Si la caja total queda por debajo de -20% del valor del plantel, quiebra.
const UMBRAL_QUIEBRA := -0.2


static func _fila_vacia_caja() -> Dictionary:
	var c := {}
	for categoria in PRESUPUESTO_PORCENTAJES:
		c[categoria] = 0.0
	return c


## Procesa una temporada terminada para un club. posicion_tabla es 1-indexado.
static func procesar_temporada(equipo: Team, posicion_tabla: int, total_equipos: int) -> Dictionary:
	var asistencia: float = AFORO_BASE * (0.3 + clamp(equipo.reputacion, 0.0, 100.0) / 100.0 * 0.7)
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
		equipo.caja[categoria] += neto * PRESUPUESTO_PORCENTAJES[categoria]

	# Reputación: sube despacio en la mitad de arriba de la tabla, baja en la
	# de abajo. Simplificado hasta que existan sponsors/prensa reales (§10.5).
	var relativo: float = (float(total_equipos) / 2.0) - posicion_tabla
	equipo.reputacion = clamp(equipo.reputacion + relativo * 0.05, 0.0, 100.0)

	var valor_plantel := 0.0
	for j in equipo.jugadores:
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
## fracción de su valor de mercado, como es habitual en fútbol.
static func sueldo_sugerido(valor: float) -> float:
	return valor * 0.15
