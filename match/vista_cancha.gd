class_name VistaCancha
extends Control

## Dibuja el estadio y los cuerpos que hay sobre la cancha. NO sabe nada
## del motor: recibe una lista de entidades ya resueltas (posición en
## metros + altura) y las proyecta.
##
## Todo el decorado (césped, tribunas, arcos) se dibuja como polígonos
## proyectados con textura y UV, no como sprites pegados: así la
## proyección los inclina sola y con cambiar las constantes de
## ProyeccionPartido cambia el estadio entero junto con los jugadores.

## Estado de la cancha (§8.4 #21 del GDD): un potrero de división 10 se ve
## de tierra y un césped híbrido, verde parejo. `aspereza` es cuánta
## variación tiene el pasto — el potrero es irregular, el híbrido parejo.
const PALETAS := {
	"potrero": {
		"claro": Color("a38a58"), "oscuro": Color("93794c"),
		"linea": Color(0.82, 0.77, 0.66, 0.78), "aspereza": 0.055,
		"franjas": 8, "desgaste": 0.32,
	},
	"barrial": {
		"claro": Color("8f8550"), "oscuro": Color("777344"),
		"linea": Color(0.86, 0.83, 0.75, 0.84), "aspereza": 0.048,
		"franjas": 10, "desgaste": 0.26,
	},
	"regular": {
		"claro": Color("4f914b"), "oscuro": Color("428344"),
		"linea": Color(0.92, 0.94, 0.90, 0.9), "aspereza": 0.035,
		"franjas": 12, "desgaste": 0.20,
	},
	"cuidado": {
		"claro": Color("4b9854"), "oscuro": Color("3f8448"),
		"linea": Color(0.95, 0.97, 0.92, 0.94), "aspereza": 0.026,
		"franjas": 14, "desgaste": 0.14,
	},
	"profesional": {
		"claro": Color("469d55"), "oscuro": Color("388649"),
		"linea": Color(0.98, 0.99, 0.96, 0.98), "aspereza": 0.020,
		"franjas": 16, "desgaste": 0.09,
	},
	"hibrido": {
		"claro": Color("4d9e58"), "oscuro": Color("408c4d"),
		"linea": Color.WHITE, "aspereza": 0.018,
		"franjas": 18, "desgaste": 0.06,
	},
	"elite": {
		"claro": Color("45a75a"), "oscuro": Color("368a49"),
		"linea": Color(1.0, 1.0, 0.98, 1.0), "aspereza": 0.012,
		"franjas": 18, "desgaste": 0.025,
	},
}

## Infraestructura sincronizada con la calidad del campo: potrero de tierra
## y público parado al inicio; estadio alto, profundo y lleno al final.
const PERFILES_ESTADIO := {
	"potrero": {"prof": 3.5, "alto": 2.5, "prof_cerca": 2.0, "alto_cerca": 1.3,
		"filas": 2, "sectores": 2, "parado": true, "muro": 1.0, "pista": Color("60452f")},
	"barrial": {"prof": 6.0, "alto": 5.0, "prof_cerca": 3.0, "alto_cerca": 1.8,
		"filas": 4, "sectores": 3, "parado": true, "muro": 1.3, "pista": Color("72543d")},
	"regular": {"prof": 9.0, "alto": 10.0, "prof_cerca": 5.0, "alto_cerca": 2.5,
		"filas": 8, "sectores": 4, "parado": false, "muro": 1.6, "pista": Color("4c5948")},
	"cuidado": {"prof": 12.0, "alto": 15.0, "prof_cerca": 7.0, "alto_cerca": 3.0,
		"filas": 12, "sectores": 5, "parado": false, "muro": 1.8, "pista": Color("4d514b")},
	"profesional": {"prof": 16.0, "alto": 22.0, "prof_cerca": 10.0, "alto_cerca": 3.6,
		"filas": 16, "sectores": 6, "parado": false, "muro": 2.0, "pista": Color("555b61")},
	"hibrido": {"prof": 17.0, "alto": 24.0, "prof_cerca": 11.0, "alto_cerca": 3.8,
		"filas": 17, "sectores": 6, "parado": false, "muro": 2.0, "pista": Color("5a6065")},
	"elite": {"prof": 21.0, "alto": 30.0, "prof_cerca": 14.0, "alto_cerca": 4.5,
		"filas": 21, "sectores": 8, "parado": false, "muro": 2.3, "pista": Color("666c72"),
		"techo": true},
}

const COLOR_CIELO := Color(0.09, 0.10, 0.13)
const COLOR_PISTA := Color(0.32, 0.20, 0.17)
const COLOR_MURO := Color(0.20, 0.21, 0.25)
const COLOR_TECHO := Color(0.11, 0.12, 0.15)

## La tribuna no compite con la cancha: va bajada de luz, y las laterales
## y la de este lado más todavía porque están más a la sombra. Sin esto
## el público tira más contraste que los jugadores y el ojo se va al
## borde de la pantalla en vez de a la pelota.
const TINTE_TRIBUNA := Color(0.82, 0.82, 0.86)
const TINTE_TRIBUNA_LATERAL := Color(0.68, 0.68, 0.74)
const TINTE_TRIBUNA_CERCA := Color(0.55, 0.55, 0.62)
const COLOR_ARCO := Color(0.97, 0.97, 0.98)

const FRANJAS := 12
const ANCHO_SPRITE_PX := 26.0

## Punto de agarre de la mano derecha en cada cuadro normal del atlas,
## medido desde el pivote de los pies. La mano sube y baja al correr: usar
## siempre (10, -32) dejaba el palo naciendo a la altura de la cara.
const MANO_BANDERA_PX := {
	0: Vector2(12, -21), 1: Vector2(13, -23), 2: Vector2(11, -24), 3: Vector2(14, -23),
	4: Vector2(13, -22), 5: Vector2(10, -19), 6: Vector2(13, -23), 7: Vector2(14, -22),
	16: Vector2(11, -19), 17: Vector2(11, -19), 18: Vector2(10, -21), 19: Vector2(10, -21),
	20: Vector2(12, -22), 21: Vector2(10, -22), 22: Vector2(11, -21), 23: Vector2(12, -21),
	24: Vector2(10, -16), 25: Vector2(10, -16),
}

## Metros que ocupa un tile de cada textura. El césped chico para que la
## veta no se lea como manchones; el público más chico todavía, que es lo
## que hace que las cabezas se vean como cabezas.
const METROS_TILE_CESPED := 3.0
const METROS_TILE_PUBLICO := 4.0
## Un rombo de red mide unos 10-12 cm de verdad. Con 0,8 m por tile la
## malla salía del tamaño de una pelota y el arco parecía una hamaca.
const METROS_TILE_RED := 0.22

