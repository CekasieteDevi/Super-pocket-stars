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
## EL JUGADOR SE ARMA POR CAPAS. Dibujar 8 direcciones x 8 poses x 6
## peinados a mano serían cientos de sprites; así son cuatro piezas que se
## componen al generar la textura:
##
##   1. cabeza pelada (5 direcciones; las otras 3 son el espejo)
##   2. peinado, pintado encima de la cabeza (6 estilos x 5 direcciones)
##   3. torso (5 direcciones), con el número estampado si mira de espaldas
##   4. piernas (una lista por pose)
##
## La barrida, la estirada del arquero y el festejo no se arman así: son
## sprites enteros, porque ahí el cuerpo no está parado.

const ANCHO := 12
const ALTO_CABEZA := 6
const ALTO_TORSO := 6
const ALTO_CUERPO := ALTO_CABEZA + ALTO_TORSO
const ALTO_PIERNAS := 8
const ALTO := ALTO_CUERPO + ALTO_PIERNAS

const TRANSPARENTE := Color(0, 0, 0, 0)
const PIEL := Color(0.95, 0.78, 0.62)
const PIEL_OSCURA := Color(0.80, 0.63, 0.48)
const OJO := Color(0.12, 0.10, 0.10)
## Color de pelo por defecto, para el sprite que no elige ninguno.
const PELO := Color(0.22, 0.14, 0.08)
## El pantalon por defecto, para los 199 clubes que no eligen nada.
const SHORT := Color(0.13, 0.13, 0.16)
const MEDIAS := Color(0.90, 0.90, 0.92)
const BOTIN := Color(0.06, 0.06, 0.06)
## Polvo de la barrida: el pasto que levanta el que se arrastra.
const POLVO := Color(0.74, 0.80, 0.64, 0.60)

## Direcciones. Las tres que faltan (5, 6, 7) son el espejo de 3, 2 y 1.
enum { ABAJO, ABAJO_DER, DERECHA, ARRIBA_DER, ARRIBA, ARRIBA_IZQ, IZQUIERDA, ABAJO_IZQ }

## Poses de piernas.
const QUIETO := "quieto"
const CORRE_A := "corre_a"
const CORRE_B := "corre_b"
## El remate son dos fotogramas: arma la pierna y después impacta. Con uno
## solo el remate se leía como un tropiezo.
const PATEA_ARMA := "patea_arma"
const PATEA := "patea"
## Salto para cabecear. El sprite además SUBE: ver ELEVACION_CABEZAZO.
const CABECEA := "cabecea"

## No son poses de piernas: son sprites enteros. Se nombran acá para que
## la vista pueda tratarlos como una pose más y decidir con un solo campo.
const BARRIDA := "barrida"
const FESTEJA := "festeja"
const VUELA := "vuela"
const BLOQUEA := "bloquea"
const CAE := "cae"
const CHILENA := "chilena"
const VOLEA := "volea"
const PALOMITA := "palomita"
const PALOMITA_PREPARA := "palomita_prepara"
const PALOMITA_CAER := "palomita_caer"
const RECUPERA := "recupera"

# Siluetas completas: contacto, equilibrio y recuperaci?n diferenciados.
const POSES_ESPECIALES := {
	BLOQUEA: ["......HHHH......", ".....HSSSSH.....", ".....SSoSSS.....", "......dSS.......", "...SSJJJJJJSS...", "..SSbJJJJJJbSS..", "....bJJJJJJb....", ".....DDDDDD.....", "....DDD..DDD....", "...SS......SS...", "..MM........MM..", ".BBB........BBB."],
	CAE: ["....................", "....................", "..HHHH..............", ".HSSSSS...SS........", "..SSoSSJJJJSS.......", "...dSSJJJJJJDD......", "....SSbJJJDDDDSSMMB.", "...SS..bbbDD........", "..SS.......SSMMBB...", "...................."],
	CHILENA: [".............BB.....", "............MM......", "...........SS.......", ".....BB...SS........", "......MM.DDD........", ".......DDDDD........", ".......JJJJb........", "....SSJJJJJJSS......", "...SS.JJJJJ..SS.....", "......dSS.....SS....", ".....SSoSS..........", ".....HSSSH..........", "......HHH...........", "....................", "....................", "...................."],
	VOLEA: ["......HHHH..........", ".....HSSSSH.........", ".....SSoSSS.........", "......dSS...........", "...SSJJJJJJ.........", "..SSbJJJJJJSS.......", "....bJJJJJJ.SS......", ".....DDDDDD.........", ".....DDD.DDSSMMBBBB.", ".....SS.............", ".....MM.............", "....BBB.............", "...................."],
	PALOMITA: ["....................", "....................", "...HHHH.............", "..HSSSSH............", "..SSoSSS............", "...dSS..............", "SSJJJJJJSS..........", "SSbJJJJJJJJSS.......", "..SSDDDDDD..........", "....DDD..DDD........", ".....MM.............", "....BBB.............", "...................."],
	PALOMITA_PREPARA: ["....................", "....................", "......HHHH..........", ".....HSSSSH.........", ".....SSoSSS.........", "......dSS...........", "...SSJJJJJJSS.......", "..SSbJJJJJJJJSS.....", "....DDDDDD..........", "...DDD..DDD.........", "..MM....MM..........", ".BBB..BBB..........."],
	PALOMITA_CAER: ["....................", "....................", "....................", "....................", "....HHHH............", "...HSSSSH...........", "...SSoSSS...........", "....dSS.............", ".SSJJJJJJSS.........", "SSbJJJJJJJJSS.......", "..DDDDDD............", "..DDD..DDD..........", "..BBB..BBB.........."],
	RECUPERA: ["................", ".....HHHH.......", "....HSSSSH......", "....SSoSSS......", ".....dSS........", "....JJJJJJ......", "...SbJJJJJS.....", "...S.DDDDD.S....", "..SS.DD.SS.SS...", ".....MM..MM.....", "....BBB..BBB...."],
}

## Peinados. El pelo es lo que permite distinguir a un jugador de otro
## cuando los dos van con la misma camiseta: a 26 píxeles de alto, la
## cabeza es lo único que queda para diferenciarlos.
const PELO_CORTO := 0
const PELO_LARGO := 1
const PELO_AFRO := 2
const PELO_CALVO := 3
const PELO_MOHICANO := 4
const PELO_VINCHA := 5
const ESTILOS_PELO := 6

