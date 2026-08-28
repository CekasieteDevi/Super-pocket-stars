class_name Tema
extends RefCounted

## El sistema visual del juego, en un solo lugar.
##
## Antes cada panel armaba sus botones y sus colores a mano, con hexadecimales
## sueltos repartidos por ui/main.gd: cambiar un color era tocar quince
## lugares y siempre quedaba uno viejo. Acá viven la paleta, la tipografía y
## los estilos, y la UI los hereda desde la raíz.
##
## Se construye en código y no como un .tres a propósito: así se lee en el
## diff de git, que es donde se revisa todo lo demás de este proyecto.
##
## Todo lo que hay acá es implementable con StyleBoxFlat: color de fondo,
## borde, radio y márgenes. Sin degradados ni imágenes.

# --- Paleta ----------------------------------------------------------------
# Verde-negro de cancha de noche, con los cuatro acentos que el juego YA
# usaba en la ficha del jugador. Se conservan con el mismo significado:
# ámbar avisa, verde está bien, rojo duele, celeste es algo que se puede tocar.
const FONDO := Color("#16201c")
const PANEL := Color("#1e2a25")
const PANEL_ALTO := Color("#26332d")
const BORDE := Color("#33443c")
const TEXTO := Color("#e8efe9")
const SUAVE := Color("#93a79b")

const AMBAR := Color("#d4a017")
const VERDE := Color("#27ae60")
const ROJO := Color("#c0392b")
const CELESTE := Color("#8ecae6")

## Verde intermedio para las barras de atributo (ya existía en la ficha).
const VERDE_TIBIO := Color("#7fb069")

# --- Tipografía ------------------------------------------------------------
const RUTA_ARCHIVO := "res://ui/fuentes/Archivo.ttf"
const RUTA_BARLOW := "res://ui/fuentes/Barlow-Regular.ttf"
const RUTA_BARLOW_MEDIA := "res://ui/fuentes/Barlow-Medium.ttf"
const RUTA_BARLOW_SEMI := "res://ui/fuentes/Barlow-SemiBold.ttf"

## Barlow para leer, Archivo para números y títulos. Archivo es una fuente
## VARIABLE: un solo archivo da todos los pesos vía FontVariation.
const TAM_BASE := 20
const TAM_CHICO := 16
const TAM_ETIQUETA := 14

# --- Medidas ---------------------------------------------------------------
## Alto mínimo de algo que se toca con el dedo. 52 px lógicos son ~8,6 mm en
## una pantalla de 320 dpi: por debajo de eso hay que apuntar.
const ALTO_TACTIL := 52
const RADIO := 9
const PADDING_BOTON := 12


static func _fuente(ruta: String) -> FontFile:
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta)


## Archivo con un peso concreto. La fuente es variable, así que el peso se
## pide por variación en vez de cargar un archivo por peso.
static func archivo(peso: int = 700) -> FontVariation:
	var base := _fuente(RUTA_ARCHIVO)
	if base == null:
		return null
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": peso}
	return v


static func _caja(fondo: Color, borde: Color = Color.TRANSPARENT, grosor: int = 0) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.corner_radius_top_left = RADIO
	caja.corner_radius_top_right = RADIO
	caja.corner_radius_bottom_left = RADIO
	caja.corner_radius_bottom_right = RADIO
	caja.content_margin_top = PADDING_BOTON
	caja.content_margin_bottom = PADDING_BOTON
	caja.content_margin_left = 16
	caja.content_margin_right = 16
	if grosor > 0:
		caja.border_width_top = grosor
		caja.border_width_bottom = grosor
		caja.border_width_left = grosor
		caja.border_width_right = grosor
		caja.border_color = borde
	return caja


