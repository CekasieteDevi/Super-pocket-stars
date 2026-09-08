class_name ValorJugador
extends RefCounted

## Valor de mercado del jugador — Fase 6 (GDD §9.2).
##
## f(media, edad, ánimo, habilidades, personalidad, premios, contrato
## restante, reputación del club). Acá entran media, edad, ánimo y contrato
## restante, que ya existen en el motor; habilidades/personalidad/premios y
## reputación de club quedan afuera hasta que existan esos sistemas (§5, §6,
## fase 9) y se documenta como simplificación, no como olvido.

const VALOR_BASE := 50000.0

## §9.2: el escalon de elite. Hasta acá el valor sube con (media/50)^4, que
## es empinado pero manejable; de acá para arriba sube muchisimo mas.
##
## Sin esto un jugador de media 99 —el techo absoluto del juego— valia
## $768.477, cuando un club de primera netea mas de un millon por
## temporada: cualquiera ahorraba dos años y se compraba al mejor jugador
## del mundo. Con el escalon vale ~$98M y es el fichaje de una era.
##
## El umbral es 70 a proposito: es la media de un titular de division 3,
## asi que de division 4 para abajo NADA cambia de precio y la calibracion
## economica de las divisiones bajas —que es donde arranca el jugador—
## queda intacta.
const MEDIA_ELITE := 70.0
const EXPONENTE_ELITE := 14.0

const FACTOR_EDAD := [
	{"max": 20, "factor": 0.7},
	{"max": 23, "factor": 0.9},
	{"max": 29, "factor": 1.0},
	{"max": 32, "factor": 0.8},
	{"max": 35, "factor": 0.5},
	{"max": 999, "factor": 0.25},
]


static func _factor_edad(edad: int) -> float:
	for tramo in FACTOR_EDAD:
		if edad <= tramo["max"]:
			return tramo["factor"]
	return 0.25


## factor_contrato: antes iba de 0.4 (contrato por vencer) a 1.1 (recién
## renovado) — una renovación (2-4 años al azar, sin que el jugador haya
## cambiado en nada) podía casi DUPLICAR el valor de un día para el otro,
## haciendo que el valor de plantel saltara de forma que no tenía que ver
## con la calidad real del equipo. Sigue siendo cierto que un contrato
## corto resta valor de negociación (eso es real), pero con un rango más
## angosto (0.7-1.0) el efecto está presente sin dominar la valuación.
static func calcular(jugador: Dictionary, animo: float, contrato_restante: int) -> float:
	return _valor(jugador, animo, contrato_restante, true)


## Cuanto de destacar sobre tu division te pagan de sueldo.
##
## El sueldo salia de la media CRUDA, y la media no sabe en que categoria
## se juega: un media 76 pedia $22.219 tanto en primera como en decima.
## En decima eso es el 41% de todo lo que entra al club en el año — con
## el presupuesto de Contratos en 20/90 del neto, no habia forma de
## renovarlo. Medido con tests/_diag_sueldo_relativo.gd.
##
## Ahora lo que se paga es la distancia a la media de TU division
## (NivelDivision.media_de), amortiguada. El mismo media 76 cobra $4.383
## en decima —8% de los ingresos, renovable— y $16.734 en cuarta: el
## sueldo te sigue cuando ascendes.
##
## 0.35 sale del barrido de tests/_diag_amortiguacion_barrido.gd. Con 0.50
## el crack seguia sin entrar en el presupuesto de decima ($6.787 contra
## $5.500); con 0.25 la curva se aplana tanto que un media 96 cobra solo
## 3,9x lo que cobra un titular comun y deja de sentirse un crack. Con
## 0.35 cobra 5,9x y entra en la caja.
const AMORTIGUACION_SUELDO := 0.35


## La media que se paga en esa division. Por debajo de la referencia no
## se toca nada: amortiguar para abajo encareceria a los malos.
##
## division -1 (liga suelta, fuera de la piramide) no amortigua: no hay
## categoria contra la cual medir.
static func media_salarial(media: float, division: int) -> float:
	if division < 0:
		return media
	var ref: float = NivelDivision.media_de(division)
	if media <= ref:
		return media
	return ref + (media - ref) * AMORTIGUACION_SUELDO


## Lo que se usa para calcular el SUELDO — el mismo valor pero SIN el
## escalon de elite y con la media amortiguada contra la division.
##
## El pase y el sueldo no escalan igual. El pase de un crack es una subasta
## por algo que no se puede conseguir de otra manera; el sueldo es lo que
## el club paga todos los años, y no puede seguir la misma curva.
##
## Sin separarlos, el sueldo era el 10% de un valor que crece como
## media^18 arriba del umbral: un plantel que mejoraba dos o tres puntos de
## media multiplicaba su masa salarial varias veces, mientras el ingreso
## sigue atado a una constante por division (Economia.MULTIPLICADOR_DIVISION).
## Medido a 6 temporadas: division 3 pagaba $3,81M de sueldos contra
## $1,50M de ingresos, y 15 de sus 20 clubes cerraban en rojo.
static func base_salarial(jugador: Dictionary, animo: float, contrato_restante: int,
		division: int = -1) -> float:
	return _valor(jugador, animo, contrato_restante, false, division)


static func _valor(jugador: Dictionary, animo: float, contrato_restante: int,
		con_elite: bool, division: int = -1) -> float:
	var media: float = max(jugador["media"], 1.0)
	# Solo el sueldo mira la division. El PASE de un crack es una subasta
	# y no le importa donde juega hoy: por eso la amortiguacion vive de
	# este lado del if y no adentro de media_salarial.
	if not con_elite:
		media = media_salarial(media, division)
	var factor_media: float = pow(media / 50.0, 4.0)
	if con_elite and media > MEDIA_ELITE:
		factor_media *= pow(media / MEDIA_ELITE, EXPONENTE_ELITE)
	var factor_edad: float = _factor_edad(jugador["edad"])
	var factor_animo: float = 0.85 + (clamp(animo, 0.0, 100.0) / 100.0) * 0.3
	var factor_contrato: float = clamp(0.7 + 0.075 * contrato_restante, 0.7, 1.0)

	return VALOR_BASE * factor_media * factor_edad * factor_animo * factor_contrato
