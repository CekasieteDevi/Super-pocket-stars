extends Control

## Laboratorio de las reglas, etapa 6 de docs/motor_v2.md: un partido de 90
## minutos con reglas (CanchitaV2Nativa con configurar_reglas) dibujado con
## los Jugador3D del partido (VistaV2). Se ve cada reanudación con el que saca
## llegando a la pelota, las faltas, las tarjetas, el offside, los cambios
## (el que sale camina hasta afuera) y el segundo tiempo con los lados
## cambiados (PartidoVistoV2 gira la cancha).
##
## Con pantalla: arriba a la izquierda el reloj, el marcador, la parada y lo
## último que pasó. Una tecla o un toque: "R" arma otro partido con la semilla
## siguiente; las flechas apuran (x1, x4, x16) para llegar al segundo tiempo.
## Sin pantalla (--headless): simula `segundos=N` (300) con la vista
## dibujando, imprime con [lab_reglas] lo que contó y cuánto costó, y sale.
## Argumentos (después de `--`): `semilla=N`, `segundos=N`, `tanda`.

const PREFIJO := "[lab_reglas]"
const PASO_SEG := 1.0 / 60.0
const SEMILLA := 20261010
const VELOCIDADES := [1, 4, 16]
const NOMBRE_EVENTO := {"saque": "saque", "gol": "GOL", "falta": "falta", "amarilla": "amarilla", "roja": "ROJA",
	"offside": "offside", "lesion": "lesión", "cambio": "cambio", "fin_tiempo": "fin del tiempo",
	"penal_tanda": "penal de la tanda"}
const NOMBRE_PARADA := {"nada": "", "saque_medio": "saque del medio", "lateral": "lateral", "saque_arco": "saque de arco",
	"corner": "córner", "tiro_libre": "tiro libre", "penal": "penal"}

var _partido: Object
var _visto: PartidoVistoV2
var _vista: VistaV2
var _etiqueta: Label
var _semilla := SEMILLA
var _tanda := false
var _acumulado := 0.0
var _velocidad := 0
var _composicion := PackedInt32Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var segundos := 300.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("segundos="):
			segundos = float(arg.get_slice("=", 1))
		elif arg.begins_with("semilla="):
			_semilla = int(arg.get_slice("=", 1))
		elif arg == "tanda":
			_tanda = true
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		_armar()
		await get_tree().process_frame
		_medir(segundos)
		get_tree().quit()
		return
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16, 16)
	_etiqueta.add_theme_font_size_override("font_size", 22)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	_armar()
	add_child(_etiqueta)


func _armar() -> void:
	_partido = CerebroV2.armar_partido(_semilla, "", "", -1, -1, true, _tanda)
	_visto = PartidoVistoV2.new(_partido)
	_composicion = PackedInt32Array()
	_rearmar_vista()


## La vista tiene un Jugador3D por cada uno: si alguien entra o se va, se arma
## de nuevo con los que hay.
func _rearmar_vista() -> void:
	_visto.actualizar()
	var ids := _visto.ids()
	if ids == _composicion and _vista != null:
		return
	_composicion = ids
	if _vista != null:
		_vista.queue_free()
	_vista = VistaV2.new()
	_vista.equipos = _visto.equipos()
	_vista.arqueros = _visto.arqueros()
	_vista.ids = ids
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	if _etiqueta != null:
		move_child(_etiqueta, -1)


func _process(delta: float) -> void:
	if _etiqueta == null:
		return
	_acumulado += delta * VELOCIDADES[_velocidad]
	var pasos := 0
	while _acumulado >= PASO_SEG and pasos < 4 * VELOCIDADES[_velocidad]:
		_partido.avanzar()
		_acumulado -= PASO_SEG
		pasos += 1
	_acumulado = minf(_acumulado, PASO_SEG)
	_rearmar_vista()
	_vista.dibujar_canchita(_visto, _acumulado / PASO_SEG, delta)
	_etiqueta.text = _texto()


func _texto() -> String:
	var e: Dictionary = _partido.get_estado()
	var k: Dictionary = _partido.contadores()
	var goles: PackedInt32Array = _partido.get_goles()
	var reloj := float(e["reloj"]) + (45.0 * 60.0 if e["periodo"] != "primer_tiempo" else 0.0)
	var t := "Semilla %d · %s %d:%02d (+%d) · x%d (R: otro, flechas: velocidad)\n" % [_semilla, e["periodo"],
		int(reloj) / 60, int(reloj) % 60, int(float(e["adicion"]) / 60.0), VELOCIDADES[_velocidad]]
	t += "Local %d - %d Visitante" % [goles[0], goles[1]]
	if e["periodo"] == "tanda" or Vector2i(e["pateados_tanda"]) != Vector2i.ZERO:
		t += " · penales %d-%d" % [Vector2i(e["goles_tanda"]).x, Vector2i(e["goles_tanda"]).y]
	var parada: String = NOMBRE_PARADA.get(str(e["parada"]), "")
	t += (" · " + parada) if parada != "" else ""
	t += "\nfaltas %d-%d · amarillas %d-%d · rojas %d-%d · offside %d-%d · cambios %d-%d\n" % [k["faltas_0"], k["faltas_1"],
		k["amarillas_0"], k["amarillas_1"], k["rojas_0"], k["rojas_1"], k["offsides_cobrados_0"],
		k["offsides_cobrados_1"], k["cambios_0"], k["cambios_1"]]
	var eventos: Array = _partido.eventos().filter(func(v): return v["tipo"] != "saque")
	for v in eventos.slice(maxi(0, eventos.size() - 5)):
		var minuto := int(float(v["paso"]) * PASO_SEG / 60.0)
		t += "%d' %s (%s)\n" % [minuto, NOMBRE_EVENTO.get(str(v["tipo"]), v["tipo"]),
			"local" if int(v["equipo"]) == 0 else "visitante"]
	return t


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed:
		if evento.keycode == KEY_RIGHT:
			_velocidad = mini(_velocidad + 1, VELOCIDADES.size() - 1)
			return
		if evento.keycode == KEY_LEFT:
			_velocidad = maxi(_velocidad - 1, 0)
			return
		if evento.keycode != KEY_R:
			return
	elif not (evento.is_pressed() and (evento is InputEventMouseButton or evento is InputEventScreenTouch)):
		return
	_semilla += 1
	_armar()


## Sin pantalla: la vista se dibuja igual (sin mostrarse) para ver que no se
## rompe con los que entran y salen y medir el costo.
func _medir(segundos: float) -> void:
	var reloj := Time.get_ticks_usec()
	var armadas := 0
	var n := int(segundos / PASO_SEG)
	for k in n:
		_partido.avanzar()
		var antes := _composicion
		_rearmar_vista()
		if _composicion != antes:
			armadas += 1
		_vista.dibujar_canchita(_visto, 1.0, PASO_SEG)
	var ms := float(Time.get_ticks_usec() - reloj) / 1000.0 / float(n)
	var k: Dictionary = _partido.contadores()
	var e: Dictionary = _partido.get_estado()
	print("%s %.0f s (%.2f ms por paso con la vista): %s reloj %.0f s, goles %d-%d, laterales %d, faltas %d, cambios %d, vista armada %d veces, correcciones %d" % [
		PREFIJO, segundos, ms, e["periodo"], e["reloj"], k["goles_0"], k["goles_1"], k["saques_lateral"],
		int(k["faltas_0"]) + int(k["faltas_1"]), int(k["cambios_0"]) + int(k["cambios_1"]), armadas,
		k["correcciones"]])
