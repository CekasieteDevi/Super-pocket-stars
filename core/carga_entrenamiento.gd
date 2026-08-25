class_name CargaEntrenamiento
extends RefCounted

## §7.4.1: carga semanal de entrenamiento. Cinco escalones que cambian
## tres cosas a la vez —cuánto recuperan, cuánto crecen y cuánto se
## lesionan— y en direcciones opuestas, que es lo que la vuelve una
## decisión en vez de un botón de "más es mejor".
##
## La gracia está en el calendario: una semana con partido entre semana
## (ver GameState, copas intercaladas) deja a los jugadores sin días para
## recuperar, y ahí bajar la carga deja de ser cobardía y pasa a ser lo
## único sensato.

const NIVELES := ["recuperacion", "ligero", "normal", "intenso", "brutal"]
const POR_DEFECTO := "normal"

## recuperacion: cuánto multiplica la recuperación de fatiga por día.
## crecimiento: cuánto multiplica la progresión de la temporada.
## lesion: cuánto multiplica el riesgo de lesión.
const EFECTOS := {
	"recuperacion": {"recuperacion": 1.40, "crecimiento": 0.88, "lesion": 0.65},
	"ligero": {"recuperacion": 1.18, "crecimiento": 0.96, "lesion": 0.85},
	"normal": {"recuperacion": 1.00, "crecimiento": 1.00, "lesion": 1.00},
	"intenso": {"recuperacion": 0.82, "crecimiento": 1.07, "lesion": 1.35},
	"brutal": {"recuperacion": 0.62, "crecimiento": 1.15, "lesion": 1.90},
}

## Nombres para la UI, en el mismo orden que NIVELES.
const ETIQUETAS := {
	"recuperacion": "Recuperación",
	"ligero": "Ligero",
	"normal": "Normal",
	"intenso": "Intenso",
	"brutal": "Brutal",
}


static func _efecto(nivel: String, clave: String) -> float:
	var d: Dictionary = EFECTOS.get(nivel, EFECTOS[POR_DEFECTO])
	return float(d[clave])


static func factor_recuperacion(nivel: String) -> float:
	return _efecto(nivel, "recuperacion")


static func factor_crecimiento(nivel: String) -> float:
	return _efecto(nivel, "crecimiento")


static func factor_lesion(nivel: String) -> float:
	return _efecto(nivel, "lesion")


static func existe(nivel: String) -> bool:
	return EFECTOS.has(nivel)


## Descripción corta para la UI: que el jugador vea los tres efectos
## juntos, porque el punto de la mecánica es el intercambio.
static func resumen(nivel: String) -> String:
	return "recuperación x%.2f   crecimiento x%.2f   lesiones x%.2f" % [
		factor_recuperacion(nivel), factor_crecimiento(nivel), factor_lesion(nivel)]