## Tonos de pelo. Son siete y no un color libre para que el cache no
## explote: estilo x tono x dirección x pose ya son muchas texturas.
const TONOS_PELO := [
	Color(0.10, 0.08, 0.07),  # negro
	Color(0.30, 0.18, 0.09),  # castaño
	Color(0.55, 0.34, 0.14),  # claro
	Color(0.85, 0.72, 0.35),  # rubio
	Color(0.68, 0.30, 0.12),  # pelirrojo
	Color(0.92, 0.92, 0.90),  # blanco
	Color(0.12, 0.35, 0.82),  # azul
]
const INDICE_PELO_BLANCO := 5
const INDICE_PELO_AZUL := 6
const UNO_CADA_TONO_RARO := 300

## La vincha (cinta en la frente) va siempre blanca: es lo que la hace
## visible contra cualquier tono de pelo.
const COLOR_VINCHA := Color(0.94, 0.94, 0.96)

# --- Cabezas: SIN pelo. El peinado se pinta encima. --------------------

const CABEZA_ABAJO := [
	"....SSSS....",
	"...SSSSSS...",
	"..SSSSSSSS..",
	"..SSoSSoSS..",
	"...SSSSSS...",
	"....dSSd....",
]

const CABEZA_ABAJO_DER := [
	"....SSSS....",
	"...SSSSSSS..",
	"..SSSSSSSSS.",
	"..SSSoSSoSS.",
	"...SSSSSSS..",
	"....dSSSd...",
]

## De perfil, mirando a la derecha: se le ve un solo ojo.
const CABEZA_DERECHA := [
	"...SSSSS....",
	"..SSSSSSS...",
	"..SSSSSSSS..",
	"..SSSSSoSS..",
	"...SSSSSSS..",
	"....dSSSd...",
]

const CABEZA_ARRIBA_DER := [
	"....SSSS....",
	"...SSSSSSS..",
	"..SSSSSSSSS.",
	"..SSSSSSSSS.",
	"...SSSSSSS..",
	"....dSSSd...",
]

## De espaldas: no se le ve la cara.
const CABEZA_ARRIBA := [
	"....SSSS....",
	"...SSSSSS...",
	"..SSSSSSSS..",
	"..SSSSSSSS..",
	"...SSSSSS...",
	"....dSSd....",
]

const CABEZAS := [CABEZA_ABAJO, CABEZA_ABAJO_DER, CABEZA_DERECHA, CABEZA_ARRIBA_DER, CABEZA_ARRIBA]

# --- Peinados: 5 filas que se pintan sobre la cabeza. ------------------
#
# El punto deja pasar la cabeza de abajo. La H es pelo y la V, la vincha.
# Cada lista sigue el orden de CABEZAS.

const PELOS := [
	# CORTO. Reproduce el sprite original: es la línea de base contra la
	# que se comparan los demás.
	[
		["....HHHH....", "...HHHHHH...", "..H......H..", "..H......H..", "............"],
		["....HHHH....", "...HHHHHHH..", "..H.......H.", "..H.......H.", "............"],
		["...HHHHH....", "..HHHHHHH...", "..H.........", "..H.........", "............"],
		["....HHHH....", "...HHHHHHH..", "..HHHHHHHHH.", "..HH.....HH.", "............"],
		["....HHHH....", "...HHHHHH...", "..HHHHHHHH..", "..HHHHHHHH..", "............"],
	],
	# LARGO: cae por los costados hasta el cuello.
	[
		["....HHHH....", "...HHHHHH...", "..HH....HH..", "..HH....HH..", "..HH....HH.."],
		["....HHHH....", "...HHHHHHH..", "..HH.....HH.", "..HH.....HH.", "..HH.....HH."],
		["...HHHHH....", "..HHHHHHH...", "..HH........", "..HH........", "..HH........"],
		["....HHHH....", "...HHHHHHH..", "..HHHHHHHHH.", "..HHHHHHHHH.", "..HH.....HH."],
		["....HHHH....", "...HHHHHH...", "..HHHHHHHH..", "..HHHHHHHH..", "..HHHHHHHH.."],
	],
	# AFRO: sobresale una columna a cada lado, que es lo que lo hace
	# reconocible de lejos.
	[
		["..HHHHHHHH..", ".HHHHHHHHHH.", ".HH......HH.", ".HH......HH.", "............"],
		["..HHHHHHHH..", ".HHHHHHHHHHH", ".HH.......HH", ".HH.......HH", "............"],
		[".HHHHHHH....", ".HHHHHHHH...", ".HHH........", ".HH.........", "............"],
		["..HHHHHHHH..", ".HHHHHHHHHHH", ".HHHHHHHHHHH", ".HHHHHHHHHH.", "............"],
		["..HHHHHHHH..", ".HHHHHHHHHH.", ".HHHHHHHHHH.", "..HHHHHHHH..", "............"],
	],
	# CALVO: corona pelada, pelo solo en los costados y la nuca.
	[
		["............", "............", "..H......H..", "..H......H..", "............"],
		["............", "............", "..H.......H.", "..H.......H.", "............"],
		["............", "...H........", "..H.........", "..H.........", "............"],
		["............", "............", "..HH.....HH.", "..HH.....HH.", "............"],
		["............", "............", "..H......H..", "..HHHHHHHH..", "............"],
	],
	# MOHICANO: cresta al medio.
	[
		[".....HH.....", "....HHHH....", "..H......H..", "..H......H..", "............"],
		[".....HH.....", "....HHHH....", "..H.......H.", "..H.......H.", "............"],
		["..HHHHHHH...", "...HHHHH....", "..H.........", "..H.........", "............"],
		[".....HH.....", "....HHHH....", "....HHHHH...", "..HH.....HH.", "............"],
		[".....HH.....", "....HHHH....", "....HHHH....", "....HHHH....", "............"],
	],
	# VINCHA: pelo corto más la cinta cruzándole la frente.
	[
		["....HHHH....", "...HHHHHH...", "..VVVVVVVV..", "..H......H..", "............"],
		["....HHHH....", "...HHHHHHH..", "..VVVVVVVVV.", "..H.......H.", "............"],
		["...HHHHH....", "..HHHHHHH...", "..VVVVVVVV..", "..H.........", "............"],
		["....HHHH....", "...HHHHHHH..", "..VVVVVVVVV.", "..HH.....HH.", "............"],
		["....HHHH....", "...HHHHHH...", "..VVVVVVVV..", "..HHHHHHHH..", "............"],
	],
]