## Construye el tema entero. Se aplica en la RAÍZ y de ahí lo hereda todo,
## incluida la UI que se crea después: los paneles se reconstruyen solos todo
## el tiempo y un tema en la raíz no se puede olvidar en una pantalla nueva.
static func construir() -> Theme:
	var tema := Theme.new()

	var cuerpo := _fuente(RUTA_BARLOW)
	if cuerpo != null:
		tema.default_font = cuerpo
	tema.default_font_size = TAM_BASE

	var semi := _fuente(RUTA_BARLOW_SEMI)

	# --- Botones -----------------------------------------------------------
	# Tres jerarquías, y una sola ámbar por pantalla: si todo resalta, nada
	# resalta. La ámbar se pide a mano con `primario()`.
	tema.set_stylebox("normal", "Button", _caja(PANEL_ALTO, BORDE, 1))
	tema.set_stylebox("hover", "Button", _caja(PANEL_ALTO.lightened(0.06), BORDE, 1))
	tema.set_stylebox("pressed", "Button", _caja(PANEL_ALTO.darkened(0.10), AMBAR, 1))
	tema.set_stylebox("disabled", "Button", _caja(PANEL, BORDE, 1))
	tema.set_stylebox("focus", "Button", _caja(Color.TRANSPARENT, AMBAR, 1))
	tema.set_color("font_color", "Button", TEXTO)
	tema.set_color("font_hover_color", "Button", TEXTO)
	tema.set_color("font_pressed_color", "Button", AMBAR)
	tema.set_color("font_disabled_color", "Button", SUAVE.darkened(0.25))
	if semi != null:
		tema.set_font("font", "Button", semi)
	tema.set_constant("h_separation", "Button", 8)

	for tipo in ["OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
			tema.set_stylebox(estado, tipo, tema.get_stylebox(estado, "Button"))
		tema.set_color("font_color", tipo, TEXTO)
		tema.set_color("font_disabled_color", tipo, SUAVE.darkened(0.25))
		if semi != null:
			tema.set_font("font", tipo, semi)

	# --- Campos ------------------------------------------------------------
	var campo := _caja(Color("#14201b"), BORDE, 1)
	tema.set_stylebox("normal", "LineEdit", campo)
	tema.set_stylebox("focus", "LineEdit", _caja(Color("#14201b"), AMBAR, 1))
	tema.set_color("font_color", "LineEdit", TEXTO)
	tema.set_color("caret_color", "LineEdit", AMBAR)
	tema.set_stylebox("panel", "PopupMenu", _caja(PANEL, BORDE, 1))
	tema.set_color("font_color", "PopupMenu", TEXTO)
	tema.set_color("font_hover_color", "PopupMenu", AMBAR)

	# --- Texto -------------------------------------------------------------
	tema.set_color("font_color", "Label", TEXTO)
	tema.set_color("default_color", "RichTextLabel", TEXTO)
	# Aire entre renglones: en las listas del plantel se TOCAN nombres, no
	# solo se leen.
	tema.set_constant("line_separation", "RichTextLabel", 8)
	tema.set_constant("line_spacing", "Label", 6)

	# --- Superficies -------------------------------------------------------
	var panel := _caja(PANEL, BORDE, 1)
	tema.set_stylebox("panel", "PanelContainer", panel)
	tema.set_stylebox("panel", "Panel", panel)
	tema.set_stylebox("panel", "AcceptDialog", _caja(PANEL, BORDE, 1))

	var fondo_scroll := StyleBoxFlat.new()
	fondo_scroll.bg_color = Color.TRANSPARENT
	tema.set_stylebox("panel", "ScrollContainer", fondo_scroll)

	tema.set_constant("separation", "VBoxContainer", 8)
	tema.set_constant("separation", "HBoxContainer", 8)
	tema.set_constant("h_separation", "GridContainer", 4)
	tema.set_constant("v_separation", "GridContainer", 4)

	return tema


## La acción principal de una pantalla: ámbar, y una sola por pantalla.
static func primario(boton: Button) -> Button:
	var caja := _caja(AMBAR)
	boton.add_theme_stylebox_override("normal", caja)
	boton.add_theme_stylebox_override("hover", _caja(AMBAR.lightened(0.08)))
	boton.add_theme_stylebox_override("pressed", _caja(AMBAR.darkened(0.12)))
	boton.add_theme_stylebox_override("disabled", _caja(AMBAR.darkened(0.45)))
	boton.add_theme_color_override("font_color", FONDO)
	boton.add_theme_color_override("font_hover_color", FONDO)
	boton.add_theme_color_override("font_pressed_color", FONDO)
	var titulo := archivo(700)
	if titulo != null:
		boton.add_theme_font_override("font", titulo)
	boton.custom_minimum_size.y = ALTO_TACTIL
	return boton


## Marca un botón como la sección/solapa ABIERTA. No se usa `disabled` para
## eso: gris apagado se lee como "no se puede tocar", que es lo contrario de
## "estás acá". Va fondo claro y una barra ámbar al costado.
static func seleccionado(boton: Button, activo: bool) -> Button:
	if not activo:
		for estado in ["normal", "hover", "pressed"]:
			boton.remove_theme_stylebox_override(estado)
		boton.remove_theme_color_override("font_color")
		return boton
	var caja := _caja(PANEL_ALTO.lightened(0.05), BORDE, 1)
	caja.border_width_left = 4
	caja.border_color = AMBAR
	for estado in ["normal", "hover", "pressed"]:
		boton.add_theme_stylebox_override(estado, caja)
	boton.add_theme_color_override("font_color", AMBAR)
	return boton


## Un número que se lee de un vistazo: Archivo, con cifras tabulares para
## que las columnas de la tabla no bailen.
static func numero(etiqueta: Label, tam: int = TAM_BASE, color: Color = TEXTO) -> Label:
	var f := archivo(700)
	if f != null:
		etiqueta.add_theme_font_override("font", f)
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


## Encabezado de sección: chico, espaciado y apagado.
static func etiqueta_seccion(texto: String) -> Label:
	var l := Label.new()
	l.text = texto.to_upper()
	l.add_theme_font_size_override("font_size", TAM_ETIQUETA)
	l.add_theme_color_override("font_color", SUAVE)
	return l
