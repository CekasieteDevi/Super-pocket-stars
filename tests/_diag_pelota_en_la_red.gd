extends SceneTree

## ¿Dónde queda quieta la pelota que sale por la línea de fondo? Si queda
## adentro del arco, o en pantalla cae encima del dibujo del arco, parece
## trabada en la red. Cuenta las dos cosas, sin contar los goles (esa
## pelota queda en la red a propósito).
##   godot --path . --headless --script tests/_diag_pelota_en_la_red.gd

const SEED := 31415
const PARTIDOS := 30
## Radio de la pelota en pantalla, en metros de proyección, con un poco de
## aire: pegada al borde también se lee como que toca la red.
const RADIO := 0.4


func _init() -> void:
	var salidas := 0
	var adentro := 0
	var encima := 0
	var atraviesa := 0
	var ejemplos := []
	for p in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + p
		var local := Team.generar("L", rng)
		var visita := Team.generar("V", rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, true)
		var fotos: Array = r["fotogramas"]
		for i in range(2, fotos.size()):
			var a: Dictionary = fotos[i]["pelota"]
			var b: Dictionary = fotos[i - 1]["pelota"]
			var c: Dictionary = fotos[i - 2]["pelota"]
			var hubo_gol: bool = fotos[i]["goles"] != fotos[maxi(0, i - 40)]["goles"] 				or i + 12 < fotos.size() and fotos[i + 12]["goles"] != fotos[i]["goles"]
			# Cualquier fotograma, en vuelo o quieta, con la pelota dentro del
			# volumen del arco sin que sea gol: atravesó la red.
			var fondo_a := absf(float(a["x"])) - ProyeccionPartido.MEDIO_LARGO
			if not hubo_gol and fondo_a > 0.0 and fondo_a < VistaCancha.ARCO_FONDO 					and absf(float(a["y"])) < VistaCancha.ARCO_MEDIO_ANCHO:
				atraviesa += 1
				_anotar(ejemplos, "partido %d fotograma %d: (%.1f, %.1f) atraviesa la red" % [p, i, a["x"], a["y"]])
			if hubo_gol or not _igual(a, b) or _igual(b, c):
				continue
			var pos := Vector2(float(a["x"]), float(a["y"]))
			if absf(pos.x) <= ProyeccionPartido.MEDIO_LARGO:
				continue
			salidas += 1
			var fondo := absf(pos.x) - ProyeccionPartido.MEDIO_LARGO
			if absf(pos.y) < VistaCancha.ARCO_MEDIO_ANCHO + RADIO and fondo < VistaCancha.ARCO_FONDO + RADIO:
				adentro += 1
				_anotar(ejemplos, "partido %d fotograma %d: (%.1f, %.1f) adentro del arco" % [p, i, pos.x, pos.y])
			elif _encima_del_arco(pos):
				encima += 1
				_anotar(ejemplos, "partido %d fotograma %d: (%.1f, %.1f) encima del dibujo" % [p, i, pos.x, pos.y])
	print("salidas por el fondo: %d | adentro del arco: %d | encima del dibujo del arco: %d | fotogramas atravesando la red: %d" % [
		salidas, adentro, encima, atraviesa])
	for e in ejemplos:
		print("  " + e)
	quit()


## La caja del arco en coordenadas de proyección (VistaCancha._q), con el
## radio de la pelota. La pelota va en el piso.
func _encima_del_arco(pos: Vector2) -> bool:
	var lado := signf(pos.x)
	var caja := Rect2(VistaCancha._q(Vector3(lado * ProyeccionPartido.MEDIO_LARGO, -VistaCancha.ARCO_MEDIO_ANCHO, 0)), Vector2.ZERO)
	for x in [ProyeccionPartido.MEDIO_LARGO, ProyeccionPartido.MEDIO_LARGO + VistaCancha.ARCO_FONDO]:
		for y in [-VistaCancha.ARCO_MEDIO_ANCHO, VistaCancha.ARCO_MEDIO_ANCHO]:
			for z in [0.0, VistaCancha.ARCO_ALTO]:
				caja = caja.expand(VistaCancha._q(Vector3(lado * x, y, z)))
	return caja.grow(RADIO).has_point(VistaCancha._q(Vector3(pos.x, pos.y, 0)))


func _igual(a: Dictionary, b: Dictionary) -> bool:
	return is_equal_approx(float(a["x"]), float(b["x"])) and is_equal_approx(float(a["y"]), float(b["y"]))


func _anotar(ejemplos: Array, texto: String) -> void:
	if ejemplos.size() < 8:
		ejemplos.append(texto)
