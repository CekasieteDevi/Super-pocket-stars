class_name Instalaciones
extends RefCounted

## Instalaciones del club (§9.5): mejoras permanentes pagadas con el
## presupuesto de Mejoras (10% de la economía, §9.1 / §15 decisión 2) que
## hasta ahora se acumulaba sin que nada lo gastara. Cinco áreas, niveles
## 1-5 cada una, cada nivel más caro que el anterior:
##   - Estadio: más aforo, más ingreso de entradas (Economia.procesar_temporada).
##   - Médica: baja el riesgo de lesión (Lesiones.evaluar_riesgo) y recupera
##     la fatiga más rápido entre fechas (Team.avanzar_dias).
##   - Juveniles: camada de cantera más grande cada temporada (Team.generar_camada).
##   - Scouting: sube el nivel de tus scouts (Scout.margen), reportes más precisos.
##   - Entrenamiento: cuántos jugadores podés poner en foco individual a la
##     vez (core/entrenamiento.gd) y un +1% de crecimiento por nivel en el
##     cierre de temporada (Progresion.aplicar_temporada) — chico a
##     propósito: la fórmula de crecimiento ya tiene rendimientos
##     decrecientes contra el potencial, así que este bonus acelera sin
##     romper el techo real de cada jugador.

const NIVEL_MAXIMO := 5
const COSTO_BASE := 40000.0
const CATEGORIAS := ["estadio", "medica", "juveniles", "scouting", "entrenamiento"]


static func nivel_inicial() -> Dictionary:
	var d := {}
	for c in CATEGORIAS:
		d[c] = 1
	return d


## Escala geométrico: cada nivel siguiente cuesta ~1.8x el anterior, como
## cualquier progresión de mejoras estilo Kairosoft.
static func costo_siguiente_nivel(nivel_actual: int) -> float:
	return COSTO_BASE * pow(1.8, nivel_actual - 1)


## Sube un nivel de instalación si hay fondos en el presupuesto de Mejoras
## y no está en el máximo. Efectos inmediatos donde corresponde (scouting).
static func mejorar(equipo: Team, categoria: String) -> Dictionary:
	if not CATEGORIAS.has(categoria):
		return {"exito": false, "motivo": "Categoría inválida."}

	var nivel_actual: int = equipo.instalaciones.get(categoria, 1)
	if nivel_actual >= NIVEL_MAXIMO:
		return {"exito": false, "motivo": "Ya está al nivel máximo."}

	var costo := costo_siguiente_nivel(nivel_actual)
	if equipo.caja["mejoras"] < costo:
		return {"exito": false, "motivo": "No alcanza el presupuesto de Mejoras.", "costo": costo, "disponible": equipo.caja["mejoras"]}

	equipo.caja["mejoras"] -= costo
	equipo.instalaciones[categoria] = nivel_actual + 1

	if categoria == "scouting" and not equipo.scouts.is_empty():
		equipo.scouts[0]["nivel"] = min(Scout.NIVEL_MAXIMO, equipo.instalaciones[categoria] * 2 - 1)

	return {"exito": true, "categoria": categoria, "nivel": equipo.instalaciones[categoria], "costo": costo}


## §9.5 médica: nivel 1 = riesgo normal (factor 1.0), nivel 5 = 40% menos
## riesgo de lesión. Se multiplica directo por evaluar_riesgo (más bajo =
## mejor, a diferencia de las otras que multiplican "para arriba").
static func factor_riesgo_lesion(equipo: Team) -> float:
	var nivel: int = equipo.instalaciones.get("medica", 1)
	return 1.0 - (nivel - 1) * 0.10


## §9.5 médica: nivel 1 = recuperación normal, nivel 5 = 60% más rápida.
static func factor_recuperacion_fatiga(equipo: Team) -> float:
	var nivel: int = equipo.instalaciones.get("medica", 1)
	return 1.0 + (nivel - 1) * 0.15


## §9.5 estadio: nivel 1 = aforo base, nivel 5 = 80% más aforo (más
## ingreso por entradas).
static func factor_aforo(equipo: Team) -> float:
	var nivel: int = equipo.instalaciones.get("estadio", 1)
	return 1.0 + (nivel - 1) * 0.20


## §9.5 juveniles: nivel 1 = camada de 3 (como antes de que existiera esta
## mejora), nivel 5 = camada de 7.
static func cantidad_camada(equipo: Team) -> int:
	var nivel: int = equipo.instalaciones.get("juveniles", 1)
	return 2 + nivel


## §9.5 juveniles, la otra mitad: además de cuántos, de qué calidad. Se
## suma al nivel del club (Team.nivel_potencial) para decidir el techo de
## la camada. Nivel 3 (el del medio) es neutro: una academia buena saca
## chicos por encima de lo que da el club y una abandonada por debajo.
## Sin esto, invertir en juveniles solo daba cantidad y la decisión era
## floja.
static func bonus_potencial_juveniles(equipo: Team) -> int:
	var nivel: int = equipo.instalaciones.get("juveniles", 1)
	return (nivel - 3) * 3


## §9.5/§7.4 entrenamiento: cuántos jugadores pueden estar en foco
## individual a la vez (ver core/entrenamiento.gd).
## Tope duro de jugadores en foco individual a la vez. Las instalaciones
## mandan hasta el nivel 3; del 4 en adelante no dan más cupos, y siguen
## valiendo por el +% de crecimiento general que da factor_entrenamiento.
## Con el nivel a secas se podían enfocar 5 jugadores y el foco dejaba de
## ser una decisión: entraba medio plantel.
const MAXIMO_FOCO_INDIVIDUAL := 3


static func limite_foco_individual(equipo: Team) -> int:
	return mini(int(equipo.instalaciones.get("entrenamiento", 1)), MAXIMO_FOCO_INDIVIDUAL)


## §9.5/§7.1 entrenamiento: +1% de crecimiento por nivel arriba del 1
## (nivel 1 = sin bonus, nivel 5 = +4%) sobre TODO el crecimiento de la
## temporada, no solo el atributo en foco — ver Progresion.aplicar_temporada.
static func factor_entrenamiento(equipo: Team) -> float:
	var nivel: int = equipo.instalaciones.get("entrenamiento", 1)
	return 1.0 + (nivel - 1) * 0.01
