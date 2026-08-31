class_name SpritesPartido
extends RefCounted

## Sprites del partido, generados por código (no hay asset pack). Si más
## adelante entran PNG de verdad, este es el único archivo a reemplazar:
## el resto de /match pide texturas por (dirección, pose, color) y no
## sabe cómo están hechas.
##
## Los jugadores son billboards: se proyecta su posición al piso, pero el
## sprite se dibuja siempre vertical y sin deformar.
##
## CUERPO Y PIERNAS VAN SEPARADOS. Dibujar 8 direcciones x 5 poses a mano
## serían 40 sprites; así son 5 cuerpos (las otras 3 direcciones son el
## espejo) y 5 juegos de piernas, que se componen al generar la textura.

const ANCHO := 12
const ALTO_CUERPO := 12
const ALTO_PIERNAS := 8
const ALTO := ALTO_CUERPO + ALTO_PIERNAS

const TRANSPARENTE := Color(0, 0, 0, 0)
const PIEL := Color(0.95, 0.78, 0.62)
const PIEL_OSCURA := Color(0.80, 0.63, 0.48)
const PELO := Color(0.22, 0.14, 0.08)
const OJO := Color(0.12, 0.10, 0.10)
## El pantalon por defecto, para los 199 clubes que no eligen nada.
const SHORT := Color(0.13, 0.13, 0.16)
const MEDIAS := Color(0.90, 0.90, 0.92)
const BOTIN := Color(0.06, 0.06, 0.06)

## Direcciones. Las tres que faltan (5, 6, 7) son el espejo de 3, 2 y 1.
enum { ABAJO, ABAJO_DER, DERECHA, ARRIBA_DER, ARRIBA, ARRIBA_IZQ, IZQUIERDA, ABAJO_IZQ }

## Poses de piernas.
const QUIETO := "quieto"
const CORRE_A := "corre_a"
const CORRE_B := "corre_b"
const PATEA := "patea"
const BARRIDA := "barrida"

## No es una pose de piernas: el arquero volando es un sprite entero
## aparte (horizontal). Se nombra acá para que la vista pueda tratarlo
## como una pose más y decidir con un solo campo.
const VUELA := "vuela"

## De frente: se le ven los ojos.
const CUERPO_ABAJO := [
	"....HHHH....",
	"...HHHHHH...",
	"..HSSSSSSH..",
	"..HSoSSoSH..",
	"...SSSSSS...",
	"....dSSd....",
	"..bJJJJJJb..",
	".bJJJJJJJJb.",
	".bJJJJJJJJb.",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
]

const CUERPO_ABAJO_DER := [
	"....HHHH....",
	"...HHHHHHH..",
	"..HSSSSSSSH.",
	"..HSSoSSoSH.",
	"...SSSSSSS..",
	"....dSSSd...",
	"..bJJJJJJJb.",
	"..bJJJJJJJJb",
	"..bJJJJJJJJb",
	"...JJJJJJJJ.",
	"...JJJJJJJJ.",
	"...JJJJJJJ..",
]

## De perfil, mirando a la derecha.
const CUERPO_DERECHA := [
	"...HHHHH....",
	"..HHHHHHH...",
	"..HSSSSSSS..",
	"..HSSSSoSS..",
	"...SSSSSSS..",
	"....dSSSd...",
	"...bJJJJJb..",
	"...bJJJJJJb.",
	"...bJJJJJJb.",
	"....JJJJJJ..",
	"....JJJJJJ..",
	"....JJJJJ...",
]

const CUERPO_ARRIBA_DER := [
	"....HHHH....",
	"...HHHHHHH..",
	"..HHHHHHHHH.",
	"..HHSSSSSHH.",
	"...SSSSSSS..",
	"....dSSSd...",
	"..bJJJJJJJb.",
	"..bJJJJJJJJb",
	"..bJJJJJJJJb",
	"...JJJJJJJJ.",
	"...JJJJJJJJ.",
	"...JJJJJJJ..",
]

