class_name Cancha
extends Control

## Cancha dibujada por código — Fase 8, pulida con 22 posiciones fijas,
## sprites pixel-art (PixelArt.jugador_textura) y forma de equipo dinámica.
## El motor sigue sin calcular posiciones x/y por jugador durante el
## partido (solo zona de la jugada + la posición del que participa), así
## que lo que se ve acá es una aproximación: una FORMACIÓN FIJA por equipo
## (11 sprites cada uno, según FORMACION_SLOTS) que se ESTIRA/COMPACTA como
## bloque según la zona de la jugada actual — el equipo que ataca empuja
## su línea hacia adelante, el que defiende retrocede — y el jugador que
## participa de la jugada actual se resalta más grande. No son 22
## muñequitos con movimiento individual real, es la mejor aproximación de
## "dónde se para el equipo" con los datos que da el motor.

## Coordenadas normalizadas (0..1) del lado local, atacando hacia la
## derecha; el visitante espeja x (1-x) y ataca hacia la izquierda. Sigue
## la formación real de Team.FORMACION: 1 ARQ, 2 DFC, 2 LAT, 2 MC, 1 MCO,
## 2 EXT, 1 DC.
const FORMACION_SLOTS := {
	"ARQ": [{"x": 0.05, "y": 0.5}],
	"DFC": [{"x": 0.16, "y": 0.35}, {"x": 0.16, "y": 0.65}],
	"LAT": [{"x": 0.18, "y": 0.12}, {"x": 0.18, "y": 0.88}],
	"MC": [{"x": 0.34, "y": 0.38}, {"x": 0.34, "y": 0.62}],
	"MCO": [{"x": 0.42, "y": 0.5}],
	"EXT": [{"x": 0.48, "y": 0.15}, {"x": 0.48, "y": 0.85}],
	"DC": [{"x": 0.50, "y": 0.5}],
}

## Cuánto se mueve cada línea cuando el equipo empuja hacia adelante (1.0)
## o retrocede (empuje negativo) — el arquero prácticamente no se mueve,
## los delanteros son los que más siguen la jugada.
const PESO_LINEA := {
	"ARQ": 0.0, "DFC": 0.35, "LAT": 0.55, "MC": 0.75,
	"MCO": 0.9, "EXT": 0.85, "DC": 1.0,
}

const COLOR_LOCAL := Color(0.95, 0.75, 0.15)
const COLOR_VISITANTE := Color(0.35, 0.65, 0.95)
const COLOR_CESPED_CLARO := Color(0.14, 0.5, 0.16)
const COLOR_CESPED_OSCURO := Color(0.11, 0.44, 0.13)
const BANDAS_CESPED := 10
const ANCHO_SPRITE_NORMAL := 20.0
const ANCHO_SPRITE_RESALTADO := 30.0

const MAX_EMPUJE := 0.14  # cuánto puede correrse la línea, en x normalizado (0..1)
const RETROCESO_RIVAL := 0.5  # el que defiende retrocede a esta fracción del empuje rival
const VELOCIDAD_EMPUJE := 5.0  # qué tan rápido el bloque alcanza su nueva posición (por segundo)

## Posición cuyo sprite se dibuja más grande — "" si ninguna — y el punto
## exacto (screen-space) donde se dibuja, que es el mismo que usa la
## pelota (Cancha.punto_en) para que el sprite agrandado y la pelota
## coincidan siempre: así se ve claro quién tiene la pelota. Los pone
## PartidoVisual según el evento actual (equipo + jugador_posicion).
var resaltado_local: String = ""
var resaltado_visitante: String = ""
var punto_resaltado_local: Vector2 = Vector2.ZERO
var punto_resaltado_visitante: Vector2 = Vector2.ZERO

## Empuje actual (animado) de cada equipo, ya aplicado con PESO_LINEA en
## el dibujo — positivo = corrido hacia el arco rival, negativo = hacia el
## propio arco.
var empuje_local: float = 0.0
var empuje_visitante: float = 0.0
var _objetivo_empuje_local: float = 0.0
var _objetivo_empuje_visitante: float = 0.0

var _tex_local: ImageTexture
var _tex_visitante: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_local = PixelArt.jugador_textura(COLOR_LOCAL)
	_tex_visitante = PixelArt.jugador_textura(COLOR_VISITANTE)


