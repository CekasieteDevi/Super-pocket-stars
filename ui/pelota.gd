class_name Pelota
extends Control

## Pelota placeholder (Fase 8) — un círculo que se mueve por la cancha
## según la zona del evento actual. Sin animación de jugadores todavía: el
## motor no calcula posiciones x/y por jugador, solo zona de la jugada
## (armado/último tercio), así que "muñequitos" completos con 22
## jugadores moviéndose es trabajo de fase 9 en adelante, cuando además
## haya arte real para mostrar.


func _draw() -> void:
	draw_circle(size / 2.0, size.x / 2.0, Color.WHITE)