## De espaldas: solo pelo, sin cara.
const CUERPO_ARRIBA := [
	"....HHHH....",
	"...HHHHHH...",
	"..HHHHHHHH..",
	"..HHHHHHHH..",
	"...SSSSSS...",
	"....dSSd....",
	"..bJJJJJJb..",
	".bJJJJJJJJb.",
	".bJJJJJJJJb.",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
]

const CUERPOS := [CUERPO_ABAJO, CUERPO_ABAJO_DER, CUERPO_DERECHA, CUERPO_ARRIBA_DER, CUERPO_ARRIBA]

const PIERNAS := {
	QUIETO: [
		"...DDDDDD...",
		"...DDDDDD...",
		"...DD..DD...",
		"...MM..MM...",
		"...MM..MM...",
		"..BBB..BBB..",
		"..BBB..BBB..",
		"............",
	],
	# Una pierna adelante y otra atrás; corre_b es la inversa, así que
	# alternándolas se lee la zancada.
	CORRE_A: [
		"...DDDDDD...",
		"...DDDDDD...",
		"..DD....DD..",
		"..MM.....MM.",
		".MM.......MM",
		".BBB.....BBB",
		"BBB.........",
		"............",
	],
	CORRE_B: [
		"...DDDDDD...",
		"...DDDDDD...",
		"..DD....DD..",
		".MM.....MM..",
		"MM.......MM.",
		"BBB.....BBB.",
		".........BBB",
		"............",
	],
	# Pierna extendida al frente: el remate.
	PATEA: [
		"...DDDDDD...",
		"...DDDDDD...",
		"...DD..DDD..",
		"...MM...MMM.",
		"...MM....MMM",
		"..BBB.....BB",
		"..BBB.......",
		"............",
	],
}

## La barrida y el arquero volando NO salen de componer cuerpo y piernas:
## son cuerpos tendidos, horizontales, y pegarles las piernas de un
## jugador parado daba un tipo de pie con las patas al costado. Van como
## sprite entero, y con dos orientaciones alcanza — tirado en el piso lo
## único que se lee es hacia qué lado se fue.
const BARRIDA_TENDIDA := [
	"....................",
	"....................",
	"....................",
	"....................",
	"..HHHH..............",
	".HSSSSH.............",
	".SSoSSJJJJJJb.......",
	"..SSSJJJJJJJJb......",
	"....JJJJJJJDDDD.....",
	".......DDDDDDMMMM...",
	"..........MMMMMMBBB.",
	".............BBB....",
]

## El arquero volando es otro sprite, horizontal: no sale de componer
## cuerpo y piernas.
const ARQUERO_VUELA := [
	"..............HHHH..",
	".............HSSSSH.",
	"...bJJJJJJJJJSSoSS..",
	"..bJJJJJJJJJJJSSS...",
	"...bJJJJJJJJJJ......",
	"..DDDDDD............",
	".MM...MM............",
	"BBB..BBB............",
]

static var _cache: Dictionary = {}


## De qué lado mira, según hacia dónde se mueve EN PANTALLA (no en la
## simulación): la proyección aplasta la profundidad, así que un
## movimiento en +y de cancha se ve como bajar, y el sprite tiene que
## coincidir con lo que el ojo ve.
static func direccion_desde(delta_pantalla: Vector2) -> int:
	if delta_pantalla.length_squared() < 0.0001:
		return ABAJO
	var ang := atan2(delta_pantalla.y, delta_pantalla.x)  # 0 = derecha
	var sector := int(round(ang / (TAU / 8.0))) % 8
	if sector < 0:
		sector += 8
	# atan2 da 0=derecha, PI/2=abajo. Se reordena al enum, que arranca en
	# ABAJO y gira en sentido horario visual.
	const MAPA := [DERECHA, ABAJO_DER, ABAJO, ABAJO_IZQ, IZQUIERDA, ARRIBA_IZQ, ARRIBA, ARRIBA_DER]
	return MAPA[sector]