## Arco reglamentario: 7,32 x 2,44. El fondo (la profundidad de la red) no
## es reglamentario, es lo que hace que se vea como un arco y no como un
## rectángulo dibujado en el aire. Ancho y fondo salen del motor: la
## pelota que se va tiene que frenar fuera de ESTE arco.
const ARCO_MEDIO_ANCHO := MotorEspacial.ARCO_MEDIO_ANCHO
const ARCO_ALTO := 2.44
const ARCO_FONDO := MotorEspacial.PROFUNDIDAD_ARCO
const ARCO_ALTO_FONDO := 1.5

## Geometría del estadio, en metros desde el borde de la cancha.
const PISTA := 5.0
## La tribuna de enfrente tiene que ser mucho más ALTA que PROFUNDA. La
## proyección aplasta la profundidad a 0,52 y estira la altura a 0,85, así
## que una tribuna de 20 m de fondo y 14 de alto sube 262 px por altura
## pero baja 229 px por fondo: neta, una franja de 30 px arriba de todo.
## Con 14 de fondo y 22 de alto queda una tribuna de verdad.
const PROF_TRIBUNA := 14.0
const ALTO_TRIBUNA := 22.0
const ALTO_MURO := 1.8
## La tribuna de este lado está ENTRE la cámara y la cancha, así que si
## sube tanto como la de enfrente se acuesta sobre el campo y tapa el
## partido. Baja y poco profunda, funciona como borde inferior del cuadro.
const PROF_TRIBUNA_CERCA := 12.0
const ALTO_TRIBUNA_CERCA := 3.5

var camara := CamaraPartido.new()
var estado_cancha := "regular"

## Tarjetas flotando sobre el infractor: [{"pos": Vector2 (metros),
## "roja": bool, "avance": float 0..1}]. Las arma VistaPartido, que es
## quien sabe qué jugador cometió la falta.

## Euforia del festejo, 0 a 1. La consume el HUD; el decorado permanece
## cacheado para no regenerar cientos de polígonos durante el gol.
var euforia := 0.0

## Cada entidad: {"pos": Vector2 (metros), "z": float, "tipo": "jugador"/"oficial"/"pelota",
## "color": Color}. La vista las ordena por profundidad y las dibuja.
var entidades: Array = []

var _tex_sombra: ImageTexture
var _tex_pelota: ImageTexture
var _tex_publico: ImageTexture
var _tex_publico_parado: ImageTexture
var _tex_red: ImageTexture
static var _mallas_desgaste := {}

## El decorado no se mueve: solo la cámara. Dibujarlo polígono por polígono
## en cada cuadro costaba 1,5 ms de GDScript y 469 draw calls en escritorio
## (tests/_diag_rendimiento_partido.gd), y en el celular eso tiraba el
## partido. Se arma UNA vez en coordenadas de proyección sin cámara (ver
## _q) y cada cuadro se dibuja con una sola transformación.
## clave -> Array de comandos (ver ConstructorDecorado).
static var _decorados := {}
## Mientras no es null, _plano/_panel/_linea anotan en vez de dibujar.
var _constructor: ConstructorDecorado = null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Las texturas del decorado se dibujan con UV mayores a 1 (un tile por
	# cada pocos metros), así que sin repetición saldría una sola copia
	# estirada. Los sprites usan UV 0..1 y no se ven afectados.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_tex_sombra = SpritesPartido.sombra()
	_tex_pelota = SpritesPartido.pelota()
	_tex_publico = TexturasEstadio.publico()
	_tex_publico_parado = TexturasEstadio.publico_parado()
	_tex_red = TexturasEstadio.red()


## De la calidad de cancha del GDD (−8 a +3, ver core/estado_cancha.gd) a
## una de las tres texturas. Es el MISMO número que ya castiga `pases` y
## `control` en el duelo: si la cancha complica el juego, se ve.
static func estado_desde_calidad(calidad: float) -> String:
	if calidad <= -4.0:
		return "potrero"
	if calidad <= 0.0:
		return "regular"
	return "hibrido"


static func nivel_estadio_desde_calidad(calidad: float) -> String:
	if calidad <= -6.0:
		return "potrero"
	if calidad <= -4.0:
		return "barrial"
	if calidad <= -2.0:
		return "regular"
	if calidad <= 0.0:
		return "cuidado"
	if calidad <= 1.5:
		return "profesional"
	return "elite"


func _perfil_estadio() -> Dictionary:
	return PERFILES_ESTADIO.get(estado_cancha, PERFILES_ESTADIO["regular"])


func _p(x: float, y: float, z: float = 0.0) -> Vector2:
	return ProyeccionPartido.sim_a_pantalla(x, y, z, camara.centro, camara.px_por_metro, size * 0.5)


func _draw() -> void:
	var pal: Dictionary = PALETAS.get(estado_cancha, PALETAS["regular"])
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_CIELO)
	# El decorado queda cacheado también durante el festejo. Regenerarlo para
	# animar la tribuna costaba cientos de draw calls por frame y congelaba la
	# celebración en teléfonos lentos. La euforia sigue animando HUD y cancha.
	_ejecutar(_decorado("fondo_" + estado_cancha, func():
		_dibujar_estadio()
		_dibujar_franjas(pal)))
	_dibujar_desgaste()
	_ejecutar(_decorado("lineas_" + estado_cancha, func(): _dibujar_lineas(pal)))
	_dibujar_banderines()
	_dibujar_entidades()


## Arma (una sola vez) los comandos de `clave` corriendo `dibujar` con el
## constructor enchufado. Es la MISMA función que dibuja en directo: la
## geometría tiene una sola fuente.
func _decorado(clave: String, dibujar: Callable) -> Array:
	if not _decorados.has(clave):
		_constructor = ConstructorDecorado.new()
		dibujar.call()
		_decorados[clave] = _constructor.terminar()
		_constructor = null
	return _decorados[clave]


## Proyección sin cámara ni zoom. La proyección es afín, así que pasar de
## acá a pantalla es una sola transformación (ver _transformacion_q).
static func _q(v: Vector3) -> Vector2:
	return Vector2(v.x + v.y * ProyeccionPartido.SHEAR_X,
		v.y * ProyeccionPartido.COMPRESION_Y - v.z * ProyeccionPartido.ESCALA_Z)


func _transformacion_q() -> Transform2D:
	var ppm := camara.px_por_metro
	var c := camara.centro
	var origen := size * 0.5 - _q(Vector3(c.x, c.y, 0.0)) * ppm
	return Transform2D(Vector2(ppm, 0.0), Vector2(0.0, ppm), origen)


