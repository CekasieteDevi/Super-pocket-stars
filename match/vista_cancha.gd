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
		"claro": Color(0.55, 0.44, 0.28), "oscuro": Color(0.49, 0.39, 0.24),
		"linea": Color(0.88, 0.86, 0.80, 0.85), "aspereza": 0.055,
	},
	"regular": {
		"claro": Color(0.28, 0.50, 0.22), "oscuro": Color(0.24, 0.45, 0.19),
		"linea": Color(0.92, 0.94, 0.90, 0.9), "aspereza": 0.035,
	},
	"hibrido": {
		"claro": Color(0.19, 0.56, 0.24), "oscuro": Color(0.15, 0.50, 0.20),
		"linea": Color.WHITE, "aspereza": 0.018,
	},
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
## rectángulo dibujado en el aire.
const ARCO_MEDIO_ANCHO := 3.66
const ARCO_ALTO := 2.44
const ARCO_FONDO := 2.2
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

## Cada entidad: {"pos": Vector2 (metros), "z": float, "tipo": "jugador"/"pelota",
## "color": Color}. La vista las ordena por profundidad y las dibuja.
var entidades: Array = []

var _tex_sombra: ImageTexture
var _tex_pelota: ImageTexture
var _tex_publico: ImageTexture
var _tex_red: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Las texturas del decorado se dibujan con UV mayores a 1 (un tile por
	# cada pocos metros), así que sin repetición saldría una sola copia
	# estirada. Los sprites usan UV 0..1 y no se ven afectados.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_tex_sombra = SpritesPartido.sombra()
	_tex_pelota = SpritesPartido.pelota()
	_tex_publico = TexturasEstadio.publico()
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


func _p(x: float, y: float, z: float = 0.0) -> Vector2:
	return ProyeccionPartido.sim_a_pantalla(x, y, z, camara.centro, camara.px_por_metro, size * 0.5)


func _draw() -> void:
	var pal: Dictionary = PALETAS.get(estado_cancha, PALETAS["regular"])
	_dibujar_estadio()
	_dibujar_cesped(pal)
	_dibujar_lineas(pal)
	_dibujar_entidades()


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
	draw_colored_polygon(
		PackedVector2Array([
			_p(p0.x, p0.y, p0.z), _p(p1.x, p1.y, p1.z),
			_p(p2.x, p2.y, p2.z), _p(p3.x, p3.y, p3.z),
		]), tinte,
		PackedVector2Array([Vector2(0, 0), Vector2(u, 0), Vector2(u, v), Vector2(0, v)]),
		tex)


func _plano(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		_p(p0.x, p0.y, p0.z), _p(p1.x, p1.y, p1.z),
		_p(p2.x, p2.y, p2.z), _p(p3.x, p3.y, p3.z),
	]), c)


