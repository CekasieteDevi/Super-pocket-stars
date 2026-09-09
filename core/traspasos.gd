class_name Traspasos
extends RefCounted

## Lista de transferibles: vos decidis por quien te pueden ofertar.
##
## Antes el mercado entrante era pura loteria: los clubes miraban tu
## plantel entero y podian venir por el que no vendes nunca. Aca cada
## jugador tuyo lleva un estado y ese estado filtra lo que llega.
##
## - DISPONIBLE: llegan ofertas normales. Es el default y por eso no se
##   guarda (ver `fijar`): una partida vieja abre con todos disponibles.
## - NO_DISPONIBLE: no llega ninguna oferta por el.
## - VENTA_RAPIDA: llegan ofertas mas baratas y el comprador casi no
##   aguanta contraofertas. Lo pones cuando queres sacartelo de encima.
##
## El estado vive en el club DUEÑO (Team.traspasos) y se borra solo cuando
## el jugador se va (Team._limpiar_registro).

const DISPONIBLE := "disponible"
const NO_DISPONIBLE := "no_disponible"
const VENTA_RAPIDA := "venta_rapida"

## El orden del boton que cicla en la solapa Traspaso.
const CICLO := [DISPONIBLE, NO_DISPONIBLE, VENTA_RAPIDA]

const ETIQUETAS := {
	DISPONIBLE: "Disponible",
	NO_DISPONIBLE: "No disponible",
	VENTA_RAPIDA: "Venta rapida",
}

const AYUDAS := {
	DISPONIBLE: "Pueden llegar ofertas por el.",
	NO_DISPONIBLE: "No llega ninguna oferta por el.",
	VENTA_RAPIDA: "Llegan ofertas entre 40% y 50% mas baratas, y el comprador casi no acepta que le pidas mas.",
}

## Cuanto de la oferta normal ofrecen por uno en venta rapida. El pedido
## es "entre 50% y 40% mas baratas", o sea la mitad larga de lo que
## pagarian estando disponible.
const FACTOR_VENTA_RAPIDA_MIN := 0.50
const FACTOR_VENTA_RAPIDA_MAX := 0.60

## Cuanto sobreprecio le aguanta el comprador de un jugador en venta
## rapida. Contra el 1.35 de Ofertas.TOPE_SOBREPRECIO_COMPRADOR: sabe que
## lo queres vender, asi que regatear casi no paga.
const TOPE_SOBREPRECIO_VENTA_RAPIDA := 1.03


static func estado(equipo, id: int) -> String:
	var e := str(equipo.traspasos.get(id, DISPONIBLE))
	return e if CICLO.has(e) else DISPONIBLE


## No guarda el default: el dict solo lleva a los que tocaste.
static func fijar(equipo, id: int, nuevo: String) -> void:
	if not CICLO.has(nuevo) or nuevo == DISPONIBLE:
		equipo.traspasos.erase(id)
		return
	equipo.traspasos[id] = nuevo


## El proximo estado del boton que cicla.
static func siguiente(actual: String) -> String:
	var i: int = CICLO.find(actual)
	return str(CICLO[(i + 1) % CICLO.size()]) if i >= 0 else NO_DISPONIBLE


static func acepta_ofertas(equipo, id: int) -> bool:
	return estado(equipo, id) != NO_DISPONIBLE


## Por cuanto multiplicar la oferta entrante que se estaba por generar.
static func factor_oferta(equipo, id: int, rng: RandomNumberGenerator) -> float:
	if estado(equipo, id) != VENTA_RAPIDA:
		return 1.0
	return rng.randf_range(FACTOR_VENTA_RAPIDA_MIN, FACTOR_VENTA_RAPIDA_MAX)


## Hasta cuanto por encima de su tasacion paga el comprador cuando le
## contraofertas pidiendo mas.
static func tope_sobreprecio(equipo, id: int, tope_normal: float) -> float:
	if estado(equipo, id) != VENTA_RAPIDA:
		return tope_normal
	return TOPE_SOBREPRECIO_VENTA_RAPIDA
