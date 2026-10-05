extends SceneTree

## BUG-011 (docs/bugs_pendientes.md): en el córner no se amontonan y el que
## cabecea salta.
##
## - Motor: al centro va el que llega primero de cada equipo y un compañero
##   más (Canchita::_analizar). Iban todos los que lo tenían a 3 m.
## - Vista: el modelo sube en el cabezazo y vuelve al piso antes de que
##   termine el gesto (VistaV2._ajustar_cuerpo).
##
## Correr con: godot --path . --headless --script tests/test_corner_monton_v2.gd

const SEED := 97000
const CORNERS := 120
## A esta distancia de la pelota, en el primer toque del centro.
const CERCA_M := 1.5
## Córners con tres o más compañeros a CERCA_M. En 400 córners de quinta:
## 36% saltando todos los que lo tenían a tiro, 10% con uno más por equipo.
const TOPE_AMONTONADOS := 0.2
## Córners que terminan en un cabezazo al arco. En 400: 40% antes y 38%
## después. Con uno solo por equipo yendo a la pelota eran el 5% (etapa 7).
const PISO_CABEZAZOS := 0.25
## Vista: el córner forzado de esta semilla termina en dos cabezazos.
const SEED_VISTA := 14
const DELTA := 1.0 / 60.0
const CUADROS_TOPE := 60 * 20
## El modelo sube 0,7 a 0,9 m (la pelota a 1,8 m, la frente a 0,97 m).
const SALTO_MIN_M := 0.3
## En el último cuadro del gesto quedaba a 0,3-0,5 m del piso.
const FIN_MAX_M := 0.1

var fallos := 0
var _armado := false
var _vista: VistaPartidoV2
var _cuadros := 0
## jugador -> [alto máximo, alto en el último cuadro del gesto]
var _saltos := {}
var _terminados: Array = []


func _process(_delta: float) -> bool:
	if not _armado:
		_armado = true
		_medir_corners()
		_armar_vista()
		return false
	for k in 60:
		_vista._process(DELTA)
		_cuadros += 1
		var c: Object = _vista._partido
		for i in c.cantidad():
			if c.get_accion(i) == "Cabecear":
				var alto: float = (_vista.vista._jugadores[i] as Jugador3D).position.y
				var d: Array = _saltos.get(i, [0.0, 0.0])
				_saltos[i] = [maxf(d[0], alto), alto]
			elif _saltos.has(i):
				_terminados.append(_saltos[i])
				_saltos.erase(i)
		if _cuadros >= CUADROS_TOPE:
			_informar_vista()
			return true
	return false


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Fuerza un córner por partido y mira el primer toque del centro.
func _medir_corners() -> void:
	var hechos := 0
	var amontonados := 0
	var cabezazos := 0
	for n in CORNERS:
		var c: Object = CerebroV2.armar_partido(SEED + n, "", "", 4, 4, true)
		c.simular(60 * 8)
		if not c.forzar_parada("corner", 0, Vector2(52.2, 33.7 if n % 2 == 0 else -33.7)):
			continue
		var pases_antes: int = c.registro_pases().size()
		var k0: Dictionary = c.contadores()
		var tocado := false
		for paso in 60 * 25:
			c.avanzar()
			var reg: Array = c.registro_pases()
			if reg.size() > pases_antes:
				# 5: el centro (DEC_CENTRO).
				if int(reg[pases_antes]["tipo"]) != 5:
					break
				if int(reg[pases_antes]["resultado"]) >= 0:
					tocado = true
					break
		if not tocado:
			continue
		hechos += 1
		var bola: Vector3 = c.get_pelota_pos()
		var pos: PackedVector2Array = c.get_pos()
		var equipos: PackedInt32Array = c.get_equipos()
		var arqueros: PackedInt32Array = c.get_arqueros()
		var cuantos := [0, 0]
		for i in c.cantidad():
			if not (i in arqueros) and pos[i].distance_to(Vector2(bola.x, bola.z)) <= CERCA_M:
				cuantos[equipos[i]] += 1
		if cuantos[0] >= 3 or cuantos[1] >= 3:
			amontonados += 1
		c.simular(120)
		cabezazos += int(c.contadores()["remates_cabeza"]) - int(k0["remates_cabeza"])
	_ok(hechos >= CORNERS * 0.8, "hay córners con centro para medir (%d de %d)." % [hechos, CORNERS])
	_ok(float(amontonados) / maxf(hechos, 1.0) <= TOPE_AMONTONADOS,
		"tres o más compañeros a %.1f m de la pelota: %d de %d córners." % [CERCA_M, amontonados, hechos])
	_ok(float(cabezazos) / maxf(hechos, 1.0) >= PISO_CABEZAZOS,
		"siguen cabeceando al arco: %d cabezazos en %d córners." % [cabezazos, hechos])


## El partido como lo dibuja el juego, con un córner forzado a los dos segundos.
func _armar_vista() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VISTA
	var local: Team = Team.generar("Local", rng, 0, NivelDivision.potencial(4), "Uruguay", NivelDivision.realizacion(4))
	var visitante: Team = Team.generar("Visitante", rng, 1000, NivelDivision.potencial(4), "Uruguay",
		NivelDivision.realizacion(4))
	var r: Dictionary = MotorV2.simular(local, visitante, rng, true)
	_vista = VistaPartidoV2.new()
	_vista.size = Vector2(1280, 720)
	root.add_child(_vista)
	_vista.iniciar(r["receta_v2"], r["eventos"], local, visitante)
	_vista.set_process(false)
	_vista._partido.simular(120)
	_vista._partido.forzar_parada("corner", 0, Vector2(ProyeccionPartido.MEDIO_LARGO, ProyeccionPartido.MEDIO_ANCHO))


func _informar_vista() -> void:
	var sube := 0.0
	var termina := 0.0
	for d in _terminados:
		sube = maxf(sube, d[0])
		termina = maxf(termina, d[1])
	_ok(not _terminados.is_empty(), "hay cabezazos en la vista para medir (%d)." % _terminados.size())
	_ok(sube >= SALTO_MIN_M, "el que cabecea salta: el que más sube, %.2f m." % sube)
	_ok(termina <= FIN_MAX_M, "el gesto termina en el piso: el que más alto queda, a %.2f m." % termina)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)
