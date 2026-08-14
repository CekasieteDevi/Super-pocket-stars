class_name Entrenamiento
extends RefCounted

## Foco individual (§7.4 punto 3) — hasta N jugadores (N = nivel de
## Instalaciones "entrenamiento", ver Instalaciones.limite_foco_individual)
## entrenan UN atributo específico con ×2 de ganancia esa temporada
## (Progresion.aplicar_temporada). Es también el requisito de entrada para
## aprender una habilidad (§5, ver core/aprendizaje.gd): 2 temporadas
## SEGUIDAS en el mismo atributo.
##
## Team.foco_individual: Dictionary jugador_id -> atributo (String), la
## selección de ESTA temporada — la arma el jugador humano a mano (UI) o
## se sortea automático para la IA (ver asignar_foco_automatico_ia). La
## racha de temporadas consecutivas se guarda en el propio dict del
## jugador ("foco_atributo"/"foco_temporadas_consecutivas"), no en el
## Team, porque viaja con el jugador si lo venden/prestan.

const EDAD_MAXIMA_FOCO_IA := 23


static func limite(equipo: Team) -> int:
	return Instalaciones.limite_foco_individual(equipo)


## true si se pudo asignar (o reasignar) el foco. Falla si ya está al
## límite de cupos Y el jugador no tenía uno asignado antes (reasignar un
## cupo ya ocupado, o cambiarle el atributo a alguien que ya lo tenía, no
## cuenta como un cupo nuevo).
static func asignar(equipo: Team, jugador_id: int, atributo: String) -> bool:
	if not equipo.foco_individual.has(jugador_id) and equipo.foco_individual.size() >= limite(equipo):
		return false
	equipo.foco_individual[jugador_id] = atributo
	return true


static func quitar(equipo: Team, jugador_id: int) -> void:
	equipo.foco_individual.erase(jugador_id)


## Se llama UNA vez por jugador por temporada, en el mismo cierre donde
## corre Progresion.aplicar_temporada — actualiza la racha ANTES de que
## Aprendizaje.procesar_jugador la lea. Si el atributo de foco cambió (o
## se sacó el foco), la racha se corta: §5 pide "2 temporadas COMPLETAS"
## en el mismo atributo, no 2 sueltas.
static func actualizar_racha(jugador: Dictionary, atributo_foco: String) -> void:
	if atributo_foco == "":
		jugador["foco_atributo"] = ""
		jugador["foco_temporadas_consecutivas"] = 0
		return
	if jugador.get("foco_atributo", "") == atributo_foco:
		jugador["foco_temporadas_consecutivas"] = jugador.get("foco_temporadas_consecutivas", 0) + 1
	else:
		jugador["foco_atributo"] = atributo_foco
		jugador["foco_temporadas_consecutivas"] = 1


## IA: mantiene el foco de quien ya lo tenía (para que llegue a las 2
## temporadas seguidas) y llena los cupos que sobren con los juveniles
## (banco + cantera, ≤23 años) de mejor potencial sin foco todavía,
## apuntando al atributo con más peso en su posición (PlayerGenerator.
## get_weights) — una heurística simple de "entrená lo que más le sirve a
## este pibe", no una IA sofisticada.
static func asignar_foco_automatico_ia(equipo: Team, rng: RandomNumberGenerator) -> void:
	var cupos := limite(equipo)
	var candidatos_existentes := []
	for id in equipo.foco_individual.keys():
		candidatos_existentes.append(id)
	for id in candidatos_existentes:
		if equipo.foco_individual.size() > cupos:
			equipo.foco_individual.erase(id)

	if equipo.foco_individual.size() >= cupos:
		return

	var elegibles := []
	for j in equipo.banco + equipo.cantera:
		if j["edad"] <= EDAD_MAXIMA_FOCO_IA and not equipo.foco_individual.has(j["id"]):
			elegibles.append(j)
	elegibles.sort_custom(func(a, b): return a["potencial"] > b["potencial"])

	var pesos := PlayerGenerator.get_weights()
	for j in elegibles:
		if equipo.foco_individual.size() >= cupos:
			break
		var peso_posicion: Dictionary = pesos.get(j["posicion"], {})
		if peso_posicion.is_empty():
			continue
		var mejor_atributo := ""
		var mejor_peso := -1.0
		for attr in peso_posicion:
			if float(peso_posicion[attr]) > mejor_peso:
				mejor_peso = float(peso_posicion[attr])
				mejor_atributo = attr
		equipo.foco_individual[j["id"]] = mejor_atributo
