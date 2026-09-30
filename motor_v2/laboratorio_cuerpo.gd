extends Control

## Laboratorio del cuerpo, etapa 2 de docs/motor_v2.md: 22 cuerpos en C++
## (CuerposV2Nativos) dibujados con los Jugador3D del partido (VistaV2), sin
## pelota ni cerebro. La vista solo lee: posición, rumbo, velocidad y la
## acción con su segundo.
##
## - 0 y 11 (arqueros) y 1 a 10: hacen, uno detrás de otro, todos los gestos
##   de data/acciones_v2.json de su modelo.
## - 12 a 16: piques de punta a punta; en cada punta dan la media vuelta.
## - 17 a 19: van a puntos al azar y llegan frenados. Parados, miran a otro
##   lado (giran en el lugar) y salen: 17 camina mirando otro punto (de
##   costado o de espaldas), 18 trota y 19 pica (Arranque y Frenada).
## - 20 y 21: corren y cada tanto patean o controlan sin frenar.
##
## Con pantalla: un toque o una tecla cambia de grupo (la cámara lo sigue).
## Sin pantalla (--headless): simula `segundos=N` (60), mide el patinaje de
## pies (DetectorPatinaV2) y el movimiento, imprime con [lab_cuerpo] y sale.

const PREFIJO := "[lab_cuerpo]"
const PASO_SEG := 1.0 / 60.0
const PASOS_MAX_POR_CUADRO := 4
const SEMILLA := 20260930
## Pausa entre dos gestos del mismo jugador.
const PAUSA_GESTOS_SEG := 0.6
const GRUPOS := [["Gestos", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]], ["Piques y medias vueltas", [12, 13, 14, 15, 16]],
	["Trote y caminata", [17, 18, 19]], ["Patea y controla corriendo", [20, 21]]]
const PIQUE_X := 30.0

var _cuerpos: Object
var _vista: VistaV2
var _etiqueta: Label
var _rng := RandomNumberGenerator.new()
var _acumulado := 0.0
var _reloj := 0.0
var _grupo := 0
## Gestos de cada jugador y cuál va.
var _gestos := {}
var _proximo := {}
var _espera := {}
var _destino := {}
var _completados := 0
var _detector := DetectorPatinaV2.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var segundos := 60.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("segundos="):
			segundos = float(arg.get_slice("=", 1))
	_rng.seed = SEMILLA
	_armar()
	_vista = VistaV2.new()
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		_medir(segundos)
		get_tree().quit()
		return
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16, 16)
	_etiqueta.add_theme_font_size_override("font_size", 28)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	add_child(_etiqueta)


func _armar() -> void:
	_cuerpos = ClassDB.instantiate("CuerposV2Nativos")
	var clips := FisicaV2.clips()
	_cuerpos.configurar(FisicaV2.parametros_cuerpo(), clips)
	for i in MundoV2.JUGADORES:
		var fisico := FisicaV2.fisico_de({"velocidad": _rng.randf_range(40.0, 95.0),
			"aceleracion": _rng.randf_range(40.0, 95.0), "agilidad": _rng.randf_range(40.0, 95.0)})
		_cuerpos.agregar(_lugar(i), PI * 0.5, fisico)
		_espera[i] = 0.0
	var de_jugador := []
	var de_golero := []
	for nombre in clips:
		var c: Dictionary = clips[nombre]
		if c["locomocion"]:
			continue
		if "jugador" in c["modelos"]:
			de_jugador.append(nombre)
		if "golero" in c["modelos"] and not "jugador" in c["modelos"]:
			de_golero.append(nombre)
	for i in range(0, 12):
		var lista: Array = de_golero if i % 11 == 0 else de_jugador
		_gestos[i] = lista
		_proximo[i] = (i * 5) % lista.size()
	for i in range(12, 17):
		_cuerpos.ir_a(i, Vector2(PIQUE_X, _lugar(i).y), 1.0, false)


## Dónde arranca cada uno.
func _lugar(i: int) -> Vector2:
	if i == 0:
		return Vector2(-8.0, -6.0)
	if i == 11:
		return Vector2(8.0, -6.0)
	if i <= 10:
		return Vector2(-12.5 + 2.5 * float(i), 0.0)
	if i <= 16:
		return Vector2(-PIQUE_X, 8.0 + 2.5 * float(i - 12))
	if i <= 19:
		return Vector2(-10.0 + 6.0 * float(i - 17), -18.0)
	return Vector2(-PIQUE_X, -26.0 + 3.0 * float(i - 20))