func _ejecutar(comandos: Array) -> void:
	var ppm := camara.px_por_metro
	draw_set_transform_matrix(_transformacion_q())
	for cmd in comandos:
		if cmd.has("malla"):
			draw_mesh(cmd["malla"], cmd["tex"])
			continue
		# Los anchos van en píxeles de pantalla, como en draw_line: se
		# dividen por el zoom porque la transformación los escala.
		var px: float = maxf(float(cmd["min"]), ppm * float(cmd["factor"]))
		if cmd.has("puntos"):
			draw_multiline(cmd["puntos"], cmd["color"], px / ppm)
		else:
			draw_circle(cmd["centro"], px * float(cmd["radio"]) / ppm, cmd["color"])
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ---------------------------------------------------------------------------
# Decorado
# ---------------------------------------------------------------------------

## Un cuadrilátero en el espacio de la cancha (metros + altura), con la
## textura tileada según su tamaño REAL. Los UV se derivan del largo de
## los lados, así que un panel grande recibe más repeticiones y el tile
## conserva su escala sin importar dónde se use.
func _panel(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		tex: Texture2D, metros_tile: float, tinte: Color = Color.WHITE) -> void:
	var u: float = p0.distance_to(p1) / metros_tile
	var v: float = p0.distance_to(p3) / metros_tile
	if _constructor != null:
		_constructor.cuadrilatero([_q(p0), _q(p1), _q(p2), _q(p3)],
			[Vector2(0, 0), Vector2(u, 0), Vector2(u, v), Vector2(0, v)], tinte, tex)
		return
	draw_colored_polygon(
		PackedVector2Array([
			_p(p0.x, p0.y, p0.z), _p(p1.x, p1.y, p1.z),
			_p(p2.x, p2.y, p2.z), _p(p3.x, p3.y, p3.z),
		]), tinte,
		PackedVector2Array([Vector2(0, 0), Vector2(u, 0), Vector2(u, v), Vector2(0, v)]),
		tex)


func _plano(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, c: Color) -> void:
	if _constructor != null:
		_constructor.cuadrilatero([_q(p0), _q(p1), _q(p2), _q(p3)], [], c, null)
		return
	draw_colored_polygon(PackedVector2Array([
		_p(p0.x, p0.y, p0.z), _p(p1.x, p1.y, p1.z),
		_p(p2.x, p2.y, p2.z), _p(p3.x, p3.y, p3.z),
	]), c)


func _dibujar_estadio_original() -> void:
	var L := ProyeccionPartido.MEDIO_LARGO
	var A := ProyeccionPartido.MEDIO_ANCHO
	# Geometría estática: se construye una vez y se reutiliza en cada frame.
	var salto := 0.0
	var luz := Color.WHITE

	# Pista: la banda entre la línea de cal y el muro.
	_plano(Vector3(-L - PISTA, -A - PISTA, 0), Vector3(L + PISTA, -A - PISTA, 0),
		Vector3(L + PISTA, A + PISTA, 0), Vector3(-L - PISTA, A + PISTA, 0), COLOR_PISTA)
	var pal: Dictionary = PALETAS.get(estado_cancha, PALETAS["regular"])
	var borde: Color = pal["oscuro"]
	_plano(Vector3(-L - 2.0, -A - 2.0, 0), Vector3(L + 2.0, -A - 2.0, 0),
		Vector3(L + 2.0, A + 2.0, 0), Vector3(-L - 2.0, A + 2.0, 0), borde.darkened(0.12))

	var xa := -L - PISTA - PROF_TRIBUNA
	var xb := L + PISTA + PROF_TRIBUNA
	var ya := -A - PISTA - PROF_TRIBUNA
	var yb := A + PISTA + PROF_TRIBUNA

	# 1. Tribuna de enfrente. Sube alejándose de la cancha, así que en
	# pantalla crece hacia arriba y hace de fondo del partido.
	_panel(Vector3(xa, -A - PISTA, 0), Vector3(xb, -A - PISTA, 0),
		Vector3(xb, ya, ALTO_TRIBUNA + salto), Vector3(xa, ya, ALTO_TRIBUNA + salto),
		_tex_publico, METROS_TILE_PUBLICO, TINTE_TRIBUNA * luz)
	_detallar_grada(Vector3(xa, -A - PISTA, 0), Vector3(xb, -A - PISTA, 0), Vector3(0, -PROF_TRIBUNA, ALTO_TRIBUNA + salto))
	_plano(Vector3(xa, ya, ALTO_TRIBUNA), Vector3(xb, ya, ALTO_TRIBUNA),
		Vector3(xb, ya - 3.0, ALTO_TRIBUNA + 5.0), Vector3(xa, ya - 3.0, ALTO_TRIBUNA + 5.0),
		COLOR_TECHO)

	# 2. Cabeceras, detrás de cada arco.
	for lado in [-1.0, 1.0]:
		var x0: float = lado * (L + PISTA)
		var x1: float = lado * (L + PISTA + PROF_TRIBUNA)
		_panel(Vector3(x0, ya, 0), Vector3(x0, yb, 0),
			Vector3(x1, yb, ALTO_TRIBUNA + salto), Vector3(x1, ya, ALTO_TRIBUNA + salto),
			_tex_publico, METROS_TILE_PUBLICO, TINTE_TRIBUNA_LATERAL * luz)
		_detallar_grada(Vector3(x0, ya, 0), Vector3(x0, yb, 0), Vector3(x1 - x0, 0, ALTO_TRIBUNA + salto))

	# 3. Muro perimetral: la pared baja que separa la pista del público.
	# Va después de las tribunas porque está por delante de ellas.
	_plano(Vector3(xa, -A - PISTA, 0), Vector3(xb, -A - PISTA, 0),
		Vector3(xb, -A - PISTA, ALTO_MURO), Vector3(xa, -A - PISTA, ALTO_MURO), COLOR_MURO)
	# Carteles bajos con paleta limitada, como el resto del pixel art.
	var carteles := [Color("d9bd77"), Color("567d91"), Color("ba6455"), Color("e1ddba")]
	for i in range(14):
		var cx := -L + i * (2.0 * L / 14.0)
		_plano(Vector3(cx + 0.25, -A - PISTA + 0.02, 0.2),
			Vector3(cx + 6.9, -A - PISTA + 0.02, 0.2),
			Vector3(cx + 6.9, -A - PISTA + 0.02, 1.45),
			Vector3(cx + 0.25, -A - PISTA + 0.02, 1.45), carteles[i % carteles.size()])
	for lado in [-1.0, 1.0]:
		var x0: float = lado * (L + PISTA)
		_plano(Vector3(x0, ya, 0), Vector3(x0, yb, 0),
			Vector3(x0, yb, ALTO_MURO), Vector3(x0, ya, ALTO_MURO), COLOR_MURO)

	# 4. Tribuna de este lado, la última porque es la más cercana.
	_panel(Vector3(xa, A + PISTA, 0), Vector3(xb, A + PISTA, 0),
		Vector3(xb, A + PISTA + PROF_TRIBUNA_CERCA, ALTO_TRIBUNA_CERCA),
		Vector3(xa, A + PISTA + PROF_TRIBUNA_CERCA, ALTO_TRIBUNA_CERCA + salto),
		_tex_publico, METROS_TILE_PUBLICO, TINTE_TRIBUNA_CERCA * luz)


