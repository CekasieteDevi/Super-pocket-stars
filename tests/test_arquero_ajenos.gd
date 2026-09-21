extends SceneTree

## El arquero nace sin atributos de jugador de campo altos, y un guardado
## viejo se recorta al cargar. Correr con:
##   <godot> --path . --headless --script tests/test_arquero_ajenos.gd

const SEED := 4242

var fallos := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("OK: " + msg)
	else:
		print("FALLA: " + msg)
		fallos += 1


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var max_ajeno := 0
	var max_propio := 0
	for i in 500:
		var j := PlayerGenerator.generate(i, rng, "ARQ", 90)
		for attr in PlayerGenerator.AJENOS_AL_ARQUERO:
			max_ajeno = maxi(max_ajeno, int(j["atributos"][attr]))
		max_propio = maxi(max_propio, int(j["atributos"]["reflejos"]))
	print("max ajeno=%d max reflejos=%d (potencial 90, 500 arqueros)" % [max_ajeno, max_propio])
	_check(max_ajeno < 75, "un arquero de potencial 90 no llega a 75 en centros/volea/etc.")
	_check(max_propio >= 85, "los atributos de arquero no cambian")

	# Guardado viejo: un arquero con centros 80.
	var viejo := PlayerGenerator.generate(7, rng, "ARQ", 90)
	viejo["potenciales"]["centros"] = 90
	viejo["atributos"]["centros"] = 80
	PlayerGenerator.recortar_ajenos_al_arquero(viejo)
	var primera := int(viejo["atributos"]["centros"])
	PlayerGenerator.recortar_ajenos_al_arquero(viejo)
	_check(primera < 70, "el guardado viejo se recorta (centros 80 -> %d)" % primera)
	_check(int(viejo["atributos"]["centros"]) == primera, "recortar dos veces da lo mismo")

	var campo := PlayerGenerator.generate(8, rng, "DC", 90)
	var antes: Dictionary = campo["atributos"].duplicate()
	PlayerGenerator.recortar_ajenos_al_arquero(campo)
	_check(campo["atributos"] == antes, "al jugador de campo no se le toca nada")

	print("FALLOS=%d" % fallos)
	quit(fallos)