# --- Torsos ------------------------------------------------------------

const TORSO_ABAJO := [
	"..bJJJJJJb..",
	".bJJJJJJJJb.",
	".bJJJJJJJJb.",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
]

const TORSO_ABAJO_DER := [
	"..bJJJJJJJb.",
	"..bJJJJJJJJb",
	"..bJJJJJJJJb",
	"...JJJJJJJJ.",
	"...JJJJJJJJ.",
	"...JJJJJJJ..",
]

const TORSO_DERECHA := [
	"...bJJJJJb..",
	"...bJJJJJJb.",
	"...bJJJJJJb.",
	"....JJJJJJ..",
	"....JJJJJJ..",
	"....JJJJJ...",
]

const TORSO_ARRIBA_DER := [
	"..bJJJJJJJb.",
	"..bJJJJJJJJb",
	"..bJJJJJJJJb",
	"...JJJJJJJJ.",
	"...JJJJJJJJ.",
	"...JJJJJJJ..",
]

const TORSO_ARRIBA := [
	"..bJJJJJJb..",
	".bJJJJJJJJb.",
	".bJJJJJJJJb.",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
]

const TORSOS := [TORSO_ABAJO, TORSO_ABAJO_DER, TORSO_DERECHA, TORSO_ARRIBA_DER, TORSO_ARRIBA]

## Los brazos en alto del festejo. Van como overlay sobre cabeza y torso
## porque suben por AFUERA del cuerpo, por las columnas 0-1 y 10-11, que
## el sprite parado deja libres.
const BRAZOS_ARRIBA := [
	".SS......SS.",
	".SS......SS.",
	".bb......bb.",
	".bb......bb.",
	".bb......bb.",
	"..bb....bb..",
	"............",
	"............",
	"............",
	"............",
	"............",
	"............",
]

## Brazos abiertos, pegados al hombro. Cada entrada es {fila del torso ->
## qué se pinta hacia afuera}, empezando por la columna que toca el
## cuerpo. Van así y no como un dibujo fijo porque el torso de perfil es
## más angosto que el de frente: con posiciones fijas el brazo quedaba
## flotando a dos columnas del hombro.
##
## El que patea abre los brazos para no irse al piso cuando lanza la
## pierna. Es lo que separa un remate de un jugador parado con una pierna
## rara.
const BRAZOS_PATEA := {1: "bSS"}

## Los del cabezazo caen abiertos y más abajo: hacen de contrapeso del
## cuerpo que se va adelante.
const BRAZOS_CABEZAZO := {1: "b", 2: "SS"}

# --- Piernas -----------------------------------------------------------

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
	# Arma el remate: la pierna que pega se va ATRÁS y el peso cae sobre la
	# otra. Es el fotograma que le da impulso al que sigue.
	#
	# Las dos poses de remate miden 16 de ancho y no 12: la pierna
	# estirada no entra en el ancho del cuerpo. _armar_parado centra las
	# piezas angostas, así que el torso sigue cayendo donde va.
	PATEA_ARMA: [
		".....DDDDDD.....",
		"....DDDDDDD.....",
		"..DDDD...DD.....",
		"..MMM....MM.....",
		".MMM.....MM.....",
		"BBB......MM.....",
		"BB......BBB.....",
		"................",
	],
	# Impacto: la pierna se estira al frente y el pie queda ALTO, a la
	# altura a la que se le pega a la pelota.
	PATEA: [
		".....DDDDDD.....",
		".....DDDDDDD....",
		".....DD.DDDDMMMM",
		".....MM.....MBBB",
		".....MM......BBB",
		"....BBB.........",
		"....BBB.........",
		"................",
	],
	# Salto: las dos piernas juntas y recogidas. Lo que dice que está en el
	# aire no es esta pose sino ELEVACION_CABEZAZO.
	CABECEA: [
		"...DDDDDD...",
		"...DDDDDD...",
		"..DDD..DDD..",
		"..MM....MM..",
		"..MM....MM..",
		".BBB...BBB..",
		"............",
		"............",
	],
}

## Cuántas filas transparentes se agregan DEBAJO del que cabecea. El
## sprite se apoya en el piso por su borde inferior (ver vista_cancha), así
## que agregar filas vacías abajo es lo que lo levanta del suelo sin que la
## vista tenga que saber nada del salto.
const ELEVACION_CABEZAZO := 4

## La barrida y el arquero volando NO salen de componer cuerpo y piernas:
## son cuerpos tendidos, horizontales, y pegarles las piernas de un
## jugador parado daba un tipo de pie con las patas al costado. Van como
## sprite entero, y con dos orientaciones alcanza — tirado en el piso lo
## único que se lee es hacia qué lado se fue.
##
## Barre con la pierna de arriba ESTIRADA al frente, la otra doblada
## debajo, y el polvo sale por detrás. Sin la pierna estirada y sin el
## polvo el sprite se leía como un jugador desmayado, no como una entrada.
const BARRIDA_TENDIDA := [
	"....................",
	"....................",
	"....................",
	"...PP...............",
	"..P.HHHH............",
	"PP..HSSSSH..........",
	".PP.HSSoSSJJJJb.....",
	"PPP..SSJJJJJJJJDDDD.",
	"..P..bJJJJJJDDDDMMMM",
	"......bJJJDDDMMMMBBB",
	".........DDDMMBBB...",
	"..........MMBBB.....",
]

## El arquero volando es otro sprite, horizontal: no sale de componer
## cuerpo y piernas. Va con el brazo ESTIRADO por delante de la cabeza y
## las piernas juntas atrás; las dos filas vacías de abajo son el aire que
## lo separa del piso, que es lo que lo diferencia de estar tirado.
const ARQUERO_VUELA := [
	"..................SS",
	"................bbS.",
	"..............bb....",
	"........HHHHbb......",
	".....bJJSSSSS.......",
	"...bJJJJJSSoSS......",
	"..DDDJJJJJJSSS......",
	"MMMDDDDJJJb.........",
	"BBMM................",
	"BB..................",
	"....................",
	"....................",
]

# --- Números de camiseta -----------------------------------------------

