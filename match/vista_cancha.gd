class_name VistaCancha
extends Control

## Dibuja la cancha proyectada y los cuerpos que hay sobre ella. NO sabe
## nada del motor: recibe una lista de entidades ya resueltas
## (posición en metros + altura) y las proyecta.
##
## Etapa 1 de la vista nueva: proyección, cámara, cancha y sprites con
## sombra. Pelota con altura, minimapa, HUD y efectos vienen después.

## Estado de la cancha (§8.4 #21 del GDD): un potrero de división 10 se ve
## de tierra y un césped híbrido, verde parejo. Es el mismo dato que ya
## usa EstadoCancha en el motor.
const PALETAS := {
	"potrero": {
		"claro": Color(0.55, 0.44, 0.28), "oscuro": Color(0.49, 0.39, 0.24),
		"linea": Color(0.88, 0.86, 0.80, 0.85),
	},
	"regular": {
		"claro": Color(0.28, 0.50, 0.22), "oscuro": Color(0.24, 0.45, 0.19),
		"linea": Color(0.92, 0.94, 0.90, 0.9),
	},
	"hibrido": {
		"claro": Color(0.19, 0.56, 0.24), "oscuro": Color(0.15, 0.50, 0.20),
		"linea": Color.WHITE,
	},
}

const COLOR_TRIBUNA := Color(0.16, 0.17, 0.20)
const COLOR_TRIBUNA_BORDE := Color(0.10, 0.11, 0.13)
const FRANJAS := 12
const ANCHO_SPRITE_PX := 26.0

var camara := CamaraPartido.new()
var estado_cancha := "regular"

## Cada entidad: {"pos": Vector2 (metros), "z": float, "tipo": "jugador"/"pelota",
## "color": Color}. La vista las ordena por profundidad y las dibuja.
var entidades: Array = []

var _tex_sombra: ImageTexture
var _tex_pelota: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_sombra = SpritesPartido.sombra()
	_tex_pelota = SpritesPartido.pelota()


func _p(x: float, y: float, z: float = 0.0) -> Vector2:
	return ProyeccionPartido.sim_a_pantalla(x, y, z, camara.centro, camara.px_por_metro, size * 0.5)


func _draw() -> void:
	var pal: Dictionary = PALETAS.get(estado_cancha, PALETAS["regular"])
	_dibujar_tribunas()
	_dibujar_cesped(pal)
	_dibujar_lineas(pal)
	_dibujar_entidades()


## Las franjas siguen la proyección: son paralelogramos, no rectángulos
## verticales. Es lo que hace que la cancha se lea inclinada.
func _dibujar_cesped(pal: Dictionary) -> void:
	var paso := ProyeccionPartido.LARGO / float(FRANJAS)
	var y0 := -ProyeccionPartido.MEDIO_ANCHO
	var y1 := ProyeccionPartido.MEDIO_ANCHO
	for i in range(FRANJAS):
		var xa := -ProyeccionPartido.MEDIO_LARGO + i * paso
		var xb := xa + paso
		draw_colored_polygon(PackedVector2Array([
			_p(xa, y0), _p(xb, y0), _p(xb, y1), _p(xa, y1),
		]), pal["claro"] if i % 2 == 0 else pal["oscuro"])


func _dibujar_lineas(pal: Dictionary) -> void:
	var c: Color = pal["linea"]
	var grosor := maxf(1.5, camara.px_por_metro * 0.06)
	var L := ProyeccionPartido.MEDIO_LARGO
	var A := ProyeccionPartido.MEDIO_ANCHO

	_poli([Vector2(-L, -A), Vector2(L, -A), Vector2(L, A), Vector2(-L, A)], c, grosor)
	draw_line(_p(0, -A), _p(0, A), c, grosor)
	_circulo(Vector2.ZERO, 9.15, c, grosor)

	for lado in [-1.0, 1.0]:
		# Área grande (16,5 x 40,32) y chica (5,5 x 18,32), reglamentarias.
		_poli([
			Vector2(lado * L, -20.16), Vector2(lado * (L - 16.5), -20.16),
			Vector2(lado * (L - 16.5), 20.16), Vector2(lado * L, 20.16),
		], c, grosor)
		_poli([
			Vector2(lado * L, -9.16), Vector2(lado * (L - 5.5), -9.16),
			Vector2(lado * (L - 5.5), 9.16), Vector2(lado * L, 9.16),
		], c, grosor)
		draw_circle(_p(lado * (L - 11.0), 0.0), grosor * 1.2, c)


