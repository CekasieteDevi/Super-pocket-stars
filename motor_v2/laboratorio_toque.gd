extends Control

## Laboratorio del toque, etapa 3 de docs/motor_v2.md: la canchita en C++
## (CanchitaV2Nativa) con pelota, cuerpos y cerebros sencillos, dibujada con
## los Jugador3D del partido (VistaV2). La vista solo lee: posiciones,
## acciones con su segundo y la pelota.
##
## - Rondo: 4 contra 2 en un cuadrado de 12 m. Si un defensor la toca, corte.
## - Partidito: 5 contra 5 sin arcos en 40 × 30 m.
##
## Con pantalla: un toque o una tecla pasa del rondo al partidito y vuelta.
## Sin pantalla (--headless): simula `segundos=N` (60) de cada juego con la
## vista dibujando, mide el patinaje de pies (DetectorPatinaV2) y lo que
## cuenta el motor, imprime con [lab_toque] y sale.
## Argumentos (después de `--`): `modo=rondo|partidito`, `semilla=N`, `segundos=N`.

const PREFIJO := "[lab_toque]"
const PASO_SEG := 1.0 / 60.0
const PASOS_MAX_POR_CUADRO := 4
const SEMILLA := 20261001
const MODOS := ["Rondo 4 contra 2", "Partidito 5 contra 5"]

var _canchita: Object
var _vista: VistaV2
var _etiqueta: Label
var _modo := 0
var _semilla := SEMILLA
var _acumulado := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var segundos := 60.0
	var modos := [0, 1]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("segundos="):
			segundos = float(arg.get_slice("=", 1))
		elif arg.begins_with("semilla="):
			_semilla = int(arg.get_slice("=", 1))
		elif arg.begins_with("modo="):
			_modo = 1 if arg.get_slice("=", 1) == "partidito" else 0
			modos = [_modo]
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		for m in modos:
			_modo = m
			_armar()
			await get_tree().process_frame
			_medir(segundos)
		get_tree().quit()
		return
	_armar()
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16, 16)
	_etiqueta.add_theme_font_size_override("font_size", 26)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	add_child(_etiqueta)


## La canchita del modo actual y una vista nueva con sus jugadores.
func _armar() -> void:
	_canchita = CanchitaV2.armar(_modo, _semilla)
	if _vista != null:
		_vista.queue_free()
	_vista = VistaV2.new()
	_vista.equipos = _canchita.get_equipos()
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	if _modo == CanchitaV2Nativa.RONDO:
		_vista.marcar_rectangulo(6.0, 6.0)
	else:
		_vista.marcar_rectangulo(20.0, 15.0)
	if _etiqueta != null:
		move_child(_etiqueta, -1)


func _process(delta: float) -> void:
	if _etiqueta == null:
		return
	_acumulado += delta
	var pasos := 0
	while _acumulado >= PASO_SEG and pasos < PASOS_MAX_POR_CUADRO:
		_canchita.avanzar()
		_acumulado -= PASO_SEG
		pasos += 1
	_acumulado = minf(_acumulado, PASO_SEG)
	_vista.dibujar_canchita(_canchita, _acumulado / PASO_SEG, delta)
	var k: Dictionary = _canchita.contadores()
	var pases := maxf(float(k["pases"]), 1.0)
	_etiqueta.text = "%s (toque: cambiar)\npases %d · completos %.0f%% · cortes %d · afuera %d\ncorrecciones %d · espera media %.2f s" % [
		MODOS[_modo], k["pases"], 100.0 * (float(k["completados"]) + float(k["completados_otro"])) / pases,
		k["cortes"], k["pases_afuera"], k["correcciones"], k["espera_media"]]


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_pressed() and (evento is InputEventKey or evento is InputEventMouseButton
			or evento is InputEventScreenTouch):
		_modo = 1 - _modo
		_armar()


## Sin pantalla: la vista se dibuja igual (sin mostrarse) para medir los pies.
func _medir(segundos: float) -> void:
	var detector := DetectorPatinaV2.new()
	var tiempo_en := {}
	var metros := {}
	var reloj := Time.get_ticks_usec()
	var clips := FisicaV2.clips()
	var toques_antes := 0
	var huecos := []
	for k in int(segundos / PASO_SEG):
		_canchita.avanzar()
		_vista.dibujar_canchita(_canchita, 1.0, PASO_SEG)
		detector.medir(_vista._jugadores, PASO_SEG)
		# En el paso del toque la pelota todavía no se movió: está donde la
		# tocaron. El hueco es lo que separa el hueso del modelo (en su pose
		# de ese cuadro) del borde de la pelota.
		var c: Dictionary = _canchita.contadores()
		var toques := int(c["pases"]) + int(c["conducciones"]) + int(c["controles"])
		if toques > toques_antes:
			var i: int = _canchita.get_ultimo_toque()
			var accion: String = _canchita.get_accion(i)
			if i >= 0 and clips.has(accion) and str(clips[accion].get("ancla", "")) in ["Pie_R", "Pie_L"]:
				var ancla: Vector3 = _vista._jugadores[i].ancla_de_pose(str(clips[accion]["ancla"]))
				var radio := MundoV2.RADIO_PELOTA * Cancha3D.ESCALA_PELOTA
				huecos.append(maxf(0.0, ancla.distance_to(_vista._pelota.position) - radio))
		toques_antes = toques
		var r: PackedFloat32Array = _canchita.get_rapidez()
		for i in _vista._jugadores.size():
			var anim: String = _vista._jugadores[i]._anim_actual
			tiempo_en[anim] = float(tiempo_en.get(anim, 0.0)) + PASO_SEG
			metros[anim] = float(metros.get(anim, 0.0)) + r[i] * PASO_SEG
	var ms := float(Time.get_ticks_usec() - reloj) / 1000.0 / (segundos / PASO_SEG)
	var k: Dictionary = _canchita.contadores()
	var claves := k.keys()
	claves.sort()
	var linea := ""
	for clave in claves:
		linea += "%s=%s " % [clave, str(snappedf(float(k[clave]), 0.001))]
	print("%s %s %.0f s (%.2f ms por paso con la vista): %s" % [PREFIJO, MODOS[_modo], segundos, ms, linea])
	huecos.sort()
	if not huecos.is_empty():
		print("%s HUECO pie-pelota dibujados en el toque (con el ajuste de pie): mediana %.2f m, 90%% %.2f m, peor %.2f m (%d toques)" % [
			PREFIJO, huecos[huecos.size() / 2], huecos[huecos.size() * 9 / 10], huecos[-1], huecos.size()])
	# Los gestos (patear, controlar) no están hechos en cinta: el detector
	# toma como apoyado al pie que patea. Solo se miden los de andar.
	for anim in ["Correr", "Trotar", "Caminar", "Arranque", "Frenada", DetectorPatinaV2.FUNDIDO]:
		if anim == DetectorPatinaV2.FUNDIDO:
			print("%s PATINA %s: %.2f m/s con el pie apoyado" % [PREFIJO, anim, detector.patina(anim)])
			continue
		if not tiempo_en.has(anim):
			continue
		var t: float = tiempo_en[anim]
		print("%s PATINA %s: %.2f m/s con el pie apoyado; el cuerpo iba a %.2f m/s (%.0f s de clip)" % [
			PREFIJO, anim, detector.patina(anim), float(metros.get(anim, 0.0)) / maxf(t, 0.001), t])
