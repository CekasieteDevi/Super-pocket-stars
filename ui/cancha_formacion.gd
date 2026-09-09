class_name CanchaFormacion
extends Control

## La cancha de la pantalla de Formación: dibuja el campo y para a los once
## titulares donde dice la formación elegida.
##
## Las posiciones salen de las MISMAS coordenadas que usa el motor
## (data/formaciones.json, metros con origen en el centro), así que lo que
## ves acá es literalmente dónde va a arrancar cada uno en el partido. Si
## se cambia una formación en el JSON, esta pantalla la refleja sola.
##
## Se dibuja VERTICAL y recortada: tu arco abajo, el ataque hacia arriba.
## Antes era la cancha entera en horizontal y la mitad del dibujo estaba
## siempre vacía —ningún titular arranca en campo rival—, así que los once
## quedaban apretados en la mitad izquierda. Recortada, los mismos once
## entran al doble de tamaño, y el alto que sobra abajo es el que ahora
## usan las listas de suplentes y reservas.

signal seleccion_pedida(jugador_id: int)

## Medidas reales de una cancha, para que el dibujo tenga las proporciones
## de una de verdad y las posiciones caigan donde corresponde.
const LARGO_M := 105.0
const ANCHO_M := 68.0
const AREA_LARGO_M := 16.5
const AREA_ANCHO_M := 40.3

## El tramo de cancha que se DIBUJA, en metros del motor: tu media
## cancha, del fondo propio a la línea de mitad. Nada más: el campo rival
## es dibujo vacío que solo hace la pantalla más alta.
const X_DESDE := -52.5
const X_HASTA := 0.0

## El tramo donde se PARAN los once, que no es el mismo: el delantero más
## adelantado de todas las formaciones arranca en +16
## (data/formaciones.json), o sea pasada la mitad. Las posiciones se
## comprimen dentro de la media cancha dibujada, así que el arquero queda
## abajo en su arco y los delanteros arriba, sobre la línea de mitad. Se pierde la
## escala exacta en metros y se gana que la formación entera entre en una
## pantalla: lo que se lee acá es quién está delante de quién.
const X_JUGADOR_DESDE := -52.5
const X_JUGADOR_HASTA := 16.0

## Cuanto se puede ensanchar el dibujo respecto de la cancha real.
##
## Poco: la cancha ahora manda en el alto (ver _ajustar_alto) y no tiene
## que deformarse para que entren los cubos. Con 1.5 se veia claramente
## achatada en pantalla ancha.
const ESTIRE_MAXIMO := 1.12

## Cuanto mas alta que ancha se pide ser, en proporcion al ancho que le
## toca. Es la proporcion real del tramo dibujado (74.5 m de largo por 68
## de ancho) y hace que la cancha crezca con la pantalla en vez de
## quedarse en el hueco que le dejan las listas de abajo.
const PROPORCION_ALTO := (X_HASTA - X_DESDE) / ANCHO_M

## Hasta donde crece el dibujo, en pixeles de ancho. Con cinco cubos a lo
## ancho (CUBOS_A_LO_ANCHO) alcanza para que ninguno se pise, y sin tope
## en una pantalla de PC la cancha salia de mil pixeles: habia que
## scrollear para ver a los delanteros.
const ANCHO_MAXIMO := 620.0


var _equipo: Team = null
var _cubos: Array = []
## jugador_id del que está esperando pareja para el cambio, -1 si ninguno.
var _seleccionado: int = -1

## Alto de cancha con el que los cubos van a tamaño completo. Por debajo
## se achican en proporcion en vez de pisarse unos a otros.
const ALTO_REFERENCIA := 460.0

## Cuantos cubos tienen que entrar de lado a lado sin tocarse. Son cinco
## porque el 3-5-2 pone cinco en la linea del medio.
const CUBOS_A_LO_ANCHO := 5.0

## Aire entre el borde de la cancha y el del control.
const MARGEN := 8.0