## Dígitos de 3x5. Es el tamaño más chico en el que un número se sigue
## leyendo, y la espalda mide 8 píxeles de ancho: entran dos.
const DIGITOS := [
	["###", "#.#", "#.#", "#.#", "###"],  # 0
	[".#.", "##.", ".#.", ".#.", "###"],  # 1
	["###", "..#", "###", "#..", "###"],  # 2
	["###", "..#", "###", "..#", "###"],  # 3
	["#.#", "#.#", "###", "..#", "..#"],  # 4
	["###", "#..", "###", "..#", "###"],  # 5
	["###", "#..", "###", "#.#", "###"],  # 6
	["###", "..#", "..#", "..#", "..#"],  # 7
	["###", "#.#", "###", "#.#", "###"],  # 8
	["###", "#.#", "###", "..#", "###"],  # 9
]

## Fila del sprite donde arranca el número, ya dentro del torso.
const FILA_NUMERO := ALTO_CABEZA + 1

## De espaldas se le ve el número; de frente, no. Son las dos direcciones
## base que muestran la espalda. Las de la izquierda son su espejo, y el
## espejo se aplica al sprite entero: el número se estampa ANTES de
## espejar, así que en esas direcciones sale invertido — es lo correcto,
## un dorsal visto de reojo se lee así.
const DIRECCIONES_CON_NUMERO := [ARRIBA, ARRIBA_DER]

static var _cache: Dictionary = {}
static var _palomita_pngs: Dictionary = {}
static var _palomita_cache: Dictionary = {}
const CUADROS_PALOMITA := 8

## Los nombres y el orden coinciden con AtlasJugadores.PEINADOS. Cada peinado
## tiene su hoja completa para conservar su silueta durante toda la palomita.
const PALOMITA_PEINADOS := ["puntas", "afro", "rapado", "atado", "mohicano",
	"rastas", "degrade", "vincha", "rodete", "raya", "trenzas",
	"rulos_cortos", "rulos_largos", "melena", "mullet", "flequillo", "jopo",
	"tupe", "hongo", "coleta", "cucurella", "doble_cresta"]
const PALOMITA_DORSAL_CENTROS := [Vector2i(31, 38), Vector2i(31, 39),
	Vector2i(31, 39), Vector2i(31, 39), Vector2i(31, 39), Vector2i(31, 43),
	Vector2i(31, 47), Vector2i(31, 49)]


## Cuadros PNG de la palomita. Van fuera del atlas principal para que una
## pose horizontal nunca pueda desplazar ni contaminar otro cuadro.
static func palomita_png(color_camiseta: Color, color_short: Color,
		frame: int, espejo: bool = false, color_pelo: Color = PELO,
		estilo_pelo: int = 0, numero: int = 0) -> ImageTexture:
	var pantalon := color_short if color_short.a > 0.0 else SHORT
	var peinado := posmod(estilo_pelo, PALOMITA_PEINADOS.size())
	var clave := "%s_%s_%s_%d_%d_%s" % [color_camiseta.to_html(), pantalon.to_html(),
		color_pelo.to_html(), frame, peinado, espejo]
	clave += "_%d" % clampi(numero, 0, 99)
	if _palomita_cache.has(clave):
		return _palomita_cache[clave]
	if not _palomita_pngs.has(peinado):
		var ruta := "res://assets/partido/palomita/%s.png" % PALOMITA_PEINADOS[peinado]
		var nueva_hoja := (load(ruta) as Texture2D).get_image()
		nueva_hoja.decompress()
		nueva_hoja.convert(Image.FORMAT_RGBA8)
		_palomita_pngs[peinado] = nueva_hoja
	var cuadro := clampi(frame, 0, CUADROS_PALOMITA - 1)
	var hoja: Image = _palomita_pngs[peinado]
	var img: Image = hoja.get_region(Rect2i(cuadro * 64, 0, 64, 64))
	_conservar_componente_principal(img)
	var mascara_camiseta := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	mascara_camiseta.fill(TRANSPARENTE)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p := img.get_pixel(x, y)
			if p.a <= 0.0:
				continue
			# El azul fuerte es la mascara de camiseta. El negro queda intacto
			# para conservar el contorno pixel-art.
			if p.b > 0.25 and p.b > p.r * 1.35 and p.b > p.g * 1.05:
				mascara_camiseta.set_pixel(x, y, Color.WHITE)
				var luz_camiseta := AtlasJugadores.factor_luz_camiseta(p)
				p = Color(color_camiseta.r * luz_camiseta, color_camiseta.g * luz_camiseta,
					color_camiseta.b * luz_camiseta, p.a)
			elif p.r > 0.82 and p.g > 0.82 and p.b > 0.82:
				p = Color(pantalon.r * p.v, pantalon.g * p.v, pantalon.b * p.v, p.a)
			elif _es_pelo_palomita(p):
				var brillo_pelo := AtlasJugadores.factor_luz_pelo(p)
				p = Color(color_pelo.r * brillo_pelo, color_pelo.g * brillo_pelo,
					color_pelo.b * brillo_pelo, p.a)
			img.set_pixel(x, y, p)
	if espejo:
		img.flip_x()
		mascara_camiseta.flip_x()
	_estampar_numero_palomita(img, mascara_camiseta, cuadro, color_camiseta, numero, espejo)
	var tex := ImageTexture.create_from_image(img)
	_palomita_cache[clave] = tex
	return tex


## Algunas hojas traen puntos negros aislados lejos del jugador. No son
## pelota ni sombra: ambas se dibujan por separado. Conservar la figura
## conectada más grande elimina esos restos sin retocar cuerpo o peinado.
static func _conservar_componente_principal(img: Image) -> void:
	var visitado := PackedByteArray()
	visitado.resize(img.get_width() * img.get_height())
	var principal := PackedInt32Array()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var inicio := y * img.get_width() + x
			if visitado[inicio] != 0 or img.get_pixel(x, y).a <= 0.0:
				continue
			var componente := PackedInt32Array([inicio])
			var cola := [inicio]
			visitado[inicio] = 1
			var cursor := 0
			while cursor < cola.size():
				var actual: int = cola[cursor]
				cursor += 1
				var ax := actual % img.get_width()
				var ay := actual / img.get_width()
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := ax + dx
						var ny := ay + dy
						if nx < 0 or nx >= img.get_width() or ny < 0 or ny >= img.get_height():
							continue
						var vecino := ny * img.get_width() + nx
						if visitado[vecino] != 0 or img.get_pixel(nx, ny).a <= 0.0:
							continue
						visitado[vecino] = 1
						cola.append(vecino)
						componente.append(vecino)
			if componente.size() > principal.size():
				principal = componente
	var conservar := PackedByteArray()
	conservar.resize(img.get_width() * img.get_height())
	for pixel in principal:
		conservar[pixel] = 1
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.0 and conservar[y * img.get_width() + x] == 0:
				img.set_pixel(x, y, Color.TRANSPARENT)


