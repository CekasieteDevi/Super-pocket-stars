class_name Pelota
extends Control

## Pelota (Fase 8, sprite pixel-art vía PixelArt.pelota_textura) que se
## mueve por la cancha según la zona del evento actual. Sin animación de
## jugadores todavía: el motor no calcula posiciones x/y por jugador, solo
## zona de la jugada (armado/último tercio), así que "muñequitos"
## completos con 22 jugadores moviéndose es trabajo de fase 9 en adelante.

var _textura: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_textura = PixelArt.pelota_textura()


func _draw() -> void:
	draw_texture_rect(_textura, Rect2(Vector2.ZERO, size), false)