func _dibujar_estadio() -> void:
	var L := ProyeccionPartido.MEDIO_LARGO
	var A := ProyeccionPartido.MEDIO_ANCHO
	var perfil := _perfil_estadio()
	var prof: float = float(perfil["prof"])
	var alto: float = float(perfil["alto"])
	var prof_cerca: float = float(perfil["prof_cerca"])
	var alto_cerca: float = float(perfil["alto_cerca"])
	var tex_publico: Texture2D = _tex_publico_parado if bool(perfil["parado"]) else _tex_publico
	var tile_publico := METROS_TILE_PUBLICO if not bool(perfil["parado"]) else 3.0
	var pal: Dictionary = PALETAS.get(estado_cancha, PALETAS["regular"])

	# Pista: tierra en el potrero, superficie cuidada en la élite.
	_plano(Vector3(-L - PISTA, -A - PISTA, 0), Vector3(L + PISTA, -A - PISTA, 0),
		Vector3(L + PISTA, A + PISTA, 0), Vector3(-L - PISTA, A + PISTA, 0), perfil["pista"])
	_plano(Vector3(-L - 2.0, -A - 2.0, 0), Vector3(L + 2.0, -A - 2.0, 0),
		Vector3(L + 2.0, A + 2.0, 0), Vector3(-L - 2.0, A + 2.0, 0), pal["oscuro"].darkened(0.12))

	var xa := -L - PISTA - prof
	var xb := L + PISTA + prof
	var ya := -A - PISTA - prof
	var yb := A + PISTA + prof
	var frente := Vector3(xa, -A - PISTA, 0)
	var frente_fin := Vector3(xb, -A - PISTA, 0)

	# Tribuna de enfrente: crece en profundidad, filas y altura.
	_panel(frente, frente_fin, Vector3(xb, ya, alto), Vector3(xa, ya, alto),
		tex_publico, tile_publico, TINTE_TRIBUNA)
	_detallar_grada(frente, frente_fin, Vector3(0, -prof, alto), int(perfil["filas"]), int(perfil["sectores"]))
	if bool(perfil.get("techo", false)):
		_plano(Vector3(xa, ya, alto), Vector3(xb, ya, alto),
			Vector3(xb, ya - 4.0, alto + 5.0), Vector3(xa, ya - 4.0, alto + 5.0), COLOR_TECHO)

	# Cabeceras detrás de cada arco.
	for lado in [-1.0, 1.0]:
		var x0: float = lado * (L + PISTA)
		var x1: float = lado * (L + PISTA + prof)
		_panel(Vector3(x0, ya, 0), Vector3(x0, yb, 0),
			Vector3(x1, yb, alto), Vector3(x1, ya, alto),
			tex_publico, tile_publico, TINTE_TRIBUNA_LATERAL)
		_detallar_grada(Vector3(x0, ya, 0), Vector3(x0, yb, 0),
			Vector3(x1 - x0, 0, alto), int(perfil["filas"]), int(perfil["sectores"]))

	# Muro perimetral y carteles.
	var alto_muro: float = float(perfil["muro"])
	_plano(Vector3(xa, -A - PISTA, 0), Vector3(xb, -A - PISTA, 0),
		Vector3(xb, -A - PISTA, alto_muro), Vector3(xa, -A - PISTA, alto_muro), COLOR_MURO)
	var carteles := [Color("d9bd77"), Color("567d91"), Color("ba6455"), Color("e1ddba")]
	var cantidad_carteles := 8 if bool(perfil["parado"]) else 14
	for i in range(cantidad_carteles):
		var cx := -L + i * (2.0 * L / float(cantidad_carteles))
		var ancho_cartel := 6.9 if cantidad_carteles > 8 else 10.0
		var alto_cartel := minf(1.45, alto_muro - 0.1)
		_plano(Vector3(cx + 0.25, -A - PISTA + 0.02, 0.2),
			Vector3(cx + ancho_cartel, -A - PISTA + 0.02, 0.2),
			Vector3(cx + ancho_cartel, -A - PISTA + 0.02, alto_cartel),
			Vector3(cx + 0.25, -A - PISTA + 0.02, alto_cartel), carteles[i % carteles.size()])
	for lado in [-1.0, 1.0]:
		var x0: float = lado * (L + PISTA)
		_plano(Vector3(x0, ya, 0), Vector3(x0, yb, 0),
			Vector3(x0, yb, alto_muro), Vector3(x0, ya, alto_muro), COLOR_MURO)

	# Tribuna cercana: siempre baja para no tapar la pelota.
	_panel(Vector3(xa, A + PISTA, 0), Vector3(xb, A + PISTA, 0),
		Vector3(xb, A + PISTA + prof_cerca, alto_cerca),
		Vector3(xa, A + PISTA + prof_cerca, alto_cerca),
		tex_publico, tile_publico, TINTE_TRIBUNA_CERCA)
	if bool(perfil.get("techo", false)):
		_dibujar_focos(L, A, prof, alto)


func _dibujar_focos(L: float, A: float, prof: float, alto: float) -> void:
	# Torres de iluminación: señal visual del estadio terminado.
	for lado in [-1.0, 1.0]:
		var x: float = lado * (L + PISTA + prof * 0.72)
		var y := -A - PISTA - prof - 1.5
		_linea(Vector3(x, y, 0), Vector3(x, y, alto + 10.0), Color("aeb5bd"), 2.0)
		_linea(Vector3(x, y, alto + 10.0), Vector3(x - lado * 2.0, y + 1.0, alto + 9.2), Color("d8d5bd"), 2.0)


func _detallar_grada(inicio: Vector3, fin: Vector3, subida: Vector3,
		filas: int = 18, sectores_forzados: int = -1) -> void:
	# Pasillos escalonados separan bloques; barandas siguen la perspectiva.
	var sectores := sectores_forzados if sectores_forzados > 0 else maxi(2, roundi(inicio.distance_to(fin) / 19.0))
	var eje := (fin - inicio).normalized()
	# Todos los escalones y DESPUÉS todas las barandas: los sectores están a
	# 19 m y no se pisan, así que el orden no cambia el dibujo, pero junta
	# los polígonos en una sola malla y las líneas en un solo trazo.
	for sector in range(1, sectores):
		var centro := inicio.lerp(fin, float(sector) / sectores)
		for escalon in range(filas):
			var a := centro + subida * (float(escalon) / float(filas))
			var b := centro + subida * (float(escalon + 1) / float(filas))
			_plano(a - eje * 0.8, a + eje * 0.8, b + eje * 0.8, b - eje * 0.8, Color("65666a") if escalon % 2 == 0 else Color("494d55"))
	for sector in range(1, sectores):
		var centro := inicio.lerp(fin, float(sector) / sectores)
		for lado in [-1.0, 1.0]:
			var base: Vector3 = centro + eje * lado * 0.95
			var alto: Vector3 = base + subida
			_linea(Vector3(base.x, base.y, 0.8), Vector3(alto.x, alto.y, alto.z + 0.8), Color("92999e"), 1.0)
	for nivel in [0.25, 0.5, 0.75, 1.0]:
		var a: Vector3 = inicio + subida * nivel
		var b: Vector3 = fin + subida * nivel
		_linea(a, b, Color("222a36"), 3.0)
		_linea(a + Vector3(0, 0, 0.5), b + Vector3(0, 0, 0.5), Color("7b838c"), 1.0)