func _poli(puntos: Array, c: Color, grosor: float) -> void:
	for i in range(puntos.size()):
		var a: Vector2 = puntos[i]
		var b: Vector2 = puntos[(i + 1) % puntos.size()]
		draw_line(_p(a.x, a.y), _p(b.x, b.y), c, grosor)


func _circulo(centro: Vector2, radio: float, c: Color, grosor: float) -> void:
	var pasos := 28
	var previo := _p(centro.x + radio, centro.y)
	for i in range(1, pasos + 1):
		var ang := TAU * float(i) / pasos
		var actual := _p(centro.x + cos(ang) * radio, centro.y + sin(ang) * radio)
		draw_line(previo, actual, c, grosor)
		previo = actual


## Tribunas: por ahora bloques planos en los bordes, para que se entienda
## que la cancha está adentro de un estadio. El público en pixel art es
## etapa 6.
func _dibujar_tribunas() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_TRIBUNA)
	var L := ProyeccionPartido.MEDIO_LARGO
	var A := ProyeccionPartido.MEDIO_ANCHO
	var m := 5.0
	draw_colored_polygon(PackedVector2Array([
		_p(-L - m, -A - m), _p(L + m, -A - m), _p(L + m, A + m), _p(-L - m, A + m),
	]), COLOR_TRIBUNA_BORDE)


## Y-sort: se dibuja de fondo hacia adelante según la Y de simulación, así
## un jugador más cercano a la cámara tapa al que está detrás.
func _dibujar_entidades() -> void:
	var orden := entidades.duplicate()
	orden.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for ent in orden:
		_dibujar_sombra(ent)
	for ent in orden:
		_dibujar_cuerpo(ent)


## La sombra va SIEMPRE en el piso (z=0) aunque el cuerpo esté en el aire:
## es justamente la separación entre sombra y cuerpo la que comunica la
## altura.
func _dibujar_sombra(ent: Dictionary) -> void:
	var suelo := _p(ent["pos"].x, ent["pos"].y, 0.0)
	var escala: float = camara.px_por_metro / CamaraPartido.PX_POR_METRO_BASE
	var alto_z: float = float(ent.get("z", 0.0))
	# Más alto = sombra más chica y más tenue.
	var reduccion: float = clampf(1.0 - alto_z * 0.05, 0.45, 1.0)
	var ancho: float = (19.0 if ent["tipo"] == "jugador" else 10.0) * escala * reduccion
	var alto := ancho * 0.5
	draw_texture_rect(_tex_sombra,
		Rect2(suelo - Vector2(ancho, alto) * 0.5, Vector2(ancho, alto)), false,
		Color(1, 1, 1, reduccion))


func _dibujar_cuerpo(ent: Dictionary) -> void:
	var escala: float = camara.px_por_metro / CamaraPartido.PX_POR_METRO_BASE
	var punto := _p(ent["pos"].x, ent["pos"].y, float(ent.get("z", 0.0)))
	if ent["tipo"] == "pelota":
		var d := 11.0 * escala
		draw_texture_rect(_tex_pelota, Rect2(punto - Vector2(d, d) * 0.5, Vector2(d, d)), false)
		return

	var tex := SpritesPartido.jugador(
		ent["color"],
		int(ent.get("direccion", SpritesPartido.ABAJO)),
		str(ent.get("pose", SpritesPartido.QUIETO)))
	var ancho := ANCHO_SPRITE_PX * escala
	var alto := ancho * (float(tex.get_height()) / float(tex.get_width()))
	# El sprite se apoya en el punto: los pies quedan en el piso.
	draw_texture_rect(tex, Rect2(punto - Vector2(ancho * 0.5, alto), Vector2(ancho, alto)), false)