static func _es_pelo_palomita(c: Color) -> bool:
	return c.a >= 0.1 and c.r > c.g * 1.12 and c.g > c.b * 1.12 and c.v < 0.55


## El dorsal solo aparece si el cuadro deja ver la espalda/camiseta. Se
## estampa sobre el PNG final para conservar el mismo color de tinta que el
## resto del atlas y no inventar un número cuando el jugador no tiene dorsal.
static func _estampar_numero_palomita(img: Image, mascara_camiseta: Image, frame: int,
		color_camiseta: Color, numero: int, espejo: bool) -> void:
	if numero <= 0:
		return
	var texto := str(clampi(numero, 0, 99))
	var escala := 2
	var ancho := texto.length() * 3 * escala + (texto.length() - 1) * escala
	var centro: Vector2i = PALOMITA_DORSAL_CENTROS[frame]
	if espejo:
		centro.x = 63 - centro.x
	var x0: int = centro.x - int(ancho / 2.0)
	var y0: int = centro.y - 5
	var tinta := Color(0.08, 0.08, 0.10) if color_camiseta.get_luminance() > 0.55 else Color(0.97, 0.97, 0.98)
	for i in range(texto.length()):
		var digito: Array = DIGITOS[int(texto[i])]
		for y in range(digito.size()):
			for x in range(3):
				if digito[y][x] != "#":
					continue
				for dy in range(escala):
					for dx in range(escala):
						var px: int = x0 + i * 4 * escala + x * escala + dx
						var py: int = y0 + y * escala + dy
						if px < 0 or px >= img.get_width() or py < 0 or py >= img.get_height():
							continue
						if mascara_camiseta.get_pixel(px, py).a > 0.0:
							img.set_pixel(px, py, tinta)


## Qué peinado le toca a un jugador. Sale de su id y no de un sorteo, así
## el mismo jugador tiene el mismo pelo en todos los partidos y en la
## repetición. Los multiplicadores son primos distintos para que estilo y
## tono no queden correlacionados: con el mismo, todos los afros salían
## del mismo color.
static func pelo_de(jugador_id: int) -> int:
	return absi(jugador_id * 7919) % ESTILOS_PELO


static func tono_pelo_de(jugador_id: int) -> Color:
	var huella := absi(jugador_id * 104729)
	var rareza := huella % UNO_CADA_TONO_RARO
	if rareza == 0:
		return TONOS_PELO[INDICE_PELO_AZUL]
	if rareza == 1:
		return TONOS_PELO[INDICE_PELO_BLANCO]
	return TONOS_PELO[huella % INDICE_PELO_BLANCO]


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


## Sprite compuesto. Se cachea por todo lo que lo define: en cancha hay 22
## jugadores y unas pocas poses, así que son centenares de texturas de
## 12x20, no una por jugador y por fotograma.
## `color_short` TRANSPARENT = el pantalon por defecto. Entra en la clave
## del cache: dos clubes con la misma camiseta y distinto pantalon son dos
## sprites distintos, y sin esto el segundo se dibujaba con el del primero.
static func jugador(color_camiseta: Color, direccion: int = ABAJO, pose: String = QUIETO,
		color_short: Color = Color.TRANSPARENT, estilo_pelo: int = PELO_CORTO,
		color_pelo: Color = PELO, numero: int = 0) -> ImageTexture:
	var clave := "j_%s_%s_%d_%s_%d_%s_%d" % [
		color_camiseta.to_html(false), color_short.to_html(true), direccion, pose,
		estilo_pelo, color_pelo.to_html(false), numero]
	if _cache.has(clave):
		return _cache[clave]

	var espejo := direccion in [ABAJO_IZQ, IZQUIERDA, ARRIBA_IZQ]
	var paleta := _paleta(color_camiseta, color_short, color_pelo)
	var tex: ImageTexture
	match pose:
		BLOQUEA, CAE, CHILENA, VOLEA, PALOMITA, PALOMITA_PREPARA, PALOMITA_CAER, RECUPERA:
			tex = _construir(POSES_ESPECIALES[pose], paleta, espejo)
		BARRIDA:
			tex = _construir(BARRIDA_TENDIDA, paleta, espejo)
		FESTEJA:
			tex = _construir(_armar_festejo(estilo_pelo), paleta, false)
		_:
			tex = _construir(_armar_parado(direccion, pose, estilo_pelo, numero), paleta, espejo)
	_cache[clave] = tex
	return tex


## Cabeza + peinado + torso (con el número) + brazos + piernas, en ese
## orden. Las piezas no miden todas lo mismo de ancho: el remate estira la
## pierna más allá del cuerpo. Se centra todo contra la más ancha.
static func _armar_parado(direccion: int, pose: String, estilo_pelo: int, numero: int) -> Array:
	var base := direccion
	match direccion:
		ABAJO_IZQ: base = ABAJO_DER
		IZQUIERDA: base = DERECHA
		ARRIBA_IZQ: base = ARRIBA_DER

	# El que cabecea agacha la cabeza: se le ve la coronilla, no la cara.
	# La coronilla ya está dibujada — es la cabeza de espaldas — así que
	# el cabezazo no necesita sprite propio y sigue tomando los 6
	# peinados. Sin esto el jugador cabeceaba mirando al frente, que es la
	# única cosa que no hace nadie al cabecear.
	var cabeza := _cabeza_con_pelo(ARRIBA if pose == CABECEA else base, estilo_pelo)
	# Además hunde la cabeza entre los hombros: se le come el cuello. Es lo
	# que da el cuerpo compacto del salto. Con el cuello entero el sprite
	# quedaba estirado, como mirando el piso de parado.
	if pose == CABECEA:
		cabeza.remove_at(cabeza.size() - 1)
	var arriba: Array = cabeza + TORSOS[base]
	if numero > 0 and base in DIRECCIONES_CON_NUMERO and pose != CABECEA:
		_estampar_numero(arriba, numero)
	match pose:
		PATEA, PATEA_ARMA:
			arriba = _abrir_brazos(arriba, cabeza.size(), BRAZOS_PATEA)
		CABECEA:
			arriba = _abrir_brazos(arriba, cabeza.size(), BRAZOS_CABEZAZO)

	var piernas: Array = PIERNAS.get(pose, PIERNAS[QUIETO])
	var ancho: int = maxi(arriba[0].length(), piernas[0].length())
	var filas: Array = _centrar(arriba, ancho) + _centrar(piernas, ancho)
	if pose == CABECEA:
		for i in range(ELEVACION_CABEZAZO):
			filas.append(".".repeat(ancho))
	return filas