## Llamado por PartidoVisual en cada evento: qué equipo tiene la pelota
## (es_local_con_pelota) y qué tan lejos de su propio arco está la jugada
## (intensidad, -1..1 — cerca de 1 es último tercio rival). El equipo con
## la pelota empuja su bloque hacia adelante; el rival retrocede.
func fijar_posesion(es_local_con_pelota: bool, intensidad: float) -> void:
	var i := clampf(intensidad, -1.0, 1.0)
	if es_local_con_pelota:
		_objetivo_empuje_local = i * MAX_EMPUJE
		_objetivo_empuje_visitante = -i * MAX_EMPUJE * RETROCESO_RIVAL
	else:
		_objetivo_empuje_visitante = i * MAX_EMPUJE
		_objetivo_empuje_local = -i * MAX_EMPUJE * RETROCESO_RIVAL


## Punto de cancha (screen-space) donde debería estar la pelota: x_local
## es la posición horizontal ya decidida por PartidoVisual según el tipo
## de jugada (0..1, propio arco a arco rival), y el carril Y sale de la
## posición del jugador que participa (con variación si esa posición
## tiene dos ubicaciones posibles, ej. LAT/EXT).
func punto_en(x_local: float, jugador_posicion: String, invertido: bool) -> Vector2:
	var slots: Array = FORMACION_SLOTS.get(jugador_posicion, [{"y": 0.5}])
	var slot: Dictionary = slots[randi() % slots.size()]
	var x: float = (1.0 - x_local) if invertido else x_local
	return Vector2(size.x * x, size.y * slot["y"])


func _process(delta: float) -> void:
	var t := clampf(delta * VELOCIDAD_EMPUJE, 0.0, 1.0)
	var cambio := false
	if not is_equal_approx(empuje_local, _objetivo_empuje_local):
		empuje_local = lerpf(empuje_local, _objetivo_empuje_local, t)
		cambio = true
	if not is_equal_approx(empuje_visitante, _objetivo_empuje_visitante):
		empuje_visitante = lerpf(empuje_visitante, _objetivo_empuje_visitante, t)
		cambio = true
	if cambio:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y

	_dibujar_cesped(w, h)
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)
	draw_line(Vector2(w / 2.0, 0), Vector2(w / 2.0, h), Color.WHITE, 2.0)
	draw_arc(Vector2(w / 2.0, h / 2.0), h * 0.16, 0, TAU, 32, Color.WHITE, 2.0)

	var area_w := w * 0.12
	var area_h := h * 0.55
	draw_rect(Rect2(Vector2(0, (h - area_h) / 2.0), Vector2(area_w, area_h)), Color.WHITE, false, 2.0)
	draw_rect(Rect2(Vector2(w - area_w, (h - area_h) / 2.0), Vector2(area_w, area_h)), Color.WHITE, false, 2.0)

	_dibujar_formacion(false, _tex_local, resaltado_local, empuje_local, punto_resaltado_local)
	_dibujar_formacion(true, _tex_visitante, resaltado_visitante, empuje_visitante, punto_resaltado_visitante)


func _dibujar_cesped(w: float, h: float) -> void:
	var ancho_banda := w / float(BANDAS_CESPED)
	for i in range(BANDAS_CESPED):
		var color := COLOR_CESPED_CLARO if i % 2 == 0 else COLOR_CESPED_OSCURO
		draw_rect(Rect2(Vector2(i * ancho_banda, 0), Vector2(ancho_banda + 1.0, h)), color)


func _dibujar_formacion(invertido: bool, textura: ImageTexture, resaltado_pos: String, empuje: float, punto_resaltado: Vector2) -> void:
	for pos in FORMACION_SLOTS:
		var slots: Array = FORMACION_SLOTS[pos]
		var peso: float = PESO_LINEA.get(pos, 0.7)
		var ya_uso_resaltado := false
		for slot in slots:
			var resaltado: bool = pos == resaltado_pos and not ya_uso_resaltado
			var punto: Vector2
			if resaltado:
				punto = punto_resaltado
				ya_uso_resaltado = true
			else:
				var x_local: float = clampf(slot["x"] + peso * empuje, 0.03, 0.97)
				var x: float = (1.0 - x_local) if invertido else x_local
				punto = Vector2(size.x * x, size.y * slot["y"])
			var ancho: float = ANCHO_SPRITE_RESALTADO if resaltado else ANCHO_SPRITE_NORMAL
			var alto: float = ancho * (textura.get_height() / float(textura.get_width()))
			var rect := Rect2(punto - Vector2(ancho, alto) / 2.0, Vector2(ancho, alto))
			draw_texture_rect(textura, rect, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
