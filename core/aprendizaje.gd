class_name Aprendizaje
extends RefCounted

## Aprender una habilidad (§5, segunda vía además de nacer con una) —
## siempre bronce, nunca plata/oro ("esas se generan o no existen"), y
## máximo 1 en toda la carrera del jugador. Se resuelve reusando
## jugador["habilidad"]: si ya tiene algo ahí (nacido con ella o
## aprendida antes), no puede aprender otra — no hace falta un flag aparte.
##
## Requisitos: 2 temporadas SEGUIDAS con el mismo atributo como el más
## usado en la cancha (§7.3, jugador["xp_uso"]) + ese atributo en 65+, y
## que ya haya pasado al menos la temporada 3 de la partida.
##
## Antes la racha salía del foco individual. Al sacarlo, el uso es lo que
## queda que diga en qué se especializa un jugador, y no depende de que
## alguien lo elija a mano.
const TEMPORADA_MINIMA := 3
const TEMPORADAS_RACHA_REQUERIDAS := 2
const MEDIA_MINIMA_ATRIBUTO := 65
const EDAD_JOVEN := 23

const CHANCE_BASE := 0.03
const BONUS_MENTOR := 0.05
const BONUS_GENETICA := 0.02
const BONUS_TRABAJADOR := 0.02
const BONUS_JOVEN := 0.03
const BONUS_INSTALACIONES_MAX := 0.02
const CHANCE_MAXIMA := 0.15

## §4: los 3 tiers de arriba de la tabla de genética (GOAT/Ídolo/Prodigio),
## los mismos que Progresion.VELOCIDAD_POR_TIER ordena de mejor a peor.
const TIERS_GENETICA_TOP := ["GOAT", "Idolo", "Prodigio"]


## §6 extendido: "mentor que tenga esa habilidad" se aproxima a "hay un
## veterano (28+, ver Mentores.es_mentor) en el plantel con ALGUNA
## habilidad asociada al mismo atributo" — pedir el nombre EXACTO sería
## demasiado estricto (el pool por atributo tiene varias habilidades) y
## el GDD no distingue entre ellas para este bonus.
static func _hay_mentor_con_habilidad_del_atributo(equipo: Team, atributo: String) -> bool:
	for j in equipo.todos_los_jugadores() + equipo.cantera:
		if not Mentores.es_mentor(j):
			continue
		var habilidad: Dictionary = j.get("habilidad", {})
		if habilidad.is_empty():
			continue
		if Habilidades.atributo_de(habilidad["nombre"]) == atributo:
			return true
	return false


static func _chance(jugador: Dictionary, equipo: Team, atributo: String) -> float:
	var chance := CHANCE_BASE
	if _hay_mentor_con_habilidad_del_atributo(equipo, atributo):
		chance += BONUS_MENTOR
	if TIERS_GENETICA_TOP.has(jugador["genetica_tier"]):
		chance += BONUS_GENETICA
	if Personalidad.tiene(jugador, "Trabajador"):
		chance += BONUS_TRABAJADOR
	if jugador["edad"] <= EDAD_JOVEN:
		chance += BONUS_JOVEN
	if equipo.instalaciones.get("entrenamiento", 1) >= Instalaciones.NIVEL_MAXIMO:
		chance += BONUS_INSTALACIONES_MAX
	return min(chance, CHANCE_MAXIMA)


## Elige una habilidad de bronce del pool que corresponde al atributo (y a
## si es arquero o jugador de campo) — mismos pools que Habilidades.gd
## usa al generar, pero siempre nivel 1 (nunca plata/oro).
static func _elegir_habilidad(jugador: Dictionary, atributo: String, rng: RandomNumberGenerator) -> Dictionary:
	var grupo := "arquero" if jugador["posicion"] == "ARQ" else "campo"
	var datos: Dictionary = Habilidades._datos()
	var pool: Array = datos.get(grupo, {}).get(atributo, [])
	if pool.is_empty():
		return {}
	return {"nombre": pool[rng.randi() % pool.size()], "nivel": 1}


## El atributo que más usó en la temporada, o "" si jugó menos de media
## temporada de titular: un suplente con cuatro partidos no se especializa
## en nada. La vara es la misma que usa Progresion para el efecto pleno
## del uso.
static func atributo_mas_usado(jugador: Dictionary) -> String:
	var uso: Dictionary = jugador.get("xp_uso", {})
	var total := 0.0
	var mejor := ""
	var maximo := 0.0
	for a in uso:
		total += float(uso[a])
		if float(uso[a]) > maximo:
			maximo = float(uso[a])
			mejor = a
	if total < Progresion.USO_TEMPORADA_PLENA * 0.5:
		return ""
	return mejor


## Se llama una vez por jugador por temporada, ANTES de
## Progresion.aplicar_temporada: esa función consume jugador["xp_uso"].
## Si el atributo más usado cambió (o casi no jugó), la racha se corta:
## §5 pide temporadas COMPLETAS seguidas, no sueltas.
static func actualizar_racha(jugador: Dictionary) -> void:
	var atributo := atributo_mas_usado(jugador)
	if atributo == "":
		jugador["uso_atributo"] = ""
		jugador["uso_temporadas_consecutivas"] = 0
	elif jugador.get("uso_atributo", "") == atributo:
		jugador["uso_temporadas_consecutivas"] = int(jugador.get("uso_temporadas_consecutivas", 0)) + 1
	else:
		jugador["uso_atributo"] = atributo
		jugador["uso_temporadas_consecutivas"] = 1


## Se llama una vez por jugador por temporada, DESPUÉS de Progresion.
## aplicar_temporada (para que el atributo ya refleje el crecimiento de
## esta temporada) y de actualizar_racha (para que la racha ya cuente
## esta temporada). Devuelve la habilidad aprendida, o {} si no pasó nada.
static func procesar_jugador(jugador: Dictionary, equipo: Team, temporada_actual: int, rng: RandomNumberGenerator) -> Dictionary:
	if not jugador.get("habilidad", {}).is_empty():
		return {}
	if temporada_actual < TEMPORADA_MINIMA:
		return {}
	var atributo: String = jugador.get("uso_atributo", "")
	if atributo == "" or jugador.get("uso_temporadas_consecutivas", 0) < TEMPORADAS_RACHA_REQUERIDAS:
		return {}
	if int(jugador["atributos"].get(atributo, 0)) < MEDIA_MINIMA_ATRIBUTO:
		return {}

	if rng.randf() >= _chance(jugador, equipo, atributo):
		return {}

	var habilidad := _elegir_habilidad(jugador, atributo, rng)
	if habilidad.is_empty():
		return {}
	jugador["habilidad"] = habilidad
	return habilidad
