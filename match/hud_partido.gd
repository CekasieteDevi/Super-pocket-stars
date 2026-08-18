class_name HudPartido
extends Control

## Marcador, reloj, quién tiene la pelota y los controles.
##
## Distribución pensada para celular horizontal: todo lo que se toca va en
## los BORDES, porque con el teléfono agarrado con las dos manos el pulgar
## llega a los costados y no al centro. El centro queda libre para ver el
## partido.
##
##   arriba izq: reloj + tiempo        arriba centro: marcador
##   borde izq: velocidades            arriba der: menú
##   abajo izq: quién tiene la pelota  abajo der: minimapa (lo pone VistaPartido)

signal velocidad_pedida(v: float)
signal pausa_pedida
signal saltar_pedido
signal menu_pedido

## Mínimo táctil recomendado en Android. No bajar de acá.
const TOQUE_MIN := 48.0
const MARGEN := 14.0
const COLOR_PANEL := Color(0.07, 0.08, 0.10, 0.78)
const COLOR_TEXTO := Color(0.96, 0.96, 0.98)
const COLOR_TENUE := Color(0.72, 0.74, 0.78)

var nombre_local := ""
var nombre_visitante := ""
var color_local := Color.WHITE
var color_visitante := Color.WHITE
var goles_local := 0
var goles_visitante := 0
var minuto := 0
var poseedor := ""

var _columna: VBoxContainer
var _boton_pausa: Button
var _boton_menu: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Velocidades: columna en el borde izquierdo, a media altura.
	_columna = VBoxContainer.new()
	_columna.add_theme_constant_override("separation", 6)
	add_child(_columna)
	for etiqueta in ["x1", "x2", "x4", "x8", "x16"]:
		var v := float(etiqueta.substr(1))
		_columna.add_child(_boton(etiqueta, 62.0, func(): velocidad_pedida.emit(v)))
	_boton_pausa = _boton("Pausa", 62.0, func(): pausa_pedida.emit())
	_columna.add_child(_boton_pausa)
	_columna.add_child(_boton("Saltar", 62.0, func(): saltar_pedido.emit()))

	_boton_menu = _boton("Menú", 76.0, func(): menu_pedido.emit())
	add_child(_boton_menu)


func _boton(texto: String, ancho: float, al_tocar: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, TOQUE_MIN)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(al_tocar)
	return b


func marcar_pausa(pausado: bool) -> void:
	_boton_pausa.text = "Seguir" if pausado else "Pausa"


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		_reubicar()


func _reubicar() -> void:
	if _columna == null:
		return
	_columna.position = Vector2(MARGEN, (size.y - _columna.size.y) * 0.5)
	_boton_menu.position = Vector2(size.x - _boton_menu.size.x - MARGEN, MARGEN)


func _draw() -> void:
	_reubicar()
	var fuente := ThemeDB.fallback_font
	_dibujar_marcador(fuente)
	_dibujar_reloj(fuente)
	_dibujar_poseedor(fuente)


## Banner: camiseta, nombre, resultado, nombre, camiseta.
func _dibujar_marcador(fuente: Font) -> void:
	var resultado := "%d - %d" % [goles_local, goles_visitante]
	var tam_nombre := 18
	var tam_resultado := 26
	var an_local := fuente.get_string_size(nombre_local, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nombre).x
	var an_visita := fuente.get_string_size(nombre_visitante, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nombre).x
	var an_res := fuente.get_string_size(resultado, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_resultado).x
	var chip := 18.0
	var hueco := 12.0
	var ancho := chip * 2 + an_local + an_visita + an_res + hueco * 5
	var alto := 42.0
	var x := (size.x - ancho) * 0.5
	var y := MARGEN

	draw_rect(Rect2(Vector2(x, y), Vector2(ancho, alto)), COLOR_PANEL)
	var cx := x + hueco * 0.5
	var medio := y + alto * 0.5
	draw_rect(Rect2(Vector2(cx, medio - chip * 0.5), Vector2(chip, chip)), color_local)
	cx += chip + hueco
	draw_string(fuente, Vector2(cx, medio + 6), nombre_local, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nombre, COLOR_TEXTO)
	cx += an_local + hueco
	draw_string(fuente, Vector2(cx, medio + 9), resultado, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_resultado, COLOR_TEXTO)
	cx += an_res + hueco
	draw_string(fuente, Vector2(cx, medio + 6), nombre_visitante, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_nombre, COLOR_TEXTO)
	cx += an_visita + hueco
	draw_rect(Rect2(Vector2(cx, medio - chip * 0.5), Vector2(chip, chip)), color_visitante)


func _dibujar_reloj(fuente: Font) -> void:
	var tiempo := "1T" if minuto < 45 else "2T"
	var texto := "%d'" % minuto
	var r := Rect2(Vector2(MARGEN, MARGEN), Vector2(86, 44))
	draw_rect(r, COLOR_PANEL)
	draw_string(fuente, r.position + Vector2(10, 22), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COLOR_TEXTO)
	draw_string(fuente, r.position + Vector2(10, 38), tiempo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_TENUE)


## Quién tiene la pelota, en vivo. Es lo que conecta lo que se ve en la
## cancha con los jugadores que el usuario fichó.
func _dibujar_poseedor(fuente: Font) -> void:
	if poseedor == "":
		return
	var tam := 17
	var an := fuente.get_string_size(poseedor, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var r := Rect2(Vector2(MARGEN, size.y - 44 - MARGEN), Vector2(an + 22, 34))
	draw_rect(r, COLOR_PANEL)
	draw_string(fuente, r.position + Vector2(11, 23), poseedor, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, COLOR_TEXTO)
