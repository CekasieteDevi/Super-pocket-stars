class_name Negociacion
extends RefCounted

## §9.3 rework: negociar un pase en dos tramos, como en la realidad.
##
##   1) CON EL CLUB. Ofertás lo que quieras. El club mira lo que vale su
##      jugador y cuánto le duele soltarlo. Si le ofrecés una miseria no
##      te dice "poco": te cierra la puerta por una temporada entera.
##
##   2) CON EL JUGADOR. Si el club aceptó, todavía falta que él quiera
##      venir. Ahí pesan el salto de división, cómo la está pasando y la
##      plata — en ese orden, salvo que sea un mercenario.
##
## Lo que le da sentido a todo esto es la niebla (ver
## core/investigadores.gd): si lo investigaste sabés más o menos cuánto
## pedirá y cuánto cobra hoy. Si vas a ciegas, estás adivinando, y
## adivinar barato sale caro.

## Debajo de esta fracción del precio pedido, la oferta ofende y el club
## te bloquea. Es el riesgo real de ofertar sin haber investigado.
const FRACCION_INSULTO := 0.55

## Cuántas temporadas dura el bloqueo por ofertar una miseria.
const TEMPORADAS_BLOQUEO := 1

## Cuánto pesa cada división de diferencia en las ganas del jugador. Bajar
## una división resta, subir suma.
##
## Calibrado para que la plata SIEMPRE pueda comprar el "no": con 0.12,
## bajar de primera a décima daba -1,08 y no había contrato en el mundo
## que lo diera vuelta, que es lo contrario de lo que tiene que pasar.
## Con 0.07 son -0,63 y un sueldo seis veces mejor alcanza justo.
const PESO_DIVISION := 0.07

## Cuánto pesa venir de estar mal (ánimo bajo). Es el "sacame de acá".
const PESO_ANIMO := 0.6

## Cuánto pesa que le mejores el sueldo.
const PESO_SUELDO := 0.35
const TOPE_SUELDO_ARRIBA := 0.85
const TOPE_SUELDO_ABAJO := -0.5

## A partir de acá el jugador acepta.
const UMBRAL_ACEPTA := 0.5

## Un hincha del club no se quiere ir ni loco. Un mercenario va donde
## pagan: la plata le pesa el doble y la categoría casi nada.
const PENALIZACION_HINCHA := 0.35
const MERCENARIO_SUELDO := 2.0
const MERCENARIO_DIVISION := 0.3


## Lo que pide el club por su jugador: el valor de mercado más lo que le
## cuesta desprenderse (Mercado.resistencia_venta — sube con el capitán,
## con la figura del puesto, con la joven promesa y con la reputación).
static func precio_pedido(vendedor: Team, jugador: Dictionary) -> float:
	var id := int(jugador["id"])
	var valor := ValorJugador.calcular(
		jugador, vendedor.animo.get(id, 50.0), vendedor.contratos.get(id, 3))
	return valor * (1.0 + Mercado.resistencia_venta(vendedor, jugador))


## ¿El club acepta esta oferta? Devuelve {acepta, insulto, pedido}.
##
## `insulto` es lo que hay que temerle: ofertar por debajo de
## FRACCION_INSULTO del precio pedido no es "negociar bajo", es faltarle
## el respeto, y te deja afuera por TEMPORADAS_BLOQUEO.
static func evaluar_oferta(vendedor: Team, jugador: Dictionary, monto: float) -> Dictionary:
	var pedido := precio_pedido(vendedor, jugador)
	if monto < pedido * FRACCION_INSULTO:
		return {"acepta": false, "insulto": true, "pedido": pedido}
	return {"acepta": monto >= pedido, "insulto": false, "pedido": pedido}


## Lo que el jugador quiere cobrar en el club nuevo. Parte de lo que cobra
## hoy y pide más si va a bajar de categoría — la plata es lo que compensa
## resignar vitrina.
static func sueldo_pretendido(jugador: Dictionary, sueldo_actual: float,
		division_origen: int, division_destino: int) -> float:
	var caida: int = maxi(0, division_destino - division_origen)
	var base: float = maxf(sueldo_actual, Economia.sueldo_sugerido(
		ValorJugador.base_salarial(jugador, 50.0, 3)))
	return base * (1.10 + 0.18 * float(caida))


## Cuántas ganas tiene el jugador de ir, de 0 a 1. Es el §9.3 "el jugador
## debe querer ir": un titular de primera no se va a décima porque sí.
##
## `division_origen` y `division_destino` son índices 0..9 (0 = primera),
## así que destino MAYOR que origen es bajar de categoría.
##
## El ánimo hace de rendimiento: en este motor se mueve con los
## resultados y los goles (Team.actualizar_post_partido), así que un
## jugador que la está pasando mal es justamente el que se quiere ir.
static func interes_jugador(jugador: Dictionary, animo: float, sueldo_actual: float,
		sueldo_ofrecido: float, division_origen: int, division_destino: int) -> Dictionary:
	var peso_division := PESO_DIVISION
	var peso_sueldo := PESO_SUELDO
	if Personalidad.tiene(jugador, "Mercenario"):
		peso_division *= MERCENARIO_DIVISION
		peso_sueldo *= MERCENARIO_SUELDO

	var por_division: float = float(division_destino - division_origen) * -peso_division
	var por_animo: float = (50.0 - clampf(animo, 0.0, 100.0)) / 100.0 * PESO_ANIMO
	var mejora: float = sueldo_ofrecido / maxf(1.0, sueldo_actual)
	var por_sueldo: float = clampf((mejora - 1.0) * peso_sueldo, TOPE_SUELDO_ABAJO, TOPE_SUELDO_ARRIBA)
	var por_rasgo: float = -PENALIZACION_HINCHA if Personalidad.tiene(jugador, "Hincha del club") else 0.0

	var total: float = clampf(0.5 + por_division + por_animo + por_sueldo + por_rasgo, 0.0, 1.0)
	return {
		"interes": total,
		"acepta": total >= UMBRAL_ACEPTA,
		"por_division": por_division,
		"por_animo": por_animo,
		"por_sueldo": por_sueldo,
		"por_rasgo": por_rasgo,
	}


## Por qué dijo que no, en una línea, para mostrarle al jugador. Se elige
## el factor que más pesa en contra: un "no quiso" pelado no le enseña
## nada a nadie.
static func motivo_rechazo(detalle: Dictionary) -> String:
	var peor := ""
	var valor := 0.0
	for clave in ["por_division", "por_animo", "por_sueldo", "por_rasgo"]:
		var v: float = float(detalle[clave])
		if v < valor:
			valor = v
			peor = clave
	match peor:
		"por_division":
			return "No quiere bajar de categoría."
		"por_sueldo":
			return "El sueldo que le ofrecés es peor que el que tiene."
		"por_rasgo":
			return "Es hincha del club y no se quiere ir."
		_:
			return "Está cómodo donde está: no le movés el amperímetro."


## ¿Este club me tiene vetado por este jugador? Los bloqueos viven en
## Team.bloqueos_mercado del club VENDEDOR: es él el que se ofendió.
static func bloqueado(vendedor: Team, jugador_id: int, temporada_actual: int) -> bool:
	return int(vendedor.bloqueos_mercado.get(jugador_id, -1)) >= temporada_actual


static func bloquear(vendedor: Team, jugador_id: int, temporada_actual: int) -> void:
	vendedor.bloqueos_mercado[jugador_id] = temporada_actual + TEMPORADAS_BLOQUEO - 1
