extends SceneTree

## Medicion, no test: en una partida real (GameState, dia a dia), que se
## come la caja de Contratos de los clubes de la IA de 6a para abajo.
## Cada dia compara la caja de cada club antes y despues, y le atribuye
## la baja al tipo de alta que aparecio en `sueldos`.

const SEED := 5151
const TEMPORADAS := 13
const GUION := preload("res://game/game_state.gd")


func _init() -> void:
	var gs = GUION.new()
	gs.partida_nueva(SEED)
	var causas := {}
	var altas := {}
	for t in range(TEMPORADAS):
		var inicial: int = gs.temporada_actual
		var pasos := 0
		while gs.temporada_actual == inicial and pasos < 5000:
			pasos += 1
			var antes := _foto(gs)
			if gs.hay_partido_hoy():
				gs.jugar_siguiente_fecha()
			elif gs.hay_partido_de_copa_hoy():
				gs.resolver_ronda_de_copa()
			elif gs.hay_partido_internacional_hoy():
				gs.resolver_ronda_internacional()
			elif gs.hay_partido_de_playoff_hoy():
				gs.resolver_playoffs()
			else:
				gs.avanzar_un_dia()
			var cierre: bool = gs.temporada_actual != inicial
			_comparar(gs, antes, causas, altas, cierre)
		var linea := "T%d" % gs.temporada_actual
		for d in [7, 8, 9]:
			var s := 0.0
			var neg := 0
			for e in gs.piramide.divisiones[d].equipos:
				s += float(e.caja["contratos"])
				if float(e.caja["contratos"]) < 0.0:
					neg += 1
			linea += " | div%d contratos %7.0f neg %2d" % [d + 1, s / 20.0, neg]
		print(linea)
	print("bajas de Contratos por causa (div 6-10, %d temporadas):" % TEMPORADAS)
	for k in causas:
		print("  %-28s %10.0f  (%d altas)" % [k, causas[k], altas.get(k, 0)])
	quit()


func _foto(gs) -> Dictionary:
	var f := {}
	for d in range(5, gs.piramide.divisiones.size()):
		for e in gs.piramide.divisiones[d].equipos:
			if e == gs.equipo_jugador:
				continue
			f[e] = {"caja": float(e.caja["contratos"]), "sueldos": e.sueldos.duplicate(),
				"cantera": _ids(e.cantera), "prestados": e.prestados_afuera.duplicate()}
	return f


func _ids(lista: Array) -> Dictionary:
	var s := {}
	for j in lista:
		s[int(j["id"])] = true
	return s


func _comparar(gs, antes: Dictionary, causas: Dictionary, altas: Dictionary, cierre: bool) -> void:
	for e in antes:
		var a: Dictionary = antes[e]
		var delta: float = float(e.caja["contratos"]) - float(a["caja"])
		if delta >= 0.0:
			continue
		if cierre:
			_sumar(causas, altas, "cierre de temporada (neto)", delta, 0)
			continue
		var nuevos := []
		for id in e.sueldos:
			if not a["sueldos"].has(id):
				nuevos.append(id)
		var causa := "sin alta (renovacion/sueldo)"
		if not nuevos.is_empty():
			var id: int = nuevos[0]
			var j: Dictionary = {}
			for x in e.todos_los_jugadores():
				if int(x["id"]) == id:
					j = x
			if a["cantera"].has(id):
				causa = "emergencia" if bool(j.get("convocado_emergencia", false)) else "sube de cantera"
			elif e.prestados_propios.has(id):
				causa = "cesion recibida"
			else:
				causa = "fichaje / libre / generado"
		_sumar(causas, altas, causa, delta, nuevos.size())


func _sumar(causas: Dictionary, altas: Dictionary, k: String, delta: float, n: int) -> void:
	causas[k] = causas.get(k, 0.0) + delta
	altas[k] = altas.get(k, 0) + n