## Una línea de `min_px` píxeles, o `factor` píxeles por metro de zoom si
## da más.
func _linea(a: Vector3, b: Vector3, c: Color, min_px: float, factor: float = 0.0) -> void:
	if _constructor != null:
		_constructor.linea(_q(a), _q(b), c, min_px, factor)
		return
	draw_line(_p(a.x, a.y, a.z), _p(b.x, b.y, b.z), c, maxf(min_px, camara.px_por_metro * factor))


## Las franjas siguen la proyección: son paralelogramos, no rectángulos
## verticales. Es lo que hace que la cancha se lea inclinada.
func _dibujar_franjas(pal: Dictionary) -> void:
	var tex := TexturasEstadio.cesped(pal["claro"], float(pal["aspereza"]))
	var cantidad_franjas: int = int(pal.get("franjas", FRANJAS))
	var paso := ProyeccionPartido.LARGO / float(cantidad_franjas)
	var y0 := -ProyeccionPartido.MEDIO_ANCHO
	var y1 := ProyeccionPartido.MEDIO_ANCHO
	# El corte de luz entre franja y franja se aplica como TINTE sobre la
	# misma textura: si fueran dos texturas distintas, la veta del pasto
	# cambiaría de dibujo en cada franja y se notaría el corte.
	var claro: Color = pal["claro"]
	var oscuro: Color = pal["oscuro"]
	var tinte_oscuro := Color(
		oscuro.r / maxf(claro.r, 0.001), oscuro.g / maxf(claro.g, 0.001),
		oscuro.b / maxf(claro.b, 0.001))
	for i in range(cantidad_franjas):
		var xa := -ProyeccionPartido.MEDIO_LARGO + i * paso
		var xb := xa + paso
		_panel(Vector3(xa, y0, 0), Vector3(xb, y0, 0), Vector3(xb, y1, 0), Vector3(xa, y1, 0),
			tex, METROS_TILE_CESPED,
			Color.WHITE if i % 2 == 0 else tinte_oscuro)


func _dibujar_desgaste() -> void:
	# Geometria fija, una sola orden de dibujo y sin azar por fotograma.
	var origen := _p(0, 0)
	var transformacion := Transform2D(_p(1, 0) - origen, _p(0, 1) - origen, origen)
	var pal: Dictionary = PALETAS.get(estado_cancha, PALETAS["regular"])
	draw_mesh(_malla_desgaste(estado_cancha), null, transformacion,
		Color(0.48, 0.39, 0.23, float(pal.get("desgaste", 0.20))))


static func _malla_desgaste(estado: String) -> ArrayMesh:
	if _mallas_desgaste.has(estado):
		return _mallas_desgaste[estado]
	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1978
	var cantidad: int = int({
		"potrero": 180, "barrial": 125, "regular": 70, "cuidado": 48,
		"profesional": 30, "hibrido": 24, "elite": 14,
	}.get(estado, 70))
	for i in range(cantidad):
		var centro := Vector2.ZERO
		if i % 3 != 0:
			centro.x = (ProyeccionPartido.MEDIO_LARGO - 4.0) * (-1.0 if i % 2 == 0 else 1.0)
		var pos := centro + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-8.0, 8.0))
		var ancho := rng.randf_range(0.15, 0.65)
		var base := vertices.size()
		vertices.append_array(PackedVector2Array([pos, pos + Vector2(ancho, 0), pos + Vector2(ancho, 0.15), pos + Vector2(0, 0.15)]))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mallas_desgaste[estado] = malla
	return malla


func _dibujar_lineas(pal: Dictionary) -> void:
	var c: Color = pal["linea"]
	var L := ProyeccionPartido.MEDIO_LARGO
	var A := ProyeccionPartido.MEDIO_ANCHO

	_poli([Vector2(-L, -A), Vector2(L, -A), Vector2(L, A), Vector2(-L, A)], c)
	_linea(Vector3(0, -A, 0), Vector3(0, A, 0), c, GROSOR_CAL_MIN, GROSOR_CAL_FACTOR)
	_circulo(Vector2.ZERO, 9.15, c)

	for lado in [-1.0, 1.0]:
		# Área grande (16,5 x 40,32) y chica (5,5 x 18,32), reglamentarias.
		_poli([
			Vector2(lado * L, -20.16), Vector2(lado * (L - 16.5), -20.16),
			Vector2(lado * (L - 16.5), 20.16), Vector2(lado * L, 20.16),
		], c)
		_poli([
			Vector2(lado * L, -9.16), Vector2(lado * (L - 5.5), -9.16),
			Vector2(lado * (L - 5.5), 9.16), Vector2(lado * L, 9.16),
		], c)
		var punto_penal := Vector3(lado * (L - 11.0), 0.0, 0.0)
		if _constructor != null:
			_constructor.circulo(_q(punto_penal), c, GROSOR_CAL_MIN, GROSOR_CAL_FACTOR, 1.2)
		else:
			draw_circle(_p(punto_penal.x, punto_penal.y),
				maxf(GROSOR_CAL_MIN, camara.px_por_metro * GROSOR_CAL_FACTOR) * 1.2, c)


## Grosor de la cal: 1,5 px, o 6 cm por metro de zoom si da más.
const GROSOR_CAL_MIN := 1.5
const GROSOR_CAL_FACTOR := 0.06


func _poli(puntos: Array, c: Color) -> void:
	for i in range(puntos.size()):
		var a: Vector2 = puntos[i]
		var b: Vector2 = puntos[(i + 1) % puntos.size()]
		_linea(Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), c, GROSOR_CAL_MIN, GROSOR_CAL_FACTOR)


func _circulo(centro: Vector2, radio: float, c: Color) -> void:
	var pasos := 28
	var previo := Vector3(centro.x + radio, centro.y, 0)
	for i in range(1, pasos + 1):
		var ang := TAU * float(i) / pasos
		var actual := Vector3(centro.x + cos(ang) * radio, centro.y + sin(ang) * radio, 0)
		_linea(previo, actual, c, GROSOR_CAL_MIN, GROSOR_CAL_FACTOR)
		previo = actual