## Le saca los brazos al cuerpo, hacia los dos lados. `alto_cabeza` dice
## dónde empieza el torso y `tramos` qué pintar en cada fila suya, contando
## desde la columna que toca el hombro hacia afuera. Ensancha las filas si
## el brazo no entra.
static func _abrir_brazos(filas: Array, alto_cabeza: int, tramos: Dictionary) -> Array:
	var margen := 0
	for t in tramos.values():
		margen = maxi(margen, str(t).length())
	var salida: Array = _centrar(filas, filas[0].length() + margen * 2)
	for fila_torso in tramos:
		var y: int = alto_cabeza + int(fila_torso)
		if y >= salida.size():
			continue
		var linea: String = salida[y]
		var izq := -1
		var der := -1
		for x in range(linea.length()):
			if linea[x] == ".":
				continue
			if izq == -1:
				izq = x
			der = x
		if izq == -1:
			continue
		var tramo: String = str(tramos[fila_torso])
		for i in range(tramo.length()):
			if izq - 1 - i >= 0:
				linea = linea.substr(0, izq - 1 - i) + tramo[i] + linea.substr(izq - i)
			if der + 1 + i < linea.length():
				linea = linea.substr(0, der + 1 + i) + tramo[i] + linea.substr(der + 2 + i)
		salida[y] = linea
	return salida


## Deja las filas de `ancho` columnas, con lo que había en el medio. Es lo
## que permite mezclar piezas de 12 y de 16 en el mismo sprite.
static func _centrar(filas: Array, ancho: int) -> Array:
	var sobra: int = ancho - filas[0].length()
	if sobra <= 0:
		return filas.duplicate()
	var izq := ".".repeat(int(sobra / 2.0))
	var der := ".".repeat(sobra - izq.length())
	var salida: Array = []
	for f in filas:
		salida.append(izq + f + der)
	return salida


static func _cabeza_con_pelo(base: int, estilo_pelo: int) -> Array:
	var estilo: int = clampi(estilo_pelo, 0, ESTILOS_PELO - 1)
	return _superponer(CABEZAS[base], PELOS[estilo][base])


## El festejo no depende de la dirección: el que grita el gol se planta de
## frente. Elegir el cuerpo por hacia dónde venía corriendo lo mostraba de
## espaldas justo en el momento en que uno quiere verle la cara.
static func _armar_festejo(estilo_pelo: int) -> Array:
	var filas := _cabeza_con_pelo(ABAJO, estilo_pelo)
	filas.append_array(TORSO_ABAJO)
	filas = _superponer(filas, BRAZOS_ARRIBA)
	filas.append_array(PIERNAS[QUIETO])
	return filas


static func arquero_volando(color_camiseta: Color, hacia_izquierda: bool,
		color_short: Color = Color.TRANSPARENT, color_pelo: Color = PELO) -> ImageTexture:
	var clave := "arq_%s_%s_%s_%s" % [
		color_camiseta.to_html(false), color_short.to_html(true), str(hacia_izquierda),
		color_pelo.to_html(false)]
	if _cache.has(clave):
		return _cache[clave]
	var tex := _construir(ARQUERO_VUELA, _paleta(color_camiseta, color_short, color_pelo),
		hacia_izquierda)
	_cache[clave] = tex
	return tex


static func pelota(fase: int = 0) -> ImageTexture:
	var cuadro := posmod(fase, 12)
	var clave := "pelota_artistica_%d" % cuadro
	if _cache.has(clave):
		return _cache[clave]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var paneles: Array[Vector3] = []
	for a in [-1.0, 1.0]:
		for b in [-1.0, 1.0]:
			paneles.append(Vector3(0, a, b * phi).normalized())
			paneles.append(Vector3(a, b * phi, 0).normalized())
			paneles.append(Vector3(b * phi, 0, a).normalized())
	var angulo := cuadro * TAU / 12.0
	for y in range(16):
		for x in range(16):
			var uv := (Vector2(x, y) - Vector2(7.5, 7.5)) / 7.5
			var r := uv.length_squared()
			if r > 1.0:
				continue
			var normal := Vector3(uv.x, uv.y, sqrt(1.0 - r))
			var rotada := normal.rotated(Vector3(0.3, 1, 0).normalized(), angulo)
			var negro := false
			for panel in paneles:
				if rotada.dot(panel) > 0.94:
					negro = true
			var c := Color("fff6df")
			if normal.dot(Vector3(-0.4, -0.6, 0.7).normalized()) < 0.25:
				c = Color("8aabb5")
			elif y > 7:
				c = Color("cfdfdb")
			if negro:
				c = Color("263444")
			if r > 0.83:
				c = Color("14202c")
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[clave] = tex
	return tex


## Cuadros de cada hoja de regate. Croqueta y bicicleta se redibujaron a 12
## cuadros (4x3) porque con 6 el traslado entre pies no se leía; las demás
## siguen en 6 (3x2). Única fuente: la vista y los tests leen de acá.
const CUADROS_REGATE := {"croqueta": 12, "bicicleta": 12, "globito": 12,
	"elastica": 6, "ruleta": 12}


## Tramos de la ruleta en fase 0..1, tomados de la hoja: los cuadros 0 y 1
## son la entrada; del 2 al 8 gira de perfil a espaldas, al otro perfil, de
## frente y vuelve; del 9 al 11 sale.
const RULETA_GIRO := 2.0 / 12.0
const RULETA_SALIDA := 9.0 / 12.0
## Las poses ya existen en cada uno de los once atlas preparados. Los dos
## cuadros marcados se espejan dentro del giro; el espejo general del regate
## se combina con ese giro local.
const CLIP_RULETA := [0, 2, 12, 16, 25, 12, 0, 24, 32, 12, 4, 6]
const ESPEJOS_RULETA := [false, false, false, false, false, true, true,
	false, false, false, false, false]