func _init() -> void:
	# La cancha PIDE su alto en vez de conformarse con el que sobra: vive
	# adentro de un ScrollContainer (ver main._construir_panel_formacion),
	# asi que puede ser mas alta que la pantalla y se llega scrolleando.
	# Antes se repartia el alto con las dos listas de abajo y en un
	# celular quedaba del tamaño de un sello.
	custom_minimum_size = Vector2(260, 420)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func mostrar(equipo: Team, seleccionado: int = -1) -> void:
	_equipo = equipo
	_seleccionado = seleccionado
	for c in _cubos:
		c.queue_free()
	_cubos.clear()

	var slots: Array = Formaciones.slots(equipo.formacion)
	var escala := _escala_cubos()
	for i in range(min(slots.size(), equipo.jugadores.size())):
		var cubo := CuboJugador.crear(
			equipo.jugadores[i], str(slots[i]["rol"]), equipo, false, escala)
		cubo.marcar_seleccionado(int(equipo.jugadores[i]["id"]) == seleccionado)
		cubo.seleccion_pedida.connect(func(id): seleccion_pedida.emit(id))
		add_child(cubo)
		_cubos.append(cubo)
	queue_redraw()
	_acomodar()


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		_ajustar_alto()
		_acomodar()
		queue_redraw()


## El alto sale del ancho que le tocó, para que la cancha crezca con la
## pantalla. Solo se toca si cambió de verdad: escribir
## custom_minimum_size dispara otro RESIZED y se realimentaría solo.
func _ajustar_alto() -> void:
	var pedido: float = minf(size.x, ANCHO_MAXIMO) * PROPORCION_ALTO / ESTIRE_MAXIMO
	if absf(custom_minimum_size.y - pedido) > 1.0:
		custom_minimum_size.y = pedido


## Mete el rectángulo de la cancha adentro del control conservando la
## proporción: estirada, las posiciones dejarían de significar lo que
## significan en el partido.
func _rect_cancha() -> Rect2:
	var disponible := size
	if disponible.x <= 0.0 or disponible.y <= 0.0:
		return Rect2()
	# Aire a cada lado. La linea de borde se dibuja CENTRADA sobre el
	# rectangulo, asi que pegada al limite del control se corta a la
	# mitad y la cancha se lee como cortada aunque este entera.
	disponible -= Vector2(MARGEN, MARGEN) * 2.0
	disponible.x = minf(disponible.x, ANCHO_MAXIMO)
	# Vertical: el ANCHO de la cancha es el ancho del dibujo y el tramo de
	# largo visible es el alto.
	var largo_visible := X_HASTA - X_DESDE
	var escala: float = minf(disponible.x / ANCHO_M, disponible.y / largo_visible)
	var h := largo_visible * escala
	# El ancho se ESTIRA hasta ESTIRE_MAXIMO si sobra lugar a los lados.
	# La pantalla es apaisada y la cancha vertical deja los costados
	# vacios; con la proporcion exacta los once entran en 230 px de ancho
	# y los cubos se pisan entre ellos. Se deforma el dibujo a proposito:
	# lo que importa aca es leer quien esta al lado de quien, y las
	# posiciones relativas no cambian.
	var w: float = minf(ANCHO_M * escala * ESTIRE_MAXIMO, disponible.x)
	return Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)


## De metros del motor a píxeles de la pantalla. La cancha está girada:
## el largo (x del motor) baja por la pantalla y el ancho (y del motor)
## cruza de izquierda a derecha.
func _a_pantalla(metros: Vector2) -> Vector2:
	var r := _rect_cancha()
	var rango := X_JUGADOR_HASTA - X_JUGADOR_DESDE
	var avance: float = (clampf(metros.x, X_JUGADOR_DESDE, X_JUGADOR_HASTA) - X_JUGADOR_DESDE) / rango
	return Vector2(
		r.position.x + (metros.y + ANCHO_M * 0.5) / ANCHO_M * r.size.x,
		r.position.y + (1.0 - avance) * r.size.y)