# ---------------------------------------------------------------------------
# Arcos
# ---------------------------------------------------------------------------

## El arco se dibuja en DOS pasadas que entran por separado al Y-sort: la
## red y el poste lejano con la profundidad del poste de atrás, el poste
## de acá con la del de adelante. Así una pelota que entra al arco queda
## por delante de la red pero por detrás del palo cercano, un arquero
## parado en la línea tapa la red, y una pelota que se va por afuera pasa
## por detrás de toda la estructura.
func _arco_fondo(lado: float) -> void:
	var gx: float = lado * ProyeccionPartido.MEDIO_LARGO
	var bx: float = gx + lado * ARCO_FONDO
	var a := ARCO_MEDIO_ANCHO
	# Sombra del interior del arco: sin esto la red blanca queda sobre la
	# pista marrón y no se lee que hay un volumen.
	_plano(Vector3(gx, -a, 0), Vector3(bx, -a, 0), Vector3(bx, a, 0), Vector3(gx, a, 0),
		Color(0, 0, 0, 0.30))
	_plano(Vector3(bx, -a, 0), Vector3(bx, a, 0),
		Vector3(bx, a, ARCO_ALTO_FONDO), Vector3(bx, -a, ARCO_ALTO_FONDO),
		Color(0.06, 0.07, 0.09, 0.55))
	# Red de fondo, techo y lateral lejano.
	_panel(Vector3(bx, -a, 0), Vector3(bx, a, 0),
		Vector3(bx, a, ARCO_ALTO_FONDO), Vector3(bx, -a, ARCO_ALTO_FONDO),
		_tex_red, METROS_TILE_RED)
	_panel(Vector3(gx, -a, ARCO_ALTO), Vector3(gx, a, ARCO_ALTO),
		Vector3(bx, a, ARCO_ALTO_FONDO), Vector3(bx, -a, ARCO_ALTO_FONDO),
		_tex_red, METROS_TILE_RED)
	_panel(Vector3(gx, -a, 0), Vector3(bx, -a, 0),
		Vector3(bx, -a, ARCO_ALTO_FONDO), Vector3(gx, -a, ARCO_ALTO),
		_tex_red, METROS_TILE_RED)
	_barra(Vector3(gx, -a, 0), Vector3(gx, -a, ARCO_ALTO))


func _arco_frente(lado: float) -> void:
	var gx: float = lado * ProyeccionPartido.MEDIO_LARGO
	var bx: float = gx + lado * ARCO_FONDO
	var a := ARCO_MEDIO_ANCHO
	_panel(Vector3(gx, a, 0), Vector3(bx, a, 0),
		Vector3(bx, a, ARCO_ALTO_FONDO), Vector3(gx, a, ARCO_ALTO),
		_tex_red, METROS_TILE_RED)
	_barra(Vector3(gx, a, 0), Vector3(gx, a, ARCO_ALTO))
	_barra(Vector3(gx, -a, ARCO_ALTO), Vector3(gx, a, ARCO_ALTO))


func _barra(a: Vector3, b: Vector3) -> void:
	_linea(a, b, Color("23383e"), 4.5, 0.24)
	_linea(a, b, COLOR_ARCO, 2.0, 0.12)


# ---------------------------------------------------------------------------
# Entidades
# ---------------------------------------------------------------------------

## Y-sort: se dibuja de fondo hacia adelante según la Y de simulación, así
## un jugador más cercano a la cámara tapa al que está detrás. Los arcos
## entran a la misma lista (ver _arco_fondo) en vez de dibujarse aparte,
## que es lo que les da profundidad real contra los jugadores y la pelota.
func _dibujar_entidades() -> void:
	var orden := entidades.duplicate()
	for lado in [-1.0, 1.0]:
		orden.append({"tipo": "arco_fondo", "lado": lado,
			"pos": Vector2(lado * ProyeccionPartido.MEDIO_LARGO, -ARCO_MEDIO_ANCHO)})
		orden.append({"tipo": "arco_frente", "lado": lado,
			"pos": Vector2(lado * ProyeccionPartido.MEDIO_LARGO, ARCO_MEDIO_ANCHO)})
	orden.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for ent in orden:
		if ent["tipo"] in ["jugador", "oficial", "pelota"]:
			_dibujar_sombra(ent)
	for ent in orden:
		match ent["tipo"]:
			"arco_fondo":
				var lado_fondo := float(ent["lado"])
				_ejecutar(_decorado("arco_fondo_%d" % int(lado_fondo), func(): _arco_fondo(lado_fondo)))
			"arco_frente":
				var lado_frente := float(ent["lado"])
				_ejecutar(_decorado("arco_frente_%d" % int(lado_frente), func(): _arco_frente(lado_frente)))
			_: _dibujar_cuerpo(ent)


## La sombra va SIEMPRE en el piso (z=0) aunque el cuerpo esté en el aire:
## es justamente la separación entre sombra y cuerpo la que comunica la
## altura.
func _dibujar_sombra(ent: Dictionary) -> void:
	var suelo := _p(ent["pos"].x, ent["pos"].y, 0.0)
	var escala: float = camara.px_por_metro / CamaraPartido.PX_POR_METRO_BASE
	var alto_z: float = float(ent.get("z", 0.0))
	# Más alto = sombra más chica y más tenue.
	var reduccion: float = clampf(1.0 - alto_z * 0.05, 0.45, 1.0)
	var ancho: float = (10.0 if ent["tipo"] == "pelota" else 19.0) * escala * reduccion
	var alto := ancho * 0.5
	draw_texture_rect(_tex_sombra,
		Rect2(suelo - Vector2(ancho, alto) * 0.5, Vector2(ancho, alto)), false,
		Color(1, 1, 1, reduccion))