## Sprite compuesto. Se cachea por (dirección, pose, color): en cancha hay
## dos equipos y unas pocas poses, así que son decenas de texturas, no una
## por jugador y por frame.
## `color_short` TRANSPARENT = el pantalon por defecto. Entra en la clave
## del cache: dos clubes con la misma camiseta y distinto pantalon son dos
## sprites distintos, y sin esto el segundo se dibujaba con el del primero.
static func jugador(color_camiseta: Color, direccion: int = ABAJO, pose: String = QUIETO,
		color_short: Color = Color.TRANSPARENT) -> ImageTexture:
	var clave := "j_%s_%s_%d_%s" % [
		color_camiseta.to_html(false), color_short.to_html(true), direccion, pose]
	if _cache.has(clave):
		return _cache[clave]

	var espejo := direccion in [ABAJO_IZQ, IZQUIERDA, ARRIBA_IZQ]
	if pose == BARRIDA:
		var tendida := _construir(BARRIDA_TENDIDA, _paleta(color_camiseta, color_short), espejo)
		_cache[clave] = tendida
		return tendida
	var base := direccion
	match direccion:
		ABAJO_IZQ: base = ABAJO_DER
		IZQUIERDA: base = DERECHA
		ARRIBA_IZQ: base = ARRIBA_DER
	var filas: Array = CUERPOS[base].duplicate()
	filas.append_array(PIERNAS.get(pose, PIERNAS[QUIETO]))

	var tex := _construir(filas, _paleta(color_camiseta, color_short), espejo)
	_cache[clave] = tex
	return tex


static func arquero_volando(color_camiseta: Color, hacia_izquierda: bool,
		color_short: Color = Color.TRANSPARENT) -> ImageTexture:
	var clave := "arq_%s_%s_%s" % [
		color_camiseta.to_html(false), color_short.to_html(true), str(hacia_izquierda)]
	if _cache.has(clave):
		return _cache[clave]
	var tex := _construir(ARQUERO_VUELA, _paleta(color_camiseta, color_short), hacia_izquierda)
	_cache[clave] = tex
	return tex


static func pelota() -> ImageTexture:
	if _cache.has("pelota"):
		return _cache["pelota"]
	var tex := _construir([
		"..WWWW..", ".WWWWWW.", "WWWKKWWW", "WWKKKKWW",
		"WWKKKKWW", "WWWKKWWW", ".WWWWWW.", "..WWWW..",
	], {".": TRANSPARENTE, "W": Color(0.97, 0.97, 0.97), "K": Color(0.10, 0.10, 0.10)}, false)
	_cache["pelota"] = tex
	return tex


## Sombra elíptica con bordes suaves. Es lo que ancla al jugador al piso
## y, en la pelota, lo que comunica que está en el aire.
static func sombra() -> ImageTexture:
	if _cache.has("sombra"):
		return _cache["sombra"]
	var an := 32
	var al := 16
	var img := Image.create(an, al, false, Image.FORMAT_RGBA8)
	var cx := (an - 1) / 2.0
	var cy := (al - 1) / 2.0
	for py in range(al):
		for px in range(an):
			var dx := (px - cx) / cx
			var dy := (py - cy) / cy
			var a: float = clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			img.set_pixel(px, py, Color(0, 0, 0, a * a * 0.62))
	var tex := ImageTexture.create_from_image(img)
	_cache["sombra"] = tex
	return tex


static func _paleta(camiseta: Color, short: Color = Color.TRANSPARENT) -> Dictionary:
	return {
		".": TRANSPARENTE, "H": PELO, "S": PIEL, "d": PIEL_OSCURA, "o": OJO,
		"J": camiseta, "b": camiseta.darkened(0.35),
		"D": short if short.a > 0.0 else SHORT, "M": MEDIAS, "B": BOTIN,
	}


static func _construir(filas: Array, paleta: Dictionary, espejar: bool) -> ImageTexture:
	var alto := filas.size()
	var ancho: int = filas[0].length()
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in range(alto):
		var fila: String = filas[y]
		for x in range(ancho):
			var destino: int = (ancho - 1 - x) if espejar else x
			img.set_pixel(destino, y, paleta[fila[x]])
	return ImageTexture.create_from_image(img)
