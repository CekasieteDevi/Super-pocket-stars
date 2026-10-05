extends SceneTree

## BUG-013 (docs/bugs_pendientes.md): la chilena entra al partido. Le pega de
## chilena el que remata de primera de espaldas al arco, adentro del área
## grande, con la pelota alta (Canchita::_de_chilena).
##
## Juega partidos enteros con reglas, sin vista, y mira el registro de
## remates del motor.
##
## Correr con: godot --path . --headless --script tests/test_chilena_v2.gd

const SEED := 97000
## En 120 partidos de quinta con esta semilla salen 15 chilenas, y en los 40
## de este test, 5: un cambio que saque una o dos no lo deja en cero.
const PARTIDOS := 40
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## El área grande de un arco, con x en valor absoluto (Cerebro::MEDIO_LARGO,
## AREA_LARGO y AREA_MEDIO_ANCHO de motor_v2/cpp/src/cerebro/cerebro.h). El
## remate se anota un paso después del toque: medio metro de margen.
const AREA_GRANDE := Rect2(52.5 - 17.0, -20.66, 17.0, 41.32)

var fallos := 0


func _init() -> void:
	var con := _medir()
	_ok(con["chilenas"] > 0, "hay chilenas en %d partidos (%d)." % [PARTIDOS, con["chilenas"]])
	_ok(con["de_cabeza"] == 0, "ninguna chilena sale con el golpe de cabeza (%d)." % con["de_cabeza"])
	_ok(con["fuera"] == 0, "todas salen de adentro del área grande (%d afuera)." % con["fuera"])
	_ok(con["sin_tiro"] == 0, "todas son de un jugador con más tiro que cabezazo (%d no)." % con["sin_tiro"])
	# El test mide algo: sin el clip de la chilena no sale ninguna.
	var remate: Dictionary = FisicaV2.datos()["remate"]
	var clip: String = remate["clip_chilena"]
	remate.erase("clip_chilena")
	var sin := _medir()
	remate["clip_chilena"] = clip
	_ok(sin["chilenas"] == 0, "sin el clip no hay chilenas (%d)." % sin["chilenas"])
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Las chilenas de PARTIDOS partidos de quinta y cuántas rompen cada regla.
func _medir() -> Dictionary:
	var s := {"chilenas": 0, "de_cabeza": 0, "fuera": 0, "sin_tiro": 0}
	for n in PARTIDOS:
		var estilos: Array = ESTILOS[n % ESTILOS.size()]
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var local := Team.generar("Local", rng, 0, NivelDivision.potencial(4), "Uruguay", NivelDivision.realizacion(4))
		var visitante := Team.generar("Visitante", rng, 1000, NivelDivision.potencial(4), "Uruguay",
			NivelDivision.realizacion(4))
		local.estilo = estilos[0]
		visitante.estilo = estilos[1]
		var atributos := {}
		for equipo in [local, visitante]:
			for j in equipo.jugadores:
				atributos[int(j["id"])] = j["atributos"]
		var c: Object = CerebroV2.armar(local, visitante, SEED + n, true)
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(600)
			pasos += 600
		for r in c.registro_remates():
			if not bool(r["chilena"]):
				continue
			s["chilenas"] += 1
			s["de_cabeza"] += int(int(r["golpe"]) == MotorV2.GOLPE_CABEZA)
			var desde: Vector2 = r["desde"]
			s["fuera"] += int(not AREA_GRANDE.has_point(Vector2(absf(desde.x), desde.y)))
			var a: Dictionary = atributos.get(int(r["pateador_id"]), {})
			s["sin_tiro"] += int(float(a.get("tiro", 0.0)) <= float(a.get("cabezazo", 0.0)))
	return s