func _dibujar_cuerpo(ent: Dictionary) -> void:
	var escala: float = camara.px_por_metro / CamaraPartido.PX_POR_METRO_BASE
	var punto := _p(ent["pos"].x, ent["pos"].y, float(ent.get("z", 0.0)))
	if ent["tipo"] == "pelota":
		punto += Vector2(ent.get("offset_px", Vector2.ZERO)) * escala
		if bool(ent.get("anclada", false)):
			punto = _p(ent["pos"].x, ent["pos"].y) + Vector2(ent["anclaje_px"]) * escala
		var d := 13.0 * escala
		var pelota := SpritesPartido.pelota(int(ent.get("giro", 0)))
		draw_texture_rect(pelota, Rect2(punto - Vector2(d, d) * 0.5, Vector2(d, d)), false)
		return

	var pose := str(ent.get("pose", SpritesPartido.QUIETO))
	var dir := int(ent.get("direccion", SpritesPartido.ABAJO))
	var accion := str(ent.get("accion", ""))
	var espejo := bool(ent.get("espejo", false)) if accion in ["vuela", "chilena"] else dir in [5, 6, 7]
	var indice_atlas := 24
	if MotorEspacial.es_accion_regate(accion):
		espejo = bool(ent.get("regate_espejo", false))
	var tex: Texture2D
	if accion == MotorEspacial.ACCION_PALOMITA:
		var frame := mini(SpritesPartido.CUADROS_PALOMITA - 1,
			int(clampf(float(ent.get("fase_animacion", 0.0)), 0.0, 0.999)
				* SpritesPartido.CUADROS_PALOMITA))
		tex = SpritesPartido.palomita_png(ent["color"], ent.get("color_short", Color.WHITE), frame, espejo,
			ent.get("color_pelo", SpritesPartido.PELO), int(ent.get("pelo", 0)), int(ent.get("numero", 0)))
	elif MotorEspacial.es_accion_regate(accion):
		var tipo_regate := MotorEspacial.tipo_regate_de_accion(accion)
		var cuadros_regate := SpritesPartido.cuadros_regate(tipo_regate)
		var frame_regate := mini(cuadros_regate - 1,
			int(clampf(float(ent.get("fase_animacion", 0.0)), 0.0, 0.999) * cuadros_regate))
		tex = SpritesPartido.regate_png(tipo_regate, frame_regate, espejo,
			ent["color"], ent.get("color_short", Color.TRANSPARENT),
			ent.get("color_pelo", SpritesPartido.PELO), int(ent.get("pelo", 0)),
			int(ent.get("numero", 0)))
	elif accion == MotorEspacial.ACCION_SAQUE_ARCO:
		var indice := AtlasJugadores.cuadro(accion,
			float(ent.get("fase_animacion", 0.0)), dir, false, true)
		indice_atlas = indice
		tex = AtlasJugadores.textura_saque_arco(indice, ent["color"],
			ent.get("color_short", Color.WHITE), ent.get("color_pelo", SpritesPartido.PELO),
			espejo, int(ent.get("numero", 0)), int(ent.get("pelo", 0)))
	else:
		var indice := AtlasJugadores.cuadro(accion, float(ent.get("fase_animacion", 0.0)), dir,
			pose in [SpritesPartido.CORRE_A, SpritesPartido.CORRE_B], bool(ent.get("arquero", false)))
		indice_atlas = indice
		tex = AtlasJugadores.textura(indice, ent["color"], ent.get("color_short", Color.WHITE),
			ent.get("color_pelo", SpritesPartido.PELO), espejo, int(ent.get("numero", 0)), int(ent.get("pelo", 0)))
	var lado := 64.0 * escala
	# Pivote com?n en los pies: no cambia con el ancho de una patada.
	# La bandera baja va detrás del cuerpo; así el palo nace de la mano
	# y no parece cruzado por delante del juez.
	if ent["tipo"] == "oficial" and str(ent.get("senal", "")) == "bandera_baja":
		_dibujar_utileria_oficial(ent, punto, escala, espejo, indice_atlas)
	draw_texture_rect(tex, Rect2((punto - Vector2(lado * 0.5, lado * 0.90625)).round(),
		Vector2(lado, lado)), false)
	if ent["tipo"] == "oficial" and str(ent.get("senal", "")) != "bandera_baja":
		_dibujar_utileria_oficial(ent, punto, escala, espejo, indice_atlas)


## Banderas, tarjeta y tablero en el mismo lenguaje pixelado del atlas. El
## cuerpo sigue siendo PNG; estas piezas informativas se dibujan nítidas para
## poder cambiar de estado y dorsales sin multiplicar hojas de sprites.
func _dibujar_utileria_oficial(ent: Dictionary, pie: Vector2, escala: float,
		espejo: bool, indice_atlas: int) -> void:
	# La mano y la bandera cambian junto con la orientación del PNG.
	var lado := -1.0 if espejo else 1.0
	var mano := pie + anclaje_bandera_px(indice_atlas, espejo) * escala
	match str(ent.get("senal", "")):
		"bandera_baja":
			_dibujar_bandera(mano, mano + Vector2(lado * 13, 14) * escala,
				escala, lado, true)
		"bandera_arriba":
			_dibujar_bandera(mano, mano + Vector2(0, -34) * escala, escala, lado)
		"bandera_horizontal":
			_dibujar_bandera(mano, mano + Vector2(lado * 30, 0) * escala, escala, lado)
		"tarjeta_amarilla":
			_dibujar_tarjeta_arbitro(pie, escala, COLOR_AMARILLA,
				float(ent.get("fase_senal", 1.0)))
		"tarjeta_roja":
			_dibujar_tarjeta_arbitro(pie, escala, COLOR_ROJA,
				float(ent.get("fase_senal", 1.0)))
		"silbato":
			var boca := pie + Vector2(8, -44) * escala
			draw_line(boca, boca + Vector2(7, 2) * escala, Color("d8dde2"), maxf(1.0, 2.0 * escala))
			draw_circle(boca + Vector2(8, 2) * escala, maxf(1.5, 2.4 * escala), Color("262d34"))
		"tablero":
			_dibujar_tablero(pie, escala, int(ent.get("numero_sale", 0)),
				int(ent.get("numero_entra", 0)))


static func anclaje_bandera_px(indice: int, espejo: bool) -> Vector2:
	var anclaje: Vector2 = MANO_BANDERA_PX.get(indice, MANO_BANDERA_PX[24])
	if espejo:
		anclaje.x = -anclaje.x
	return anclaje


func _dibujar_bandera(mano: Vector2, punta: Vector2, escala: float, lado: float,
		colgando: bool = false) -> void:
	var ancho_linea := maxf(1.0, 3.0 * escala)
	draw_line(mano, punta, Color("181b20"), ancho_linea + maxf(1.0, escala))
	draw_line(mano, punta, Color("d9c49a"), ancho_linea)
	var direccion := (punta - mano).normalized()
	var tela_ancho := 15.0 * escala
	var tela_alto := 11.0 * escala
	var origen := punta - direccion * (2.0 * escala)
	var eje_a: Vector2
	var eje_b: Vector2
	if colgando:
		# Con el palo hacia abajo, la tela queda sujeta a su tramo final y
		# cae hacia el suelo. Antes usaba la perpendicular del palo y parecía
		# ondear hacia arriba, contra la gravedad.
		eje_a = -direccion * tela_alto
		eje_b = Vector2.DOWN * tela_ancho
	else:
		var normal := Vector2(-direccion.y, direccion.x)
		if absf(normal.x) < 0.01:
			normal = Vector2.DOWN
		elif signf(normal.x) != signf(lado):
			normal = -normal
		eje_a = normal * tela_ancho
		eje_b = -direccion * tela_alto
	var puntos := PackedVector2Array([origen, origen + eje_a,
		origen + eje_a + eje_b, origen + eje_b])
	draw_colored_polygon(puntos, Color("17191d"))
	var margen := maxf(1.0, escala)
	var a := eje_a - eje_a.normalized() * margen * 2.0
	var b := eje_b - eje_b.normalized() * margen * 2.0
	var o := origen + eje_a.normalized() * margen + eje_b.normalized() * margen
	draw_colored_polygon(PackedVector2Array([o, o + a * 0.5, o + a * 0.5 + b * 0.5, o + b * 0.5]), Color("ffd326"))
	draw_colored_polygon(PackedVector2Array([o + a * 0.5, o + a, o + a + b * 0.5, o + a * 0.5 + b * 0.5]), Color("f06b24"))
	draw_colored_polygon(PackedVector2Array([o + b * 0.5, o + a * 0.5 + b * 0.5, o + a * 0.5 + b, o + b]), Color("f06b24"))
	draw_colored_polygon(PackedVector2Array([o + a * 0.5 + b * 0.5, o + a + b * 0.5, o + a + b, o + a * 0.5 + b]), Color("ffd326"))


