extends SceneTree

## El partido no depende de cómo se parte la simulación. La vista avanza de a
## 600 pasos (simular(600)) y la herramienta de replay de a 1 (simular(1)). Si
## la huella del estado diverge en algún bloque, un replay no reproduce el
## partido que el jugador vio, y el save con receta deja de ser fiel.
##
## Compara la huella en cada bloque de 600 pasos de un partido completo.
## Correr con: godot --path . --headless --script tests/test_determinismo_v2.gd

const SEED := 97000
const DIVISION := 4
const BLOQUE := 600
const PASOS_TOPE := 60 * 60 * 20
## Un partido completo tiene unos 19.800 pasos: ~33 bloques de 600.
const BLOQUES_MIN := 20

var fallos := 0


func _init() -> void:
	var a: Object = CerebroV2.armar_partido(SEED, "Tiki taka", "Juego directo", DIVISION, DIVISION, true)
	var b: Object = CerebroV2.armar_partido(SEED, "Tiki taka", "Juego directo", DIVISION, DIVISION, true)
	var inicial: int = a.huella()
	var comparados := 0
	var diverge_en := -1
	while str(a.get_estado()["periodo"]) != "terminado" and int(a.get_estado()["paso"]) < PASOS_TOPE:
		a.simular(BLOQUE)
		var paso := int(a.get_estado()["paso"])
		while int(b.get_estado()["paso"]) < paso:
			b.simular(1)
		comparados += 1
		if a.huella() != b.huella():
			diverge_en = paso
			break
	var sufijo := "" if diverge_en < 0 else " (diverge en paso %d)" % diverge_en
	_ok(diverge_en < 0, "simular(600) y simular(1) dan la misma huella en cada bloque" + sufijo)
	_ok(a.huella() != inicial, "el partido se mueve: la huella final cambia respecto del inicio")
	_ok(comparados >= BLOQUES_MIN, "se compararon %d bloques de %d pasos (al menos %d)" % [comparados, BLOQUE, BLOQUES_MIN])
	var goles_a: PackedInt32Array = a.get_goles()
	var goles_b: PackedInt32Array = b.get_goles()
	_ok(goles_a == goles_b, "mismo marcador por ambos caminos (%d-%d y %d-%d)" % [goles_a[0], goles_a[1], goles_b[0], goles_b[1]])
	print("FALLOS=%d" % fallos)
	quit(1 if fallos > 0 else 0)


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: ", texto)
	else:
		print("FALLA: ", texto)
		fallos += 1
