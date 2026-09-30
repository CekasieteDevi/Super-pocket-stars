extends Control

## Laboratorio de la pelota, etapa 1 de docs/motor_v2.md: dispara los
## disparos de DisparosPelotaV2 (tiros, centros, globos, palo, travesaño,
## saque de arco) con la pelota en C++ (PelotaV2Nativa) y la cámara del
## partido 3D (VistaV2). La vista solo dibuja: interpola entre los dos
## últimos pasos del mundo y nunca mueve la pelota.
##
## Con pantalla pasa de un disparo al siguiente solo; un toque o una tecla
## salta al que sigue. Sin pantalla (--headless) simula todos, imprime lo
## que midió cada uno con el prefijo [lab_pelota] y sale.
##
## Argumentos (después de `--`): `disparo=N` (solo ese, contando desde 0),
## `cancha=N` (calidad de EstadoCancha, -8 a +3), `clima=Lluvia|Viento`.

const PREFIJO := "[lab_pelota]"
const PASO_SEG := 1.0 / 60.0
## Si un cuadro se atrasa, no se ponen más de estos pasos de golpe.
const PASOS_MAX_POR_CUADRO := 4
## Pausa con la pelota quieta antes del disparo siguiente.
const PAUSA_SEG := 1.0

var _disparos: Array[Dictionary] = DisparosPelotaV2.lista()
var _parametros: Dictionary
var _pelota: Object
var _vista: VistaV2
var _etiqueta: Label
var _actual := 0
var _reloj := 0.0
var _acumulado := 0.0
var _solo := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cancha := 0.0
	var clima := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("disparo="):
			_solo = int(arg.get_slice("=", 1))
		elif arg.begins_with("cancha="):
			cancha = float(arg.get_slice("=", 1))
		elif arg.begins_with("clima="):
			clima = arg.get_slice("=", 1)
	_parametros = FisicaV2.parametros(cancha, clima)
	_pelota = ClassDB.instantiate("PelotaV2Nativa")
	_pelota.configurar(_parametros)
	if _solo >= 0:
		_disparos = [_disparos[_solo]]
	if DisplayServer.get_name() == "headless":
		_medir_todo()
		get_tree().quit()
		return
	_vista = VistaV2.new()
	_vista.con_jugadores = false
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16, 16)
	_etiqueta.add_theme_font_size_override("font_size", 28)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	add_child(_etiqueta)
	_disparar(0)


func _disparar(i: int) -> void:
	_actual = i % _disparos.size()
	var d: Dictionary = _disparos[_actual]
	_pelota.configurar(_parametros)
	_pelota.poner(d["pos"], d["vel"], d["giro"])
	_reloj = 0.0
	_acumulado = 0.0


func _process(delta: float) -> void:
	if _vista == null:
		return
	var d: Dictionary = _disparos[_actual]
	_acumulado += delta
	var pasos := 0
	while _acumulado >= PASO_SEG and pasos < PASOS_MAX_POR_CUADRO:
		_pelota.avanzar()
		_acumulado -= PASO_SEG
		_reloj += PASO_SEG
		pasos += 1
	_acumulado = minf(_acumulado, PASO_SEG)
	_vista.dibujar_pelota(_pelota.get_previa(), _pelota.get_pos(), _acumulado / PASO_SEG, delta,
		_pelota.get_giro())
	var c: Dictionary = _pelota.contadores()
	_etiqueta.text = "%s\npiques %d · palos %d · travesaño %d · red %d · saltos %d\n%.1f m/s" % [
		d["nombre"], c["piques"], c["palos"], c["travesanos"], c["redes"], c["saltos"],
		_pelota.get_vel().length()]
	if _reloj >= float(d["segundos"]) + PAUSA_SEG:
		_disparar(_actual + 1)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_pressed() and (evento is InputEventKey or evento is InputEventMouseButton
			or evento is InputEventScreenTouch):
		_disparar(_actual + 1)


## Sin pantalla: cada disparo entero, con lo que hace falta para revisarlo
## sin mirarlo.
func _medir_todo() -> void:
	for d in _disparos:
		var m := DisparosPelotaV2.medir(_pelota, _parametros, d)
		print("%s %s: piques=%d palos=%d travesanos=%d redes=%d saltos=%d primer_pique_x=%.1f " % [
			PREFIJO, d["nombre"], m["piques"], m["palos"], m["travesanos"], m["redes"], m["saltos"],
			m["primer_pique_x"]]
			+ "altura_max=%.2f rodo_m=%.1f desvio_m=%.2f fin=%s quieta=%s" % [
			m["altura_max"], m["rodo_m"], m["desvio_m"], m["fin"], m["quieta"]])