func _dibujar_estadio() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_CIELO)
	var L := ProyeccionPartido.MEDIO_LARGO
	var A := ProyeccionPartido.MEDIO_ANCHO

	# Pista: la banda entre la línea de cal y el muro.
	_plano(Vector3(-L - PISTA, -A - PISTA, 0), Vector3(L + PISTA, -A - PISTA, 0),
		Vector3(L + PISTA, A + PISTA, 0), Vector3(-L - PISTA, A + PISTA, 0), COLOR_PISTA)

	var xa := -L - PISTA - PROF_TRIBUNA
	var xb := L + PISTA + PROF_TRIBUNA
	var ya := -A - PISTA - PROF_TRIBUNA
	var yb := A + PISTA + PROF_TRIBUNA

	# 1. Tribuna de enfrente. Sube alejándose de la cancha, así que en
	# pantalla crece hacia arriba y hace de fondo del partido.
	_panel(Vector3(xa, -A - PISTA, 0), Vector3(xb, -A - PISTA, 0),
		Vector3(xb, ya, ALTO_TRIBUNA), Vector3(xa, ya, ALTO_TRIBUNA),
		_tex_publico, METROS_TILE_PUBLICO, TINTE_TRIBUNA)
	_plano(Vector3(xa, ya, ALTO_TRIBUNA), Vector3(xb, ya, ALTO_TRIBUNA),
		Vector3(xb, ya - 3.0, ALTO_TRIBUNA + 5.0), Vector3(xa, ya - 3.0, ALTO_TRIBUNA + 5.0),
		COLOR_TECHO)

	# 2. Cabeceras, detrás de cada arco.
	for lado in [-1.0, 1.0]:
		var x0: float = lado * (L + PISTA)
		var x1: float = lado * (L + PISTA + PROF_TRIBUNA)
		_panel(Vector3(x0, ya, 0), Vector3(x0, yb, 0),
			Vector3(x1, yb, ALTO_TRIBUNA), Vector3(x1, ya, ALTO_TRIBUNA),
			_tex_publico, METROS_TILE_PUBLICO, TINTE_TRIBUNA_LATERAL)

	# 3. Muro perimetral: la pared baja que separa la pista del público.
	# Va después de las tribunas porque está por delante de ellas.
	_plano(Vector3(xa, -A - PISTA, 0), Vector3(xb, -A - PISTA, 0),
		Vector3(xb, -A - PISTA, ALTO_MURO), Vector3(xa, -A - PISTA, ALTO_MURO), COLOR_MURO)
	for lado in [-1.0, 1.0]:
		var x0: float = lado * (L + PISTA)
		_plano(Vector3(x0, ya, 0), Vector3(x0, yb, 0),
			Vector3(x0, yb, ALTO_MURO), Vector3(x0, ya, ALTO_MURO), COLOR_MURO)

	# 4. Tribuna de este lado, la última porque es la más cercana.
	_panel(Vector3(xa, A + PISTA, 0), Vector3(xb, A + PISTA, 0),
		Vector3(xb, A + PISTA + PROF_TRIBUNA_CERCA, ALTO_TRIBUNA_CERCA),
		Vector3(xa, A + PISTA + PROF_TRIBUNA_CERCA, ALTO_TRIBUNA_CERCA),
		_tex_publico, METROS_TILE_PUBLICO, TINTE_TRIBUNA_CERCA)


## Las franjas siguen la proyección: son paralelogramos, no rectángulos
## verticales. Es lo que hace que la cancha se lea inclinada.
func _dibujar_cesped(pal: Dictionary) -> void:
	var tex := TexturasEstadio.cesped(pal["claro"], float(pal["aspereza"]))
	var paso := ProyeccionPartido.LARGO / float(FRANJAS)
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
	for i in range(FRANJAS):
		var xa := -ProyeccionPartido.MEDIO_LARGO + i * paso
		var xb := xa + paso
		_panel(Vector3(xa, y0, 0), Vector3(xb, y0, 0), Vector3(xb, y1, 0), Vector3(xa, y1, 0),
			tex, METROS_TILE_CESPED,
			Color.WHITE if i % 2 == 0 else tinte_oscuro)


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
	draw_line(_p(a.x, a.y, a.z), _p(b.x, b.y, b.z), COLOR_ARCO,
		maxf(2.5, camara.px_por_metro * 0.16))


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
		if ent["tipo"] == "jugador" or ent["tipo"] == "pelota":
			_dibujar_sombra(ent)
	for ent in orden:
		match ent["tipo"]:
			"arco_fondo": _arco_fondo(float(ent["lado"]))
			"arco_frente": _arco_frente(float(ent["lado"]))
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

	var pose := str(ent.get("pose", SpritesPartido.QUIETO))
	var tex: ImageTexture
	if pose == SpritesPartido.VUELA:
		tex = SpritesPartido.arquero_volando(ent["color"], bool(ent.get("espejo", false)))
	else:
		tex = SpritesPartido.jugador(ent["color"], int(ent.get("direccion", SpritesPartido.ABAJO)), pose)
	# El ancho se deriva del ancho del sprite y no es fijo: así el arquero
	# volando (que es más ancho que alto) se dibuja con píxeles del mismo
	# tamaño que los demás en vez de aplastado al ancho de un jugador.
	var ancho := ANCHO_SPRITE_PX * escala * (float(tex.get_width()) / float(SpritesPartido.ANCHO))
	var alto := ancho * (float(tex.get_height()) / float(tex.get_width()))
	# El sprite se apoya en el punto: los pies quedan en el piso.
	draw_texture_rect(tex, Rect2(punto - Vector2(ancho * 0.5, alto), Vector2(ancho, alto)), false)
