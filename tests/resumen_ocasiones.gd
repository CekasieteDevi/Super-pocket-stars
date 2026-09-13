extends RefCounted

## Geometría común: indicador del contexto sin habilidad del rematador.
## No es probabilidad de gol. Presión y arquero se muestran por separado.
const LIMITES := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]


static func resumir(partidos: Array) -> Dictionary:
	var grupos := {}
	var excluidos := {"forzados": 0, "sin_contexto": 0, "duplicados": 0, "invalidos": 0, "sin_resultado": 0}
	for partido in partidos:
		var vistos := {}
		for remate in partido.get("remates", []):
			if remate.get("ejecucion", {}).get("forzado_laboratorio", false):
				excluidos["forzados"] += 1
				continue
			var ocasion: Dictionary = remate.get("ocasion", {})
			if not ocasion.has("geometria_comun"):
				excluidos["sin_contexto"] += 1
				continue
			var valor := float(ocasion["geometria_comun"])
			if not is_finite(valor) or valor < 0.0 or valor > 1.0:
				excluidos["invalidos"] += 1
				continue
			if remate.get("resultado_observado", "") not in ["gol", "atajada", "afuera", "palo", "bloqueado"]:
				excluidos["sin_resultado"] += 1
				continue
			if remate.has("remate_id"):
				if vistos.has(remate["remate_id"]):
					excluidos["duplicados"] += 1
					continue
				vistos[remate["remate_id"]] = true
			var tramo := LIMITES.size() - 2
			for limite in range(1, LIMITES.size() - 1):
				if valor < LIMITES[limite]:
					tramo = limite - 1
					break
			var tipo := str(remate.get("atributo", ocasion.get("tipo", "desconocido")))
			var clave := "%s:%d" % [tipo, tramo]
			if not grupos.has(clave):
				grupos[clave] = {"tipo": tipo, "desde": LIMITES[tramo], "hasta": LIMITES[tramo + 1],
					"incluye_hasta": tramo == LIMITES.size() - 2, "intentos": 0, "goles": 0, "bloqueados": 0,
					"por_presion": {}, "por_arquero": {}}
			var grupo: Dictionary = grupos[clave]
			_sumar(grupo, remate)
			var presion: String = "sin_dato"
			if ocasion.has("presion"):
				var p := float(ocasion["presion"])
				presion = "[0,0.33)" if p < 0.33 else ("[0.33,0.66)" if p < 0.66 else "[0.66,1]")
			var arquero := "sin_dato"
			if ocasion.has("arco_desprotegido"):
				arquero = "desprotegido" if ocasion["arco_desprotegido"] else "alcanzable"
			for dimension in [["por_presion", presion], ["por_arquero", arquero]]:
				var tabla: Dictionary = grupo[dimension[0]]
				if not tabla.has(dimension[1]): tabla[dimension[1]] = {"intentos": 0, "goles": 0, "bloqueados": 0}
				_sumar(tabla[dimension[1]], remate)
	var claves := grupos.keys()
	claves.sort()
	var filas := []
	for clave in claves:
		var grupo: Dictionary = grupos[clave]
		_tasa(grupo)
		for dimension in ["por_presion", "por_arquero"]:
			for subgrupo in grupo[dimension].values(): _tasa(subgrupo)
		filas.append(grupo)
	return {"indicador": "geometria_comun_sin_habilidad", "es_xg": false,
		"definicion": "Intervalos [desde,hasta), salvo último cerrado. Conversión=goles confirmados/intentos con evento final, incluidos bloqueados. Sin filas para intervalos vacíos. Penales fuera del registro. Subgrupos por presión y posibilidad de intervención del arquero.",
		"excluidos": excluidos, "filas": filas}


static func _sumar(grupo: Dictionary, remate: Dictionary) -> void:
	grupo["intentos"] += 1
	if remate["resultado_observado"] == "gol": grupo["goles"] += 1
	if remate["resultado_observado"] == "bloqueado": grupo["bloqueados"] += 1


static func _tasa(grupo: Dictionary) -> void:
	grupo["conversion"] = float(grupo["goles"]) / int(grupo["intentos"])
