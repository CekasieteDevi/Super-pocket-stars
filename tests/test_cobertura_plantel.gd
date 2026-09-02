extends SceneTree

## Ningun club puede quedarse sin jugadores de un puesto.
##
## El banco salia de los puestos de la formacion con la que arrancaba el
## club y de ninguno mas: uno que arrancaba en 5-3-2 no tenia un solo EXT
## ni un solo MCO en todo el plantel, y si te querias pasar a 4-3-3 no
## habia con quien. Quedabas atado a la formacion que te toco.

const SEED := 7788


func _init() -> void:
	var fallas := 0
	fallas += _test_todas_las_formaciones()
	fallas += _test_los_clubes_generados()
	print("FALLOS=%d" % fallas)
	quit()


## Con cualquiera de las cinco formaciones, el plantel (once + banco)
## tiene al menos dos jugadores de cada uno de los siete puestos.
func _test_todas_las_formaciones() -> int:
	var fallas := 0
	for formacion in Formaciones.lista():
		var conteo := {}
		for p in Puestos.TODOS:
			conteo[p] = 0
		for r in Formaciones.roles(formacion):
			conteo[r] = int(conteo[r]) + 1
		for r in Formaciones.banco_para(formacion):
			conteo[r] = int(conteo[r]) + 1
		var faltan := []
		for p in Puestos.TODOS:
			if int(conteo[p]) < Formaciones.MINIMO_POR_PUESTO:
				faltan.append("%s=%d" % [p, int(conteo[p])])
		if faltan.is_empty():
			print("OK: %s cubre los siete puestos (%s)." % [formacion, conteo])
		else:
			print("FALLA: %s deja puestos cortos: %s" % [formacion, ", ".join(faltan)])
			fallas += 1
	return fallas


## Y lo mismo pero sobre clubes generados de verdad, que es donde importa.
func _test_los_clubes_generados() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var cortos := 0
	var revisados := 0
	var ejemplo := ""
	for liga in piramide.divisiones:
		for club in liga.equipos:
			revisados += 1
			var conteo := {}
			for p in Puestos.TODOS:
				conteo[p] = 0
			for j in club.jugadores + club.banco:
				conteo[str(j["posicion"])] = int(conteo.get(str(j["posicion"]), 0)) + 1
			for p in Puestos.TODOS:
				if int(conteo[p]) < Formaciones.MINIMO_POR_PUESTO:
					cortos += 1
					if ejemplo == "":
						ejemplo = "%s (%s) tiene %d de %s" % [
							club.nombre, club.formacion, int(conteo[p]), p]
					break
	if cortos == 0:
		print("OK: los %d clubes de la piramide tienen 2+ de cada puesto." % revisados)
		return 0
	print("FALLA: %d de %d clubes quedan cortos. Ej: %s" % [cortos, revisados, ejemplo])
	return 1