## Cuanto se achican los cubos cuando la cancha entra chica. Sin esto, en
## una pantalla baja los once quedaban del mismo tamaño sobre una cancha
## mas chica y se pisaban entre ellos.
func _escala_cubos() -> float:
	var r := _rect_cancha()
	if r.size.y <= 0.0:
		return 1.0
	# Contra el alto Y el ancho: la cancha vertical se queda corta de
	# ancho antes que de alto, y era ahi donde los cubos se pisaban.
	var por_alto: float = r.size.y / ALTO_REFERENCIA
	var por_ancho: float = r.size.x / (CUBOS_A_LO_ANCHO * float(CuboJugador.ANCHO))
	return clampf(minf(por_alto, por_ancho), 0.55, 1.0)


func _acomodar() -> void:
	if _equipo == null:
		return
	var slots: Array = Formaciones.slots(_equipo.formacion)
	var escala := _escala_cubos()
	for i in range(_cubos.size()):
		if i >= slots.size():
			continue
		var cubo: CuboJugador = _cubos[i]
		if not is_equal_approx(cubo.escala, escala):
			cubo.aplicar_escala(escala)
		var centro := _a_pantalla(slots[i]["base"])
		# El cubo va CENTRADO en su posicion, asi que los slots pegados a
		# la linea de fondo quedaban con media ficha afuera del control.
		# Se empuja adentro el que se pasa, en vez de reencuadrar a los
		# once: apretarlos a todos media ficha por lado los hacia pisarse
		# en el medio, que es donde mas hay.
		var sitio := centro - cubo.custom_minimum_size * 0.5
		cubo.position = Vector2(
			clampf(sitio.x, 0.0, maxf(0.0, size.x - cubo.custom_minimum_size.x)),
			clampf(sitio.y, 0.0, maxf(0.0, size.y - cubo.custom_minimum_size.y)))


func _draw() -> void:
	var r := _rect_cancha()
	if r.size.x <= 0.0:
		return
	var cesped := Color("#1b3327")
	var linea := Color(1, 1, 1, 0.28)
	var por_metro := r.size.y / (X_HASTA - X_DESDE)
	draw_rect(r, cesped, true)

	# Franjas de corte, como una cancha de verdad. Sutiles: son fondo, no
	# tienen que competir con los jugadores. Cruzadas, porque la cancha
	# ahora corre de arriba hacia abajo.
	var franjas := 8
	for i in range(franjas):
		if i % 2 == 0:
			continue
		var alto_franja := r.size.y / float(franjas)
		draw_rect(Rect2(r.position.x, r.position.y + i * alto_franja,
			r.size.x, alto_franja), Color(1, 1, 1, 0.022), true)

	draw_rect(r, linea, false, 2.0)

	# El área propia, abajo: tu arco está en el borde de abajo.
	var area_w := AREA_ANCHO_M / ANCHO_M * r.size.x
	var area_h := AREA_LARGO_M * por_metro
	draw_rect(Rect2(r.position.x + (r.size.x - area_w) * 0.5,
		r.position.y + r.size.y - area_h, area_w, area_h), linea, false, 2.0)

	# El círculo central asoma por el borde de arriba, que ES la línea de
	# mitad: media cancha, media rueda.
	draw_arc(Vector2(r.position.x + r.size.x * 0.5, r.position.y),
		9.15 * por_metro, 0.0, PI, 32, linea, 2.0)

	# Hacia dónde se ataca: sin esto no se entiende por qué el arquero está
	# abajo.
	var flecha_x := r.position.x + r.size.x - 18.0
	var y_desde := r.position.y + r.size.y * 0.58
	var y_hasta := r.position.y + r.size.y * 0.26
	var tenue := Color(1, 1, 1, 0.18)
	draw_line(Vector2(flecha_x, y_desde), Vector2(flecha_x, y_hasta), tenue, 2.0)
	draw_line(Vector2(flecha_x, y_hasta), Vector2(flecha_x - 6, y_hasta + 10), tenue, 2.0)
	draw_line(Vector2(flecha_x, y_hasta), Vector2(flecha_x + 6, y_hasta + 10), tenue, 2.0)
