extends SceneTree

## BUG-008 (docs/bugs_pendientes.md): nadie remata con el pie de espaldas al
## arco, salvo el que tiene tiro 90 o más y está adentro del área grande. El
## que queda de espaldas se da vuelta y remata de frente.
##
## Juega partidos enteros con reglas, sin vista, y mira el registro de
## remates del motor: `de_lado` es cuánto se aparta el remate de adonde mira
## el que patea (0 de frente, 1 de espaldas).
##
## Correr con: godot --path . --headless --script tests/test_remate_de_espaldas_v2.gd

const SEED := 97000
const PARTIDOS := 24
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## De espaldas: el remate sale a más de 90 grados de adonde mira.
const DE_ESPALDAS := 0.5
## Al tocarla mira un poco distinto que al decidir: algún remate se escapa.
## Con el arreglo son 14 de 604 remates de pie en 120 partidos de quinta
## (2,3%); con el arreglo apagado, 127 de 616 (21%). En los 24 de este test,
## 4 de 126 y 28 de 125. Con 8 partidos (39 remates) el test fallaba por
## azar: 3 remates ya pasaban el tope.
const TOPE_CON_ARREGLO := 0.08
const PISO_SIN_ARREGLO := 0.15
## El área grande de un arco, con x en valor absoluto (Cerebro::MEDIO_LARGO,
## AREA_LARGO y AREA_MEDIO_ANCHO de motor_v2/cpp/src/cerebro/cerebro.h).
const AREA_GRANDE := Rect2(52.5 - 16.5, -20.16, 16.5, 40.32)

var fallos := 0


func _init() -> void:
	var con := _medir()
	_ok(con["pie"] > 0, "hay remates de pie para medir (%d)." % con["pie"])
	_ok(float(con["mal"]) / maxf(con["pie"], 1.0) <= TOPE_CON_ARREGLO,
		"de espaldas sin permiso: %d de %d remates de pie." % [con["mal"], con["pie"]])
	# El test mide algo: con el arreglo apagado los remates de espaldas vuelven.
	var remate: Dictionary = FisicaV2.datos()["remate"]
	var umbral: float = remate["taco_desde_rad"]
	remate["taco_desde_rad"] = 0.0
	var sin := _medir()
	remate["taco_desde_rad"] = umbral
	_ok(float(sin["mal"]) / maxf(sin["pie"], 1.0) >= PISO_SIN_ARREGLO,
		"con el arreglo apagado vuelven: %d de %d." % [sin["mal"], sin["pie"]])
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Remates de pie de PARTIDOS partidos de quinta, y cuántos salieron de
## espaldas sin permiso (tiro menor a taco_tiro, o desde afuera del área).
func _medir() -> Dictionary:
	var remate: Dictionary = FisicaV2.datos()["remate"]
	var tiro_minimo: float = remate["taco_tiro"]
	var s := {"pie": 0, "mal": 0}
	for n in PARTIDOS:
		var estilos: Array = ESTILOS[n % ESTILOS.size()]
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var local := Team.generar("Local", rng, 0, NivelDivision.potencial(4), "Uruguay", NivelDivision.realizacion(4))
		var visitante := Team.generar("Visitante", rng, 1000, NivelDivision.potencial(4), "Uruguay",
			NivelDivision.realizacion(4))
		local.estilo = estilos[0]
		visitante.estilo = estilos[1]
		var tiro := {}
		for equipo in [local, visitante]:
			for j in equipo.jugadores:
				tiro[int(j["id"])] = float(j["atributos"].get("tiro", 50.0))
		var c: Object = CerebroV2.armar(local, visitante, SEED + n, true)
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(600)
			pasos += 600
		for r in c.registro_remates():
			if int(r["golpe"]) == MotorV2.GOLPE_CABEZA:
				continue
			s["pie"] += 1
			if float(r["de_lado"]) <= DE_ESPALDAS:
				continue
			# Los equipos cambian de lado en el segundo tiempo: el área del
			# remate es la del arco más cercano.
			var desde: Vector2 = r["desde"]
			var en_area := AREA_GRANDE.has_point(Vector2(absf(desde.x), desde.y))
			if not (en_area and float(tiro.get(int(r["pateador_id"]), 0.0)) >= tiro_minimo):
				s["mal"] += 1
	return s