const CLIPS_REGATE_ATLAS := {
	"croqueta": [0, 1, 2, 3, 32, 33, 32, 33, 4, 5, 6, 7],
	"bicicleta": [0, 2, 12, 13, 14, 15, 13, 14, 15, 4, 6, 0],
	"ruleta": CLIP_RULETA,
	"globito": [0, 2, 4, 12, 13, 14, 15, 1, 3, 5, 7, 1],
	"elastica": [68, 69, 70, 69, 71, 0],
}
const ESPEJOS_REGATE_ATLAS := {"ruleta": ESPEJOS_RULETA}
## A cuánto de los pies va la pelota mientras gira: la lleva con la suela.
const RULETA_RADIO_PELOTA := 0.32


## Cuerpo y pelota de la ruleta, en el mismo marco que globito(). El
## jugador gira mientras se corre al costado del rival, y la pelota da la
## vuelta con él: queda siempre del lado hacia donde mira el dibujo. Así la
## espalda tapa la pelota justo cuando pasa junto al rival.
static func ruleta(fase: float) -> Dictionary:
	var f := clampf(fase, 0.0, 1.0)
	if f < RULETA_GIRO:
		var cuerpo := Vector2(lerpf(0.0, 1.0, f / RULETA_GIRO), 0.0)
		return {"cuerpo": cuerpo, "pelota": cuerpo + Vector2(lerpf(0.25, RULETA_RADIO_PELOTA, f / RULETA_GIRO), 0.0),
			"altura": 0.0}
	if f < RULETA_SALIDA:
		var g := (f - RULETA_GIRO) / (RULETA_SALIDA - RULETA_GIRO)
		var corrimiento := smoothstep(0.0, 1.0, g)
		var cuerpo := Vector2(1.0 + corrimiento, -1.3 * corrimiento)
		# El dibujo mira a la derecha, arriba, izquierda y abajo, en ese
		# orden: el ángulo baja de 0 a -TAU.
		var angulo := -TAU * g
		return {"cuerpo": cuerpo, "pelota": cuerpo + Vector2(cos(angulo), sin(angulo)) * RULETA_RADIO_PELOTA,
			"altura": 0.0}
	var e := (f - RULETA_SALIDA) / (1.0 - RULETA_SALIDA)
	var cuerpo := Vector2(2.0 + 1.8 * smoothstep(0.0, 1.0, e), -1.3 + 0.1 * e)
	return {"cuerpo": cuerpo, "pelota": cuerpo + Vector2(RULETA_RADIO_PELOTA + 0.2 * e, 0.0), "altura": 0.0}


## Tramos del globito en fase 0..1, tomados de la hoja: del 0 al 3 entra
## corriendo, en el 4 mete la punta debajo de la pelota, hasta el 6 la
## levanta y desde el 7 corre a buscarla por al lado del rival.
const GLOBITO_TOQUE := 4.0 / 12.0
const GLOBITO_CARRERA := 7.0 / 12.0
## La pelota pasa por encima de la cabeza del rival (el sprite mide 1,8 m)
## y pica antes de que llegue el que la tiró.
const GLOBITO_ALTURA := 2.6
const GLOBITO_PIQUE := 0.8


## Cuerpo y pelota del globito en metros, relativos al punto de partida:
## x hacia adelante, y hacia el costado. Lo leen el Laboratorio para mover
## al jugador y la vista para ubicar la pelota, así los dos cuentan la
## misma jugada: la pelota va por arriba del rival y el jugador lo rodea.
static func globito(fase: float) -> Dictionary:
	var f := clampf(fase, 0.0, 1.0)
	var cuerpo := Vector2.ZERO
	if f < GLOBITO_TOQUE:
		cuerpo.x = lerpf(0.0, 0.9, f / GLOBITO_TOQUE)
	elif f < GLOBITO_CARRERA:
		cuerpo.x = lerpf(0.9, 1.0, (f - GLOBITO_TOQUE) / (GLOBITO_CARRERA - GLOBITO_TOQUE))
	else:
		var c := (f - GLOBITO_CARRERA) / (1.0 - GLOBITO_CARRERA)
		cuerpo = Vector2(1.0 + 2.4 * smoothstep(0.0, 1.0, c), -sin(c * PI) - 0.2 * c)
	if f < GLOBITO_TOQUE:
		return {"cuerpo": cuerpo, "pelota": cuerpo + Vector2(lerpf(0.25, 0.35, f / GLOBITO_TOQUE), 0.0),
			"altura": 0.0}
	var s := (f - GLOBITO_TOQUE) / (1.0 - GLOBITO_TOQUE)
	if s < GLOBITO_PIQUE:
		var vuelo := s / GLOBITO_PIQUE
		return {"cuerpo": cuerpo, "pelota": Vector2(lerpf(1.25, 3.6, vuelo), 0.0),
			"altura": GLOBITO_ALTURA * sin(vuelo * PI)}
	var rueda := (s - GLOBITO_PIQUE) / (1.0 - GLOBITO_PIQUE)
	return {"cuerpo": cuerpo, "pelota": Vector2(lerpf(3.6, 3.85, rueda), -0.2 * rueda), "altura": 0.0}


## Tramos de la bicicleta en fase 0..1, tomados de la hoja: los cuadros 0
## y 1 son la carrera de entrada, del 2 al 8 van los dos amagues sobre la
## pelota y del 9 al 11 la salida. El cuerpo y la pelota cambian de tramo
## en el mismo cuadro que el dibujo.
const BICICLETA_INICIO_AMAGUES := 2.0 / 12.0
const BICICLETA_INICIO_SALIDA := 9.0 / 12.0


static func cuadros_regate(tipo: String) -> int:
	return int(CUADROS_REGATE.get(tipo, 6))


