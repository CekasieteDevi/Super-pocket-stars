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

## Diez niveles, uno por división de la pirámide. Eran cinco, con el
## primer salto a $40.000 fijos: un club de décima cerraba la temporada
## con $1.385 de presupuesto de Mejoras y el presupuesto se reinicia cada
## año (Economia.procesar_temporada), así que ese club no llegaba NUNCA
## al nivel 2 de nada. La mejora existía solo para primera.
const NIVEL_MAXIMO := 10
const CATEGORIAS := ["estadio", "medica", "juveniles", "scouting", "entrenamiento"]

## Lo que cuesta pasar del nivel 1 al 2: una temporada entera del
## presupuesto de Mejoras de un club promedio de décima, medido con
## tests/_diag_mejoras_por_division.gd: $2.968.
##
## Puesto en $2.500 y no en los $2.968 justos porque ese número es el
## PROMEDIO de la división: con el promedio clavado, la mitad de los
## clubes de décima no llegaba igual. Con $2.500, un club de décima paga
## el nivel 2 de una instalación por temporada, y cinco temporadas quieto
## ahí le dan el nivel 2 de las cinco.
const COSTO_NIVEL_2 := 2500.0


static func nivel_inicial() -> Dictionary:
	var d := {}
	for c in CATEGORIAS:
		d[c] = 1
	return d


## Cuánto da cada área en el nivel máximo. Los efectos son estos números
## por `progreso`, así que la escala entera cuelga de acá y de
## NIVEL_MAXIMO: cuando los niveles pasaron de cinco a diez, el nivel 10
## quedó valiendo exactamente lo que valía el 5, sin tocar el balance.
##
## La UI muestra los mismos efectos (ver _efecto_instalacion en
## ui/main.gd) y los calcula con estas constantes, no con una copia.
const BONUS_AFORO_MAX := 0.80
const REDUCCION_LESION_MAX := 0.40
const BONUS_RECUPERACION_MAX := 0.60
const BONUS_ENTRENAMIENTO_MAX := 0.04
const CAMADA_MIN := 3
const CAMADA_MAX := 7
## De cuánto es el abanico de calidad de la cantera, de punta a punta. La
## mitad de la escala es el punto neutro: por debajo la academia saca
## chicos peores que el club, por encima mejores.
const CALIDAD_JUVENILES_RANGO := 12.0


## 0.0 en el nivel 1, 1.0 en el nivel máximo.
static func progreso(nivel: int) -> float:
	return float(clampi(nivel, 1, NIVEL_MAXIMO) - 1) / float(NIVEL_MAXIMO - 1)


## Un nivel por división: subir al 2 cuesta lo que gana en Mejoras un club
## de décima en una temporada, y subir al 10 lo que gana uno de primera.
## Los escalones salen de MULTIPLICADOR_DIVISION y no de una constante
## nueva — es la misma curva por la que crecen los ingresos, así que el
## costo de mejorar sigue a lo que el club puede pagar.
##
## La consecuencia buscada: te alcanza para una mejora por temporada, y la
## decisión es en cuál de las cinco la ponés. Cinco temporadas quieto en
## décima = un nivel de cada una. Si ascendés todos los años, el costo
## sube con vos y vas a llegar arriba con varias sin tocar.
static func costo_siguiente_nivel(nivel_actual: int) -> float:
	var indice: int = 9 - clampi(nivel_actual, 1, NIVEL_MAXIMO - 1)
	return COSTO_NIVEL_2 * Economia.factor_division(indice) / Economia.factor_division(8)


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
		equipo.scouts[0]["nivel"] = nivel_scout_de_nivel(equipo.instalaciones[categoria])

	return {"exito": true, "categoria": categoria, "nivel": equipo.instalaciones[categoria], "costo": costo}


## §9.5 médica: nivel 1 = riesgo normal (factor 1.0), nivel máximo = 40%
## menos riesgo de lesión. Se multiplica directo por evaluar_riesgo (más
## bajo = mejor, a diferencia de las otras que multiplican "para arriba").
static func factor_riesgo_lesion(equipo: Team) -> float:
	return 1.0 - progreso(equipo.instalaciones.get("medica", 1)) * REDUCCION_LESION_MAX


## §9.5 médica: nivel 1 = recuperación normal, nivel máximo = 60% más
## rápida.
static func factor_recuperacion_fatiga(equipo: Team) -> float:
	return 1.0 + progreso(equipo.instalaciones.get("medica", 1)) * BONUS_RECUPERACION_MAX


## §9.5 estadio: nivel 1 = aforo base, nivel máximo = 80% más aforo (más
## ingreso por entradas).
## El nivel del scout del club, que sube con la instalación de scouting.
## Vive acá y no en el `mejorar` de más arriba porque la UI lo muestra
## antes de comprar, y una segunda copia de la fórmula ya se había
## desincronizado una vez.
static func nivel_scout_de_nivel(nivel: int) -> int:
	return 1 + int(round(progreso(nivel) * float(Scout.NIVEL_MAXIMO - 1)))


static func factor_aforo(equipo: Team) -> float:
	return 1.0 + progreso(equipo.instalaciones.get("estadio", 1)) * BONUS_AFORO_MAX


## §9.5 juveniles: nivel 1 = camada de 3 (como antes de que existiera esta
## mejora), nivel máximo = camada de 7.
static func cantidad_camada(equipo: Team) -> int:
	return CAMADA_MIN + int(round(progreso(equipo.instalaciones.get("juveniles", 1))
		* float(CAMADA_MAX - CAMADA_MIN)))


## §9.5 juveniles, la otra mitad: además de cuántos, de qué calidad. Se
## suma al nivel del club (Team.nivel_potencial) para decidir el techo de
## la camada. Nivel 3 (el del medio) es neutro: una academia buena saca
## chicos por encima de lo que da el club y una abandonada por debajo.
## Sin esto, invertir en juveniles solo daba cantidad y la decisión era
## floja.
static func bonus_potencial_juveniles(equipo: Team) -> int:
	return int(round((progreso(equipo.instalaciones.get("juveniles", 1)) - 0.5)
		* CALIDAD_JUVENILES_RANGO))


## §9.5/§7.4 entrenamiento: cuántos jugadores pueden estar en foco
## individual a la vez (ver core/entrenamiento.gd).
## Tope duro de jugadores en foco individual a la vez. Los cupos se
## reparten a lo largo de toda la escala: 1 al empezar, 3 en el nivel
## máximo. Con el nivel a secas se podían enfocar 5 jugadores y el foco
## dejaba de ser una decisión: entraba medio plantel.
const MAXIMO_FOCO_INDIVIDUAL := 3


static func limite_foco_individual(equipo: Team) -> int:
	return cupos_foco_de_nivel(equipo.instalaciones.get("entrenamiento", 1))


static func cupos_foco_de_nivel(nivel: int) -> int:
	# round y no int: con truncado, la mitad de la escala (nivel 5 de 10)
	# seguia dando un solo cupo y el segundo aparecia recien en el 6.
	return 1 + int(round(progreso(nivel) * float(MAXIMO_FOCO_INDIVIDUAL - 1)))


## §9.5/§7.1 entrenamiento: nivel 1 = sin bonus, nivel máximo = +4% sobre
## TODO el crecimiento de la temporada, no solo el atributo en foco — ver
## Progresion.aplicar_temporada.
static func factor_entrenamiento(equipo: Team) -> float:
	return 1.0 + progreso(equipo.instalaciones.get("entrenamiento", 1)) * BONUS_ENTRENAMIENTO_MAX
