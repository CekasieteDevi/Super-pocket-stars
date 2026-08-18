class_name CamaraPartido
extends RefCounted

## Cámara del partido: sigue la pelota con suavizado y anticipación, y
## nunca deja ver fuera de la cancha.
##
## No es un Camera2D: la vista dibuja todo con _draw() y la proyección
## recibe el centro y el zoom, así que la cámara es solo estado. Eso
## permite tener control total del orden de dibujo (Y-sort) sin pelearse
## con el árbol de nodos.

## Zoom base, en píxeles por metro. Con ~22 px/m entra alrededor de un
## cuarto de la cancha en una pantalla de celular horizontal, que es el
## encuadre de referencia.
const PX_POR_METRO_BASE := 22.0

## Cuánto se abre en jugadas de área y en el gol (valores menores = se ve
## más cancha).
const PX_POR_METRO_AREA := 18.0
const PX_POR_METRO_GOL := 15.0

## Segundos de la pelota que la cámara mira "hacia adelante". Sin esto la
## cámara siempre va atrás de la jugada.
const ANTICIPACION := 0.45

## Qué tan rápido alcanza su objetivo (por segundo). Alto = pega saltos,
## bajo = se queda colgada.
const SUAVIZADO := 3.2
const SUAVIZADO_ZOOM := 2.5

## Margen de cancha que sí se puede mostrar: da aire para las tribunas.
const MARGEN_M := 2.0

var centro := Vector2.ZERO
var px_por_metro := PX_POR_METRO_BASE

var _objetivo_zoom := PX_POR_METRO_BASE


## `objetivo` es dónde está la pelota; `velocidad` hacia dónde va (m/s).
func seguir(objetivo: Vector2, velocidad: Vector2, tamano_pantalla: Vector2, delta: float) -> void:
	var deseado := objetivo + velocidad * ANTICIPACION
	var t: float = clampf(delta * SUAVIZADO, 0.0, 1.0)
	centro = centro.lerp(deseado, t)

	px_por_metro = lerpf(px_por_metro, _objetivo_zoom, clampf(delta * SUAVIZADO_ZOOM, 0.0, 1.0))
	_clampear(tamano_pantalla)


## Se llama cuando la jugada entra al área o hay gol, para abrir un poco
## el plano y que se entienda el contexto.
func fijar_encuadre(en_area: bool, festejo: bool) -> void:
	if festejo:
		_objetivo_zoom = PX_POR_METRO_GOL
	elif en_area:
		_objetivo_zoom = PX_POR_METRO_AREA
	else:
		_objetivo_zoom = PX_POR_METRO_BASE


## Nunca mostrar el vacío: el centro se limita para que el encuadre quede
## adentro de la cancha más el margen de tribunas. Si el zoom es tan
## abierto que la cancha entra entera, se centra y listo.
func _clampear(tamano_pantalla: Vector2) -> void:
	var visible := ProyeccionPartido.metros_visibles(tamano_pantalla, px_por_metro)
	var limite_x: float = ProyeccionPartido.MEDIO_LARGO + MARGEN_M - visible.x * 0.5
	var limite_y: float = ProyeccionPartido.MEDIO_ANCHO + MARGEN_M - visible.y * 0.5
	centro.x = clampf(centro.x, -limite_x, limite_x) if limite_x > 0.0 else 0.0
	centro.y = clampf(centro.y, -limite_y, limite_y) if limite_y > 0.0 else 0.0


func saltar_a(objetivo: Vector2, tamano_pantalla: Vector2) -> void:
	centro = objetivo
	px_por_metro = _objetivo_zoom
	_clampear(tamano_pantalla)