## Cuadro de regate de 64 px. Las cinco secuencias reutilizan los cuadros
## exactos del atlas del jugador: cuerpo, peinado, tono y dorsal permanecen
## iguales antes, durante y después del gesto. La pelota se dibuja aparte.
static func regate_png(tipo: String, fase: int = 0, espejo: bool = false,
		camiseta: Color = Color("2d70e8"), pantalon: Color = Color.TRANSPARENT,
		pelo: Color = PELO, estilo_pelo: int = 0, numero: int = 0) -> ImageTexture:
	if CLIPS_REGATE_ATLAS.has(tipo):
		var clip: Array = CLIPS_REGATE_ATLAS[tipo]
		var cuadro_atlas := posmod(fase, clip.size())
		var espejos_locales: Array = ESPEJOS_REGATE_ATLAS.get(tipo, [])
		var espejo_local := not espejos_locales.is_empty() and bool(espejos_locales[cuadro_atlas])
		return AtlasJugadores.textura(int(clip[cuadro_atlas]), camiseta, pantalon,
			pelo, espejo != espejo_local, numero, estilo_pelo)
	if not CUADROS_REGATE.has(tipo):
		return jugador(Color("2d70e8"), DERECHA, QUIETO)
	var cuadros := cuadros_regate(tipo)
	var columnas := 4 if cuadros == 12 else 3
	var cuadro := posmod(fase, cuadros)
	var clave := "regate_%s_%d_%s_%s_%s" % [tipo, cuadro, espejo,
		camiseta.to_html(true), pantalon.to_html(true)]
	if _cache.has(clave):
		return _cache[clave]
	var fuente := load("res://assets/partido/regates/%s.png" % tipo) as Texture2D
	if fuente == null:
		return jugador(Color("2d70e8"), DERECHA, QUIETO)
	var img := fuente.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var region := img.get_region(Rect2i((cuadro % columnas) * 64,
		(cuadro / columnas) * 64, 64, 64))
	# El fallback sigue cubriendo hojas viejas de 6 cuadros y también evita
	# parpadeos si una celda nueva queda vacía.
	if not _region_tiene_pintura(region):
		for paso in range(1, cuadros + 1):
			var candidato := posmod(cuadro - paso, cuadros)
			var respaldo := img.get_region(Rect2i((candidato % columnas) * 64,
				(candidato / columnas) * 64, 64, 64))
			if _region_tiene_pintura(respaldo):
				region = respaldo
				break
	if not _region_tiene_pintura(region):
		return jugador(camiseta, IZQUIERDA if espejo else DERECHA, QUIETO, pantalon)
	for y in range(64):
		for x in range(64):
			var pixel := region.get_pixel(x, y)
			if pixel.a < 0.1:
				continue
			if pixel.b > pixel.r * 1.25 and pixel.b > pixel.g * 1.05:
				var tinta := camiseta * clampf(pixel.v / 0.85, 0.25, 1.2)
				tinta.a = pixel.a
				region.set_pixel(x, y, tinta)
			elif pantalon.a > 0.0 and pixel.s < 0.18 and pixel.v > 0.72 and y > 34:
				var tinta_short := pantalon * pixel.v
				tinta_short.a = pixel.a
				region.set_pixel(x, y, tinta_short)
	if espejo:
		region.flip_x()
	var tex := ImageTexture.create_from_image(region)
	_cache[clave] = tex
	return tex


static func _region_tiene_pintura(region: Image) -> bool:
	for y in range(region.get_height()):
		for x in range(region.get_width()):
			if region.get_pixel(x, y).a > 0.1:
				return true
	return false


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


## Pinta el número sobre el torso. Un dígito va centrado; dos ocupan el
## ancho entero de la espalda. Escribe una N, que la paleta resuelve al
## color que contrasta con la camiseta.
static func _estampar_numero(filas: Array, numero: int) -> void:
	var texto := str(clampi(numero, 0, 99))
	var ancho_texto := texto.length() * 4 - 1
	var x0 := int((ANCHO - ancho_texto) / 2.0)
	for i in range(texto.length()):
		var digito: Array = DIGITOS[int(texto[i])]
		for y in range(digito.size()):
			var fila: String = filas[FILA_NUMERO + y]
			var patron: String = digito[y]
			for x in range(3):
				if patron[x] != "#":
					continue
				var col := x0 + i * 4 + x
				if col < 0 or col >= ANCHO:
					continue
				fila = fila.substr(0, col) + "N" + fila.substr(col + 1)
			filas[FILA_NUMERO + y] = fila


## Pinta `encima` sobre `filas`: donde `encima` tiene un punto, pasa lo de
## abajo. Es lo que permite tener un solo juego de cabezas y seis
## peinados, en vez de treinta cabezas.
static func _superponer(filas: Array, encima: Array) -> Array:
	var salida: Array = []
	for y in range(filas.size()):
		if y >= encima.size():
			salida.append(filas[y])
			continue
		var base: String = filas[y]
		var arriba: String = encima[y]
		var fila := ""
		for x in range(base.length()):
			fila += base[x] if (x >= arriba.length() or arriba[x] == ".") else arriba[x]
		salida.append(fila)
	return salida


static func _paleta(camiseta: Color, short: Color, pelo: Color) -> Dictionary:
	return {
		".": TRANSPARENTE, "H": pelo, "S": PIEL, "d": PIEL_OSCURA, "o": OJO,
		"V": COLOR_VINCHA, "P": POLVO,
		"J": camiseta, "b": camiseta.darkened(0.35),
		"N": _color_numero(camiseta),
		"D": short if short.a > 0.0 else SHORT, "M": MEDIAS, "B": BOTIN,
	}


## El número va blanco sobre camiseta oscura y negro sobre camiseta clara.
## Con un color fijo desaparecía en la mitad de los clubes.
static func _color_numero(camiseta: Color) -> Color:
	var luz := camiseta.r * 0.299 + camiseta.g * 0.587 + camiseta.b * 0.114
	return Color(0.08, 0.08, 0.10) if luz > 0.55 else Color(0.97, 0.97, 0.98)


static func _construir(filas: Array, paleta: Dictionary, espejar: bool) -> ImageTexture:
	var alto := filas.size()
	var ancho: int = filas[0].length()
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in range(alto):
		var fila: String = filas[y]
		for x in range(ancho):
			var destino: int = (ancho - 1 - x) if espejar else x
			var c: Color = paleta[fila[x]]
			# Luz superior izquierda y costuras, sin suavizar los p?xeles.
			if fila[x] in ["J", "D", "H", "S", "M"]:
				if x == 0 or fila[x - 1] != fila[x]:
					c = c.lightened(0.16)
				elif x == ancho - 1 or fila[x + 1] != fila[x]:
					c = c.darkened(0.22)
				elif fila[x] == "J" and y % 3 == 0:
					c = c.darkened(0.07)
			img.set_pixel(destino, y, c)
	return ImageTexture.create_from_image(img)
