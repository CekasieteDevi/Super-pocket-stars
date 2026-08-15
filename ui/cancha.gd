class_name Cancha
extends Control

## Cancha dibujada por código — Fase 8, pulida con 22 posiciones fijas,
## sprites pixel-art (PixelArt.jugador_textura) y forma de equipo dinámica.
## El motor sigue sin calcular posiciones x/y por jugador durante el
## partido (solo zona de la jugada + la posición del que participa), así
## que lo que se ve acá es una aproximación: una FORMACIÓN FIJA por equipo
## (11 sprites cada uno, según FORMACION_SLOTS) que se ESTIRA/COMPACTA como
## bloque según la zona de la jugada actual — el equipo que ataca empuja su
## línea hacia adelante, el que defiende retrocede.
##
## Cada uno de los 22 sprites tiene una posición "renderizada" persistente
## (_render_local/_render_visitante) que en cada frame CAMINA hacia su
## objetivo actual en vez de aparecer ahí de golpe: el jugador que
## participa de la jugada camina hasta el punto exacto de la pelota (se
## dibuja más grande mientras tanto) y, en cuanto deja de participar,
## camina de vuelta a su lugar en la formación — así se ve continuidad
## ("sube al área, espera el pase, remata, vuelve") en vez de que los
## puntos salten de una posición a otra como piezas de ajedrez. No son 22
## muñequitos con movimiento individual real (el motor no calcula eso),
## es la mejor aproximación posible con los datos que da.

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
const VELOCIDAD_EMPUJE := 5.0  # qué tan rápido el bloque alcanza su nueva forma (por segundo)
const VELOCIDAD_JUGADOR := 4.0  # qué tan rápido cada sprite camina a su objetivo (por segundo)
const DISTANCIA_MINIMA := 0.5  # px — por debajo de esto se considera "llegó", no sigue redibujando

## Posición cuyo sprite se dibuja más grande — "" si ninguna. Lo pone
## PartidoVisual según el evento actual (equipo + jugador_posicion); el
## punto exacto (screen-space) es el mismo que usa la pelota (punto_en),
## para que el sprite agrandado y la pelota siempre coincidan.
var resaltado_local: String = ""
var resaltado_visitante: String = ""
var punto_resaltado_local: Vector2 = Vector2.ZERO
var punto_resaltado_visitante: Vector2 = Vector2.ZERO

## Empuje actual (animado) de cada equipo — positivo = corrido hacia el
## arco rival, negativo = hacia el propio arco. Define el objetivo de los
## sprites que NO están participando de la jugada actual.
var empuje_local: float = 0.0
var empuje_visitante: float = 0.0
var _objetivo_empuje_local: float = 0.0
var _objetivo_empuje_visitante: float = 0.0

## Posición renderizada (screen-space) de cada sprite, clave "POS_indice"
## (ej. "DFC_0") — persiste entre frames y camina hacia su objetivo en
## _process, en vez de recalcularse de cero en cada _draw.
var _render_local: Dictionary = {}
var _render_visitante: Dictionary = {}

var _tex_local: ImageTexture
var _tex_visitante: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_local = PixelArt.jugador_textura(COLOR_LOCAL)
	_tex_visitante = PixelArt.jugador_textura(COLOR_VISITANTE)


## Llamado por PartidoVisual en cada evento: qué equipo tiene la pelota
## (es_local_con_pelota), qué tan lejos de su propio arco está la jugada
## (intensidad, -1..1 — cerca de 1 es último tercio rival) y cuánto
## retrocede el que NO tiene la pelota (retroceso_rival — ver
## Estilos.retroceso_sin_pelota; negativo = presiona hacia adelante en vez
## de replegarse). El equipo con la pelota siempre empuja hacia adelante.
func fijar_posesion(es_local_con_pelota: bool, intensidad: float, retroceso_rival: float = 0.5) -> void:
	var i := clampf(intensidad, -1.0, 1.0)
	if es_local_con_pelota:
		_objetivo_empuje_local = i * MAX_EMPUJE
		_objetivo_empuje_visitante = -i * MAX_EMPUJE * retroceso_rival
	else:
		_objetivo_empuje_visitante = i * MAX_EMPUJE
		_objetivo_empuje_local = -i * MAX_EMPUJE * retroceso_rival


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


