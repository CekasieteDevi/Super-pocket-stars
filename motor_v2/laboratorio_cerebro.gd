extends Control

## Laboratorio del cerebro, etapa 4 de docs/motor_v2.md: 11 contra 11 en la
## cancha entera (CanchitaV2Nativa, modo PARTIDO) con el cerebro en C++,
## dibujado con los Jugador3D del partido (VistaV2). Sin las reglas de la
## etapa 6: la pelota que sale vuelve con un lateral, un córner o un saque de
## arco. Desde la etapa 5 hay remates, arqueros que atajan y goles, que se
## sacan del medio.
##
## Con pantalla: arriba a la izquierda, lo que cuenta el motor y la última
## decisión del poseedor con sus mejores opciones. Un toque o una tecla arma
## otro partido con la semilla siguiente.
## Sin pantalla (--headless): simula `segundos=N` (120) con la vista
## dibujando, mide el patinaje de pies (DetectorPatinaV2) y lo que cuenta el
## motor, imprime con [lab_cerebro] y sale.
## Argumentos (después de `--`): `semilla=N`, `segundos=N`.

const PREFIJO := "[lab_cerebro]"
const PASO_SEG := 1.0 / 60.0
const PASOS_MAX_POR_CUADRO := 4
const SEMILLA := 20261002
const FASES := ["circulación", "aceleración", "transición"]
const ROLES := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]

var _partido: Object
var _vista: VistaV2
var _etiqueta: Label
var _semilla := SEMILLA
var _acumulado := 0.0
var _roles := PackedInt32Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var segundos := 120.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("segundos="):
			segundos = float(arg.get_slice("=", 1))
		elif arg.begins_with("semilla="):
			_semilla = int(arg.get_slice("=", 1))
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		_armar()
		await get_tree().process_frame
		_medir(segundos)
		get_tree().quit()
		return
	_armar()
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16, 16)
	_etiqueta.add_theme_font_size_override("font_size", 22)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	add_child(_etiqueta)


func _armar() -> void:
	_partido = CerebroV2.armar_partido(_semilla)
	_roles = _partido.get_roles()
	if _vista != null:
		_vista.queue_free()
	_vista = VistaV2.new()
	# Sin pantalla mide a todos, también a los que la cámara no muestra.
	_vista.clavar_fuera_de_camara = DisplayServer.get_name() == "headless"
	_vista.equipos = _partido.get_equipos()
	_vista.arqueros = _partido.get_arqueros()
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	if _etiqueta != null:
		move_child(_etiqueta, -1)


func _process(delta: float) -> void:
	if _etiqueta == null:
		return
	_acumulado += delta
	var pasos := 0
	while _acumulado >= PASO_SEG and pasos < PASOS_MAX_POR_CUADRO:
		_partido.avanzar()
		_acumulado -= PASO_SEG
		pasos += 1
	_acumulado = minf(_acumulado, PASO_SEG)
	_vista.dibujar_canchita(_partido, _acumulado / PASO_SEG, delta)
	_etiqueta.text = _texto()


func _texto() -> String:
	var k: Dictionary = _partido.contadores()
	var pases := maxf(float(k["pases"]), 1.0)
	var segundos := float(k["pasos"]) * PASO_SEG
	var fase: int = _partido.get_fase_ritmo()
	var t := "Semilla %d · %d:%02d (toque: otro partido)\n" % [_semilla, int(segundos) / 60, int(segundos) % 60]
	t += "pases %d · completos %.0f%% · al espacio %d (%d llegan)\n" % [k["pases"],
		100.0 * (float(k["completados"]) + float(k["completados_otro"])) / pases, k["pases_al_espacio"],
		k["pases_al_espacio_completos"]]
	t += "posesiones %d · de 3+ pases %d · de 5+ %d · llegadas %d-%d\n" % [k["posesiones"], k["posesiones_3_pases"],
		k["posesiones_5_pases"], k["llegadas_0"], k["llegadas_1"]]
	var goles: PackedInt32Array = _partido.get_goles()
	t += "goles %d-%d · remates %d-%d · atajados %d\n" % [goles[0], goles[1], k["remates_0"], k["remates_1"],
		k["remates_atajado"]]
	t += "ritmo: %s · correcciones %d\n" % [FASES[clampi(fase, 0, 2)], k["correcciones"]]
	var d: Dictionary = _partido.ultima_decision()
	if int(d["decisor"]) >= 0:
		var opciones: Array = d["opciones"]
		opciones.sort_custom(func(a, b): return float(a["utilidad"]) > float(b["utilidad"]))
		t += "%s (T %.2f):" % [ROLES[_roles[d["decisor"]]], d["temperatura"]]
		for o in opciones.slice(0, 4):
			var a: String = ROLES[_roles[o["receptor"]]] if int(o["receptor"]) >= 0 else ""
			t += " %s%s %.2f ·" % [o["tipo"], (" a " + a) if a != "" else "", o["utilidad"]]
	return t


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_pressed() and (evento is InputEventKey or evento is InputEventMouseButton
			or evento is InputEventScreenTouch):
		_semilla += 1
		_armar()


## Sin pantalla: la vista se dibuja igual (sin mostrarse) para medir los pies.
func _medir(segundos: float) -> void:
	var detector := DetectorPatinaV2.new()
	var tiempo_en := {}
	var metros := {}
	var reloj := Time.get_ticks_usec()
	for k in int(segundos / PASO_SEG):
		_partido.avanzar()
		_vista.dibujar_canchita(_partido, 1.0, PASO_SEG)
		detector.medir(_vista._jugadores, PASO_SEG)
		var r: PackedFloat32Array = _partido.get_rapidez()
		for i in _vista._jugadores.size():
			var anim: String = _vista._jugadores[i]._anim_actual
			tiempo_en[anim] = float(tiempo_en.get(anim, 0.0)) + PASO_SEG
			metros[anim] = float(metros.get(anim, 0.0)) + r[i] * PASO_SEG
	var ms := float(Time.get_ticks_usec() - reloj) / 1000.0 / (segundos / PASO_SEG)
	var k: Dictionary = _partido.contadores()
	print("%s %.0f s (%.2f ms por paso con la vista): pases=%d posesiones=%d de_3=%d de_5=%d al_espacio=%d correcciones=%d" % [
		PREFIJO, segundos, ms, k["pases"], k["posesiones"], k["posesiones_3_pases"], k["posesiones_5_pases"],
		k["pases_al_espacio"], k["correcciones"]])
	for anim in ["Correr", "Trotar", "Caminar", "Arranque", "Frenada", DetectorPatinaV2.FUNDIDO]:
		if anim == DetectorPatinaV2.FUNDIDO:
			print("%s PATINA %s: %.2f m/s con el pie apoyado" % [PREFIJO, anim, detector.patina(anim)])
			continue
		if not tiempo_en.has(anim):
			continue
		var t: float = tiempo_en[anim]
		print("%s PATINA %s: %.2f m/s con el pie apoyado; el cuerpo iba a %.2f m/s (%.0f s de clip)" % [
			PREFIJO, anim, detector.patina(anim), float(metros.get(anim, 0.0)) / maxf(t, 0.001), t])
