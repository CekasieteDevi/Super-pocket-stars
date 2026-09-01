class_name Calendario
extends RefCounted

## De un numero de dia a una fecha de verdad.
##
## El motor ya corria por dias desde siempre: Team.avanzar_dias() recupera
## fatiga, hace derivar el animo, descuenta lesiones y avanza informes, y
## las ofertas tienen su plazo en dias. Lo que no habia era una FECHA: se
## jugaba una jornada, pasaban 7 dias de golpe y todo lo que vencia en el
## medio aparecia junto al final, sin manera de frenar antes.
##
## Aca no hay logica de juego, solo la conversion a fecha y su formato.

## Arranque de la primera temporada. Un domingo, para que las jornadas de
## liga caigan siempre en domingo y las rondas de copa en miercoles.
const ANIO_INICIAL := 2025
const MES_INICIAL := 3
const DIA_INICIAL := 2  # domingo 2 de marzo de 2025

const MESES := ["enero", "febrero", "marzo", "abril", "mayo", "junio",
	"julio", "agosto", "setiembre", "octubre", "noviembre", "diciembre"]
const DIAS_SEMANA := ["lunes", "martes", "miercoles", "jueves", "viernes",
	"sabado", "domingo"]
const MESES_CORTOS := ["ene", "feb", "mar", "abr", "may", "jun",
	"jul", "ago", "set", "oct", "nov", "dic"]

const SEGUNDOS_POR_DIA := 86400


## Timestamp del dia 0. Se calcula una vez.
static func _origen() -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": ANIO_INICIAL, "month": MES_INICIAL, "day": DIA_INICIAL,
		"hour": 12, "minute": 0, "second": 0,
	}))


## {year, month, day, weekday} del dia `dia` contado desde el arranque.
static func fecha(dia: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(_origen() + dia * SEGUNDOS_POR_DIA)


## "domingo 2 de marzo de 2025"
static func texto_largo(dia: int) -> String:
	var f := fecha(dia)
	return "%s %d de %s de %d" % [
		_nombre_dia(f), int(f["day"]), MESES[int(f["month"]) - 1], int(f["year"])]


## "2 de marzo"
static func texto_medio(dia: int) -> String:
	var f := fecha(dia)
	return "%d de %s" % [int(f["day"]), MESES[int(f["month"]) - 1]]


## "dom 2/3"
static func texto_corto(dia: int) -> String:
	var f := fecha(dia)
	return "%s %d/%d" % [_nombre_dia(f).substr(0, 3), int(f["day"]), int(f["month"])]


## Godot devuelve weekday con 0 = domingo; la semana en castellano
## arranca en lunes.
static func _nombre_dia(f: Dictionary) -> String:
	var wd: int = int(f.get("weekday", 0))
	return DIAS_SEMANA[(wd + 6) % 7]


## Cuantos dias faltan, en palabras. Es lo que se lee al lado del proximo
## partido: "en 3 dias" se entiende mas rapido que una fecha.
static func en_cuantos_dias(dias: int) -> String:
	if dias <= 0:
		return "hoy"
	if dias == 1:
		return "manana"
	return "en %d dias" % dias