func _dibujar_tarjeta_arbitro(pie: Vector2, escala: float, color: Color,
		fase: float) -> void:
	var tam := Vector2(9, 13) * escala
	var origen := origen_tarjeta_px(fase)
	var rect := Rect2(pie + origen * escala, tam)
	draw_rect(Rect2(rect.position + Vector2.ONE * maxf(1.0, escala), rect.size), Color(0, 0, 0, 0.55))
	draw_rect(rect, color)


static func origen_tarjeta_px(fase: float) -> Vector2:
	var subida := smoothstep(0.0, 1.0, clampf(fase, 0.0, 1.0))
	# Arriba, el borde inferior de la tarjeta se superpone con el puño del
	# cuadro 58. La posición vieja quedaba flotando sobre la mano.
	return Vector2(5.0, -43.0).lerp(Vector2(-9.0, -58.0), subida)


func _dibujar_tablero(pie: Vector2, escala: float, numero_sale: int, numero_entra: int) -> void:
	var centro := pie + Vector2(0, -70) * escala
	var rect := Rect2(centro - Vector2(23, 12) * escala, Vector2(46, 24) * escala)
	draw_rect(rect, Color("090c10"))
	draw_rect(rect.grow(-maxf(2.0, 2.0 * escala)), Color("20262b"))
	_dibujar_numero_tablero(Vector2(centro.x - 11.5 * escala, centro.y), numero_sale,
		Color("ff3138"), escala)
	_dibujar_numero_tablero(Vector2(centro.x + 11.5 * escala, centro.y), numero_entra,
		Color("35e35a"), escala)


func _dibujar_numero_tablero(centro: Vector2, numero: int, color: Color, escala: float) -> void:
	var texto := str(clampi(numero, 0, 99))
	var pixel := maxf(1.0, 1.45 * escala)
	var ancho := float(texto.length() * 4 - 1) * pixel
	var origen := centro - Vector2(ancho * 0.5, 2.5 * pixel)
	for i in range(texto.length()):
		var digito: Array = SpritesPartido.DIGITOS[int(texto[i])]
		for y in range(5):
			for x in range(3):
				if digito[y][x] == "#":
					draw_rect(Rect2(origen + Vector2(i * 4 + x, y) * pixel,
						Vector2.ONE * pixel), color)



const COLOR_AMARILLA := Color(0.98, 0.83, 0.16)
const COLOR_ROJA := Color(0.84, 0.16, 0.16)

func _dibujar_banderines() -> void:
	for x in [-ProyeccionPartido.MEDIO_LARGO, ProyeccionPartido.MEDIO_LARGO]:
		for y in [-ProyeccionPartido.MEDIO_ANCHO, ProyeccionPartido.MEDIO_ANCHO]:
			var pie := _p(x, y)
			var punta := _p(x, y, 1.45)
			draw_line(pie, punta, Color("23383e"), 3.0)
			draw_line(pie, punta, Color("f5e8b9"), 1.0)
			var vuelo := camara.px_por_metro * 0.48
			draw_colored_polygon(PackedVector2Array([punta, punta + Vector2(vuelo, 3), punta + Vector2(0, vuelo * 0.65)]), Color("eac35e"))


## Junta lo que dibujaría el decorado en comandos baratos de repetir:
## polígonos seguidos con la misma textura en UNA malla, y líneas seguidas
## del mismo color y grosor en UN draw_multiline. Respeta el orden: un
## cambio de textura o de tipo cierra el lote y abre otro.
class ConstructorDecorado:
	var comandos: Array = []
	var _tex: Texture2D = null
	var _vertices := PackedVector2Array()
	var _uvs := PackedVector2Array()
	var _colores := PackedColorArray()
	var _indices := PackedInt32Array()
	var _lineas: Dictionary = {}

	func cuadrilatero(puntos: Array, uvs: Array, color: Color, tex: Texture2D) -> void:
		_cerrar_lineas()
		if tex != _tex and not _vertices.is_empty():
			_cerrar_malla()
		_tex = tex
		var base := _vertices.size()
		for i in range(4):
			_vertices.append(puntos[i])
			_uvs.append(uvs[i] if not uvs.is_empty() else Vector2.ZERO)
			_colores.append(color)
		_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

	func linea(a: Vector2, b: Vector2, color: Color, min_px: float, factor: float) -> void:
		_cerrar_malla()
		if not _lineas.is_empty() and (_lineas["color"] != color
				or _lineas["min"] != min_px or _lineas["factor"] != factor):
			_cerrar_lineas()
		if _lineas.is_empty():
			_lineas = {"puntos": PackedVector2Array(), "color": color, "min": min_px, "factor": factor}
		var puntos: PackedVector2Array = _lineas["puntos"]
		puntos.append(a)
		puntos.append(b)
		_lineas["puntos"] = puntos

	func circulo(centro: Vector2, color: Color, min_px: float, factor: float, radio: float) -> void:
		_cerrar_malla()
		_cerrar_lineas()
		comandos.append({"centro": centro, "color": color, "min": min_px, "factor": factor, "radio": radio})

	func terminar() -> Array:
		_cerrar_malla()
		_cerrar_lineas()
		return comandos

	func _cerrar_lineas() -> void:
		if not _lineas.is_empty():
			comandos.append(_lineas)
			_lineas = {}

	func _cerrar_malla() -> void:
		if _vertices.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _vertices
		arrays[Mesh.ARRAY_TEX_UV] = _uvs
		arrays[Mesh.ARRAY_COLOR] = _colores
		arrays[Mesh.ARRAY_INDEX] = _indices
		var malla := ArrayMesh.new()
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		comandos.append({"malla": malla, "tex": _tex})
		_vertices = PackedVector2Array()
		_uvs = PackedVector2Array()
		_colores = PackedColorArray()
		_indices = PackedInt32Array()
		_tex = null