func _punto_formacion(pos: String, slot: Dictionary, invertido: bool, empuje: float) -> Vector2:
	var peso: float = PESO_LINEA.get(pos, 0.7)
	var x_local: float = clampf(slot["x"] + peso * empuje, 0.03, 0.97)
	var x: float = (1.0 - x_local) if invertido else x_local
	return Vector2(size.x * x, size.y * slot["y"])


func _process(delta: float) -> void:
	if size.x <= 0.0:
		return

	var t_bloque := clampf(delta * VELOCIDAD_EMPUJE, 0.0, 1.0)
	empuje_local = lerpf(empuje_local, _objetivo_empuje_local, t_bloque)
	empuje_visitante = lerpf(empuje_visitante, _objetivo_empuje_visitante, t_bloque)

	var t_jugador := clampf(delta * VELOCIDAD_JUGADOR, 0.0, 1.0)
	var cambio := _actualizar_render(_render_local, false, resaltado_local, punto_resaltado_local, empuje_local, t_jugador)
	cambio = _actualizar_render(_render_visitante, true, resaltado_visitante, punto_resaltado_visitante, empuje_visitante, t_jugador) or cambio
	if cambio:
		queue_redraw()


## Mueve cada sprite del equipo un paso hacia su objetivo actual (el punto
## de la jugada si es el que participa, si no su lugar en la formación) y
## devuelve true si algo se movió (para saber si hace falta redibujar).
func _actualizar_render(render: Dictionary, invertido: bool, resaltado_pos: String, punto_resaltado: Vector2, empuje: float, t: float) -> bool:
	var cambio := false
	var ya_uso_resaltado := false
	for pos in FORMACION_SLOTS:
		var slots: Array = FORMACION_SLOTS[pos]
		for i in range(slots.size()):
			var clave := "%s_%d" % [pos, i]
			var es_resaltado: bool = pos == resaltado_pos and not ya_uso_resaltado
			var objetivo: Vector2
			if es_resaltado:
				objetivo = punto_resaltado
				ya_uso_resaltado = true
			else:
				objetivo = _punto_formacion(pos, slots[i], invertido, empuje)

			if not render.has(clave):
				render[clave] = objetivo
				cambio = true
				continue

			var actual: Vector2 = render[clave]
			if actual.distance_to(objetivo) > DISTANCIA_MINIMA:
				render[clave] = actual.lerp(objetivo, t)
				cambio = true
	return cambio


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

	_dibujar_formacion(_render_local, _tex_local, resaltado_local)
	_dibujar_formacion(_render_visitante, _tex_visitante, resaltado_visitante)


func _dibujar_cesped(w: float, h: float) -> void:
	var ancho_banda := w / float(BANDAS_CESPED)
	for i in range(BANDAS_CESPED):
		var color := COLOR_CESPED_CLARO if i % 2 == 0 else COLOR_CESPED_OSCURO
		draw_rect(Rect2(Vector2(i * ancho_banda, 0), Vector2(ancho_banda + 1.0, h)), color)


func _dibujar_formacion(render: Dictionary, textura: ImageTexture, resaltado_pos: String) -> void:
	var ya_uso_resaltado := false
	for pos in FORMACION_SLOTS:
		var slots: Array = FORMACION_SLOTS[pos]
		for i in range(slots.size()):
			var clave := "%s_%d" % [pos, i]
			if not render.has(clave):
				continue
			var punto: Vector2 = render[clave]
			var resaltado: bool = pos == resaltado_pos and not ya_uso_resaltado
			if resaltado:
				ya_uso_resaltado = true
			var ancho: float = ANCHO_SPRITE_RESALTADO if resaltado else ANCHO_SPRITE_NORMAL
			var alto: float = ancho * (textura.get_height() / float(textura.get_width()))
			var rect := Rect2(punto - Vector2(ancho, alto) / 2.0, Vector2(ancho, alto))
			draw_texture_rect(textura, rect, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
