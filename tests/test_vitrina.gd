extends SceneTree

## La vitrina: que anote lo que se gana, que no anote lo que no, y que
## sobreviva al guardado.

const SEED := 3311


func _init() -> void:
	var fallas := 0
	# El autoload GameState no existe en modo --script. SIN meterlo en el
	# arbol: _ready() carga la partida guardada del usuario.
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(SEED, "Club Prueba")

	# Salir campeon de la liga: un titulo.
	gs._anotar_en_la_vitrina(1, {})
	if gs.vitrina.size() == 1 and str(gs.vitrina[0]["titulo"]) == "Liga":
		print("OK: salir primero anota la liga (%s)." % gs.vitrina[0]["detalle"])
	else:
		print("FALLA: salir primero no anoto la liga: %s" % [gs.vitrina])
		fallas += 1

	# Salir segundo no anota nada.
	var antes: int = gs.vitrina.size()
	gs._anotar_en_la_vitrina(2, {})
	if gs.vitrina.size() == antes:
		print("OK: salir segundo no anota nada.")
	else:
		print("FALLA: salir segundo anoto %s." % [gs.vitrina[gs.vitrina.size() - 1]])
		fallas += 1

	# Ganar una internacional.
	gs._anotar_en_la_vitrina(5, {"campeones": {"campeon": gs.equipo_jugador}})
	var ultimo: Dictionary = gs.vitrina[gs.vitrina.size() - 1]
	if str(ultimo["titulo"]) == "Copa de Campeones":
		print("OK: ganar la internacional anota la copa.")
	else:
		print("FALLA: ganar la internacional anoto \"%s\"." % ultimo["titulo"])
		fallas += 1

	# Ganarla otro club NO se anota.
	antes = gs.vitrina.size()
	var otro: Team = gs.liga_jugador().equipos[1]
	gs._anotar_en_la_vitrina(5, {"campeones": {"campeon": otro}})
	if gs.vitrina.size() == antes:
		print("OK: el titulo de otro club no entra en tu vitrina.")
	else:
		print("FALLA: se anoto un titulo que gano %s." % otro.nombre)
		fallas += 1

	# Cada titulo deja ademas su noticia, en la categoria de campeones.
	var con_vitrina := 0
	for n in gs.noticias:
		if str(n.get("cat", "")) == "campeones" and str(n["texto"]).begins_with("VITRINA"):
			con_vitrina += 1
	if con_vitrina == gs.vitrina.size():
		print("OK: los %d titulos dejaron su noticia en Campeones." % con_vitrina)
	else:
		print("FALLA: %d noticias de vitrina para %d titulos." % [con_vitrina, gs.vitrina.size()])
		fallas += 1

	# Guardado: JSON devuelve los numeros como float.
	var texto := JSON.stringify(gs.vitrina)
	var recargada: Array = JSON.parse_string(texto)
	var ok: bool = recargada.size() == gs.vitrina.size()
	for i in range(recargada.size()):
		if str(recargada[i]["titulo"]) != str(gs.vitrina[i]["titulo"]) \
				or int(recargada[i]["anio"]) != int(gs.vitrina[i]["anio"]):
			ok = false
	if ok:
		print("OK: los %d titulos sobreviven al guardado." % recargada.size())
	else:
		print("FALLA: la vitrina no sobrevive al guardado.")
		fallas += 1

	gs.free()
	print("FALLOS=%d" % fallas)
	quit()