func _paso() -> void:
	for i in range(0, 12):
		if _cuerpos.get_accion(i) != "":
			continue
		_espera[i] = float(_espera[i]) + PASO_SEG
		if float(_espera[i]) < PAUSA_GESTOS_SEG:
			continue
		var lista: Array = _gestos[i]
		if _cuerpos.empezar_accion(i, lista[int(_proximo[i]) % lista.size()]):
			_proximo[i] = int(_proximo[i]) + 1
			_espera[i] = 0.0
	for i in range(12, 17):
		if _cuerpos.get_eventos(i) & CuerposV2Nativos.LLEGO:
			var p: Vector2 = _cuerpos.get_pos()[i]
			_cuerpos.ir_a(i, Vector2(-signf(p.x) * PIQUE_X, p.y), 1.0, false)
	for i in range(17, 20):
		if _cuerpos.get_rapidez()[i] != 0.0:
			_espera[i] = 0.0
			continue
		if float(_espera[i]) == 0.0:
			_destino[i] = Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-30.0, -12.0))
			var mira: Vector2 = _destino[i] if i != 17 else Vector2(_rng.randf_range(-20.0, 20.0), -21.0)
			_cuerpos.mirar_a(i, mira)
		_espera[i] = float(_espera[i]) + PASO_SEG
		if absf(_cuerpos.get_giro_pendiente(i)) < 0.05 and float(_espera[i]) > PAUSA_GESTOS_SEG:
			_cuerpos.ir_a(i, _destino[i], [0.2, 0.5, 1.0][i - 17], true)
	for i in range(20, 22):
		var p: Vector2 = _cuerpos.get_pos()[i]
		if absf(p.x) >= PIQUE_X - 0.5 or _cuerpos.get_rapidez()[i] == 0.0:
			_cuerpos.ir_a(i, Vector2(-signf(p.x if p.x != 0.0 else -1.0) * PIQUE_X, p.y), 1.0, false)
		if _rng.randf() < 1.0 / 120.0:
			_cuerpos.empezar_accion(i, "Patear_Corriendo" if i == 20 else "Control_Corriendo")
	_cuerpos.avanzar()
	for i in 22:
		if _cuerpos.get_eventos(i) & CuerposV2Nativos.TERMINA_ACCION:
			_completados += 1


func _foco() -> Vector2:
	var suma := Vector2.ZERO
	var miembros: Array = GRUPOS[_grupo][1]
	for i in miembros:
		suma += _cuerpos.get_pos()[i]
	return suma / float(miembros.size())


func _process(delta: float) -> void:
	if _etiqueta == null:
		return
	_acumulado += delta
	var pasos := 0
	while _acumulado >= PASO_SEG and pasos < PASOS_MAX_POR_CUADRO:
		_paso()
		_acumulado -= PASO_SEG
		_reloj += PASO_SEG
		pasos += 1
	_acumulado = minf(_acumulado, PASO_SEG)
	_vista.dibujar_cuerpos(_cuerpos, _acumulado / PASO_SEG, delta, _foco())
	var linea := ""
	if _grupo == 0:
		for i in range(1, 11):
			linea += "%s  " % _cuerpos.get_accion(i)
	_etiqueta.text = "%s (toque: otro grupo)\n%s" % [GRUPOS[_grupo][0], linea]


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_pressed() and (evento is InputEventKey or evento is InputEventMouseButton
			or evento is InputEventScreenTouch):
		_grupo = (_grupo + 1) % GRUPOS.size()


## Sin pantalla: la vista se dibuja igual (sin mostrarse) para medir los pies.
func _medir(segundos: float) -> void:
	var peor_salto := 0.0
	var minima_en_vuelta := INF
	var metros := {}
	var tiempo_en := {}
	var r_previa: PackedFloat32Array = _cuerpos.get_rapidez()
	for k in int(segundos / PASO_SEG):
		_paso()
		var pos: PackedVector2Array = _cuerpos.get_pos()
		var previa: PackedVector2Array = _cuerpos.get_pos_previa()
		var r: PackedFloat32Array = _cuerpos.get_rapidez()
		for i in 22:
			peor_salto = maxf(peor_salto, pos[i].distance_to(previa[i]) - maxf(r[i], r_previa[i]) * PASO_SEG)
		for i in range(12, 17):
			if absf(pos[i].x) > PIQUE_X - 6.0:
				minima_en_vuelta = minf(minima_en_vuelta, r[i])
		r_previa = r
		_vista.dibujar_cuerpos(_cuerpos, 1.0, PASO_SEG, _foco())
		_detector.medir(_vista._jugadores, PASO_SEG)
		for p3 in _vista._jugadores:
			var anim: String = p3._anim_actual
			tiempo_en[anim] = float(tiempo_en.get(anim, 0.0)) + PASO_SEG
		for i in 22:
			var anim: String = _vista._jugadores[i]._anim_actual
			metros[anim] = float(metros.get(anim, 0.0)) + r[i] * PASO_SEG
	print("%s %.0f s: %d gestos terminados, peor exceso de paso %s m, rapidez mínima en las medias vueltas %.2f m/s"
		% [PREFIJO, segundos, _completados, peor_salto, minima_en_vuelta])
	for anim in ["Correr", "Trotar", "Caminar", "Correr_Costado_Izq", "Correr_Costado_Der", "Correr_Espaldas",
			"Arranque", "Frenada", "Giro_90_Izq", "Giro_90_Der", "Giro_180_Izq", "Giro_180_Der", "Media_Vuelta_Izq", "Media_Vuelta_Der", "Respirar", "Golero_Guardia", "Patear_Corriendo", "Control_Corriendo", DetectorPatinaV2.FUNDIDO]:
		if anim == DetectorPatinaV2.FUNDIDO:
			print("%s PATINA %s: %.2f m/s con el pie apoyado, mientras un clip se funde con otro" % [
				PREFIJO, anim, _detector.patina(anim)])
			continue
		if not tiempo_en.has(anim):
			continue
		var t: float = tiempo_en[anim]
		print("%s PATINA %s: %.2f m/s con el pie apoyado; el cuerpo iba a %.2f m/s (%.0f s de clip)" % [
			PREFIJO, anim, _detector.patina(anim), float(metros.get(anim, 0.0)) / maxf(t, 0.001), t])
	print("%s PATINA todos: %.2f m/s" % [PREFIJO, _detector.patina()])
