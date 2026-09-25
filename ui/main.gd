extends Control

## Se precarga de forma explicita para que el editor no dependa del escaneo
## de class_name globales al abrir el proyecto.
const ESCUDO_CLUB_SCRIPT = preload("res://ui/escudo_club.gd")

## Fase 4 del roadmap (GDD §13): UI mínima — plantel/formación, tabla,
## resultado de partido. Fase 7: la tabla ahora es la de la división real
## del jugador dentro de la pirámide. Fase 9: paneles de Economía, Cantera
## y Noticias. Sin pixel art todavía (eso es la fase de pulido); acá solo
## tiene que andar y mostrar datos reales del motor.
##
## Los nodos se arman por código en vez de a mano en el editor: así el
## layout queda versionado y reproducible sin depender de una sesión
## interactiva del editor.

var paneles: Dictionary = {}  # nombre -> Control, para mostrar/ocultar en bloque

var contenedor_ficha: VBoxContainer
var ficha_jugador_id := -1
var ficha_publica_liga := false
## Panel desde el que se abrio la ficha. Permite volver al contexto correcto.
var ficha_origen: String = "plantel"
## De que club es el jugador de la ficha. null = uno propio. Si es ajeno,
## la ficha se dibuja en modo AJENO: sin lo que solo sabe un club de su
## propia gente y sin las habilidades dormidas (ver _refrescar_ficha).
var ficha_club: Team = null
var boton_volver_ficha: Button
var boton_investigar_ficha: Button
var fila_fichar_ficha: HBoxContainer
var boton_comprar_ficha: Button
var boton_prestamo_ficha: Button
var boton_carrera_ficha: Button
var ficha_ver_carrera := false
## La oferta desde la que se abrio la ficha. Al volver se reabre esa oferta:
## la ficha es para decidir, y la decision se toma en el modal.
var ficha_oferta_id := -1
var option_formacion: OptionButton
var barra_familiaridad: ProgressBar
var label_familiaridad: Label
var label_carga_efecto: Label
var contenedor_formacion: HBoxContainer
var contenedor_reservas: HBoxContainer
var etiqueta_suplentes: Label
var etiqueta_reservas: Label
## El jugador marcado esperando con quien cambiarse, -1 si ninguno (ver
## CuboJugador: se marca manteniendolo apretado).
var formacion_marcado: int = -1
## Cuanto se achican los cubos de las dos filas de abajo. En 1.0 desde
## que el cuerpo scrollea: ya no le sacan alto a la cancha.
const ESCALA_LISTAS := 1.0
var cancha_formacion: CanchaFormacion
var label_formacion_estado: Label
## Quienes no pueden jugar la proxima fecha, arriba de la cancha. Va
## aparte de label_formacion_estado porque ese lo pisan los mensajes de
## promover un juvenil, y una baja no se puede perder por eso.
var label_bajas: Label
## Jugador tocado primero en la pantalla de formacion, a la espera del
## segundo para intercambiarlos. -1 = nadie seleccionado.
var contenedor_tabla: VBoxContainer
var scroll_tabla: ScrollContainer
var label_tabla_leyenda: Label
var contenedor_ultimo_partido: VBoxContainer
var contenedor_lista_partidos: VBoxContainer
var contenedor_jugadores_liga: VBoxContainer
var contenedor_encabezado_jugadores: VBoxContainer
var botones_ranking: Dictionary = {}
var ranking_elegido: String = "goles"
## Cual de los partidos guardados se esta mirando (0 = el mas reciente).
var historial_elegido: int = 0
## En un solo lugar: estaba escrito a mano al construirlo y al terminar de
## simular, y bastaba tocar uno para que el boton cambiara de nombre solo.
const TEXTO_SIMULAR_TEMPORADA := "Simular resto de la temporada"
## El aviso mientras el motor corre el partido. El motor bloquea el hilo
## y la pantalla queda quieta un rato: sin aviso parece que se tranco.
## Antes era un modal que tapaba la pantalla; ahora es el texto del propio
## boton de Jugar, que molesta menos y dice lo mismo.
const TEXTO_CARGANDO_PARTIDO := "Cargando..."
## El boton de Jugar de la portada. Se guarda porque el que muestra el
## "Cargando..." es _jugar_el_partido_de_hoy, que corre lejos de donde se
## construye el boton.
var boton_jugar_partido: Button
var option_estilo: OptionButton
var option_cambios: OptionButton
var check_rotacion: CheckBox

const OPCIONES_CAMBIOS := ["equilibrado", "descanso", "rendimiento"]
const ETIQUETAS_CAMBIOS := {"equilibrado": "Equilibrado", "descanso": "Priorizar descanso", "rendimiento": "Priorizar rendimiento"}
var vista_partido: VistaPartido
var resumen_partido: CenterContainer
var contenedor_resumen: VBoxContainer
var capa_resumen_partido: CanvasLayer
var contenedor_economia: VBoxContainer
var lista_cantera: RichTextLabel
var contenedor_cantera_botones: VBoxContainer
var contenedor_noticias: VBoxContainer
var capa_resumen: CanvasLayer
var contenedor_resumen_temporada: VBoxContainer
var contenedor_vitrina: VBoxContainer
var contenedor_sponsors: VBoxContainer
var label_sponsors_estado: Label
var contenedor_copa: VBoxContainer
var label_copa_titulo: Label
var label_copa_camino: Label
var copa_elegida: String = "copa_interna"
var option_historia_division: OptionButton
var option_historia_club: OptionButton
var contenedor_historia_club: VBoxContainer
var historia_club_elegido: String = ""
var option_palmares: OptionButton
var contenedor_palmares: VBoxContainer
var palmares_elegido: String = ""
var noticias_solapa: String = "todas"
var botones_solapa_noticias: Dictionary = {}
var capa_modal_jugador: CanvasLayer
var capa_modal_roles: CanvasLayer
var boton_dorsal_ficha: Button
var capa_modal_dorsal: CanvasLayer
var contenedor_modal_dorsal: VBoxContainer
var modal_dorsal_id: int = -1
var capa_modal_alineacion: CanvasLayer
var contenedor_modal_alineacion: VBoxContainer
var contenedor_modal_roles: VBoxContainer
var contenedor_roles: GridContainer
var modal_rol_clave: String = ""
var contenedor_modal_jugador: VBoxContainer
var modal_jugador_id: int = -1
var label_modal_jugador_estado: String = ""
var label_mercado_estado: Label
var contenedor_libres_botones: VBoxContainer
var label_libres_estado: Label
var caja_filtros_libres: HBoxContainer
## Puesto que se esta mirando en Mercado > Libres. "TODOS" = sin filtro.
var filtro_libres: String = "TODOS"
## Cuantos agentes libres se listan de una. El pool junta los vencimientos
## de las diez divisiones: sin tope, la pantalla arma cientos de filas y
## tarda en abrir. Se muestran los de mejor media, que son los que se
## miran.
const MAXIMO_LIBRES := 40
var label_prestamos_estado: Label
var contenedor_instalaciones_botones: VBoxContainer
var label_instalaciones_estado: Label
var contenedor_seleccion: VBoxContainer
var label_cantera_mentor: Label
var label_partida_estado: Label
var boton_cargar_partida: Button
var boton_borrar_partida: Button
var capa_inicio: CanvasLayer
var menu_inicio: VBoxContainer
var formulario_inicio: VBoxContainer
var formulario_escudo: VBoxContainer
var campo_nombre_club: LineEdit
var campo_abreviacion: LineEdit
var fila_camiseta: HBoxContainer
var fila_short: HBoxContainer
var fila_camiseta_secundaria: HBoxContainer
var fila_short_secundario: HBoxContainer
var boton_comenzar: Button
var boton_crear_club: Button
var boton_cargar_inicio: Button
var label_inicio_estado: Label
var capa_changelog: Control
var color_camiseta_elegido := 0
var color_short_elegido := 8
var color_camiseta_secundaria_elegido := 1
var color_short_secundario_elegido := 7
var color_escudo_elegido := 0
var color_logo_elegido := 7
var escudo_forma_elegida := 0
var logo_forma_elegida := 0
var preview_escudo
var etiqueta_nombre_escudo: Label
var etiqueta_nombre_logo: Label
var etiqueta_color_escudo: Label
var etiqueta_color_logo: Label
var normalizando_abreviacion := false
var dialogo_borrar_partida: ConfirmationDialog
var boton_partida_nueva: Button
var dialogo_partida_nueva: ConfirmationDialog
var option_fps: OptionButton
var option_velocidad_partido: OptionButton
var option_tema: OptionButton

const OPCIONES_FPS := [30, 60, 120]
const OPCIONES_VELOCIDAD_PARTIDO := [1.0, 2.0, 4.0, 8.0, 16.0]
const OPCIONES_TEMA := ["oscuro", "claro"]
const RUTA_OPCIONES := "user://opciones.cfg"
var fps_elegido := 60
var velocidad_partido_elegida := 1.0
var tema_visual := "oscuro"
static var _recarga_por_tema := false
static var _seccion_antes_del_tema := "jugar"
static var _panel_antes_del_tema := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cargar_opciones()
	Engine.max_fps = fps_elegido
	Tema.aplicar_modo(tema_visual)

	# El sistema visual entero vive en ui/tema.gd y se hereda desde la raiz.
	theme = Tema.construir()

	# Fondo real del tema elegido. Antes la raiz era transparente y el color
	# dependia de que cada pantalla alcanzara a cubrir todo el viewport.
	var fondo_juego := ColorRect.new()
	fondo_juego.color = Tema.FONDO
	fondo_juego.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo_juego.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo_juego)

	# Margen exterior comun: evita que el riel, las barras y el contenido
	# queden pegados a cualquiera de los cuatro bordes de la pantalla.
	var margen_pantalla := MarginContainer.new()
	margen_pantalla.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "top", "right", "bottom"]:
		margen_pantalla.add_theme_constant_override(
				"margin_%s" % lado, Tema.MARGEN_PANTALLA)
	add_child(margen_pantalla)

	# Marco amarillo grueso: es el borde de la "consola" y separa el juego
	# del fondo del dispositivo, igual que en la propuesta aprobada.
	var marco_juego := PanelContainer.new()
	marco_juego.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marco_juego.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var estilo_marco := StyleBoxFlat.new()
	estilo_marco.bg_color = Tema.AMBAR
	estilo_marco.border_width_top = 3
	estilo_marco.border_width_bottom = 3
	estilo_marco.border_width_left = 3
	estilo_marco.border_width_right = 3
	estilo_marco.border_color = Tema.TINTA_OSCURA
	estilo_marco.corner_radius_top_left = 7
	estilo_marco.corner_radius_top_right = 7
	estilo_marco.corner_radius_bottom_left = 7
	estilo_marco.corner_radius_bottom_right = 7
	estilo_marco.content_margin_left = 7
	estilo_marco.content_margin_right = 7
	estilo_marco.content_margin_top = 7
	estilo_marco.content_margin_bottom = 7
	estilo_marco.shadow_color = Color(0.02, 0.04, 0.03, 0.75)
	estilo_marco.shadow_size = 3
	estilo_marco.shadow_offset = Vector2(5, 5)
	marco_juego.add_theme_stylebox_override("panel", estilo_marco)
	margen_pantalla.add_child(marco_juego)

	# Raiz apaisada: el riel de secciones al COSTADO y el contenido al lado.
	# Al costado y no abajo porque el alto (648 px logicos) es lo escaso en
	# apaisado, mientras que a lo ancho sobra.
	var raiz := HBoxContainer.new()
	raiz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raiz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco_juego.add_child(raiz)

	_construir_riel(raiz)

	# El contenido vive sobre una trama pixelada real. No es una captura ni
	# una imagen de muestra: se genera en memoria para ambos temas.
	var columna_marco := Control.new()
	columna_marco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna_marco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(columna_marco)
	var trama := TextureRect.new()
	trama.texture = _textura_trama_pixel()
	trama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trama.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	trama.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trama.stretch_mode = TextureRect.STRETCH_TILE
	trama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columna_marco.add_child(trama)

	var columna := VBoxContainer.new()
	columna.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columna_marco.add_child(columna)

	_construir_barra_contexto(columna)

	var margen_subsolapas := MarginContainer.new()
	margen_subsolapas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margen_subsolapas.add_theme_constant_override("margin_left", 24)
	margen_subsolapas.add_theme_constant_override("margin_right", 24)
	margen_subsolapas.add_theme_constant_override("margin_top", 8)
	margen_subsolapas.add_theme_constant_override("margin_bottom", 8)
	columna.add_child(margen_subsolapas)

	var sub_scroll := ScrollContainer.new()
	sub_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sub_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margen_subsolapas.add_child(sub_scroll)
	barra_subsolapas = HBoxContainer.new()
	sub_scroll.add_child(barra_subsolapas)

	var margen := MarginContainer.new()
	margen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for lado in ["left", "top", "right", "bottom"]:
		margen.add_theme_constant_override("margin_%s" % lado, 24)
	columna.add_child(margen)

	var contenedor := Control.new()
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margen.add_child(contenedor)

	_construir_panel_portada(contenedor)
	_construir_panel_plantel(contenedor)
	_construir_panel_tabla(contenedor)
	_construir_panel_jugadores_liga(contenedor)
	_construir_panel_historial(contenedor)
	_construir_panel_copas(contenedor)
	_construir_panel_vitrina(contenedor)
	_construir_panel_historia_clubes(contenedor)
	_construir_panel_palmares(contenedor)
	_construir_panel_laboratorio(contenedor)
	_construir_panel_sponsors(contenedor)
	_construir_panel_roles(contenedor)
	_construir_panel_entrenamiento(contenedor)
	_construir_panel_jugadas(contenedor)
	_construir_panel_partido_animado(contenedor)
	_construir_panel_economia(contenedor)
	_construir_panel_mercado(contenedor)
	_construir_panel_libres(contenedor)
	_construir_panel_traspaso(contenedor)
	_construir_panel_prestamos(contenedor)
	_construir_panel_instalaciones(contenedor)
	_construir_panel_renovaciones(contenedor)
	_construir_panel_cedidos(contenedor)
	_construir_panel_seleccion(contenedor)
	_construir_panel_cantera(contenedor)
	_construir_panel_noticias(contenedor)
	_construir_panel_partida_guardado(contenedor)
	_construir_panel_opciones(contenedor)
	_construir_panel_ficha(contenedor)
	_construir_panel_formacion(contenedor)
	_construir_dialogo_novedades()
	_construir_dialogo_vencimientos()
	_construir_dialogo_negociacion()
	_construir_dialogo_prestamo()
	_construir_dialogo_cesion()
	_construir_dialogo_investigador()

	# Al final, cuando ya esta todo construido: deja las listas
	# deslizables con el dedo (ver _ajustar_para_tactil).
	_ajustar_para_tactil(self)

	_construir_modal_jugador()
	_construir_dialogo_renovacion()
	_construir_modal_roles()
	_construir_modal_dorsal()
	_construir_modal_alineacion()
	_construir_pantalla_resumen()
	_construir_pantalla_inicio()
	_mostrar_seccion("jugar")
	_mostrar_inicio()
	if _recarga_por_tema:
		_recarga_por_tema = false
		_entrar_al_juego()
		_mostrar_seccion(_seccion_antes_del_tema, _panel_antes_del_tema)


func _textura_trama_pixel() -> ImageTexture:
	var imagen := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var base := Tema.FONDO
	var alterno := base.lightened(0.035) if tema_visual == "oscuro" else base.darkened(0.025)
	imagen.fill(base)
	imagen.fill_rect(Rect2i(0, 0, 16, 16), alterno)
	imagen.fill_rect(Rect2i(16, 16, 16, 16), alterno)
	return ImageTexture.create_from_image(imagen)


## La pantalla que se ve al abrir el juego. Tapa TODO —el riel incluido—
## porque hasta que no elegis partida no hay club que mirar: antes el
## juego abria directo en la portada de un club que nadie habia elegido.
##
## Vive como un CanvasLayer aparte y no como un panel mas: los paneles se
## muestran y se ocultan entre ellos, y esto tiene que quedar por encima
## de todo sin participar de ese baile.
func _construir_pantalla_inicio() -> void:
	capa_inicio = CanvasLayer.new()
	capa_inicio.layer = 10
	add_child(capa_inicio)

	var fondo := PanelContainer.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.FONDO
	fondo.add_theme_stylebox_override("panel", estilo)
	capa_inicio.add_child(fondo)

	var centro := CenterContainer.new()
	fondo.add_child(centro)
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(820, 0)
	caja.add_theme_constant_override("separation", 14)
	centro.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Super Pocket Stars"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tema.numero(titulo, 44, Tema.AMBAR)
	caja.add_child(titulo)

	# --- Menu -------------------------------------------------------------
	menu_inicio = VBoxContainer.new()
	menu_inicio.add_theme_constant_override("separation", 10)
	caja.add_child(menu_inicio)

	var btn_nueva := Button.new()
	btn_nueva.text = "Nueva partida"
	btn_nueva.custom_minimum_size = Vector2(0, 64)
	Tema.primario(btn_nueva)
	btn_nueva.pressed.connect(func():
		menu_inicio.visible = false
		formulario_inicio.visible = true
		formulario_escudo.visible = false
		_refrescar_colores_elegidos()
		campo_nombre_club.grab_focus())
	menu_inicio.add_child(btn_nueva)

	boton_cargar_inicio = Button.new()
	boton_cargar_inicio.text = "Cargar partida"
	boton_cargar_inicio.custom_minimum_size = Vector2(0, 64)
	boton_cargar_inicio.pressed.connect(_on_cargar_desde_inicio)
	menu_inicio.add_child(boton_cargar_inicio)

	label_inicio_estado = Label.new()
	label_inicio_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_inicio_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_inicio_estado.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_inicio_estado.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(label_inicio_estado)

	var label_version := Label.new()
	label_version.text = "Actualización v%s" % Changelog.version_actual()
	label_version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_version.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_version.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(label_version)

	var btn_changelog := Button.new()
	btn_changelog.text = "Changelog"
	btn_changelog.custom_minimum_size = Vector2(220, Tema.ALTO_TACTIL)
	btn_changelog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_changelog.pressed.connect(func(): capa_changelog.visible = true)
	caja.add_child(btn_changelog)

	_construir_changelog()

	# --- Formulario de club nuevo ----------------------------------------
	formulario_inicio = VBoxContainer.new()
	formulario_inicio.visible = false
	formulario_inicio.add_theme_constant_override("separation", 10)
	caja.add_child(formulario_inicio)

	formulario_inicio.add_child(Tema.etiqueta_seccion("Nombre del club"))
	campo_nombre_club = LineEdit.new()
	campo_nombre_club.placeholder_text = "Como se llama tu equipo"
	campo_nombre_club.max_length = 28
	campo_nombre_club.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	campo_nombre_club.text_changed.connect(func(_t): _validar_club_nuevo())
	formulario_inicio.add_child(campo_nombre_club)

	var fila_identidad := HBoxContainer.new()
	fila_identidad.add_theme_constant_override("separation", 10)
	formulario_inicio.add_child(fila_identidad)
	var caja_abreviacion := VBoxContainer.new()
	caja_abreviacion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_abreviacion.add_child(Tema.etiqueta_seccion("Abreviación del marcador"))
	campo_abreviacion = LineEdit.new()
	campo_abreviacion.placeholder_text = "ABC"
	campo_abreviacion.max_length = 3
	campo_abreviacion.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	campo_abreviacion.text_changed.connect(_normalizar_abreviacion)
	caja_abreviacion.add_child(campo_abreviacion)
	var ayuda_abreviacion := Label.new()
	ayuda_abreviacion.text = "Máximo 3 letras o números"
	ayuda_abreviacion.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	ayuda_abreviacion.add_theme_color_override("font_color", Tema.SUAVE)
	caja_abreviacion.add_child(ayuda_abreviacion)
	fila_identidad.add_child(caja_abreviacion)

	formulario_inicio.add_child(Tema.etiqueta_seccion("Colores del uniforme"))
	var cuadricula_colores := GridContainer.new()
	cuadricula_colores.columns = 2
	cuadricula_colores.add_theme_constant_override("h_separation", 18)
	cuadricula_colores.add_theme_constant_override("v_separation", 8)
	formulario_inicio.add_child(cuadricula_colores)
	var caja_principal := VBoxContainer.new()
	caja_principal.add_child(Tema.etiqueta_seccion("Uniforme principal"))
	caja_principal.add_child(_etiqueta_color("Camiseta"))
	fila_camiseta = _fila_de_colores("camiseta")
	caja_principal.add_child(fila_camiseta)
	caja_principal.add_child(_etiqueta_color("Pantalón"))
	fila_short = _fila_de_colores("short")
	caja_principal.add_child(fila_short)
	cuadricula_colores.add_child(caja_principal)
	var caja_secundaria := VBoxContainer.new()
	caja_secundaria.add_child(Tema.etiqueta_seccion("Uniforme secundario"))
	caja_secundaria.add_child(_etiqueta_color("Camiseta"))
	fila_camiseta_secundaria = _fila_de_colores("camiseta_secundaria")
	caja_secundaria.add_child(fila_camiseta_secundaria)
	caja_secundaria.add_child(_etiqueta_color("Pantalón"))
	fila_short_secundario = _fila_de_colores("short_secundario")
	caja_secundaria.add_child(fila_short_secundario)
	cuadricula_colores.add_child(caja_secundaria)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 10)
	formulario_inicio.add_child(acciones)

	var btn_volver := Button.new()
	btn_volver.text = "Volver"
	btn_volver.custom_minimum_size = Vector2(140, Tema.ALTO_TACTIL)
	btn_volver.pressed.connect(func():
		formulario_inicio.visible = false
		menu_inicio.visible = true
		_refrescar_inicio())
	acciones.add_child(btn_volver)

	boton_comenzar = Button.new()
	boton_comenzar.text = "Siguiente: escudo"
	boton_comenzar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_comenzar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	Tema.primario(boton_comenzar)
	boton_comenzar.pressed.connect(_mostrar_formulario_escudo)
	acciones.add_child(boton_comenzar)

	# --- Segunda pantalla: escudo y logo ---------------------------------
	formulario_escudo = VBoxContainer.new()
	formulario_escudo.visible = false
	formulario_escudo.add_theme_constant_override("separation", 8)
	caja.add_child(formulario_escudo)
	formulario_escudo.add_child(Tema.etiqueta_seccion("Escudo del club  ·  paso 2 de 2"))
	var ayuda_escudo := Label.new()
	ayuda_escudo.text = "Elegí una forma de escudo, un logo y sus colores."
	ayuda_escudo.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	ayuda_escudo.add_theme_color_override("font_color", Tema.SUAVE)
	formulario_escudo.add_child(ayuda_escudo)

	var fila_navegacion_escudo := HBoxContainer.new()
	fila_navegacion_escudo.add_theme_constant_override("separation", 8)
	formulario_escudo.add_child(fila_navegacion_escudo)
	fila_navegacion_escudo.add_child(_boton_flecha("‹", func(): _cambiar_escudo(-1)))
	etiqueta_nombre_escudo = Label.new()
	etiqueta_nombre_escudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta_nombre_escudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tema.numero(etiqueta_nombre_escudo, Tema.TAM_BASE, Tema.AMBAR)
	fila_navegacion_escudo.add_child(etiqueta_nombre_escudo)
	fila_navegacion_escudo.add_child(_boton_flecha("›", func(): _cambiar_escudo(1)))

	preview_escudo = ESCUDO_CLUB_SCRIPT.new()
	preview_escudo.custom_minimum_size = Vector2(0, 190)
	preview_escudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formulario_escudo.add_child(preview_escudo)

	var fila_navegacion_logo := HBoxContainer.new()
	fila_navegacion_logo.add_theme_constant_override("separation", 8)
	formulario_escudo.add_child(fila_navegacion_logo)
	fila_navegacion_logo.add_child(_boton_flecha("‹", func(): _cambiar_logo(-1)))
	etiqueta_nombre_logo = Label.new()
	etiqueta_nombre_logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta_nombre_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tema.numero(etiqueta_nombre_logo, Tema.TAM_BASE, Tema.AMBAR)
	fila_navegacion_logo.add_child(etiqueta_nombre_logo)
	fila_navegacion_logo.add_child(_boton_flecha("›", func(): _cambiar_logo(1)))

	var colores_identidad := GridContainer.new()
	colores_identidad.columns = 2
	colores_identidad.add_theme_constant_override("h_separation", 18)
	formulario_escudo.add_child(colores_identidad)
	var colores_escudo := VBoxContainer.new()
	etiqueta_color_escudo = _etiqueta_color("Color del escudo")
	colores_escudo.add_child(etiqueta_color_escudo)
	colores_escudo.add_child(_fila_de_colores("escudo"))
	colores_identidad.add_child(colores_escudo)
	var colores_logo := VBoxContainer.new()
	etiqueta_color_logo = _etiqueta_color("Color del logo · tocá un color")
	colores_logo.add_child(etiqueta_color_logo)
	colores_logo.add_child(_fila_de_colores("logo"))
	colores_identidad.add_child(colores_logo)

	var acciones_escudo := HBoxContainer.new()
	formulario_escudo.add_child(acciones_escudo)
	var volver_escudo := Button.new()
	volver_escudo.text = "Volver"
	volver_escudo.custom_minimum_size = Vector2(140, Tema.ALTO_TACTIL)
	volver_escudo.pressed.connect(_volver_a_colores)
	acciones_escudo.add_child(volver_escudo)
	boton_crear_club = Button.new()
	boton_crear_club.text = "Crear club"
	boton_crear_club.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_crear_club.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	Tema.primario(boton_crear_club)
	boton_crear_club.pressed.connect(_on_comenzar_partida)
	acciones_escudo.add_child(boton_crear_club)
	_refrescar_preview_escudo()


## Los diez colores como botones cuadrados. Se marca el elegido con un
## borde ambar: sobre una fila de colores, cualquier otra señal (un tilde,
## una sombra) se pierde contra el propio color del boton.
func _fila_de_colores(tipo: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	for i in range(ColoresClub.PALETA.size()):
		var c: Color = ColoresClub.PALETA[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(34, 34)
		b.tooltip_text = ColoresClub.NOMBRES[i]
		_pintar_muestra(b, c, false)
		var idx := i
		b.pressed.connect(func(): _seleccionar_color(tipo, idx))
		fila.add_child(b)
	return fila


func _etiqueta_color(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	l.add_theme_color_override("font_color", Tema.SUAVE)
	return l


func _boton_flecha(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(52, Tema.ALTO_TACTIL)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(accion)
	return b


func _seleccionar_color(tipo: String, idx: int) -> void:
	match tipo:
		"camiseta": color_camiseta_elegido = idx
		"short": color_short_elegido = idx
		"camiseta_secundaria": color_camiseta_secundaria_elegido = idx
		"short_secundario": color_short_secundario_elegido = idx
		"escudo": color_escudo_elegido = idx
		"logo": color_logo_elegido = idx
	_refrescar_colores_elegidos()
	_refrescar_preview_escudo()


func _pintar_muestra(boton: Button, color: Color, elegido: bool) -> void:
	for estado in ["normal", "hover", "pressed", "focus"]:
		var caja := StyleBoxFlat.new()
		caja.bg_color = color
		caja.corner_radius_top_left = 8
		caja.corner_radius_top_right = 8
		caja.corner_radius_bottom_left = 8
		caja.corner_radius_bottom_right = 8
		if elegido:
			caja.border_width_top = 3
			caja.border_width_bottom = 3
			caja.border_width_left = 3
			caja.border_width_right = 3
			caja.border_color = Tema.AMBAR
		boton.add_theme_stylebox_override(estado, caja)


func _refrescar_colores_elegidos() -> void:
	_refrescar_fila_color(fila_camiseta, color_camiseta_elegido)
	_refrescar_fila_color(fila_short, color_short_elegido)
	_refrescar_fila_color(fila_camiseta_secundaria, color_camiseta_secundaria_elegido)
	_refrescar_fila_color(fila_short_secundario, color_short_secundario_elegido)
	if etiqueta_color_escudo != null:
		etiqueta_color_escudo.text = "Color del escudo · %s" % ColoresClub.NOMBRES[color_escudo_elegido]
	if etiqueta_color_logo != null:
		etiqueta_color_logo.text = "Color del logo · %s" % ColoresClub.NOMBRES[color_logo_elegido]
	if formulario_escudo != null:
		for fila in formulario_escudo.find_children("*", "HBoxContainer", true, false):
			if fila.get_child_count() != ColoresClub.PALETA.size():
				continue
			var padre := fila.get_parent()
			var titulo := str(padre.get_child(0).text) if padre.get_child_count() > 0 else ""
			_refrescar_fila_color(fila, color_escudo_elegido if titulo == "Color del escudo" else color_logo_elegido)
	_validar_club_nuevo()


func _refrescar_fila_color(fila: HBoxContainer, elegido: int) -> void:
	if fila == null:
		return
	for i in range(fila.get_child_count()):
		_pintar_muestra(fila.get_child(i), ColoresClub.PALETA[i], i == elegido)


func _normalizar_abreviacion(_texto: String) -> void:
	if normalizando_abreviacion or campo_abreviacion == null:
		return
	normalizando_abreviacion = true
	var posicion_cursor := campo_abreviacion.caret_column
	var limpio := ""
	var texto_mayuscula := campo_abreviacion.text.to_upper()
	for indice in range(texto_mayuscula.length()):
		var caracter := texto_mayuscula.substr(indice, 1)
		var codigo := caracter.unicode_at(0)
		if (codigo >= 65 and codigo <= 90) or (codigo >= 48 and codigo <= 57):
			limpio += caracter
			if limpio.length() == 3:
				break
	if campo_abreviacion.text != limpio:
		campo_abreviacion.text = limpio
		campo_abreviacion.caret_column = mini(posicion_cursor, limpio.length())
	normalizando_abreviacion = false
	_validar_club_nuevo()


func _cambiar_escudo(delta: int) -> void:
	escudo_forma_elegida = posmod(escudo_forma_elegida + delta, ESCUDO_CLUB_SCRIPT.NOMBRES_ESCUDOS.size())
	_refrescar_preview_escudo()


func _cambiar_logo(delta: int) -> void:
	logo_forma_elegida = posmod(logo_forma_elegida + delta, ESCUDO_CLUB_SCRIPT.NOMBRES_LOGOS.size())
	_refrescar_preview_escudo()


func _refrescar_preview_escudo() -> void:
	if preview_escudo == null:
		return
	preview_escudo.configurar(escudo_forma_elegida, logo_forma_elegida,
		ColoresClub.PALETA[color_escudo_elegido], ColoresClub.PALETA[color_logo_elegido])
	if etiqueta_nombre_escudo != null:
		etiqueta_nombre_escudo.text = "Escudo  ·  %s" % ESCUDO_CLUB_SCRIPT.NOMBRES_ESCUDOS[escudo_forma_elegida]
	if etiqueta_nombre_logo != null:
		etiqueta_nombre_logo.text = "Logo  ·  %s" % ESCUDO_CLUB_SCRIPT.NOMBRES_LOGOS[logo_forma_elegida]


func _mostrar_formulario_escudo() -> void:
	_validar_club_nuevo()
	if boton_comenzar.disabled:
		return
	formulario_inicio.visible = false
	formulario_escudo.visible = true
	label_inicio_estado.text = ""
	_refrescar_preview_escudo()


func _volver_a_colores() -> void:
	formulario_escudo.visible = false
	formulario_inicio.visible = true
	label_inicio_estado.text = ""
	_refrescar_colores_elegidos()


func _validar_club_nuevo() -> void:
	if campo_nombre_club == null or boton_comenzar == null:
		return
	var nombre := campo_nombre_club.text.strip_edges()
	var motivo := ""
	if nombre == "":
		motivo = "Poné el nombre de tu club."
	elif campo_abreviacion == null or campo_abreviacion.text.strip_edges() == "":
		motivo = "Poné una abreviación para el marcador."
	boton_comenzar.disabled = motivo != ""
	if boton_crear_club != null:
		boton_crear_club.disabled = motivo != ""
	label_inicio_estado.text = motivo


## Lista de data/changelog.json encima de la pantalla de inicio. Va
## dentro de capa_inicio porque esa capa tapa a todas las demás.
func _construir_changelog() -> void:
	capa_changelog = PanelContainer.new()
	capa_changelog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa_changelog.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.65)
	capa_changelog.add_theme_stylebox_override("panel", estilo)
	capa_inicio.add_child(capa_changelog)

	var centro := CenterContainer.new()
	capa_changelog.add_child(centro)
	var tarjeta := Componentes.tarjeta()
	tarjeta.custom_minimum_size = Vector2(640, 560)
	centro.add_child(tarjeta)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	tarjeta.add_child(caja)

	var titulo := Label.new()
	titulo.text = "Changelog"
	Tema.numero(titulo, 26, Tema.TEXTO)
	caja.add_child(titulo)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	scroll.add_child(lista)

	for e in Changelog.cargar():
		var version := Label.new()
		version.text = "v%s · %s" % [str(e["version"]), str(e.get("fecha", ""))]
		version.add_theme_color_override("font_color", Tema.AMBAR)
		lista.add_child(version)
		lista.add_child(_texto_suave(str(e["cambio"])))

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(func(): capa_changelog.visible = false)
	caja.add_child(cerrar)


func _mostrar_inicio() -> void:
	capa_inicio.visible = true
	menu_inicio.visible = true
	formulario_inicio.visible = false
	formulario_escudo.visible = false
	_refrescar_inicio()


func _refrescar_inicio() -> void:
	var hay := GameState.hay_partida_guardada()
	boton_cargar_inicio.disabled = not hay
	if hay:
		var info := GameState.info_partida_guardada()
		label_inicio_estado.text = "Hay una partida guardada del %s." % str(info.get("cuando", "?"))
	else:
		label_inicio_estado.text = "Todavía no hay ninguna partida guardada."


func _on_cargar_desde_inicio() -> void:
	if not GameState.cargar_partida():
		label_inicio_estado.text = "No se pudo cargar la partida (archivo corrupto)."
		return
	_entrar_al_juego()


func _on_comenzar_partida() -> void:
	_validar_club_nuevo()
	if boton_crear_club != null and boton_crear_club.disabled:
		return
	GameState.partida_nueva(-1, campo_nombre_club.text.strip_edges(),
		ColoresClub.PALETA[color_camiseta_elegido],
		ColoresClub.PALETA[color_short_elegido],
		campo_abreviacion.text.strip_edges().to_upper(),
		ColoresClub.PALETA[color_camiseta_secundaria_elegido],
		ColoresClub.PALETA[color_short_secundario_elegido],
		escudo_forma_elegida, logo_forma_elegida,
		ColoresClub.PALETA[color_escudo_elegido],
		ColoresClub.PALETA[color_logo_elegido])
	_entrar_al_juego()


## Sale de la pantalla de inicio hacia el juego, con todo repintado: lo
## que la UI tuviera cargado es de otro mundo o de ninguno.
func _entrar_al_juego() -> void:
	plantel_elegido = -1
	ficha_jugador_id = -1
	resultados_mercado = []
	filtros_mercado = BusquedaMercado.filtros_vacios()
	_refrescar_historial_partidos()
	_refrescar_formacion()
	_refrescar_plantel()
	_refrescar_tabla()
	_refrescar_economia()
	_refrescar_cantera()
	_refrescar_noticias()
	_refrescar_instalaciones()
	_refrescar_renovaciones()
	_refrescar_partida_guardado()
	capa_inicio.visible = false
	_mostrar_seccion("jugar")
	# Si el cierre de temporada dejo un aviso sin leer, aparece al entrar:
	# el cartel se borra al aceptarlo, no al cerrar el juego.
	_mostrar_vencimientos_si_hay()


## Fix 10: nombre y apellido del jugador, para las listas de la UI.
func _nombre_jugador(j: Dictionary) -> String:
	return "%s %s" % [j.get("nombre", "?"), j.get("apellido", "")]


## §5: muestra todas las habilidades con una estrella por nivel.
## Las dormidas aparecen atenuadas en jugadores propios; en jugadores ajenos
## directamente no se muestran.
func _tag_habilidad(j: Dictionary, ajeno: bool = false) -> String:
	var habilidades: Array = BusquedaMercado.habilidades_visibles(j, ajeno)
	if habilidades.is_empty():
		return ""
	var etiquetas := []
	for h in habilidades:
		var estrellas := "★".repeat(int(h.get("nivel", 1)))
		if Habilidades.tiene_manifestada(j, str(h.get("nombre", ""))):
			etiquetas.append("%s %s" % [h["nombre"], estrellas])
		else:
			etiquetas.append("%s %s, dormida" % [h["nombre"], estrellas])
	return "  [%s]" % ", ".join(etiquetas)


func _ocultar_todos() -> void:
	for panel in paneles.values():
		panel.visible = false


## §14: plantel de 25 — 11 titulares + 7 banco (se muestran acá) + cantera
## (pestaña aparte). "Subir a titular" es la contraparte manual de
## Team.promover_a_titular(): la IA lo hace sola (Liga._procesar_cantera),
## el jugador humano lo decide desde acá.
## §UI: el plantel en dos columnas — la lista a la izquierda y la ficha del
## elegido a la derecha.
##
## Antes la ficha era una PANTALLA aparte: para comparar dos jugadores
## había que entrar, volver, entrar de nuevo, y al volver se perdía dónde
## estabas en la lista. En apaisado hay ancho de sobra para tenerla al lado.
##
## Y la lista deja de ser un RichTextLabel con enlaces BBCode: eran líneas
## de 23 px imposibles de acertar con el dedo, y el nombre era lo único
## tocable de toda la fila.
var plantel_elegido: int = -1
var contenedor_lista_plantel: VBoxContainer
var contenedor_ficha_lateral: VBoxContainer


func _construir_panel_plantel(padre: Control) -> void:
	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padre.add_child(raiz)
	paneles["plantel"] = raiz

	var panel := HBoxContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raiz.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_lista_plantel = VBoxContainer.new()
	contenedor_lista_plantel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_lista_plantel)

	var lateral := ScrollContainer.new()
	# Sin scroll de costado: con un valor de ocho cifras la ficha pedia mas
	# de 388 px y quedaba cortada a la derecha. Asi la columna se ensancha.
	lateral.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lateral.custom_minimum_size = Vector2(388, 0)
	lateral.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(lateral)

	contenedor_ficha_lateral = VBoxContainer.new()
	contenedor_ficha_lateral.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lateral.add_child(contenedor_ficha_lateral)

	_refrescar_plantel()


func _refrescar_plantel() -> void:
	if contenedor_lista_plantel == null:
		return
	for hijo in contenedor_lista_plantel.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador

	# Si no elegiste a nadie todavia, se muestra el capitan: abrir en vacio
	# desperdicia media pantalla.
	if plantel_elegido == -1 or _buscar_jugador_por_id(equipo, plantel_elegido).is_empty():
		plantel_elegido = equipo.capitan_id if equipo.capitan_id != -1 else int(equipo.jugadores[0]["id"])

	contenedor_lista_plantel.add_child(Tema.etiqueta_seccion(
		"Titulares (%d)  ·  %s" % [equipo.jugadores.size(), equipo.formacion]))
	for i in range(equipo.jugadores.size()):
		contenedor_lista_plantel.add_child(_fila_jugador(equipo, equipo.jugadores[i], i % 2 == 0, false))

	contenedor_lista_plantel.add_child(Tema.etiqueta_seccion(
		"Banco (%d de %d)" % [equipo.banco.size(), Team.max_suplentes()]))
	for i in range(equipo.banco.size()):
		contenedor_lista_plantel.add_child(_fila_jugador(equipo, equipo.banco[i], i % 2 == 0, true))

	if not equipo.reservas.is_empty():
		contenedor_lista_plantel.add_child(Tema.etiqueta_seccion(
			"Reservas (%d)  ·  no van al partido" % equipo.reservas.size()))
		for i in range(equipo.reservas.size()):
			contenedor_lista_plantel.add_child(
				_fila_jugador(equipo, equipo.reservas[i], i % 2 == 0, true))

	_refrescar_ficha_lateral()


## Alto de una fila del plantel. Con Tema.ALTO_TACTIL (52) y el margen
## de la fila cada jugador ocupaba 64 px: titulares, banco y reservas
## juntos pasaban las cuatro pantallas de scroll. 36 px sigue siendo un
## blanco comodo porque toda la fila es tocable, no solo el nombre.
const ALTO_FILA_PLANTEL := 44


## Una fila del plantel. TODA la fila es tocable, no solo el nombre.
func _fila_jugador(equipo: Team, j: Dictionary, par: bool, es_banco: bool) -> Control:
	var id := int(j["id"])
	var elegido := id == plantel_elegido
	var fila := Componentes.fila(par or elegido)
	var estilo: StyleBoxFlat = fila.get_theme_stylebox("panel")
	estilo.content_margin_top = 1
	estilo.content_margin_bottom = 1
	if elegido:
		estilo.bg_color = Tema.PANEL_ALTO
		estilo.border_width_left = 4
		estilo.border_color = Tema.AMBAR
	var dentro := Componentes.contenido(fila)

	var caja_pos := CenterContainer.new()
	caja_pos.custom_minimum_size = Vector2(56, 0)
	var color_pos := Color("#4a2a28") if equipo.esta_lesionado(id) else Color("#2f4a3c")
	caja_pos.add_child(Componentes.chip(str(j["posicion"]), color_pos))
	dentro.add_child(caja_pos)

	var btn := Button.new()
	btn.text = _nombre_jugador(j)
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.tooltip_text = btn.text
	_compactar_boton(btn)
	btn.pressed.connect(func():
		plantel_elegido = id
		_refrescar_plantel()
	)
	dentro.add_child(btn)

	if id == equipo.capitan_id:
		dentro.add_child(Componentes.chip("C", Tema.AMBAR, Tema.TINTA_OSCURA))

	dentro.add_child(Componentes.celda_numero("%.1f" % float(j["media"]), 62))
	dentro.add_child(Componentes.celda("→%d" % int(j["potencial"]), 52, Tema.SUAVE))

	# El valor, en la lista y no solo en la ficha: comparar lo que te
	# ofrecen por uno contra lo que valen los demas es la decision que se
	# toma en esta pantalla.
	dentro.add_child(Componentes.celda_numero(
		Economia.formato_dinero(ValorJugador.calcular(
			j, equipo.animo.get(id, 50.0), equipo.contratos.get(id, 3))),
		Componentes.COL_VALOR, Tema.VERDE, HORIZONTAL_ALIGNMENT_RIGHT,
		Tema.TAM_BASE))

	# Estado: lo unico que hace falta saber de un vistazo al armar el equipo.
	# Vacio cuando esta disponible: "Listo" en once filas era ruido que
	# tapaba a los pocos que de verdad no pueden jugar.
	var estado := ""
	var color := Tema.ROJO
	if equipo.esta_lesionado(id):
		var les: Dictionary = equipo.lesiones[id]
		estado = "%d d" % int(les["dias_restantes"])
	elif int(equipo.suspendidos.get(id, 0)) > 0:
		estado = "Susp."
	dentro.add_child(Componentes.celda(estado, 54, color))

	# Ficha y no "Subir": cambiar jugadores de lugar se hace arrastrando en
	# Formacion, que es donde se ve la cancha. Tener las dos formas en dos
	# pantallas distintas confundia mas de lo que ayudaba.
	var btn_ficha := Button.new()
	btn_ficha.text = "Ficha"
	btn_ficha.custom_minimum_size = Vector2(72, 0)
	_compactar_boton(btn_ficha)
	btn_ficha.pressed.connect(func(): _mostrar_ficha(id))
	dentro.add_child(btn_ficha)
	return fila


## Baja el boton al alto de la fila. El margen de 12 px arriba y abajo que
## pone el tema (Tema.PADDING_BOTON) es lo que estiraba la fila: el alto
## minimo solo no alcanza, porque el boton nunca baja de su contenido.
func _compactar_boton(boton: Button) -> void:
	boton.custom_minimum_size.y = ALTO_FILA_PLANTEL
	boton.add_theme_font_size_override("font_size", Tema.TAM_BASE)
	# Del tema de la pantalla y no de boton.get_theme_stylebox: el boton
	# todavia no esta en el arbol y devolveria el tema por defecto de Godot.
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		if not theme.has_stylebox(estado, "Button"):
			continue
		var caja: StyleBox = theme.get_stylebox(estado, "Button")
		caja = caja.duplicate()
		caja.content_margin_top = 2
		caja.content_margin_bottom = 2
		boton.add_theme_stylebox_override(estado, caja)


func _on_promover_a_titular(jugador_id: int) -> void:
	GameState.equipo_jugador.promover_a_titular(jugador_id)
	_refrescar_plantel()


## La ficha del elegido, al costado. Muestra lo que hace falta para
## DECIDIR: en qué es fuerte, cuánto le queda por crecer y cómo está.
## Los 25 atributos completos siguen estando en la ficha entera.
func _refrescar_ficha_lateral() -> void:
	for hijo in contenedor_ficha_lateral.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var j := _buscar_jugador_por_id(equipo, plantel_elegido)
	if j.is_empty():
		return

	var tarjeta := Componentes.tarjeta()
	contenedor_ficha_lateral.add_child(tarjeta)
	var caja := VBoxContainer.new()
	tarjeta.add_child(caja)

	# Nombre y datos a la izquierda, retrato a la derecha. El retrato es
	# alto: si fuera hijo directo de la caja empujaria todo hacia abajo y
	# el boton del final quedaria fuera de la pantalla.
	var encabezado := HBoxContainer.new()
	caja.add_child(encabezado)
	var datos := VBoxContainer.new()
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	encabezado.add_child(datos)
	encabezado.add_child(_retrato_jugador(equipo, j))

	var titulo := Label.new()
	titulo.text = _nombre_jugador(j)
	Tema.numero(titulo, 24)
	datos.add_child(titulo)

	var sub := Label.new()
	sub.text = "%s  ·  %d años  ·  %s" % [j["posicion"], int(j["edad"]), j["genetica_tier"]]
	sub.add_theme_color_override("font_color", Tema.SUAVE)
	datos.add_child(sub)

	var rasgos: Dictionary = j.get("personalidades", {})
	if not rasgos.is_empty():
		var fila_rasgos := HBoxContainer.new()
		datos.add_child(fila_rasgos)
		if str(rasgos.get("positiva", "")) != "":
			fila_rasgos.add_child(Componentes.chip(
				str(rasgos["positiva"]), Color("#23402f"), Color("#7fd6a0")))
		if str(rasgos.get("negativa", "")) != "":
			fila_rasgos.add_child(Componentes.chip(
				str(rasgos["negativa"]), Color("#3f2523"), Color("#e29d95")))
	var tag := _tag_habilidad(j)
	if tag != "":
		var l := Label.new()
		l.text = "Habilidad:%s" % tag
		l.add_theme_color_override("font_color", Tema.AMBAR)
		l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		datos.add_child(l)

	# Los tres numeros que se miran primero.
	var fila_nums := HBoxContainer.new()
	caja.add_child(fila_nums)
	fila_nums.add_child(_caja_numero("Media", "%.1f" % float(j["media"]), Tema.TEXTO))
	fila_nums.add_child(_caja_numero("Techo", str(int(j["potencial"])), Tema.AMBAR))
	var animo := int(equipo.animo.get(plantel_elegido, 50))
	fila_nums.add_child(_caja_numero("Ánimo", str(animo), Componentes.color_de_valor(animo)))
	fila_nums.add_child(_caja_numero("Vale", Economia.formato_dinero(
		ValorJugador.calcular(j, float(animo),
			equipo.contratos.get(plantel_elegido, 3))), Tema.VERDE))

	if equipo.esta_lesionado(plantel_elegido):
		var les: Dictionary = equipo.lesiones[plantel_elegido]
		var l := Label.new()
		l.text = "Lesionado: %s, %d días" % [les["tipo"], int(les["dias_restantes"])]
		l.add_theme_color_override("font_color", Tema.ROJO)
		caja.add_child(l)

	caja.add_child(Tema.etiqueta_seccion("En qué es fuerte"))
	# Cuatro y no cinco: con la quimica agregada abajo, la ficha se pasaba
	# de alto y el boton del final quedaba fuera de la pantalla.
	for attr in _mejores_atributos(j, 4):
		caja.add_child(Componentes.barra_atributo(
			attr, int(j["atributos"][attr]), int(Progresion.techo_de(j, attr))))

	_agregar_quimica(caja, equipo, j)

	var contrato := Label.new()
	contrato.text = "Contrato %d año(s)  ·  sueldo %s" % [
		int(equipo.contratos.get(plantel_elegido, 0)),
		Economia.formato_dinero(equipo.sueldos.get(plantel_elegido, 0))]
	contrato.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(contrato)

	var btn := Button.new()
	btn.text = "Ficha completa"
	btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	var id := plantel_elegido
	btn.pressed.connect(func(): _mostrar_ficha(id))
	caja.add_child(btn)


## Recorte del cuadro de frente y quieto (24) del atlas del partido. La
## celda mide 64x64 y el jugador ocupa el centro: medido sobre los once
## peinados, el cuerpo va de x 16 a 48 y de y 13 a 58. Un recorte fijo y
## no el de cada peinado: asi todos los retratos salen a la misma escala.
const RECORTE_RETRATO := Rect2(14, 12, 36, 47)
## Escala entera: con nearest, una escala fraccionaria deja columnas de
## pixeles de ancho desparejo y el sprite se ve deformado.
const ESCALA_RETRATO := 2
## Alto del retrato de la ficha lateral: el recorte a escala 2 (94 px) mas
## un margen. Con 100 px el boton "Ficha completa" sigue entrando en 1152x648.
const ALTO_RETRATO := 100
## Ancho: el sprite a escala 2 mide 72 px y a su derecha va el dorsal de
## dos digitos. Con el dorsal encima del sprite tapaba la cabeza. Mas de
## 108 px y la ficha lateral se pasa de sus 388 px y aparece scroll de costado.
const ANCHO_RETRATO := 108
## Las variantes nuevas del atlas sirven para el partido, pero algunas
## tienen peinados demasiado cargados al verse ampliadas en la ficha.
## La ficha usa las cuatro hojas base, ya probadas a esta escala.
const ESTILOS_RETRATO_ESTABLES := [0, 1, 2, 3]


## Retrato: el mismo sprite que sale a la cancha, de frente y quieto, con
## la camiseta del club. Es el sprite del partido y no un dibujo aparte:
## asi el jugador que el usuario elige en el plantel es el que reconoce
## despues corriendo. Sale del atlas (AtlasJugadores) con el mismo peinado
## y tono de pelo que le da VistaPartido; antes salia de los sprites
## dibujados por codigo, que el partido ya no usa.
##
## El dorsal va como etiqueta a la derecha y no estampado en el sprite:
## el atlas solo lo estampa en los cuadros de espalda.
func _retrato_jugador(equipo: Team, j: Dictionary) -> Control:
	var marco := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.PANEL_ALTO
	estilo.corner_radius_top_left = Tema.RADIO
	estilo.corner_radius_top_right = Tema.RADIO
	estilo.corner_radius_bottom_left = Tema.RADIO
	estilo.corner_radius_bottom_right = Tema.RADIO
	estilo.border_width_top = 1
	estilo.border_width_bottom = 1
	estilo.border_width_left = 1
	estilo.border_width_right = 1
	estilo.border_color = Tema.BORDE
	marco.add_theme_stylebox_override("panel", estilo)

	var pila := Control.new()
	pila.custom_minimum_size = Vector2(ANCHO_RETRATO, ALTO_RETRATO)
	pila.clip_contents = true
	marco.add_child(pila)

	var id := int(j["id"])
	var estilo_atlas := AtlasJugadores.estilo_de(id)
	var estilo_retrato: int = ESTILOS_RETRATO_ESTABLES[
		posmod(estilo_atlas, ESTILOS_RETRATO_ESTABLES.size())]
	var atlas := AtlasJugadores.textura(AtlasJugadores.cuadro("", 0.0, 0, false),
		ColoresClub.de_equipo(equipo), equipo.color_short,
		SpritesPartido.tono_pelo_de(id), false, 0, estilo_retrato)
	# Copiar el recorte a una textura propia evita que el escalado del atlas
	# filtre píxeles de otra celda y los mezcle con el pelo o los hombros.
	var retrato := atlas.get_image().get_region(Rect2i(RECORTE_RETRATO))
	var lado := RECORTE_RETRATO.size * ESCALA_RETRATO
	retrato.resize(int(lado.x), int(lado.y), Image.INTERPOLATE_NEAREST)
	var lamina := TextureRect.new()
	lamina.texture = ImageTexture.create_from_image(retrato)
	lamina.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lamina.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	lamina.stretch_mode = TextureRect.STRETCH_KEEP
	lamina.position = Vector2(2.0, ALTO_RETRATO - lado.y - 3.0)
	lamina.size = lado
	pila.add_child(lamina)

	var dorsal := equipo.dorsal_de(id)
	if dorsal > 0:
		var num := Label.new()
		num.text = str(dorsal)
		Tema.numero(num, 22, Tema.AMBAR)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		num.offset_left = -32.0
		num.offset_top = 2.0
		num.offset_right = -4.0
		pila.add_child(num)
	return marco


## §7.4.6: con quien se entiende este jugador.
##
## Va en la ficha lateral y no como columna de la lista porque la quimica
## es de a PARES: no hay un numero de quimica de un jugador solo, hay uno
## por cada compañero. Lo que se muestra son sus mejores duplas, que es lo
## que hace falta para decidir a quien no tocar.
func _agregar_quimica(caja: VBoxContainer, equipo: Team, j: Dictionary) -> void:
	var duplas := Quimica.mejores_duplas(equipo, int(j["id"]), 3)
	caja.add_child(Tema.etiqueta_seccion("Química · con quién se entiende"))

	if duplas.is_empty():
		var vacio := Label.new()
		vacio.text = "Todavía con nadie. Hacen falta %d partidos juntos en el once para que una dupla empiece a rendir." % int(Quimica.PARTIDOS_MINIMOS)
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vacio.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		vacio.add_theme_color_override("font_color", Tema.SUAVE)
		caja.add_child(vacio)
		return

	for d in duplas:
		var otro := _buscar_jugador_por_id(equipo, int(d["id"]))
		if otro.is_empty():
			continue
		var fila := HBoxContainer.new()
		caja.add_child(fila)

		var nombre := Componentes.celda(
			_nombre_jugador(otro), 130, Tema.TEXTO)
		nombre.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		fila.add_child(nombre)

		# La barra mide contra el TOPE de la mecanica, no contra la mejor
		# dupla del plantel: asi se ve cuanto le queda por crecer.
		var barra := ProgressBar.new()
		barra.min_value = 0.0
		barra.max_value = Quimica.PARTIDOS_TOPE
		barra.value = float(d["partidos"])
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 9)
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		barra.tooltip_text = "%d partidos juntos en el once." % int(d["partidos"])
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Tema.PANEL_ALTO
		fondo.corner_radius_top_left = 5
		fondo.corner_radius_top_right = 5
		fondo.corner_radius_bottom_left = 5
		fondo.corner_radius_bottom_right = 5
		barra.add_theme_stylebox_override("background", fondo)
		var relleno := StyleBoxFlat.new()
		relleno.bg_color = Tema.CELESTE
		relleno.corner_radius_top_left = 5
		relleno.corner_radius_top_right = 5
		relleno.corner_radius_bottom_left = 5
		relleno.corner_radius_bottom_right = 5
		barra.add_theme_stylebox_override("fill", relleno)
		fila.add_child(barra)

		var bonus := Componentes.celda_numero(
			"+%.1f" % float(d["bonus"]), 54, Tema.CELESTE, HORIZONTAL_ALIGNMENT_RIGHT)
		bonus.tooltip_text = "Lo que suman en los pases ENTRE ELLOS."
		fila.add_child(bonus)


func _caja_numero(etiqueta: String, valor: String, color: Color) -> Control:
	var caja := PanelContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.PANEL_ALTO
	estilo.corner_radius_top_left = Tema.RADIO
	estilo.corner_radius_top_right = Tema.RADIO
	estilo.corner_radius_bottom_left = Tema.RADIO
	estilo.corner_radius_bottom_right = Tema.RADIO
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	caja.add_theme_stylebox_override("panel", estilo)
	var dentro := VBoxContainer.new()
	caja.add_child(dentro)
	dentro.add_child(Tema.etiqueta_seccion(etiqueta))
	var l := Label.new()
	l.text = valor
	# Un valor de ocho cifras ("$10,329,476") a 26 px ensanchaba la ficha
	# lateral y le comia el ancho a los nombres de la lista.
	Tema.numero(l, 26 if valor.length() <= 8 else 20, color)
	dentro.add_child(l)
	return caja


## Los atributos donde este jugador es mejor, para no mostrar los 25.
## Solo los que le sirven a su puesto: la `estirada` de un delantero no
## dice nada.
func _mejores_atributos(j: Dictionary, cuantos: int) -> Array:
	var grupos: Dictionary = PlayerGenerator.get_attribute_groups()
	var candidatos := []
	for grupo in grupos:
		if grupo == "arquero" and str(j["posicion"]) != "ARQ":
			continue
		for a in grupos[grupo]:
			if j["atributos"].has(a):
				candidatos.append(a)
	candidatos.sort_custom(func(a, b):
		return int(j["atributos"][a]) > int(j["atributos"][b]))
	return candidatos.slice(0, cuantos)


## Ficha del jugador: los atributos, que hasta ahora no se veian en
## ningun lado. Sin esto el jugador no puede entender por que su equipo
## juega como juega — que un plantel tire pases cortos o remate de lejos
## sale de numeros que estaban ocultos.
func _construir_panel_ficha(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["ficha"] = panel

	boton_volver_ficha = Button.new()
	boton_volver_ficha.text = "< Volver al plantel"
	boton_volver_ficha.pressed.connect(_volver_desde_ficha)
	panel.add_child(boton_volver_ficha)

	boton_investigar_ficha = Button.new()
	boton_investigar_ficha.text = "Investigar"
	boton_investigar_ficha.pressed.connect(_investigar_desde_ficha)
	panel.add_child(boton_investigar_ficha)

	# Con el informe terminado la ficha es donde se decide la compra: mandar
	# al jugador de vuelta a buscarlo en la lista del mercado era un paso de mas.
	fila_fichar_ficha = HBoxContainer.new()
	fila_fichar_ficha.add_theme_constant_override("separation", 8)
	panel.add_child(fila_fichar_ficha)
	boton_comprar_ficha = Button.new()
	boton_comprar_ficha.text = "Comprar"
	boton_comprar_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_comprar_ficha.pressed.connect(func():
		_abrir_negociacion(ficha_club, ficha_jugador_id))
	fila_fichar_ficha.add_child(boton_comprar_ficha)
	boton_prestamo_ficha = Button.new()
	boton_prestamo_ficha.text = "Pedir a préstamo"
	boton_prestamo_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_prestamo_ficha.pressed.connect(func():
		_abrir_prestamo(ficha_club, ficha_jugador_id))
	fila_fichar_ficha.add_child(boton_prestamo_ficha)

	boton_carrera_ficha = Button.new()
	boton_carrera_ficha.pressed.connect(func():
		ficha_ver_carrera = not ficha_ver_carrera
		_refrescar_ficha())
	panel.add_child(boton_carrera_ficha)

	# El dorsal se cambia desde la ficha y no desde la lista del plantel:
	# es una decision por jugador y aca esta el jugador entero a la vista.
	boton_dorsal_ficha = Button.new()
	boton_dorsal_ficha.text = "Cambiar numero de la camiseta"
	boton_dorsal_ficha.pressed.connect(func(): _abrir_modal_dorsal(ficha_jugador_id))
	panel.add_child(boton_dorsal_ficha)

	# Todo se repinta de cero en _refrescar_ficha: la ficha cambia entera
	# entre un jugador y otro (un arquero trae seis atributos mas) y no
	# hay nada que valga la pena conservar entre una y otra.
	# El scroll hace falta aunque las columnas se pensaron para entrar
	# enteras: en pantallas bajas (el celular apaisado) la cabecera y los
	# botones se comen el alto y las ultimas filas quedaban cortadas.
	var scroll_ficha := ScrollContainer.new()
	scroll_ficha.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll_ficha)
	contenedor_ficha = VBoxContainer.new()
	contenedor_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_ficha.add_theme_constant_override("separation", 8)
	scroll_ficha.add_child(contenedor_ficha)


## club = null para uno propio; el Team dueño si es ajeno (viene del
## mercado, y solo se llega hasta aca con el informe terminado).
func _mostrar_ficha(jugador_id: int, club: Team = null,
	publica_liga: bool = false) -> void:
	ficha_jugador_id = jugador_id
	ficha_club = club
	ficha_publica_liga = publica_liga
	ficha_ver_carrera = false
	if publica_liga:
		ficha_origen = "jugadores_liga"
	elif club != null:
		ficha_origen = "mercado"
	else:
		ficha_origen = "plantel"
	_ocultar_todos()
	paneles["ficha"].visible = true
	_refrescar_ficha()


func _volver_desde_ficha() -> void:
	match ficha_origen:
		"jugadores_liga": _mostrar_jugadores_liga()
		"oferta":
			_mostrar_mercado()
			_abrir_oferta(ficha_oferta_id)
		"mercado": _mostrar_mercado()
		_: _mostrar_plantel()


## Al cerrar la compra o el préstamo abiertos desde la ficha: sin esto los
## botones seguian activos con la negociacion ya en curso.
func _refrescar_ficha_si_visible() -> void:
	if paneles.has("ficha") and paneles["ficha"].visible:
		_refrescar_ficha()


func _investigar_desde_ficha() -> void:
	if ficha_club == null:
		return
	_asignar_investigador(ficha_club, ficha_jugador_id)
	_refrescar_ficha()


## La ficha ENTERA, en dos columnas para que entre sin scroll: los 19
## atributos de un jugador de campo (25 si es arquero) no se leen en una
## lista vertical de la que solo se ve la mitad.
##
## Antes era un RichTextLabel con barras hechas de bloques de texto. Se
## veia de otra epoca que el resto del juego y ademas no alineaba: la
## fuente no es monoespaciada, asi que las columnas bailaban fila a fila.
## Ahora usa los mismos componentes que la ficha lateral del plantel, que
## es la que el jugador ya conoce.
func _refrescar_ficha() -> void:
	for hijo in contenedor_ficha.get_children():
		hijo.queue_free()

	var ajeno: bool = ficha_club != null
	var equipo: Team = ficha_club if ajeno else GameState.equipo_jugador
	match ficha_origen:
		"jugadores_liga": boton_volver_ficha.text = "< Volver a estadísticas"
		"mercado": boton_volver_ficha.text = "< Volver al mercado"
		"oferta": boton_volver_ficha.text = "< Volver a la oferta"
		_: boton_volver_ficha.text = "< Volver al plantel"
	# El numero de un jugador ajeno no se toca: es el club del rival.
	# La cantera tampoco lleva dorsal — el plantel de partido son 18.
	boton_dorsal_ficha.visible = (not ajeno
		and GameState.equipo_jugador.dorsal_de(ficha_jugador_id) > 0)

	# _buscar_jugador_por_id mira todo el plantel, incluidas las reservas.
	var j := _buscar_jugador_por_id(equipo, ficha_jugador_id)
	# Desde las estadisticas de la liga tambien llegan jugadores tuyos.
	fila_fichar_ficha.visible = (ajeno and not j.is_empty()
		and ficha_club != GameState.equipo_jugador
		and Investigadores.conoce(GameState.equipo_jugador, ficha_jugador_id))
	if fila_fichar_ficha.visible:
		var traba := _traba_para_fichar(ficha_club, ficha_jugador_id)
		var ayuda: String = "" if traba.is_empty() else traba[1]
		for b in [boton_comprar_ficha, boton_prestamo_ficha]:
			b.disabled = not traba.is_empty()
			b.tooltip_text = ayuda
		if traba.is_empty() and not Mercado.puede_comprarse(j, GameState.temporada_actual):
			boton_comprar_ficha.disabled = true
			boton_comprar_ficha.tooltip_text = Mercado.MOTIVO_RECIEN_COMPRADO
	if j.is_empty():
		contenedor_ficha.add_child(_texto_suave(
			"Ese jugador ya no esta en %s." % (equipo.nombre if ajeno else "el plantel")))
		return

	boton_carrera_ficha.text = "Ver atributos" if ficha_ver_carrera else "Ver carrera"
	if ficha_ver_carrera:
		boton_investigar_ficha.visible = false
		_carrera_en_ficha(equipo, j)
		return

	var conocido := not ajeno or Investigadores.conoce(GameState.equipo_jugador, ficha_jugador_id)
	var progreso := Investigadores.progreso(GameState.equipo_jugador, ficha_jugador_id)
	boton_investigar_ficha.visible = ajeno and not conocido and progreso < 0.0 \
		and not Investigadores.libres(GameState.equipo_jugador).is_empty()
	if ajeno and not conocido:
		# De un rival solo son publicos nombre, club, puesto y edad. La ficha
		# completa aparece cuando termina el informe del investigador.
		contenedor_ficha.add_child(_cabecera_publica_de_ficha(equipo, j))
		if progreso >= 0.0:
			contenedor_ficha.add_child(_texto_suave("Investigacion en curso."))
		elif Investigadores.libres(GameState.equipo_jugador).is_empty():
			contenedor_ficha.add_child(_texto_suave("No tenes investigadores libres."))
		return

	boton_investigar_ficha.visible = false

	contenedor_ficha.add_child(_cabecera_de_ficha(equipo, j, ajeno))

	var columnas := HBoxContainer.new()
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columnas.add_theme_constant_override("separation", 10)
	contenedor_ficha.add_child(columnas)

	# El reparto busca que las columnas midan parecido, no que cada una
	# tenga la misma cantidad de grupos: fisicos (7) + defensivos (2) de un
	# lado y tecnicos (8) + mentales (2) del otro dan 9 y 10 filas, que es
	# lo que entra de alto sin scroll.
	#
	# El arquero tiene seis atributos mas —25 en total— y en dos columnas
	# no entran de ninguna manera, asi que se abre una tercera. Es la unica
	# diferencia entre las dos fichas y se nota poco: la primera columna es
	# la misma en los dos casos.
	var es_arquero: bool = j["posicion"] == "ARQ"
	var reparto := [["fisicos", "defensivos"], ["tecnicos", "mentales"]]
	if es_arquero:
		reparto = [["fisicos", "defensivos"], ["tecnicos"], ["arquero", "mentales"]]

	var grupos: Dictionary = PlayerGenerator.get_attribute_groups()
	for lista in reparto:
		var caja := VBoxContainer.new()
		caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caja.add_theme_constant_override("separation", 8)
		columnas.add_child(caja)
		for grupo in lista:
			if grupos.has(grupo):
				caja.add_child(_bloque_de_atributos(j, str(grupo), grupos[grupo]))
		# Empuja los bloques hacia arriba: sin esto las columnas estiran
		# sus tarjetas para llenar el alto y las barras quedan separadas
		# por huecos distintos de una columna a la otra.
		var relleno := Control.new()
		relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
		caja.add_child(relleno)


## Quien es y como esta: la franja de arriba, a todo el ancho.
func _cabecera_publica_de_ficha(equipo: Team, j: Dictionary) -> Control:
	var tarjeta := Componentes.tarjeta()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 5)
	tarjeta.add_child(caja)

	var nombre := Label.new()
	nombre.text = "%s   %s" % [_nombre_jugador(j), equipo.nombre]
	Tema.numero(nombre, 26)
	caja.add_child(nombre)

	var datos := Label.new()
	datos.text = "%s  ·  %d años" % [str(j["posicion"]), int(j["edad"])]
	datos.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(datos)

	var aviso := Label.new()
	aviso.text = "Datos ocultos. Necesitas investigar a este jugador."
	aviso.add_theme_color_override("font_color", Tema.AMBAR)
	caja.add_child(aviso)
	return tarjeta


func _cabecera_de_ficha(equipo: Team, j: Dictionary, ajeno: bool) -> Control:
	var id: int = int(j["id"])
	var tarjeta := Componentes.tarjeta()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	tarjeta.add_child(caja)

	# Los datos a la izquierda y los numeros a la derecha, en la misma
	# franja: apilados uno abajo del otro la cabecera se comia un tercio de
	# la pantalla y los atributos no entraban sin scroll, que es todo el
	# punto de esta pantalla.
	var franja := HBoxContainer.new()
	franja.add_theme_constant_override("separation", 16)
	caja.add_child(franja)
	var datos := VBoxContainer.new()
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	datos.add_theme_constant_override("separation", 2)
	franja.add_child(datos)

	var linea_nombre := HBoxContainer.new()
	datos.add_child(linea_nombre)
	var titulo := Label.new()
	titulo.text = _nombre_jugador(j)
	Tema.numero(titulo, 26)
	linea_nombre.add_child(titulo)
	if ajeno:
		var club := Label.new()
		club.text = "   %s" % equipo.nombre
		club.add_theme_color_override("font_color", Tema.CELESTE)
		club.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linea_nombre.add_child(club)

	var sub := Label.new()
	sub.text = "%s  ·  %d años  ·  %s  ·  pie %s" % [
		j["posicion"], int(j["edad"]), j["genetica_tier"],
		"izquierdo" if Personalidad.pie_preferido(j) < 0 else "derecho"]
	sub.add_theme_color_override("font_color", Tema.SUAVE)
	sub.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	datos.add_child(sub)

	# Rasgos y habilidades en la misma linea para ahorrar alto.
	var fila_tags := HBoxContainer.new()
	datos.add_child(fila_tags)
	var rasgos: Dictionary = j.get("personalidades", {})
	if str(rasgos.get("positiva", "")) != "":
		fila_tags.add_child(Componentes.chip(
			str(rasgos["positiva"]), Color("#23402f"), Color("#7fd6a0")))
	if str(rasgos.get("negativa", "")) != "":
		fila_tags.add_child(Componentes.chip(
			str(rasgos["negativa"]), Color("#3f2523"), Color("#e29d95")))
	var tag := _tag_habilidad(j, ajeno)
	if tag != "":
		var l := Label.new()
		l.text = "  Habilidad:%s" % tag
		l.add_theme_color_override("font_color", Tema.AMBAR)
		l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fila_tags.add_child(l)

	var nums := HBoxContainer.new()
	nums.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	franja.add_child(nums)
	nums.add_child(_caja_numero("Media", "%.1f" % float(j["media"]), Tema.TEXTO))
	nums.add_child(_caja_numero("Techo", str(int(j["potencial"])), Tema.AMBAR))
	var animo := int(equipo.animo.get(id, 50))
	nums.add_child(_caja_numero("Ánimo", str(animo), Componentes.color_de_valor(animo)))
	# El valor va SIEMPRE, tambien en TUS jugadores. Antes solo se veia el
	# de los ajenos: cuando un club te ofertaba por uno tuyo, la unica
	# cifra a la vista era el monto de la oferta y no habia contra que
	# compararla.
	nums.add_child(_caja_numero("Valor", Economia.formato_dinero(
		ValorJugador.calcular(j, equipo.animo.get(id, 50.0),
			equipo.contratos.get(id, 3))), Tema.VERDE))
	if not ajeno:
		# La energia con la que va a EMPEZAR el proximo partido, no la del
		# ultimo (ver Team.energia_proximo_partido). De un jugador ajeno no
		# se sabe, y ademas no significa nada fuera de su calendario.
		var energia := int(round(equipo.energia_proximo_partido(id) * 100.0))
		nums.add_child(_caja_numero(
			"Energía", "%d%%" % energia, Componentes.color_de_valor(energia)))

	var pie := []
	pie.append("Contrato %d año(s)  ·  sueldo %s" % [
		int(equipo.contratos.get(id, 0)),
		Economia.formato_dinero(equipo.sueldos.get(id, 0))])
	datos.add_child(_texto_suave("   ·   ".join(pie)))

	# Lo que lo deja afuera va en rojo y al final, que es donde se mira
	# cuando la pregunta es "¿puede jugar el domingo?".
	var bajas := []
	if equipo.esta_lesionado(id):
		var les: Dictionary = equipo.lesiones[id]
		bajas.append("Lesionado: %s, %d días" % [les["tipo"], int(les["dias_restantes"])])
	if not ajeno:
		var susp: int = int(equipo.suspendidos.get(id, 0))
		if susp > 0:
			bajas.append("Suspendido %d fecha(s)" % susp)
	if not bajas.is_empty():
		var l := Label.new()
		l.text = "   ·   ".join(bajas)
		l.add_theme_color_override("font_color", Tema.ROJO)
		l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		datos.add_child(l)

	return tarjeta


func _bloque_de_atributos(j: Dictionary, grupo: String, atributos: Array) -> Control:
	var tarjeta := Componentes.tarjeta()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	tarjeta.add_child(caja)
	caja.add_child(Tema.etiqueta_seccion(grupo.capitalize()))
	var attrs: Dictionary = j["atributos"]
	for a in atributos:
		if attrs.has(a):
			caja.add_child(Componentes.barra_atributo(
				str(a), int(attrs[a]), int(Progresion.techo_de(j, a)), true))
	return tarjeta



## §8.1: elegir formacion y mover jugadores. La formacion define los 11
## SLOTS y el slot i lo ocupa jugadores[i] (ver core/formaciones.gd), asi
## que mover a alguien de lugar es literalmente reordenar esa lista.
##
## El intercambio es en dos toques —uno elige, el otro confirma— en vez de
## un desplegable por slot: con un plantel de 18 un OptionButton por fila
## ya son 18 listas de 18, y con el tope de 40 es peor todavia. En un
## celular eso no se toca.
func _construir_panel_formacion(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["formacion"] = panel

	# Las decisiones del plan de partido viven junto a la formación y su
	# familiaridad: cambiar el estilo modifica inmediatamente ese valor.
	# El bloque toma el ancho exacto de los cuatro controles; la tarjeta de
	# familiaridad termina en el mismo borde y no cruza toda la pantalla.
	var bloque_plan := VBoxContainer.new()
	bloque_plan.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bloque_plan.add_theme_constant_override("separation", 8)
	panel.add_child(bloque_plan)

	var barra_plan := HBoxContainer.new()
	barra_plan.add_theme_constant_override("separation", 12)
	bloque_plan.add_child(barra_plan)

	option_formacion = OptionButton.new()
	option_formacion.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	for nombre in Formaciones.lista():
		option_formacion.add_item(nombre)
	option_formacion.item_selected.connect(_on_formacion_elegida)
	barra_plan.add_child(_grupo_filtro("Formación", option_formacion))

	option_estilo = OptionButton.new()
	for estilo in Estilos.LISTA:
		option_estilo.add_item(estilo)
	option_estilo.custom_minimum_size = Vector2(190, Tema.ALTO_TACTIL)
	option_estilo.item_selected.connect(_on_estilo_seleccionado)
	barra_plan.add_child(_grupo_filtro("Estilo de juego", option_estilo))

	option_cambios = OptionButton.new()
	for opcion in OPCIONES_CAMBIOS:
		option_cambios.add_item(ETIQUETAS_CAMBIOS[opcion])
	option_cambios.custom_minimum_size = Vector2(230, Tema.ALTO_TACTIL)
	option_cambios.item_selected.connect(_on_config_cambios_seleccionado)
	barra_plan.add_child(_grupo_filtro("Cambios automáticos", option_cambios))

	check_rotacion = CheckBox.new()
	check_rotacion.text = "Descansar jugadores cansados"
	check_rotacion.tooltip_text = "Antes de cada partido, cambia automáticamente a los titulares que necesitan descanso."
	check_rotacion.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	check_rotacion.toggled.connect(func(activo: bool):
		GameState.equipo_jugador.rotacion_automatica = activo)
	barra_plan.add_child(_grupo_filtro("Rotación automática", check_rotacion))

	# La familiaridad queda sola debajo del plan. Así se ve inmediatamente
	# qué efecto tuvo cambiar la formación o el estilo de juego.
	var tarjeta_fam := Componentes.tarjeta(Tema.VERDE)
	tarjeta_fam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bloque_plan.add_child(tarjeta_fam)
	var caja_fam := HBoxContainer.new()
	caja_fam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_fam.add_theme_constant_override("separation", 12)
	tarjeta_fam.add_child(caja_fam)
	caja_fam.add_child(Tema.etiqueta_seccion("Familiaridad"))
	barra_familiaridad = ProgressBar.new()
	barra_familiaridad.min_value = 0.0
	barra_familiaridad.max_value = 100.0
	barra_familiaridad.show_percentage = false
	barra_familiaridad.custom_minimum_size = Vector2(220, 10)
	barra_familiaridad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_familiaridad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo_fam := StyleBoxFlat.new()
	fondo_fam.bg_color = Tema.PANEL_ALTO
	barra_familiaridad.add_theme_stylebox_override("background", fondo_fam)
	caja_fam.add_child(barra_familiaridad)
	label_familiaridad = Label.new()
	label_familiaridad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_familiaridad.clip_text = true
	label_familiaridad.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	caja_fam.add_child(label_familiaridad)

	label_bajas = Label.new()
	label_bajas.add_theme_color_override("font_color", Tema.ROJO)
	label_bajas.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_bajas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_bajas.clip_text = true
	panel.add_child(label_bajas)

	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 10)
	panel.add_child(pie)

	label_formacion_estado = Label.new()
	label_formacion_estado.text = ""
	label_formacion_estado.visible = false
	label_formacion_estado.add_theme_color_override("font_color", Tema.SUAVE)
	label_formacion_estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(label_formacion_estado)

	# El efecto de la carga no entra en la fila de los tres desplegables
	# —ahi quedaba cortado a la mitad— y aca sobra ancho.
	label_carga_efecto = Label.new()
	label_carga_efecto.add_theme_color_override("font_color", Tema.SUAVE)
	label_carga_efecto.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_carga_efecto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# RECORTADO. Sin esto el label pide todo el ancho que necesita su
	# texto, estira la fila mas alla de la ventana y empuja el BANCO —que
	# esta a la derecha de la cancha— fuera de la pantalla. Un texto largo
	# en el pie no puede tener el poder de borrar media pantalla.
	label_carga_efecto.clip_text = true
	label_carga_efecto.custom_minimum_size = Vector2(280, 0)
	label_carga_efecto.visible = false
	pie.add_child(label_carga_efecto)

	# Todo el cuerpo scrollea: la cancha pide su propio alto (ver
	# CanchaFormacion._ajustar_alto) y las dos listas van abajo de ella,
	# fuera de la pantalla en un celular. Antes se repartian el alto y la
	# cancha quedaba diminuta para que las listas entraran siempre.
	var scroll_cuerpo := ScrollContainer.new()
	scroll_cuerpo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll_cuerpo)

	var cuerpo := VBoxContainer.new()
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_cuerpo.add_child(cuerpo)

	cancha_formacion = CanchaFormacion.new()
	cancha_formacion.seleccion_pedida.connect(_on_cubo_tocado)
	cuerpo.add_child(cancha_formacion)

	# Las dos listas ABAJO de la cancha y en fila, no al costado: la
	# cancha ahora es vertical y el ancho que sobra a los lados no alcanza
	# para una columna de cubos, pero el alto de abajo sí para dos filas.
	etiqueta_suplentes = Tema.etiqueta_seccion("Suplentes")
	cuerpo.add_child(etiqueta_suplentes)
	contenedor_formacion = _fila_de_cubos(cuerpo)

	etiqueta_reservas = Tema.etiqueta_seccion("Reservas")
	cuerpo.add_child(etiqueta_reservas)
	contenedor_reservas = _fila_de_cubos(cuerpo)


## Una fila horizontal de cubos que scrollea sola. El alto es el del cubo
## mas un poco: sin minimo, el ScrollContainer se queda en cero y la fila
## no se ve.
func _fila_de_cubos(padre: Control) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, CuboJugador.ALTO * ESCALA_LISTAS + 12)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(scroll)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	scroll.add_child(fila)
	return fila


func _mostrar_formacion() -> void:
	_ocultar_todos()
	paneles["formacion"].visible = true
	option_estilo.select(maxi(Estilos.LISTA.find(GameState.equipo_jugador.estilo), 0))
	option_cambios.select(maxi(
			OPCIONES_CAMBIOS.find(GameState.equipo_jugador.config_cambios), 0))
	check_rotacion.set_pressed_no_signal(GameState.equipo_jugador.rotacion_automatica)
	_refrescar_formacion()


## §7.4.1: la carga se elige entre fecha y fecha. Lo que decide la
## progresión es el PROMEDIO de la temporada, así que bajarla una semana
## apretada no arruina el año.
func _on_carga_elegida(idx: int) -> void:
	GameState.equipo_jugador.carga_entrenamiento = CargaEntrenamiento.NIVELES[idx]
	_refrescar_formacion()


## §7.4.2: se puede cambiar cuando quieras. Lo que pesa al cierre de
## temporada es cuantas SEMANAS estuvo puesto cada ejercicio, asi que
## cambiar a mitad de año reparte en vez de reiniciar. El bonus del
## partido, en cambio, es del ejercicio puesto HOY.
func _on_ejercicio_elegido(ranura: String, idx: int) -> void:
	var ejercicio: String = Entrenamiento.EJERCICIOS[ranura][idx]
	if ranura == Entrenamiento.FISICO:
		GameState.equipo_jugador.ejercicio_fisico = ejercicio
	else:
		GameState.equipo_jugador.ejercicio_tactico = ejercicio
	_refrescar_formacion()


## "Correr + Penales", para las lineas de resumen.
func _texto_ejercicios(equipo: Team) -> String:
	return "%s + %s" % [
		Entrenamiento.ETIQUETAS.get(equipo.ejercicio_fisico, "?"),
		Entrenamiento.ETIQUETAS.get(equipo.ejercicio_tactico, "?")]


func _on_formacion_elegida(idx: int) -> void:
	var nombre: String = option_formacion.get_item_text(idx)
	GameState.equipo_jugador.formacion = nombre
	_refrescar_formacion()


## Aviso cuando alguien esta fuera de su puesto. No lo impide —es una
## decision del DT— pero el motor lo castiga solo: el jugador toma el ROL
## del slot y juega con SUS atributos, asi que un defensor de 9 remata con
## el `tiro` que tiene.
func _texto_slot(rol: String, j: Dictionary) -> String:
	var aviso := ""
	if j["posicion"] != rol:
		aviso = "   [%s de puesto natural]" % j["posicion"]
	return "%-4s  %-22s  media %5.1f%s%s" % [
		rol, _nombre_jugador(j), j["media"], aviso, _tag_habilidad(j)]


## Lo que hace la carga elegida, en la fila misma.
##
## Antes aca iba el promedio de la temporada, que es correcto pero arranca
## en x1.00 y solo se mueve semana a semana: mover el desplegable no
## cambiaba el numero y se leia como un control roto. El promedio sigue
## estando, atras, y solo cuando ya significa algo.
## §7.4.5: en que anda la tactica puesta y que le hace al equipo.
##
## Dice los PUNTOS del modificador y no solo el nivel, porque "72/100" no
## significa nada solo: lo que se compara al decidir un cambio es cuanto
## suma o resta en los duelos.
func _refrescar_familiaridad(equipo: Team) -> void:
	var nivel := Familiaridad.nivel(equipo)
	var mod := Familiaridad.modificador(equipo)
	barra_familiaridad.value = nivel

	var color := Tema.VERDE if mod > 0.0 else (Tema.SUAVE if mod == 0.0 else (
		Tema.ROJO if mod <= -4.0 else Tema.AMBAR))
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color
	barra_familiaridad.add_theme_stylebox_override("fill", relleno)

	var texto := "%d/100  ·  %+.1f en los duelos" % [int(round(nivel)), mod]
	if mod < 0.0:
		texto += "  ·  le faltan %d fechas para dejar de restar" % \
			Familiaridad.fechas_para_neutro(equipo)
	elif nivel < Familiaridad.MAXIMO:
		texto += "  ·  sigue subiendo si no cambias de plan"
	label_familiaridad.text = texto
	label_familiaridad.add_theme_color_override("font_color", color)
	label_familiaridad.tooltip_text = "Cada formacion + estilo se entrena por separado. Un plan nuevo arranca en frio y resta hasta que el equipo lo asimila; el ejercicio de jugadas armadas lo acelera. Cambiar solo una de las dos mitades arrastra parte de lo que ya sabias."


func _texto_carga(equipo: Team) -> String:
	var nivel: String = equipo.carga_entrenamiento
	var t := "crecimiento x%.2f · recuperación x%.2f · lesiones x%.2f" % [
		CargaEntrenamiento.factor_crecimiento(nivel),
		CargaEntrenamiento.factor_recuperacion(nivel),
		CargaEntrenamiento.factor_lesion(nivel)]
	# Lo que decide la progresion es el promedio de la temporada, no el
	# nivel de hoy: sin esto, bajar la carga la ultima semana pareceria
	# arruinar el año entero.
	if equipo.carga_semanas > 0.0:
		t += "   —   temporada x%.2f" % equipo.factor_carga_temporada()
	return t


func _refrescar_formacion() -> void:
	var equipo := GameState.equipo_jugador
	var idx := Formaciones.lista().find(equipo.formacion)
	if idx >= 0:
		option_formacion.selected = idx
	# El pie de la formacion recuerda como viene el entrenamiento, aunque
	# se elija en su propia solapa: la familiaridad tactica de abajo
	# depende del ejercicio tactico, asi que el dato tiene que estar a mano.
	label_carga_efecto.text = "Carga %s  ·  %s" % [
		CargaEntrenamiento.ETIQUETAS.get(equipo.carga_entrenamiento, "?"),
		_texto_ejercicios(equipo)]
	label_carga_efecto.tooltip_text = _texto_carga(equipo)

	_refrescar_familiaridad(equipo)
	_refrescar_bajas(equipo)

	cancha_formacion.mostrar(equipo, formacion_marcado)

	for hijo in contenedor_formacion.get_children():
		hijo.queue_free()
	for hijo in contenedor_reservas.get_children():
		hijo.queue_free()

	# Los que no pueden jugar van al final de la fila, no mezclados: el
	# suspendido del banco NO entra por un cambio
	# (MatchEngine._mejor_suplente_para filtra puede_jugar) ni tapa el
	# hueco de un titular (Alineacion.reemplazo_para hace lo mismo).
	# Mezclado con los sanos parecia un suplente mas, asi que mover al
	# suspendido al banco daba la sensacion de haberlo resuelto.
	var sanos := []
	var no_disponibles := []
	for j in equipo.banco:
		if equipo.puede_jugar(int(j["id"])):
			sanos.append(j)
		else:
			no_disponibles.append(j)

	etiqueta_suplentes.text = "SUPLENTES (%d DE %d)  ·  VAN AL PARTIDO" % [
		equipo.banco.size(), Team.max_suplentes()]
	for j in sanos + no_disponibles:
		contenedor_formacion.add_child(_cubo_de_lista(equipo, j, true))
	# Un hueco por cada lugar libre del banco: es donde se suelta a una
	# reserva cuando no hay a quien sacar. Sin el, con el banco a medio
	# llenar no habia forma de subir a nadie.
	for _i in range(Team.max_suplentes() - equipo.banco.size()):
		contenedor_formacion.add_child(_hueco_de_banco())

	etiqueta_reservas.text = "RESERVAS (%d)  ·  NO VAN AL PARTIDO" % equipo.reservas.size()
	for j in equipo.reservas:
		contenedor_reservas.add_child(_cubo_de_lista(equipo, j, false))
	# El hueco de reservas no tiene tope: siempre hay uno al final para
	# bajar a un suplente sin tener que cambiarlo por alguien.
	contenedor_reservas.add_child(_hueco_de_reservas())


## Un cubo de una de las dos filas de abajo. La cancha arma los suyos
## (ver CanchaFormacion.mostrar); estos son los mismos cubos con el
## puesto natural como rol, porque fuera del once nadie ocupa un slot.
func _cubo_de_lista(equipo: Team, j: Dictionary, es_suplente: bool) -> Control:
	var cubo := CuboJugador.crear(j, str(j["posicion"]), equipo, true, ESCALA_LISTAS)
	cubo.marcar_seleccionado(int(j["id"]) == formacion_marcado)
	cubo.seleccion_pedida.connect(_on_cubo_tocado)
	if not es_suplente:
		# Apagado, como el que no juega: es la diferencia que hay que ver
		# de un vistazo entre el banco y las reservas.
		cubo.modulate = Color(1, 1, 1, 0.72)
	return cubo


## Un lugar vacio del banco. Se toca con alguien marcado para meterlo
## ahi; solo, no hace nada.
func _hueco_de_banco() -> Control:
	return _hueco("Lugar libre", func(): _on_hueco_tocado(true))


func _hueco_de_reservas() -> Control:
	return _hueco("A reservas", func(): _on_hueco_tocado(false))


func _hueco(texto: String, al_tocar: Callable) -> Control:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(
		CuboJugador.ANCHO * ESCALA_LISTAS, CuboJugador.ALTO * ESCALA_LISTAS)
	btn.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	btn.add_theme_color_override("font_color", Tema.SUAVE)
	btn.pressed.connect(al_tocar)
	return btn


## Tocaste un cubo. El primero se MARCA (manteniendolo apretado, ver
## CuboJugador) y el segundo cierra el cambio de una.
func _on_cubo_tocado(jugador_id: int) -> void:
	if formacion_marcado == jugador_id:
		formacion_marcado = -1
		_mostrar_estado_formacion("Listo, no cambiaste nada.")
		_refrescar_formacion()
		return
	if formacion_marcado == -1:
		formacion_marcado = jugador_id
		_mostrar_estado_formacion("Marcado. Tocá a otro para cambiarlos de lugar.")
		_refrescar_formacion()
		return

	var equipo := GameState.equipo_jugador
	if equipo.intercambiar(formacion_marcado, jugador_id):
		_mostrar_estado_formacion("Cambiados de lugar.")
	else:
		_mostrar_estado_formacion("No se pudieron cambiar.")
	formacion_marcado = -1
	_refrescar_formacion()
	_refrescar_plantel()


## Tocaste un lugar vacio. Solo tiene sentido con alguien marcado: mueve
## al marcado a esa lista, sin sacar a nadie.
func _on_hueco_tocado(al_banco: bool) -> void:
	if formacion_marcado == -1:
		_mostrar_estado_formacion("Primero mantené apretado 2 segundos al que querés mover.")
		return
	var equipo := GameState.equipo_jugador
	var donde := equipo.donde_esta(formacion_marcado)
	# El hueco del banco solo acepta reservas y el de reservas solo
	# suplentes: un titular tiene que salir del once por un cambio, o el
	# equipo quedaria con diez.
	if al_banco and donde != "reservas":
		_mostrar_estado_formacion("Ese lugar es para una reserva. A un titular cambialo por un suplente.")
		return
	if not al_banco and donde != "banco":
		_mostrar_estado_formacion("A reservas solo baja un suplente. A un titular cambialo primero por uno del banco.")
		return
	var r := equipo.mover_entre_banco_y_reservas(formacion_marcado)
	_mostrar_estado_formacion("Movido al banco." if bool(r.get("exito", false)) and str(r.get("a", "")) == "banco" 		else ("Movido a reservas." if bool(r.get("exito", false)) else str(r.get("motivo", ""))))
	formacion_marcado = -1
	_refrescar_formacion()
	_refrescar_plantel()


func _mostrar_estado_formacion(texto: String) -> void:
	label_formacion_estado.text = texto
	label_formacion_estado.visible = not texto.is_empty()


## Los que no pueden jugar, titulares y suplentes. Los suplentes tambien
## —y por eso no uso Alineacion.indisponibles, que mira solo los once—:
## si el reemplazo del suspendido esta lesionado, hay que saberlo ANTES de
## arrastrarlo a la cancha, no despues.
func _refrescar_bajas(equipo: Team) -> void:
	var partes := []
	for j in equipo.convocados():
		var id := int(j["id"])
		var motivo := Alineacion.texto_motivo(equipo, id)
		if motivo == "":
			continue
		partes.append("%s (%s)" % [_nombre_jugador(j), motivo])
	if partes.is_empty():
		label_bajas.text = ""
		label_bajas.tooltip_text = ""
		label_bajas.visible = false
		return
	label_bajas.text = "No pueden jugar: %s" % "   ·   ".join(partes)
	label_bajas.tooltip_text = label_bajas.text
	label_bajas.visible = true


func _construir_panel_tabla(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["tabla"] = panel

	var titulo := Label.new()
	titulo.name = "titulo"
	Tema.numero(titulo, Tema.TAM_BASE)
	panel.add_child(titulo)

	# La leyenda de zonas: sin esto las barras de color son decoracion.
	label_tabla_leyenda = Label.new()
	label_tabla_leyenda.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_tabla_leyenda.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(label_tabla_leyenda)

	panel.add_child(_encabezado_tabla())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	scroll_tabla = scroll
	contenedor_tabla = VBoxContainer.new()
	contenedor_tabla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_tabla.add_theme_constant_override("separation", 0)
	scroll.add_child(contenedor_tabla)
	_refrescar_tabla()


func _encabezado_tabla() -> PanelContainer:
	var fila := Componentes.fila(false)
	var dentro := Componentes.contenido(fila)
	dentro.add_child(Componentes.acento_lateral(Color.TRANSPARENT))
	var cols := [
		["#", Componentes.COL_POSICION, HORIZONTAL_ALIGNMENT_RIGHT],
		["Equipo", Componentes.COL_EQUIPO, HORIZONTAL_ALIGNMENT_LEFT],
		["PJ", Componentes.COL_JUGADOS, HORIZONTAL_ALIGNMENT_RIGHT],
		["PG", Componentes.COL_JUGADOS, HORIZONTAL_ALIGNMENT_RIGHT],
		["PE", Componentes.COL_JUGADOS, HORIZONTAL_ALIGNMENT_RIGHT],
		["PP", Componentes.COL_JUGADOS, HORIZONTAL_ALIGNMENT_RIGHT],
		["GF", Componentes.COL_GOLES, HORIZONTAL_ALIGNMENT_RIGHT],
		["GC", Componentes.COL_GOLES, HORIZONTAL_ALIGNMENT_RIGHT],
		["DG", Componentes.COL_DIFERENCIA, HORIZONTAL_ALIGNMENT_RIGHT],
		["Pts", Componentes.COL_PUNTOS, HORIZONTAL_ALIGNMENT_RIGHT],
	]
	for c in cols:
		var l := Componentes.celda(str(c[0]), int(c[1]), Tema.SUAVE, int(c[2]))
		l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		dentro.add_child(l)
	return fila


## Que le pasa al que termina en esta posicion. Las reglas viven en
## Piramide (1° y 2° suben, 3° juega el playoff contra el 18°, 19° y 20°
## bajan); aca solo se traducen a color. Division 1 no asciende y division
## 10 no desciende, y por eso la zona depende de en cual estas.
func _zona_de_posicion(pos: int, division: int) -> Dictionary:
	if division > 1:
		if pos <= 2:
			return {"color": Tema.VERDE, "que": "asciende"}
		if pos == 3:
			return {"color": Tema.VERDE_TIBIO, "que": "playoff de ascenso"}
	if division < Piramide.N_DIVISIONES:
		if pos >= 19:
			return {"color": Tema.ROJO, "que": "desciende"}
		if pos == 18:
			return {"color": Color("#a2622f"), "que": "playoff de descenso"}
	return {"color": Color.TRANSPARENT, "que": ""}


func _refrescar_tabla() -> void:
	var panel: VBoxContainer = paneles["tabla"]
	var division := GameState.division_jugador + 1
	var titulo: Label = panel.get_node("titulo")
	titulo.text = "Tabla de posiciones — División %d" % division

	# La leyenda dice solo lo que aplica: division 1 no asciende y
	# division 10 no desciende, y anunciar una zona que no existe es peor
	# que no decir nada.
	var partes := []
	if division > 1:
		partes.append("verde: ascienden · verde claro: playoff de ascenso")
	if division < Piramide.N_DIVISIONES:
		partes.append("naranja: playoff de descenso · rojo: descienden")
	label_tabla_leyenda.text = "      ".join(partes)

	for hijo in contenedor_tabla.get_children():
		hijo.queue_free()

	var liga := GameState.liga_jugador()
	var mio: String = GameState.equipo_jugador.nombre
	var pos := 1
	for nombre in liga.tabla_ordenada():
		var f: Dictionary = liga.tabla[nombre]
		var zona := _zona_de_posicion(pos, division)
		var soy_yo: bool = nombre == mio
		var fila := Componentes.fila(pos % 2 == 0)
		if soy_yo:
			# Tu club tiene que saltar a la vista al abrir la pantalla: es
			# lo unico que se busca en una tabla de 20.
			var e: StyleBoxFlat = fila.get_theme_stylebox("panel").duplicate()
			e.bg_color = Tema.PANEL_ALTO
			e.border_width_top = 1
			e.border_width_bottom = 1
			e.border_color = Tema.AMBAR
			fila.add_theme_stylebox_override("panel", e)
		var dentro := Componentes.contenido(fila)
		dentro.add_child(Componentes.acento_lateral(zona["color"]))
		if zona["que"] != "":
			fila.tooltip_text = str(zona["que"]).capitalize()

		var color_texto: Color = Tema.AMBAR if soy_yo else Tema.TEXTO
		dentro.add_child(Componentes.celda_numero(
			str(pos), Componentes.COL_POSICION, color_texto, HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(Componentes.celda(
			nombre, Componentes.COL_EQUIPO, color_texto))
		for clave in ["pj", "pg", "pe", "pp"]:
			dentro.add_child(Componentes.celda_numero(str(f[clave]),
				Componentes.COL_JUGADOS, Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
		for clave in ["gf", "gc"]:
			dentro.add_child(Componentes.celda_numero(str(f[clave]),
				Componentes.COL_GOLES, Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
		var dg := int(f["dg"])
		dentro.add_child(Componentes.celda_numero(
			("+%d" % dg) if dg > 0 else str(dg), Componentes.COL_DIFERENCIA,
			Tema.VERDE if dg > 0 else (Tema.ROJO if dg < 0 else Tema.SUAVE),
			HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(Componentes.celda_numero(
			str(f["pts"]), Componentes.COL_PUNTOS, color_texto, HORIZONTAL_ALIGNMENT_RIGHT))
		contenedor_tabla.add_child(fila)
		pos += 1

	_tabla_desde_arriba.call_deferred()


## Abre la tabla en el puntero. Antes centraba tu fila, y si venias ultimo
## entrabas viendo el fondo de la tabla. Va diferido porque el scroll se
## acomoda recien despues de que el contenedor mide las filas.
func _tabla_desde_arriba() -> void:
	if scroll_tabla == null or not is_instance_valid(scroll_tabla):
		return
	scroll_tabla.scroll_vertical = 0


## Los mejores de la division, en las cuatro listas que se miran de
## verdad: goleadores, asistencias, vallas invictas y amarillas.
##
## Sale de TODOS los partidos de la liga y no solo de los nuestros (ver
## core/estadisticas_liga.gd): la gracia es saber que el 9 del puntero te
## lleva cinco goles, no cuantos hizo el tuyo, que eso ya se ve en Plantel.
const RANKINGS := [
	["goles", "Goleadores", "Goles"],
	["asistencias", "Asistencias", "Asist."],
	["vallas", "Porterias invictas", "Vallas"],
	["amarillas", "Amarillas", "Amar."],
]


func _construir_panel_jugadores_liga(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["jugadores_liga"] = panel

	var barra := HBoxContainer.new()
	panel.add_child(barra)
	for entrada in RANKINGS:
		var btn := Button.new()
		btn.text = str(entrada[1])
		btn.custom_minimum_size = Vector2(0, 44)
		var clave := str(entrada[0])
		btn.pressed.connect(func():
			ranking_elegido = clave
			_refrescar_jugadores_liga())
		barra.add_child(btn)
		botones_ranking[clave] = btn

	# El encabezado cambia de titulo con la solapa (Goles / Asist. /
	# Vallas), asi que se repinta junto con la lista.
	contenedor_encabezado_jugadores = VBoxContainer.new()
	panel.add_child(contenedor_encabezado_jugadores)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_jugadores_liga = VBoxContainer.new()
	contenedor_jugadores_liga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_jugadores_liga.add_theme_constant_override("separation", 0)
	scroll.add_child(contenedor_jugadores_liga)


func _mostrar_jugadores_liga() -> void:
	_ocultar_todos()
	paneles["jugadores_liga"].visible = true
	_refrescar_jugadores_liga()


func _refrescar_jugadores_liga() -> void:
	var titulo_columna := "Goles"
	for entrada in RANKINGS:
		var clave := str(entrada[0])
		Tema.seleccionado(botones_ranking[clave], clave == ranking_elegido)
		if clave == ranking_elegido:
			titulo_columna = str(entrada[2])

	for hijo in contenedor_encabezado_jugadores.get_children():
		hijo.queue_free()
	contenedor_encabezado_jugadores.add_child(_encabezado_jugadores_liga(titulo_columna))

	for hijo in contenedor_jugadores_liga.get_children():
		hijo.queue_free()

	var liga := GameState.liga_jugador()
	var filas := EstadisticasLiga.ranking(liga.estadisticas, ranking_elegido, 40)
	if filas.is_empty():
		# Sin partidos jugados la lista esta vacia, y una lista vacia sin
		# explicacion parece un bug.
		contenedor_jugadores_liga.add_child(_texto_suave(
			"Todavia no hay nada para mostrar: la temporada recien empieza."))
		return

	var mio: String = GameState.equipo_jugador.nombre
	var puesto := 0
	var anterior := -1
	for i in range(filas.size()):
		var f: Dictionary = filas[i]
		var valor := int(f[ranking_elegido])
		# Los empatados comparten puesto: dos con 12 goles son los dos
		# primeros, y el que sigue es tercero.
		if valor != anterior:
			puesto = i + 1
			anterior = valor
		var soy_yo: bool = str(f["equipo"]) == mio
		var fila := Componentes.fila(i % 2 == 0)
		var dentro := Componentes.contenido(fila)
		dentro.add_child(Componentes.acento_lateral(
			Tema.AMBAR if soy_yo else Color.TRANSPARENT))
		var color: Color = Tema.AMBAR if soy_yo else Tema.TEXTO
		dentro.add_child(Componentes.celda_numero(
			str(puesto), Componentes.COL_POSICION, Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
		var club_fila: Team = _equipo_de_jugador_en_liga(liga, int(f["id"]))
		var nombre := Componentes.boton_de_celda(
			str(f["nombre"]), Componentes.COL_NOMBRE + 40,
			HORIZONTAL_ALIGNMENT_LEFT, color)
		if club_fila != null:
			nombre.pressed.connect(func():
				_mostrar_ficha(int(f["id"]), club_fila, true))
		dentro.add_child(nombre)
		dentro.add_child(Componentes.celda(
			str(f["posicion"]), Componentes.COL_POS, Tema.SUAVE))
		dentro.add_child(Componentes.celda(
			str(f["equipo"]), Componentes.COL_EQUIPO, Tema.SUAVE))
		dentro.add_child(Componentes.celda_numero(
			str(valor), Componentes.COL_GOLES, color, HORIZONTAL_ALIGNMENT_RIGHT))
		# En la lista de amarillas interesa tambien quien se fue expulsado.
		if ranking_elegido == "amarillas":
			var rojas := int(f["rojas"])
			dentro.add_child(Componentes.celda_numero(
				str(rojas) if rojas > 0 else "-", Componentes.COL_GOLES,
				Tema.ROJO if rojas > 0 else Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
		contenedor_jugadores_liga.add_child(fila)


func _encabezado_jugadores_liga(titulo_columna: String) -> PanelContainer:
	var fila := Componentes.fila(false)
	var dentro := Componentes.contenido(fila)
	dentro.add_child(Componentes.acento_lateral(Color.TRANSPARENT))
	var cols := [
		["#", Componentes.COL_POSICION, HORIZONTAL_ALIGNMENT_RIGHT],
		["Jugador", Componentes.COL_NOMBRE + 40, HORIZONTAL_ALIGNMENT_LEFT],
		["Pos", Componentes.COL_POS, HORIZONTAL_ALIGNMENT_LEFT],
		["Equipo", Componentes.COL_EQUIPO, HORIZONTAL_ALIGNMENT_LEFT],
		[titulo_columna, Componentes.COL_GOLES, HORIZONTAL_ALIGNMENT_RIGHT],
	]
	if ranking_elegido == "amarillas":
		cols.append(["Rojas", Componentes.COL_GOLES, HORIZONTAL_ALIGNMENT_RIGHT])
	for c in cols:
		var l := Componentes.celda(str(c[0]), int(c[1]), Tema.SUAVE, int(c[2]))
		l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		dentro.add_child(l)
	return fila


## Historial de NUESTROS partidos: la lista a la izquierda, el detalle del
## que elijas a la derecha.
##
## Reemplaza a la vieja pantalla "Partido", que mezclaba tres cosas que no
## van juntas: los controles del equipo (estilo, cambios), los botones que
## avanzan el calendario y el resumen del ultimo partido. Los dos primeros
## se fueron a Plantel y a Club, que es donde se decide; aca queda solo lo
## que se MIRA, y ya no solo del ultimo partido.
func _construir_panel_historial(padre: Control) -> void:
	var panel := HBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["historial"] = panel

	var izq := VBoxContainer.new()
	izq.custom_minimum_size = Vector2(340, 0)
	panel.add_child(izq)
	izq.add_child(Tema.etiqueta_seccion("Tus partidos"))
	var scroll_lista := ScrollContainer.new()
	scroll_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	izq.add_child(scroll_lista)
	contenedor_lista_partidos = VBoxContainer.new()
	contenedor_lista_partidos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_lista.add_child(contenedor_lista_partidos)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_ultimo_partido = VBoxContainer.new()
	contenedor_ultimo_partido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_ultimo_partido.add_theme_constant_override("separation", 10)
	scroll.add_child(contenedor_ultimo_partido)


## Reproduce el último partido propio con la vista de /match: proyección
## oblicua, cámara que sigue la pelota, estadio y relato. El panel no
## lleva barra de "Volver" propia porque la vista trae su botón Menú
## arriba a la derecha — la pantalla es toda cancha, que es el punto.
func _construir_panel_partido_animado(padre: Control) -> void:
	var panel := Control.new()
	# top_level: el panel se ancla a la pantalla y no al contenedor. Anclado
	# al contenedor quedaban el riel y la barra de arriba vivos al costado:
	# el zoom abierto del gol los dejaba ver, y un toque que buscaba los
	# botones de velocidad caia en Copa o Mercado.
	panel.top_level = true
	panel.visible = false
	padre.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paneles["partido_animado"] = panel

	vista_partido = VistaPartido.new()
	vista_partido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vista_partido)
	vista_partido.hud.menu_pedido.connect(func():
		if viendo_laboratorio:
			viendo_laboratorio = false
			_mostrar_laboratorio()
		else:
			_volver_al_club())
	# Al terminar NO se cierra solo. Aparece el resumen encima de la
	# cancha y de ahi se sale a mano: cerrar de una no dejaba ver el
	# ultimo minuto ni enterarse de como termino.
	vista_partido.terminado.connect(func():
		# Un clip del laboratorio no tiene resumen de partido que mostrar:
		# se vuelve a la lista para poder tirar la jugada siguiente.
		if viendo_laboratorio:
			viendo_laboratorio = false
			_mostrar_laboratorio()
			return
		# Saltar emite terminado desde el callback del boton. Diferir un frame
		# asegura que el panel ya quedo en el ultimo fotograma antes de mostrar
		# el cartel de estadisticas.
		call_deferred("_mostrar_resumen_partido"))

	_construir_resumen_partido(self)


## El cuadro de fin de partido: marcador grande y las estadisticas.
##
## Va ENCIMA de la cancha y no en otra pantalla, para poder mirar el
## ultimo fotograma mientras se leen los numeros.
func _construir_resumen_partido(padre: Control) -> void:
	# La cancha animada es `top_level` y vive en otro contenedor. Un
	# CenterContainer comun podia quedar debajo de esa vista aunque estuviera
	# visible. CanvasLayer garantiza que el marcador y las estadisticas sean
	# realmente un overlay, tambien al usar Saltar.
	capa_resumen_partido = CanvasLayer.new()
	capa_resumen_partido.layer = 12
	padre.add_child(capa_resumen_partido)
	resumen_partido = CenterContainer.new()
	resumen_partido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resumen_partido.visible = false
	capa_resumen_partido.add_child(resumen_partido)

	var tarjeta := PanelContainer.new()
	tarjeta.custom_minimum_size = Vector2(560, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(Tema.PANEL.r, Tema.PANEL.g, Tema.PANEL.b, 0.97)
	estilo.corner_radius_top_left = Tema.RADIO
	estilo.corner_radius_top_right = Tema.RADIO
	estilo.corner_radius_bottom_left = Tema.RADIO
	estilo.corner_radius_bottom_right = Tema.RADIO
	estilo.border_width_top = 2
	estilo.border_width_bottom = 2
	estilo.border_width_left = 2
	estilo.border_width_right = 2
	estilo.border_color = Tema.AMBAR
	estilo.content_margin_left = 24
	estilo.content_margin_right = 24
	estilo.content_margin_top = 18
	estilo.content_margin_bottom = 18
	tarjeta.add_theme_stylebox_override("panel", estilo)
	resumen_partido.add_child(tarjeta)

	contenedor_resumen = VBoxContainer.new()
	contenedor_resumen.add_theme_constant_override("separation", 10)
	tarjeta.add_child(contenedor_resumen)


func _mostrar_resumen_partido() -> void:
	for hijo in contenedor_resumen.get_children():
		hijo.queue_free()
	var r: Dictionary = GameState.ultimo_resultado
	if r.is_empty():
		_volver_al_club()
		return

	contenedor_resumen.add_child(Tema.etiqueta_seccion("Final del partido"))

	var marcador := Label.new()
	var equipo_local_marcador := _equipo_por_nombre(str(r["local"]))
	var equipo_visitante_marcador := _equipo_por_nombre(str(r["visitante"]))
	marcador.text = "%s   %d - %d   %s" % [
		_nombre_marcador(equipo_local_marcador) if equipo_local_marcador != null else r["local"],
		r["gl"], r["gv"],
		_nombre_marcador(equipo_visitante_marcador) if equipo_visitante_marcador != null else r["visitante"]]
	# En un cruce de copa el marcador no alcanza: 1-1 puede ser un pase de
	# ronda o una eliminacion. Se dice como se cerro.
	var definicion := str(r.get("definicion", "90 minutos"))
	if definicion != "90 minutos":
		marcador.text += "
(%s%s)" % [definicion, str(r.get("penales_texto", ""))]
	marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marcador.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tema.numero(marcador, 28)
	contenedor_resumen.add_child(marcador)

	# Quien gano, dicho con todas las letras: un marcador solo obliga a
	# acordarse de cual de los dos sos.
	var mio: String = GameState.equipo_jugador.nombre
	var propios: int = int(r["gl"]) if str(r["local"]) == mio else int(r["gv"])
	var ajenos: int = int(r["gv"]) if str(r["local"]) == mio else int(r["gl"])
	var veredicto := Label.new()
	# El veredicto va en semibold: en rojo sobre fondo oscuro el trazo
	# regular se apagaba y "Quedas eliminado" casi no se leia.
	var fuente_veredicto := Tema.negrita()
	if fuente_veredicto != null:
		veredicto.add_theme_font_override("font", fuente_veredicto)
	# En un cruce de copa manda QUIEN PASO, no el marcador: una tanda de
	# penales ganada deja el partido empatado igual.
	var ganador := str(r.get("ganador", ""))
	if ganador != "":
		if ganador == mio:
			veredicto.text = "Ganaste" if definicion == "90 minutos" else "Pasas de ronda"
			veredicto.add_theme_color_override("font_color", Tema.VERDE)
		else:
			veredicto.text = "Perdiste" if definicion == "90 minutos" else "Quedas eliminado"
			veredicto.add_theme_color_override("font_color", Tema.ROJO)
	elif propios > ajenos:
		veredicto.text = "Ganaste"
		veredicto.add_theme_color_override("font_color", Tema.VERDE)
	elif propios < ajenos:
		veredicto.text = "Perdiste"
		veredicto.add_theme_color_override("font_color", Tema.ROJO)
	else:
		veredicto.text = "Empate"
		veredicto.add_theme_color_override("font_color", Tema.SUAVE)
	veredicto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenedor_resumen.add_child(veredicto)

	# Aca SI van los eventos del partido recien jugado: este cuadro sale
	# apenas termina, antes de que se guarde nada.
	var stats := EstadisticasPartido.calcular(
		GameState.ultimos_eventos, str(r["local"]), str(r["visitante"]))
	var loc: Dictionary = stats[str(r["local"])]
	var vis: Dictionary = stats[str(r["visitante"])]
	contenedor_resumen.add_child(_fila_estadistica(
		"Posesión", "%.0f%%" % loc["posesion_pct"], "%.0f%%" % vis["posesion_pct"],
		float(loc["posesion_pct"]), float(vis["posesion_pct"])))
	contenedor_resumen.add_child(_fila_estadistica(
		"Tiros", str(loc["tiros"]), str(vis["tiros"]),
		float(loc["tiros"]), float(vis["tiros"])))
	contenedor_resumen.add_child(_fila_estadistica(
		"Tiros al arco", str(loc["tiros_al_arco"]), str(vis["tiros_al_arco"]),
		float(loc["tiros_al_arco"]), float(vis["tiros_al_arco"])))
	contenedor_resumen.add_child(_fila_estadistica(
		"Pases completados",
		"%d/%d" % [loc["pases_completados"], loc["pases_intentados"]],
		"%d/%d" % [vis["pases_completados"], vis["pases_intentados"]],
		float(loc["pases_completados"]), float(vis["pases_completados"])))

	var goleadores := _texto_goleadores()
	if goleadores != "":
		var l := Label.new()
		l.text = goleadores
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		l.add_theme_color_override("font_color", Tema.SUAVE)
		contenedor_resumen.add_child(l)

	# Una sola salida. Estuvo un "Seguir viendo" que sacaba el cuadro y te
	# devolvia a la cancha, pero al final del partido ya no hay nada que
	# mirar: los 22 quedan parados en el ultimo fotograma.
	var btn_cerrar := Button.new()
	btn_cerrar.text = "Cerrar"
	btn_cerrar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	Tema.primario(btn_cerrar)
	btn_cerrar.pressed.connect(func():
		resumen_partido.visible = false
		_mostrar_seccion("jugar"))
	contenedor_resumen.add_child(btn_cerrar)

	resumen_partido.visible = true


## Una fila de la comparacion, con barra: el numero solo no dice quien
## domino, y la barra se lee de un vistazo aunque el numero sea chico.
func _fila_estadistica(titulo: String, izq: String, der: String,
		valor_izq: float, valor_der: float) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)

	var fila := HBoxContainer.new()
	caja.add_child(fila)
	var l_izq := Componentes.celda_numero(izq, 80, Tema.TEXTO)
	fila.add_child(l_izq)
	var l_medio := Label.new()
	l_medio.text = titulo
	l_medio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_medio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_medio.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	l_medio.add_theme_color_override("font_color", Tema.SUAVE)
	fila.add_child(l_medio)
	fila.add_child(Componentes.celda_numero(der, 80, Tema.TEXTO,
		HORIZONTAL_ALIGNMENT_RIGHT))

	var barras := HBoxContainer.new()
	barras.add_theme_constant_override("separation", 3)
	caja.add_child(barras)
	var total: float = maxf(valor_izq + valor_der, 0.001)
	barras.add_child(_barra_mitad(valor_izq / total, Tema.CELESTE, false))
	barras.add_child(_barra_mitad(valor_der / total, Tema.AMBAR, true))
	return caja


func _barra_mitad(fraccion: float, color: Color, derecha: bool) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 7)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = maxf(fraccion, 0.02)
	var e := StyleBoxFlat.new()
	e.bg_color = color
	if derecha:
		e.corner_radius_top_right = 4
		e.corner_radius_bottom_right = 4
	else:
		e.corner_radius_top_left = 4
		e.corner_radius_bottom_left = 4
	p.add_theme_stylebox_override("panel", e)
	return p


## Quien hizo los goles, que es lo primero que se busca al terminar.
func _texto_goleadores() -> String:
	var r: Dictionary = GameState.ultimo_resultado
	var local := _equipo_por_nombre(str(r.get("local", "")))
	var visitante := _equipo_por_nombre(str(r.get("visitante", "")))
	var partes := []
	for gol in r.get("goles_log", []):
		# El log guarda el ID, no el nombre: se resuelve contra los dos
		# planteles, que es donde estan los jugadores de este partido.
		var nombre := "?"
		for equipo in [local, visitante]:
			if equipo == null:
				continue
			var j := _buscar_jugador_por_id(equipo, int(gol.get("jugador_id", -1)))
			if not j.is_empty():
				nombre = _nombre_jugador(j)
				break
		partes.append("%d' %s" % [int(gol.get("minuto", 0)), nombre])
	if partes.is_empty():
		return ""
	return "Goles:  %s" % "   ·   ".join(partes)


## §11: la economia del club. Cuatro cajas separadas —fichajes,
## contratos, mejoras y mantenimiento— y no se puede pasar plata de una a
## otra, por eso no hay un "total": sumarlas no te dice cuanto podes
## gastar en nada concreto.
func _construir_panel_economia(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["economia"] = panel

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_economia = VBoxContainer.new()
	contenedor_economia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_economia)


## Una caja de presupuesto. El numero grande es el RESTANTE porque es lo
## unico que se puede gastar hoy; lo gastado y contra que se mide van
## abajo, chicos, y la barra los muestra de un vistazo.
##
## `asignado` es lo que reparte el cierre de temporada. `disponible` es lo
## que quedaba cuando el club agarro el control, ya descontada la
## intertemporada. Los dos numeros hacen falta: la barra y el pie miden
## contra `disponible`, que es el unico cero real contra el que el jugador
## gasta, y cuando difieren la caja muestra la diferencia en vez de
## esconderla. Antes el pie decia "gastaste $639 de $8,025" con $519
## restantes: los tres numeros no cerraban entre si, asi que cualquier
## renovacion parecia descontar de mas.
func _caja_presupuesto(categoria: String, asignado: float, disponible: float,
		usado: float, restante: float) -> Control:
	var caja := Componentes.tarjeta(Tema.ROJO if restante < 0.0 else Color.TRANSPARENT)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.tooltip_text = "El presupuesto se REINICIA cada temporada: lo que no gastaste no se acumula, la deuda si se arrastra."
	var dentro := VBoxContainer.new()
	dentro.add_theme_constant_override("separation", 4)
	caja.add_child(dentro)
	dentro.add_child(Tema.etiqueta_seccion(categoria))

	var l := Label.new()
	l.text = Economia.formato_dinero(restante)
	Tema.numero(l, 24, Tema.ROJO if restante < 0.0 else Tema.TEXTO)
	dentro.add_child(l)

	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.value = clampf(usado / disponible, 0.0, 1.0) if disponible > 0.0 else 0.0
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 6)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Tema.PANEL_ALTO
	barra.add_theme_stylebox_override("background", fondo)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Tema.ROJO if restante < 0.0 else Tema.AMBAR
	barra.add_theme_stylebox_override("fill", relleno)
	dentro.add_child(barra)

	var pie := Label.new()
	pie.text = "gastaste %s de %s" % [
		Economia.formato_dinero(usado), Economia.formato_dinero(disponible)]
	pie.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	pie.add_theme_color_override("font_color", Tema.SUAVE)
	pie.clip_text = true
	dentro.add_child(pie)

	# La intertemporada gasta sola: los contratos que se vencen vuelven a
	# entrar pagando sueldo de mercado (AgentesLibres.liberar) y los
	# canteranos que suben cobran ficha. Sin esta linea esa plata
	# desaparecia del presupuesto sin que ninguna pantalla la nombrara.
	var comido: float = asignado - disponible
	if comido > 0.5:
		var nota_intertemporada := Label.new()
		nota_intertemporada.text = "la intertemporada se llevo %s de los %s asignados" % [
			Economia.formato_dinero(comido), Economia.formato_dinero(asignado)]
		nota_intertemporada.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		nota_intertemporada.add_theme_color_override("font_color", Tema.AMBAR)
		nota_intertemporada.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dentro.add_child(nota_intertemporada)
	return caja


## Una linea del balance: concepto a la izquierda, plata a la derecha.
## `fuerte` es para los totales; `sangria` para el desglose de egresos.
func _linea_balance(concepto: String, monto: float, color: Color,
		sangria: int = 0, fuerte: bool = false) -> Control:
	var fila := HBoxContainer.new()
	if sangria > 0:
		var hueco := Control.new()
		hueco.custom_minimum_size = Vector2(sangria, 0)
		fila.add_child(hueco)
	var izq := Label.new()
	izq.text = concepto
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_color_override("font_color", Tema.TEXTO if fuerte else Tema.SUAVE)
	fila.add_child(izq)
	var der := Label.new()
	der.text = Economia.formato_dinero(monto)
	der.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	der.custom_minimum_size = Vector2(200, 0)
	Tema.numero(der, Tema.TAM_BASE if fuerte else Tema.TAM_CHICO, color)
	fila.add_child(der)
	return fila


func _refrescar_economia() -> void:
	if contenedor_economia == null:
		return
	for hijo in contenedor_economia.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador

	if equipo.quebrado:
		var aviso := Componentes.tarjeta(Tema.ROJO)
		var l := Label.new()
		l.text = "EN QUIEBRA — el club se esta liquidando: se venden jugadores hasta salir del rojo."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Tema.ROJO)
		aviso.add_child(l)
		contenedor_economia.add_child(aviso)

	# Primero los presupuestos: es lo unico que podes gastar hoy.
	contenedor_economia.add_child(Tema.etiqueta_seccion(
		"Presupuestos · lo que te queda por categoria"))
	var grilla := HBoxContainer.new()
	grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_economia.add_child(grilla)
	for categoria in Economia.CATEGORIAS_CAJA:
		var asignado: float = equipo.presupuesto_temporada.get(categoria, 0.0)
		var restante: float = equipo.caja.get(categoria, 0.0)
		# El cero contra el que se mide lo gastado no es lo asignado, sino lo
		# que quedaba al terminar la intertemporada: ver _caja_presupuesto.
		var disponible: float = equipo.caja_al_cierre.get(categoria, 0.0)
		var usado: float = disponible - restante
		grilla.add_child(_caja_presupuesto(
			str(categoria).capitalize(), asignado, disponible, usado, restante))

	var nota := Label.new()
	nota.text = "No se puede pasar plata de una caja a otra: por eso no hay un total. El presupuesto se reinicia cada temporada — lo que no gastaste no se acumula, la deuda si se arrastra."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	nota.add_theme_color_override("font_color", Tema.SUAVE)
	contenedor_economia.add_child(nota)

	contenedor_economia.add_child(Tema.etiqueta_seccion("Ultimo balance de temporada"))
	var tarjeta := Componentes.tarjeta()
	contenedor_economia.add_child(tarjeta)
	var caja_balance := VBoxContainer.new()
	tarjeta.add_child(caja_balance)

	var informe: Dictionary = GameState.ultimo_informe_economico
	if informe.is_empty():
		var vacio := Label.new()
		vacio.text = "Todavia no cerraste una temporada. La plata entra al terminar la fecha 38: entradas, sponsor, premio segun donde termines en la tabla y lo que hayas ganado en las copas."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vacio.add_theme_color_override("font_color", Tema.SUAVE)
		caja_balance.add_child(vacio)
	else:
		caja_balance.add_child(_linea_balance(
			"Ingresos", informe["ingresos"], Tema.VERDE, 0, true))
		# Solo si hubo: una linea en cero todas las temporadas es ruido.
		var premios: float = float(informe.get("premios_copa", 0.0))
		if premios > 0.0:
			caja_balance.add_child(_linea_balance(
				"de los cuales, premios de copa", premios, Tema.AMBAR, 24))
		var por_sponsors: float = float(informe.get("sponsors", 0.0))
		if por_sponsors > 0.0:
			caja_balance.add_child(_linea_balance(
				"de los cuales, sponsors", por_sponsors, Tema.AMBAR, 24))
		caja_balance.add_child(_linea_balance(
			"Egresos", -absf(informe["egresos"]), Tema.ROJO, 0, true))
		caja_balance.add_child(_linea_balance(
			"de los cuales, sueldos", informe["sueldos"], Tema.SUAVE, 24))
		caja_balance.add_child(_linea_balance(
			"de los cuales, mantenimiento", informe["mantenimiento"], Tema.SUAVE, 24))
		var neto: float = informe["neto"]
		caja_balance.add_child(_linea_balance(
			"Neto", neto, Tema.VERDE if neto >= 0.0 else Tema.ROJO, 0, true))

	contenedor_economia.add_child(Tema.etiqueta_seccion("El club"))
	var fila_club := HBoxContainer.new()
	fila_club.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_economia.add_child(fila_club)

	var sueldos := 0.0
	for id in equipo.sueldos:
		sueldos += equipo.sueldos[id]
	var valor_plantel := 0.0
	for j in equipo.jugadores:
		valor_plantel += ValorJugador.calcular(
			j, equipo.animo.get(j["id"], 50.0), equipo.contratos.get(j["id"], 1))

	fila_club.add_child(_caja_numero("Reputación", "%.1f" % equipo.reputacion, Tema.TEXTO))
	# El color va por el APOYO (que tan grande es para su categoria) y no
	# por el numero: 30.000 hinchas es una barbaridad en decima y una
	# miseria en primera.
	fila_club.add_child(_caja_numero("Hinchas", Fans.texto(equipo.fans),
		Componentes.color_de_valor(int(Fans.apoyo(equipo, equipo.division_actual) * 100.0))))
	fila_club.add_child(_caja_numero("Masa salarial",
		Economia.formato_dinero(sueldos), Tema.TEXTO))
	fila_club.add_child(_caja_numero("Valor del plantel",
		Economia.formato_dinero(valor_plantel), Tema.TEXTO))

	var explica := Label.new()
	explica.text = "Todos los clubes arrancan con 0 hinchas: se ganan ganando, se pierden con una racha larga sin ganar, y ascender o descender pesa fuerte. Mas hinchas = mas gente en el estadio y mas ingreso por entradas. Racha sin ganar: %d. La masa salarial es la de HOY: puede diferir del balance si fichaste despues." % equipo.racha_sin_ganar
	explica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explica.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	explica.add_theme_color_override("font_color", Tema.SUAVE)
	contenedor_economia.add_child(explica)


## Fase 9, extendido con mercado más profundo: mercado iniciado por el
## §9.3 rework: el mercado tiene cuatro solapas —Jugadores, Ofertas
## enviadas, Ofertas recibidas e Historial— porque una negociacion ya no
## se resuelve en el acto: dura dias y hay varias abiertas a la vez.
##
## La logica de filtrar, tapar y ordenar vive en core/busqueda_mercado.gd
## y la de negociar en core/ofertas.gd; aca solo se dibuja.
var filtros_mercado: Dictionary = BusquedaMercado.filtros_vacios()
var resultados_mercado: Array = []
var orden_mercado: String = "nombre"
var orden_mercado_asc: bool = true
var contenedor_mercado_tabla: VBoxContainer
var label_mercado_resumen: Label
var option_pos_mercado: OptionButton
var option_div_mercado: OptionButton
var option_club_mercado: OptionButton
var grupo_club_mercado: Control
var spin_edad_min: SpinBox
var spin_edad_max: SpinBox
var spin_contrato: SpinBox

var solapas_mercado: Dictionary = {}
var solapa_mercado_actual: String = "jugadores"
var botones_solapa_mercado: Dictionary = {}
var contenedor_enviadas: VBoxContainer
var contenedor_recibidas: VBoxContainer
var contenedor_historial: VBoxContainer
var contenedor_investigaciones: VBoxContainer
var contenedor_portada: VBoxContainer


func _construir_panel_mercado(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["mercado"] = panel

	var barra_scroll := ScrollContainer.new()
	barra_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	barra_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(barra_scroll)
	var barra := HBoxContainer.new()
	barra_scroll.add_child(barra)
	for entrada in [["jugadores", "Jugadores"], ["enviadas", "Ofertas enviadas"],
			["recibidas", "Ofertas recibidas"], ["historial", "Historial"],
			["investigaciones", "Investigaciones"]]:
		var btn := Button.new()
		btn.text = entrada[1]
		btn.custom_minimum_size = Vector2(0, 44)
		var clave := str(entrada[0])
		btn.pressed.connect(func(): _mostrar_solapa_mercado(clave))
		barra.add_child(btn)
		botones_solapa_mercado[clave] = btn

	label_mercado_estado = Label.new()
	label_mercado_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_mercado_estado.text = ""
	panel.add_child(label_mercado_estado)

	var cuerpo := Control.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(cuerpo)

	solapas_mercado["jugadores"] = _construir_solapa_jugadores(cuerpo)
	contenedor_enviadas = VBoxContainer.new()
	solapas_mercado["enviadas"] = _solapa_con_scroll(cuerpo, contenedor_enviadas)
	contenedor_recibidas = VBoxContainer.new()
	solapas_mercado["recibidas"] = _solapa_con_scroll(cuerpo, contenedor_recibidas)
	contenedor_historial = VBoxContainer.new()
	solapas_mercado["historial"] = _solapa_con_scroll(cuerpo, contenedor_historial)
	contenedor_investigaciones = VBoxContainer.new()
	solapas_mercado["investigaciones"] = _solapa_con_scroll(cuerpo, contenedor_investigaciones)
	_mostrar_solapa_mercado("jugadores")


func _solapa_con_scroll(padre: Control, contenido: VBoxContainer) -> Control:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.visible = false
	padre.add_child(scroll)
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenido)
	return scroll


## Un filtro con su titulo ARRIBA. Al lado, el par titulo+control mide
## casi el doble de ancho, y con cuatro filtros eso no entra en una
## pantalla de telefono.
func _grupo_filtro(titulo: String, control: Control) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	caja.add_child(Tema.etiqueta_seccion(titulo))
	caja.add_child(control)
	return caja


func _construir_solapa_jugadores(padre: Control) -> Control:
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padre.add_child(caja)

	# Los filtros en un contenedor que ENVUELVE, y cada uno con su titulo
	# ARRIBA en vez de al lado. En una sola fila con "Puesto:" al costado la
	# barra medía mas que la pantalla y el boton Buscar quedaba fuera del
	# viewport: sin el boton, la pantalla entera no servia para nada.
	var filtros := HFlowContainer.new()
	filtros.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filtros.add_theme_constant_override("h_separation", 12)
	filtros.add_theme_constant_override("v_separation", 8)
	caja.add_child(filtros)

	option_pos_mercado = OptionButton.new()
	option_pos_mercado.add_item("Cualquiera")
	for pos in BusquedaMercado.POSICIONES:
		option_pos_mercado.add_item(pos)
	option_pos_mercado.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	filtros.add_child(_grupo_filtro("Puesto", option_pos_mercado))

	option_div_mercado = OptionButton.new()
	option_div_mercado.add_item("Cualquiera")
	for d in range(10):
		option_div_mercado.add_item("D%d" % (d + 1))
	option_div_mercado.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	option_div_mercado.item_selected.connect(func(_i): _refrescar_clubes_del_filtro())
	filtros.add_child(_grupo_filtro("Division", option_div_mercado))

	# El club solo aparece con una division elegida: sin eso serian los 200
	# clubes de la piramide en una sola lista, que no se puede tocar en un
	# telefono.
	option_club_mercado = OptionButton.new()
	option_club_mercado.custom_minimum_size = Vector2(210, Tema.ALTO_TACTIL)
	grupo_club_mercado = _grupo_filtro("Club", option_club_mercado)
	grupo_club_mercado.visible = false
	filtros.add_child(grupo_club_mercado)

	var caja_edad := HBoxContainer.new()
	caja_edad.add_theme_constant_override("separation", 6)
	spin_edad_min = _spin(0, 45, 0)
	spin_edad_min.custom_minimum_size = Vector2(96, Tema.ALTO_TACTIL)
	caja_edad.add_child(spin_edad_min)
	var a := Label.new()
	a.text = "a"
	a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a.add_theme_color_override("font_color", Tema.SUAVE)
	caja_edad.add_child(a)
	spin_edad_max = _spin(0, 45, 0)
	spin_edad_max.custom_minimum_size = Vector2(96, Tema.ALTO_TACTIL)
	caja_edad.add_child(spin_edad_max)
	filtros.add_child(_grupo_filtro("Edad  (0 = sin limite)", caja_edad))

	spin_contrato = _spin(0, 6, 0)
	spin_contrato.custom_minimum_size = Vector2(110, Tema.ALTO_TACTIL)
	filtros.add_child(_grupo_filtro("Contrato hasta  (0 = cualquiera)", spin_contrato))

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	var btn_buscar := Button.new()
	btn_buscar.text = "Buscar"
	btn_buscar.custom_minimum_size = Vector2(140, Tema.ALTO_TACTIL)
	Tema.primario(btn_buscar)
	btn_buscar.pressed.connect(_on_buscar_mercado)
	acciones.add_child(btn_buscar)
	var btn_limpiar := Button.new()
	btn_limpiar.text = "Limpiar"
	btn_limpiar.custom_minimum_size = Vector2(120, Tema.ALTO_TACTIL)
	btn_limpiar.tooltip_text = "Deja todos los filtros en cualquiera."
	btn_limpiar.pressed.connect(func():
		option_pos_mercado.selected = 0
		option_div_mercado.selected = 0
		_refrescar_clubes_del_filtro()
		spin_edad_min.value = 0
		spin_edad_max.value = 0
		spin_contrato.value = 0
		_on_buscar_mercado()
	)
	acciones.add_child(btn_limpiar)
	filtros.add_child(_grupo_filtro(" ", acciones))

	label_mercado_resumen = Label.new()
	label_mercado_resumen.text = "Ponele los filtros que quieras (todos opcionales) y toca Buscar."
	caja.add_child(label_mercado_resumen)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(scroll)

	# Filas y no una grilla: la grilla no puede fusionar celdas, y el bloque
	# "sin investigar" tiene que ocupar el lugar de las cinco columnas
	# tapadas de una (ver Componentes.bloque_tapado). Cada fila es un HBox
	# de celdas de ancho fijo, los mismos anchos que usa el encabezado.
	contenedor_mercado_tabla = VBoxContainer.new()
	scroll.add_child(contenedor_mercado_tabla)
	return caja


func _mostrar_solapa_mercado(clave: String) -> void:
	solapa_mercado_actual = clave
	for k in solapas_mercado:
		solapas_mercado[k].visible = (k == clave)
	match clave:
		"jugadores": _refrescar_mercado()
		"enviadas": _refrescar_ofertas(contenedor_enviadas, false)
		"recibidas": _refrescar_ofertas(contenedor_recibidas, true)
		"historial": _refrescar_historial()
		"investigaciones": _refrescar_investigaciones()
	_actualizar_titulos_solapas()


## El numero al lado de "Ofertas recibidas" es lo que hace que la solapa
## se mire: sin eso, una oferta por tu goleador se pierde en el feed.
func _actualizar_titulos_solapas() -> void:
	var equipo := GameState.equipo_jugador
	var pendientes := {"enviadas": 0, "recibidas": 0}
	for o in equipo.ofertas:
		if str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS or \
				(str(o["estado"]) == Ofertas.ACUERDO_CLUB and not bool(o["entrante"])):
			pendientes["recibidas" if bool(o["entrante"]) else "enviadas"] += 1
	for clave in pendientes:
		var base: String = "Ofertas enviadas" if clave == "enviadas" else "Ofertas recibidas"
		var n: int = pendientes[clave]
		botones_solapa_mercado[clave].text = base if n == 0 else "%s (%d)" % [base, n]


func _etiqueta(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	return l


## Etiqueta con ancho TOPE y puntos suspensivos. La usan las columnas de
## texto largo de la tabla del mercado: un nombre de club como
## "Estudiantes Sol Naciente" ensanchaba la grilla lo suficiente como para
## que los botones de accion arrancaran fuera de pantalla en un telefono
## angosto. El texto completo queda en el tooltip, asi que no se pierde.
func _etiqueta_corta(texto: String, ancho: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.tooltip_text = texto
	l.custom_minimum_size = Vector2(ancho, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _spin(minimo: int, maximo: int, valor: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = minimo
	sb.max_value = maximo
	sb.value = valor
	sb.custom_minimum_size = Vector2(70, 44)
	return sb


## 0 en un spin = "sin filtro", por eso se traduce a -1.
## Llena el desplegable de clubes con los de la division elegida. Se
## rearma cada vez porque los 20 clubes de una division cambian entre
## temporadas: los que ascienden y descienden se van.
func _refrescar_clubes_del_filtro() -> void:
	var division: int = option_div_mercado.selected - 1
	option_club_mercado.clear()
	grupo_club_mercado.visible = division >= 0
	if division < 0:
		return
	option_club_mercado.add_item("Cualquiera")
	var nombres := []
	for club in GameState.piramide.divisiones[division].equipos:
		# El propio no: el buscador del mercado nunca muestra tus jugadores.
		if club != GameState.equipo_jugador:
			nombres.append(club.nombre)
	nombres.sort()
	for n in nombres:
		option_club_mercado.add_item(n)


func _on_buscar_mercado() -> void:
	filtros_mercado = {
		"posicion": "" if option_pos_mercado.selected <= 0 else option_pos_mercado.get_item_text(option_pos_mercado.selected),
		"division": option_div_mercado.selected - 1,
		"club": "" if option_club_mercado.selected <= 0 			else option_club_mercado.get_item_text(option_club_mercado.selected),
		"edad_min": -1 if int(spin_edad_min.value) == 0 else int(spin_edad_min.value),
		"edad_max": -1 if int(spin_edad_max.value) == 0 else int(spin_edad_max.value),
		"contrato_max": -1 if int(spin_contrato.value) == 0 else int(spin_contrato.value),
	}
	orden_mercado = "nombre"
	orden_mercado_asc = true
	# Se guardan las ENTRADAS, no las fichas: la ficha (y con ella el
	# avance del informe, el valor y el animo) se recalcula en cada
	# refresco. Cacheandola, el boton Investigar quedaba clavado en el
	# porcentaje del momento en que apretaste Buscar y no se movia nunca
	# aunque pasaran temporadas.
	resultados_mercado = BusquedaMercado.buscar(
		GameState.piramide, GameState.equipo_jugador, filtros_mercado)
	_refrescar_mercado()


func _on_ordenar_mercado(clave: String) -> void:
	if orden_mercado == clave:
		orden_mercado_asc = not orden_mercado_asc
	else:
		orden_mercado = clave
		orden_mercado_asc = true
	_refrescar_mercado()


func _refrescar_mercado() -> void:
	if contenedor_mercado_tabla == null:
		return
	for hijo in contenedor_mercado_tabla.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador
	var libres: int = Investigadores.libres(equipo).size()
	label_mercado_resumen.text = "%d jugadores  ·  investigadores %d de %d libres" % [
		resultados_mercado.size(), libres, equipo.investigadores.size()]
	_actualizar_titulos_solapas()

	if resultados_mercado.is_empty():
		return

	# La ficha se recalcula en cada refresco y no se cachea: el avance del
	# informe, el valor y el animo viven ahi, y guardarlos dejaba la tabla
	# mostrando una foto vieja.
	var fichas := []
	for entrada in resultados_mercado:
		var f := BusquedaMercado.ficha(GameState.equipo_jugador, entrada)
		f["equipo"] = entrada["equipo"]
		fichas.append(f)
	fichas = BusquedaMercado.ordenar(fichas, orden_mercado, orden_mercado_asc)

	contenedor_mercado_tabla.add_child(_encabezado_mercado(
		orden_mercado, orden_mercado_asc, _on_ordenar_mercado))
	# Un tope: la piramide tiene ~3.600 jugadores y dibujarlos a todos cuelga
	# la pantalla. Con los filtros y el orden, 60 alcanzan.
	for i in range(min(60, fichas.size())):
		contenedor_mercado_tabla.add_child(_fila_mercado(fichas[i], i % 2 == 0))


## El encabezado. Cada columna es un boton que ordena: lo desconocido va
## al final (ver BusquedaMercado.ordenar). Lo comparten la tabla de
## Jugadores y las dos de Investigaciones, que usan la misma fila.
## `al_ordenar` vacio = titulos quietos, para una lista que no se ordena.
## `con_informe` agrega el titulo que ordena por dias de informe, sobre la
## columna del boton Investigar.
func _encabezado_mercado(orden: String, ascendente: bool, al_ordenar: Callable,
		con_informe: bool = false) -> Control:
	var fila := Componentes.fila(false)
	var dentro := Componentes.contenido(fila)
	var columnas := []
	for col in BusquedaMercado.COLUMNAS:
		columnas.append([str(col["clave"]), str(col["titulo"])])
	columnas.append(["club", "Club"])
	if con_informe:
		columnas.append(["vigencia", "Informe"])
	for par in columnas:
		var clave: String = par[0]
		var titulo: String = par[1]
		if orden == clave:
			titulo += " ↑" if ascendente else " ↓"
		# El titulo se alinea como la celda que encabeza, o la columna se
		# lee torcida: los numeros van pegados a la derecha y el titulo
		# quedaba pegado a la izquierda, a 60 px de sus propias cifras.
		var btn := Componentes.boton_de_celda(titulo, _ancho_de_columna(clave),
			_alineacion_de_columna(clave),
			Tema.AMBAR if orden == clave else Tema.SUAVE)
		if al_ordenar.is_valid():
			btn.pressed.connect(func(): al_ordenar.call(clave))
		else:
			btn.disabled = true
		dentro.add_child(btn)
	return fila


func _ancho_de_columna(clave: String) -> int:
	match clave:
		"nombre": return Componentes.COL_NOMBRE
		"edad": return Componentes.COL_EDAD
		"posicion": return Componentes.COL_POS
		"media": return Componentes.COL_MEDIA
		"valor": return Componentes.COL_VALOR
		"salario": return Componentes.COL_SALARIO
		"contrato": return Componentes.COL_CONTRATO
		"animo": return Componentes.COL_ANIMO
		"club": return Componentes.COL_CLUB
		"vigencia": return Componentes.COL_ACCION
	return 90


## Como se alinea el contenido de cada columna del mercado. El encabezado
## la copia: una cifra a la derecha con su titulo a la izquierda no se lee
## como la misma columna.
func _alineacion_de_columna(clave: String) -> int:
	match clave:
		"nombre", "club": return HORIZONTAL_ALIGNMENT_LEFT
		"posicion", "vigencia": return HORIZONTAL_ALIGNMENT_CENTER
	return HORIZONTAL_ALIGNMENT_RIGHT


func _fila_mercado(f: Dictionary, par: bool) -> Control:
	var equipo := GameState.equipo_jugador
	var fila := Componentes.fila(par)
	var dentro := Componentes.contenido(fila)
	var vendedor: Team = f["equipo"]
	var jugador_id := int(f["id"])
	var conocido: bool = bool(f["conocido"])

	# Nombre: entra a la ficha, pero solo si lo investigaste.
	var btn_nombre := Componentes.boton_de_celda(str(f["nombre"]),
		Componentes.COL_NOMBRE, HORIZONTAL_ALIGNMENT_LEFT,
		Tema.CELESTE if conocido else Tema.SUAVE.darkened(0.25))
	btn_nombre.disabled = not conocido
	if conocido:
		btn_nombre.pressed.connect(func(): _mostrar_ficha(jugador_id, vendedor))
	dentro.add_child(btn_nombre)

	# La edad se sabe SIEMPRE: en el futbol es publica.
	dentro.add_child(Componentes.celda_numero(str(f["edad"]), Componentes.COL_EDAD,
		Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT, Componentes.TAM_TABLA))

	var caja_pos := CenterContainer.new()
	caja_pos.custom_minimum_size = Vector2(Componentes.COL_POS, 0)
	caja_pos.add_child(Componentes.chip(str(f["posicion"]), Color("#2f4a3c")))
	dentro.add_child(caja_pos)

	if conocido:
		dentro.add_child(Componentes.celda_numero("%.1f" % float(f["media"]), Componentes.COL_MEDIA,
			Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT, Componentes.TAM_TABLA))
		dentro.add_child(Componentes.celda_numero(
			Economia.formato_dinero(f["valor"]), Componentes.COL_VALOR,
			Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT, Componentes.TAM_TABLA))
		dentro.add_child(Componentes.celda_numero(
			Economia.formato_dinero(f["salario"]), Componentes.COL_SALARIO,
			Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT, Componentes.TAM_TABLA))
		dentro.add_child(Componentes.celda_numero(
			"%d años" % int(f["contrato"]), Componentes.COL_CONTRATO,
			Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT, Componentes.TAM_TABLA))
		dentro.add_child(Componentes.celda_numero(str(int(f["animo"])), Componentes.COL_ANIMO,
			Componentes.color_de_valor(int(f["animo"])),
			HORIZONTAL_ALIGNMENT_RIGHT, Componentes.TAM_TABLA))
	elif float(f["progreso"]) >= 0.0:
		var inv := Investigadores.progreso(equipo, jugador_id)
		var faltan := _dias_que_faltan(equipo, jugador_id)
		dentro.add_child(Componentes.bloque_investigando(
			Componentes.COL_TAPADAS, inv, faltan))
	else:
		dentro.add_child(Componentes.bloque_tapado(Componentes.COL_TAPADAS))

	dentro.add_child(Componentes.celda(
		"%s D%d" % [str(f["club"]), int(f["division"])], Componentes.COL_CLUB, Tema.SUAVE,
		HORIZONTAL_ALIGNMENT_LEFT, Componentes.TAM_TABLA))

	# --- Acciones ----------------------------------------------------------
	# Dos botones y no tres. Comprar y Prestamo eran dos columnas separadas
	# y entre las tres acciones la fila medía 1.270 px contra 1.010 de
	# pantalla: el ultimo boton quedaba fuera del viewport. Son las dos
	# formas de quedarse con el MISMO jugador, asi que van juntas bajo
	# "Fichar" y se elige adentro.
	var btn_inv: Button
	if conocido:
		# Los dias a la vista y no solo "Conocido": en Investigaciones la
		# lista se ordena por esto, y un numero sin mostrar no se entiende.
		var quedan := Investigadores.vigencia(equipo, jugador_id)
		var pronto := quedan < Investigadores.DIAS_VENCE_PRONTO
		# "Conocido · 540 días" no entra en COL_ACCION: con el relleno del
		# boton pasa los 140 px y se recorta. El tooltip dice el resto.
		btn_inv = Componentes.boton_de_accion("%d días" % quedan, Componentes.COL_ACCION)
		btn_inv.tooltip_text = "El informe vence en %d días." % quedan
		btn_inv.disabled = true
		btn_inv.add_theme_color_override("font_disabled_color",
			Tema.ROJO if pronto else Tema.SUAVE)
	elif float(f["progreso"]) >= 0.0:
		# Cancelar desde la fila misma: antes habia que ir a otra solapa.
		var id_inv := -1
		for inv in equipo.investigadores:
			if int(inv["objetivo"]) == jugador_id:
				id_inv = int(inv["id"])
		btn_inv = _boton_cancelar_informe(id_inv)
	else:
		btn_inv = Componentes.boton_de_accion("Investigar", Componentes.COL_ACCION)
		btn_inv.disabled = Investigadores.libres(equipo).is_empty()
		if btn_inv.disabled:
			btn_inv.tooltip_text = "No tenes investigadores libres. Se contratan en Equipo › Instalaciones."
		btn_inv.add_theme_color_override("font_color", Tema.AMBAR)
		btn_inv.pressed.connect(func(): _on_investigar(vendedor, jugador_id))
	dentro.add_child(btn_inv)

	var traba := _traba_para_fichar(vendedor, jugador_id)
	if not traba.is_empty():
		dentro.add_child(_boton_fichar_apagado(traba[0], traba[1]))
	else:
		var menu := MenuButton.new()
		menu.text = "Fichar"
		menu.custom_minimum_size = Vector2(Componentes.COL_FICHAR, 0)
		menu.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		menu.clip_text = true
		menu.flat = false
		var pop := menu.get_popup()
		pop.add_item("Comprar", 0)
		pop.add_item("Pedir a préstamo", 1)
		var donde := Mercado.ubicar(vendedor, jugador_id)
		if not donde.is_empty() and not Mercado.puede_comprarse(
				donde["jugador"], GameState.temporada_actual):
			var indice_compra := pop.get_item_index(0)
			pop.set_item_disabled(indice_compra, true)
			pop.set_item_tooltip(indice_compra, Mercado.MOTIVO_RECIEN_COMPRADO)
		pop.id_pressed.connect(func(id: int):
			if id == 0:
				_abrir_negociacion(vendedor, jugador_id)
			else:
				_abrir_prestamo(vendedor, jugador_id)
		)
		dentro.add_child(menu)
	return fila


## [texto, ayuda] de lo que impide ofertar por el jugador; vacio si nada.
## La usan la fila del mercado y la ficha, para que las dos digan lo mismo.
func _traba_para_fichar(vendedor: Team, jugador_id: int) -> Array:
	if Negociacion.bloqueado(vendedor, jugador_id, GameState.temporada_actual):
		return ["Vetado",
			"Te ofendieron con la ultima oferta. Vuelven a escucharte la temporada que viene."]
	for o in GameState.equipo_jugador.ofertas:
		if int(o["jugador_id"]) == jugador_id and Ofertas.abierta(o):
			return ["En curso",
				"Ya tenes una negociacion abierta por el. Miralo en Ofertas enviadas."]
	return []


## El lugar del boton Fichar cuando no se puede fichar. Ocupa el MISMO
## ancho: si desapareciera, la fila se desalinearia con las de al lado.
func _boton_fichar_apagado(texto: String, ayuda: String) -> Button:
	var b := Componentes.boton_de_accion(texto, Componentes.COL_FICHAR)
	b.tooltip_text = ayuda
	b.disabled = true
	return b



## Cuantos dias le faltan al informe de este jugador. -1 si no hay ninguno.
func _dias_que_faltan(equipo: Team, jugador_id: int) -> int:
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == jugador_id:
			return int(ceil(
				Investigadores.dias_de_informe(int(inv["estrellas"])) - float(inv["dias"])))
	return -1


## Filtros de Conocidos. Viven fuera de los controles porque la solapa se
## rearma entera en cada refresco: si el estado viviera en el OptionButton,
## se perderia al tocar cualquier cosa.
var filtro_conocidos_posicion: String = ""
var filtro_conocidos_division: int = -1
var filtro_conocidos_pronto: bool = false
var orden_conocidos: String = "vigencia"
var orden_conocidos_asc: bool = true


## Mercado › Investigaciones: a quien estas mirando y a quien ya conoces.
## Contratar y despedir investigadores no vive aca sino en Instalaciones,
## que es donde se decide en que gasta el club.
##
## Las dos listas usan la MISMA fila que la tabla de Jugadores. Antes eran
## tarjetas y celdas de anchos propios: la solapa parecia de otro juego, y
## desde un conocido no se podia fichar sin volver a buscarlo.
##
## Arriba de todo va cuantos investigadores tenes y un boton que lleva
## derecho a contratarlos. Es la pregunta que aparece sola al entrar acá
## —"¿y dónde compro investigadores?"— y la respuesta estaba a tres
## clicks, en otra seccion.
func _refrescar_investigaciones() -> void:
	for hijo in contenedor_investigaciones.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var indice := _indice_de_jugadores()
	contenedor_investigaciones.add_child(_cabecera_investigaciones(equipo))

	# --- En curso ----------------------------------------------------------
	var en_curso := []
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) != -1:
			en_curso.append(inv)
	contenedor_investigaciones.add_child(Tema.etiqueta_seccion(
		"Informes en curso (%d)" % en_curso.size()))
	if en_curso.is_empty():
		contenedor_investigaciones.add_child(_tarjeta_vacia(
			"Nadie bajo la lupa. Los investigadores libres estan esperando orden: elegi a quien mirar desde la solapa Jugadores."))
	else:
		contenedor_investigaciones.add_child(_encabezado_mercado("", true, Callable()))
		for i in range(en_curso.size()):
			var inv: Dictionary = en_curso[i]
			var id := int(inv["objetivo"])
			if indice.has(id):
				contenedor_investigaciones.add_child(
					_fila_mercado(_ficha_de_indice(indice[id]), i % 2 == 0))
			else:
				contenedor_investigaciones.add_child(_fila_objetivo_perdido(inv, i % 2 == 0))

	# --- Conocidos ---------------------------------------------------------
	# Solo los que siguen en un club ajeno: el retirado ya no se puede
	# fichar, y el que ficharon para tu club ya lo ves entero en el plantel.
	var todos := []
	for id in equipo.conocimiento:
		var dato: Dictionary = indice.get(int(id), {})
		if dato.is_empty() or dato["club"] == equipo:
			continue
		todos.append(_ficha_de_indice(dato))
	var fichas := []
	for f in todos:
		if filtro_conocidos_posicion != "" and str(f["posicion"]) != filtro_conocidos_posicion:
			continue
		if filtro_conocidos_division != -1 and int(f["division"]) != filtro_conocidos_division + 1:
			continue
		if filtro_conocidos_pronto and int(f["vigencia"]) >= Investigadores.DIAS_VENCE_PRONTO:
			continue
		fichas.append(f)

	var cuantos := str(todos.size())
	if fichas.size() != todos.size():
		cuantos = "%d de %d" % [fichas.size(), todos.size()]
	contenedor_investigaciones.add_child(Tema.etiqueta_seccion(
		"Conocidos (%s)  ·  un informe dura %d dias y despues el jugador vuelve a quedar tapado" % [
			cuantos, Investigadores.DIAS_VIGENCIA]))
	if todos.is_empty():
		contenedor_investigaciones.add_child(_tarjeta_vacia(
			"Todavia no terminaste ningun informe."))
		return
	contenedor_investigaciones.add_child(_filtros_conocidos())
	if fichas.is_empty():
		contenedor_investigaciones.add_child(_tarjeta_vacia(
			"Ningun conocido pasa estos filtros."))
		return

	fichas = BusquedaMercado.ordenar(fichas, orden_conocidos, orden_conocidos_asc)
	contenedor_investigaciones.add_child(_encabezado_mercado(
		orden_conocidos, orden_conocidos_asc, _on_ordenar_conocidos, true))
	for i in range(fichas.size()):
		contenedor_investigaciones.add_child(_fila_mercado(fichas[i], i % 2 == 0))


func _cabecera_investigaciones(equipo: Team) -> Control:
	var libres: int = Investigadores.libres(equipo).size()
	var cabecera := Componentes.tarjeta(
		Tema.ROJO if equipo.investigadores.is_empty() else Color.TRANSPARENT)
	var fila_cab := HBoxContainer.new()
	cabecera.add_child(fila_cab)
	var izq := VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_constant_override("separation", 2)
	fila_cab.add_child(izq)
	izq.add_child(Tema.etiqueta_seccion("Tu red de investigadores"))
	var resumen := Label.new()
	if equipo.investigadores.is_empty():
		resumen.text = "No tenes ninguno. Sin investigadores no podes averiguar nada de los jugadores de otros clubes: los ves tapados."
		resumen.add_theme_color_override("font_color", Tema.ROJO)
	else:
		resumen.text = "%d contratado%s, %d libre%s esperando orden." % [
			equipo.investigadores.size(), "" if equipo.investigadores.size() == 1 else "s",
			libres, "" if libres == 1 else "s"]
	resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	izq.add_child(resumen)

	var btn_contratar := Button.new()
	btn_contratar.text = "Contratar investigadores"
	btn_contratar.custom_minimum_size = Vector2(280, Tema.ALTO_TACTIL)
	btn_contratar.tooltip_text = "Se contratan en Equipo › Instalaciones, con el presupuesto de Mejoras."
	if equipo.investigadores.is_empty():
		Tema.primario(btn_contratar)
	btn_contratar.pressed.connect(func():
		solapa_instalaciones = "investigadores"
		# Instalaciones es de Club, no de Equipo: con "equipo" quedaba la
		# barra de subsolapas de Equipo arriba de un panel que no es suyo.
		_mostrar_seccion("club", "instalaciones")
	)
	fila_cab.add_child(btn_contratar)
	return cabecera


## La misma barra que la de Jugadores: titulo arriba de cada filtro y un
## contenedor que envuelve en pantallas angostas. Sin boton Buscar: la
## lista es corta y filtra al tocar.
func _filtros_conocidos() -> Control:
	var filtros := HFlowContainer.new()
	filtros.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filtros.add_theme_constant_override("h_separation", 12)
	filtros.add_theme_constant_override("v_separation", 8)

	var op_pos := OptionButton.new()
	op_pos.add_item("Cualquiera")
	for pos in BusquedaMercado.POSICIONES:
		op_pos.add_item(pos)
	op_pos.selected = BusquedaMercado.POSICIONES.find(filtro_conocidos_posicion) + 1
	op_pos.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	op_pos.item_selected.connect(func(i: int):
		filtro_conocidos_posicion = "" if i <= 0 else op_pos.get_item_text(i)
		_refrescar_investigaciones.call_deferred()
	)
	filtros.add_child(_grupo_filtro("Puesto", op_pos))

	var op_div := OptionButton.new()
	op_div.add_item("Cualquiera")
	for d in range(GameState.piramide.divisiones.size()):
		op_div.add_item("D%d" % (d + 1))
	op_div.selected = filtro_conocidos_division + 1
	op_div.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	op_div.item_selected.connect(func(i: int):
		filtro_conocidos_division = i - 1
		_refrescar_investigaciones.call_deferred()
	)
	filtros.add_child(_grupo_filtro("Division", op_div))

	var op_informe := OptionButton.new()
	op_informe.add_item("Todos")
	op_informe.add_item("Vence pronto")
	op_informe.selected = 1 if filtro_conocidos_pronto else 0
	op_informe.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	op_informe.tooltip_text = "Vence pronto = le quedan menos de %d dias." % Investigadores.DIAS_VENCE_PRONTO
	op_informe.item_selected.connect(func(i: int):
		filtro_conocidos_pronto = i == 1
		_refrescar_investigaciones.call_deferred()
	)
	filtros.add_child(_grupo_filtro("Informe", op_informe))

	var btn_limpiar := Button.new()
	btn_limpiar.text = "Limpiar"
	btn_limpiar.custom_minimum_size = Vector2(120, Tema.ALTO_TACTIL)
	btn_limpiar.tooltip_text = "Deja todos los filtros en cualquiera."
	btn_limpiar.pressed.connect(func():
		filtro_conocidos_posicion = ""
		filtro_conocidos_division = -1
		filtro_conocidos_pronto = false
		_refrescar_investigaciones.call_deferred()
	)
	filtros.add_child(_grupo_filtro(" ", btn_limpiar))
	return filtros


func _on_ordenar_conocidos(clave: String) -> void:
	if orden_conocidos == clave:
		orden_conocidos_asc = not orden_conocidos_asc
	else:
		orden_conocidos = clave
		orden_conocidos_asc = true
	_refrescar_investigaciones()


## La ficha del mercado armada desde el indice, con los dias de informe
## que le quedan para poder ordenar y filtrar por eso.
func _ficha_de_indice(dato: Dictionary) -> Dictionary:
	var f := BusquedaMercado.ficha(GameState.equipo_jugador, {
		"equipo": dato["club"], "jugador": dato["jugador"],
		"division": dato["division"], "origen": dato["origen"]})
	f["equipo"] = dato["club"]
	var quedan := Investigadores.vigencia(GameState.equipo_jugador, int(f["id"]))
	f["vigencia"] = quedan if quedan >= 0 else null
	return f


## Un informe en curso sobre alguien que ya no esta en la piramide: se
## retiro en una partida guardada antes de que el cierre de temporada
## cancelara esos informes solo. Queda el nombre y el boton para liberar
## al investigador.
func _fila_objetivo_perdido(inv: Dictionary, par: bool) -> Control:
	var fila := Componentes.fila(par)
	var dentro := Componentes.contenido(fila)
	var quien := str(inv.get("nombre_objetivo", ""))
	dentro.add_child(Componentes.celda(quien if quien != "" else "un jugador",
		Componentes.COL_NOMBRE, Tema.SUAVE, HORIZONTAL_ALIGNMENT_LEFT, Componentes.TAM_TABLA))
	var aviso := Componentes.celda("Ya no esta en la piramide", 0,
		Tema.ROJO, HORIZONTAL_ALIGNMENT_LEFT, Componentes.TAM_TABLA)
	aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dentro.add_child(aviso)
	dentro.add_child(_boton_cancelar_informe(int(inv["id"])))
	return fila


## Cancela un informe desde cualquier tabla y refresca la que este abierta.
func _boton_cancelar_informe(id_inv: int) -> Button:
	var btn := Componentes.boton_de_accion("Cancelar", Componentes.COL_ACCION)
	btn.tooltip_text = "Se pierde lo avanzado: el investigador vuelve a quedar libre."
	btn.pressed.connect(func():
		Investigadores.cancelar(GameState.equipo_jugador, id_inv)
		if solapa_mercado_actual == "investigaciones":
			_refrescar_investigaciones()
		else:
			_refrescar_mercado()
	)
	return btn


## id -> {jugador, club, division, origen} de toda la piramide. Se arma
## una vez por refresco: el conocimiento guarda solo el id, y buscar cada
## uno por separado seria recorrer 3.600 jugadores por fila.
##
## Recorre los mismos grupos que BusquedaMercado.buscar. Antes se salteaba
## las reservas, y un conocido de reserva figuraba como "ya no esta en la
## piramide".
func _indice_de_jugadores() -> Dictionary:
	var indice := {}
	for d in range(GameState.piramide.divisiones.size()):
		for club in GameState.piramide.divisiones[d].equipos:
			for grupo in [[club.jugadores, "titular"], [club.banco, "banco"],
					[club.reservas, "reserva"], [club.cantera, "cantera"]]:
				for j in grupo[0]:
					indice[int(j["id"])] = {"jugador": j, "club": club,
						"division": d + 1, "origen": grupo[1]}
	return indice


func _on_investigar(vendedor: Team, jugador_id: int) -> void:
	label_mercado_estado.text = _asignar_investigador(vendedor, jugador_id)
	_on_buscar_mercado()


## Le manda un investigador y devuelve que paso, en texto. Devuelve el
## mensaje en vez de escribirlo: lo piden dos pantallas distintas (la
## tabla del mercado y el modal del jugador que sale de una noticia) y
## cada una lo muestra en su lugar.
func _asignar_investigador(club: Team, jugador_id: int) -> String:
	var donde := Mercado.ubicar(club, jugador_id)
	var nombre := _nombre_jugador(donde["jugador"]) if not donde.is_empty() else ""
	var r := Investigadores.investigar(GameState.equipo_jugador, jugador_id, club.nombre, nombre)
	if r["exito"]:
		return "Investigador de %d estrellas asignado: el informe tarda %d dias." % [
			int(r["investigador"]["estrellas"]), int(round(float(r["dias_totales"])))]
	return "No se pudo: %s" % r["motivo"]


## Las dos solapas de negociaciones abiertas. `entrantes` = las que
## vienen por jugadores nuestros.
func _refrescar_ofertas(contenedor: VBoxContainer, entrantes: bool) -> void:
	for hijo in contenedor.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var hubo := false
	for o in equipo.ofertas:
		if bool(o["entrante"]) != entrantes:
			continue
		# Solo las VIVAS. Las rechazadas y las que se cayeron al cerrar el
		# mercado se van al historial: seguian apareciendo en la lista, con
		# su boton de "Ver oferta", como si todavia hubiera algo que
		# decidir.
		if not Ofertas.abierta(o):
			continue
		hubo = true
		contenedor.add_child(_fila_oferta(o))
	if not hubo:
		contenedor.add_child(_etiqueta(
			"No hay ofertas por tus jugadores." if entrantes else "No mandaste ninguna oferta."))


func _fila_oferta(o: Dictionary) -> Control:
	var fila := HBoxContainer.new()
	# Una cesion no se resume con un monto: lo que importa son los
	# terminos (cuanto dura, cuanto del sueldo cubren, si hay opcion).
	var plata: String = Cesiones.resumen(o) if str(o.get("tipo", "compra")) == "cesion" 		else Economia.formato_dinero(o["monto"])
	var rol := _rol_en_su_club(o)
	var texto := "%s: %s (%s%s) — %s — %s — %s" % [
		_tipo_de_oferta(o).to_upper(), str(o["jugador"]), str(o["posicion"]),
		"" if rol == "" else ", " + rol, str(o["club"]), plata, _estado_legible(o)]
	var l := _etiqueta(texto)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Los terminos de un prestamo son largos: sin cortar la linea, los
	# botones Ficha y Ver oferta quedaban fuera de la pantalla.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(l)
	var btn_ficha := Button.new()
	btn_ficha.text = "Ficha"
	btn_ficha.custom_minimum_size = Vector2(90, 44)
	var oferta_id := int(o["id"])
	btn_ficha.pressed.connect(func(): _ficha_desde_oferta(oferta_id))
	fila.add_child(btn_ficha)
	var btn := Button.new()
	btn.text = "Ver oferta"
	btn.custom_minimum_size = Vector2(130, 44)
	var id := int(o["id"])
	btn.pressed.connect(func(): _abrir_oferta(id))
	fila.add_child(btn)
	return fila


## Una compra se lleva al jugador para siempre; un prestamo lo devuelve.
## Son decisiones distintas y la lista las mezclaba sin decir cual era.
func _tipo_de_oferta(o: Dictionary) -> String:
	return "Préstamo" if str(o.get("tipo", "compra")) == "cesion" else "Compra"


## El club dueño del jugador de la oferta: nosotros si la oferta es
## entrante, el otro club si la mandamos nosotros.
func _dueno_de_oferta(o: Dictionary) -> Team:
	if bool(o["entrante"]):
		return GameState.equipo_jugador
	return GameState._club_por_nombre(str(o["club"]))


## Que lugar ocupa en su club: vender a un titular no es lo mismo que
## vender a una reserva. Vacio si ya no esta en el club.
func _rol_en_su_club(o: Dictionary) -> String:
	var dueno := _dueno_de_oferta(o)
	if dueno == null:
		return ""
	match str(Mercado.ubicar(dueno, int(o["jugador_id"])).get("origen", "")):
		"titular": return "titular"
		"banco": return "suplente"
		"reserva": return "reserva"
		"cantera": return "cantera"
	return ""


## Abre la ficha del jugador de la oferta. El modal se cierra para que la
## ficha quede a la vista; al volver se reabre la misma oferta.
func _ficha_desde_oferta(oferta_id: int) -> void:
	var o := GameState._oferta_por_id(oferta_id)
	if o.is_empty():
		return
	dialogo_negociacion.hide()
	dialogo_cesion.hide()
	var entrante: bool = bool(o["entrante"])
	_mostrar_ficha(int(o["jugador_id"]), null if entrante else _dueno_de_oferta(o))
	ficha_oferta_id = oferta_id
	ficha_origen = "oferta"
	_refrescar_ficha()


## "COMPRA · titular": lo primero que hay que saber antes de mirar montos.
func _subtitulo_jugador_de_oferta(o: Dictionary) -> String:
	var rol := _rol_en_su_club(o)
	return _tipo_de_oferta(o).to_upper() + ("" if rol == "" else "  ·  " + rol)


func _boton_ficha_de_oferta(al_tocar: Callable) -> Button:
	var b := Button.new()
	b.text = "Ficha"
	b.custom_minimum_size = Vector2(110, Tema.ALTO_TACTIL)
	b.pressed.connect(al_tocar)
	return b


func _fila_titulo_oferta(titulo: Label, boton: Button) -> HBoxContainer:
	var fila := HBoxContainer.new()
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(titulo)
	fila.add_child(boton)
	return fila


func _estado_legible(o: Dictionary) -> String:
	match str(o["estado"]):
		Ofertas.PENDIENTE_ELLOS:
			return "esperando respuesta (%d dias)" % int(ceil(float(o["dias"])))
		Ofertas.PENDIENTE_NOSOTROS:
			return "TE TOCA RESPONDER"
		Ofertas.ACUERDO_CLUB:
			if bool(o["entrante"]):
				return "arreglando contrato con el jugador (%d dias)" % int(ceil(float(o["dias"])))
			return "ACORDADO: falta firmar el contrato"
		Ofertas.CERRADA:
			return "cerrada"
		Ofertas.RECHAZADA:
			return "rechazada"
		Ofertas.RETIRADA:
			return "retirada"
		Ofertas.SIN_ACUERDO:
			return "sin acuerdo con el jugador"
	return str(o["estado"])


func _refrescar_historial() -> void:
	for hijo in contenedor_historial.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	if equipo.historial_mercado.is_empty():
		contenedor_historial.add_child(_etiqueta("Todavia no cerraste ni perdiste ninguna negociacion."))
		return
	# Al reves: lo ultimo primero, que es lo que se quiere ver.
	for i in range(equipo.historial_mercado.size() - 1, -1, -1):
		var o: Dictionary = equipo.historial_mercado[i]
		var rc := RichTextLabel.new()
		rc.bbcode_enabled = true
		rc.fit_content = true
		rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color := "#27ae60" if str(o["estado"]) == Ofertas.CERRADA else "#c0392b"
		var flecha := "<-" if bool(o["entrante"]) else "->"
		var t := "[color=%s]%s[/color]  %s %s %s  (%s)\n" % [
			color, _estado_legible(o), str(o["jugador"]), flecha, str(o["club"]),
			Economia.formato_dinero(o["monto"])]
		for linea in o["log"]:
			t += "    [color=#7f8c8d]%s[/color]\n" % str(linea)
		rc.text = t
		contenedor_historial.add_child(rc)


## §9.3 rework: el modal de PRESTAMO. A diferencia de una compra no hay
## regateo por rondas: el dueño mira las condiciones y contesta si o no en
## el momento. Lo que se negocia no es el precio sino los terminos —
## cuanto dura, cuanto del sueldo le sacas de encima, y si te lo atas con
## una opcion de compra.
## Lo que paso mientras pasaban los dias. Sin esto, avanzar el dia seria
## un boton que no dice nada — y enterarse es la mitad del punto de tener
## calendario.
var dialogo_novedades: AcceptDialog
var label_novedades: Label


## El ancho y el alto del cuerpo del dialogo. Fijos a proposito: el
## AcceptDialog crece solo para entrar todo su contenido, y al cerrar la
## temporada las novedades son decenas de lineas — el dialogo terminaba
## mas alto que la pantalla y el boton "Entendido" quedaba FUERA. En el
## telefono eso deja el juego trabado en el cambio de temporada, sin forma
## de cerrar el cartel ni de seguir jugando.
const ANCHO_NOVEDADES := 820
const ALTO_NOVEDADES := 360


func _construir_dialogo_novedades() -> void:
	dialogo_novedades = AcceptDialog.new()
	dialogo_novedades.title = "Novedades"
	dialogo_novedades.ok_button_text = "Entendido"

	# El texto va adentro de un scroll y no en dialog_text: asi el dialogo
	# mide siempre lo mismo y lo que sobra se scrollea.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ANCHO_NOVEDADES, ALTO_NOVEDADES)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogo_novedades.add_child(scroll)
	label_novedades = Label.new()
	label_novedades.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_novedades.custom_minimum_size = Vector2(ANCHO_NOVEDADES - 20, 0)
	label_novedades.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label_novedades)
	add_child(dialogo_novedades)
	Tema.dialogo(dialogo_novedades)


## Muestra el cartel de novedades. Todo pasa por aca para que nadie vuelva
## a escribir dialog_text, que es lo que hacia crecer el dialogo.
func _mostrar_novedades(texto: String) -> void:
	label_novedades.text = texto
	# Arriba de todo: si quedo scrolleado del cartel anterior, el nuevo
	# abriria por la mitad.
	var scroll := label_novedades.get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0
	dialogo_novedades.popup_centered()


## §9.3: el cartel de vencimientos. Al empezar la temporada, los contratos
## que no renovaste ya se ejecutaron: el jugador se fue libre y un juvenil
## de la cantera le tapo el puesto (ver AgentesLibres._reemplazo_para). Eso
## le cambia el plantel al jugador sin que el haya decidido nada, asi que
## no puede quedar solo en Noticias: se avisa con un cartel que hay que
## aceptar, y recien ahi se borra la lista.
var dialogo_vencimientos: AcceptDialog
var label_vencimientos: Label


func _construir_dialogo_vencimientos() -> void:
	dialogo_vencimientos = AcceptDialog.new()
	dialogo_vencimientos.title = "Contratos vencidos"
	dialogo_vencimientos.ok_button_text = "Entendido"

	# Mismo scroll de alto fijo que el cartel de novedades, y por la misma
	# razon: con muchas lineas el dialogo crecia mas que la pantalla y el
	# boton de cerrar quedaba afuera.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ANCHO_NOVEDADES, ALTO_NOVEDADES)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogo_vencimientos.add_child(scroll)
	label_vencimientos = Label.new()
	label_vencimientos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_vencimientos.custom_minimum_size = Vector2(ANCHO_NOVEDADES - 20, 0)
	label_vencimientos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label_vencimientos)
	add_child(dialogo_vencimientos)
	Tema.dialogo(dialogo_vencimientos)

	# Aceptar es lo que borra la lista: mientras no la lea, el aviso
	# sobrevive a cerrar el juego (Team.vencimientos_del_cierre se guarda).
	dialogo_vencimientos.confirmed.connect(_on_vencimientos_aceptados)
	dialogo_vencimientos.canceled.connect(_on_vencimientos_aceptados)


func _on_vencimientos_aceptados() -> void:
	var equipo := GameState.equipo_jugador
	if equipo != null:
		equipo.vencimientos_del_cierre.clear()
	_refrescar_plantel()
	_refrescar_cantera()
	_refrescar_renovaciones()


## Abre el cartel si quedo algo por avisar. Devuelve si lo abrio.
func _mostrar_vencimientos_si_hay() -> bool:
	var equipo := GameState.equipo_jugador
	if equipo == null or equipo.vencimientos_del_cierre.is_empty():
		return false

	var lista: Array = equipo.vencimientos_del_cierre
	var lineas := []
	lineas.append("Se te vencieron %d contrato%s y no los renovaste. Los jugadores se fueron libres." % [
		lista.size(), "" if lista.size() == 1 else "s"])
	lineas.append("")
	for v in lista:
		lineas.append("SE FUE  %s (%s, %d años, media %d) — cobraba %s" % [
			str(v.get("sale", "")), str(v.get("sale_puesto", "")),
			int(v.get("sale_edad", 0)), int(v.get("sale_media", 0)),
			Economia.formato_dinero(float(v.get("sale_sueldo", 0.0)))])
	label_vencimientos.text = "
".join(lineas)
	var scroll := label_vencimientos.get_parent() as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0
	dialogo_vencimientos.popup_centered()
	return true


var dialogo_prestamo: AcceptDialog
var prestamo_dueno: Team = null
var prestamo_jugador_id: int = -1
var option_prestamo_duracion: OptionButton
var slider_prestamo_sueldo: HSlider
var label_prestamo_sueldo: Label
var spin_prestamo_plus: SpinBox
var label_prestamo_plus: Label
var prestamo_sueldo_referencia: float = 0.0
var check_prestamo_opcion: CheckBox
var spin_prestamo_opcion: SpinBox
var label_prestamo_datos: Label
var label_prestamo_estado: RichTextLabel


func _construir_dialogo_prestamo() -> void:
	dialogo_prestamo = AcceptDialog.new()
	dialogo_prestamo.title = "Prestamo"
	dialogo_prestamo.min_size = Vector2(640, 0)
	add_child(dialogo_prestamo)
	Tema.dialogo(dialogo_prestamo)
	dialogo_prestamo.get_ok_button().hide()
	dialogo_prestamo.visibility_changed.connect(_refrescar_ficha_si_visible)

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogo_prestamo.add_child(caja)

	label_prestamo_datos = Label.new()
	label_prestamo_datos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(label_prestamo_datos)

	var fila_dur := HBoxContainer.new()
	caja.add_child(fila_dur)
	fila_dur.add_child(_etiqueta("Duración:"))
	option_prestamo_duracion = OptionButton.new()
	for clave in Prestamos.DURACIONES:
		option_prestamo_duracion.add_item(Prestamos.ETIQUETAS_DURACION[clave])
		option_prestamo_duracion.set_item_metadata(option_prestamo_duracion.item_count - 1, clave)
	option_prestamo_duracion.selected = 1
	fila_dur.add_child(option_prestamo_duracion)

	var fila_sueldo := HBoxContainer.new()
	caja.add_child(fila_sueldo)
	fila_sueldo.add_child(_etiqueta("Del sueldo pagás:"))
	slider_prestamo_sueldo = HSlider.new()
	slider_prestamo_sueldo.min_value = 0
	slider_prestamo_sueldo.max_value = 100
	slider_prestamo_sueldo.step = 5
	slider_prestamo_sueldo.value = 100
	slider_prestamo_sueldo.custom_minimum_size = Vector2(260, 44)
	fila_sueldo.add_child(slider_prestamo_sueldo)
	label_prestamo_sueldo = Label.new()
	fila_sueldo.add_child(label_prestamo_sueldo)
	slider_prestamo_sueldo.value_changed.connect(func(_v): _refrescar_prestamo_sueldo())

	# El reparto del sueldo es plata entre CLUBES: al jugador no le cambia
	# nada. El plus es lo unico que lo convence de bajar de categoria.
	var fila_plus := HBoxContainer.new()
	caja.add_child(fila_plus)
	fila_plus.add_child(_etiqueta("Plus para el jugador:"))
	spin_prestamo_plus = SpinBox.new()
	spin_prestamo_plus.min_value = 0
	spin_prestamo_plus.max_value = 100000000
	spin_prestamo_plus.step = 500
	spin_prestamo_plus.custom_minimum_size = Vector2(200, 44)
	fila_plus.add_child(spin_prestamo_plus)
	_activar_formato_miles(spin_prestamo_plus)
	label_prestamo_plus = Label.new()
	label_prestamo_plus.add_theme_color_override("font_color", Tema.SUAVE)
	fila_plus.add_child(label_prestamo_plus)
	spin_prestamo_plus.value_changed.connect(func(_v): _refrescar_prestamo_sueldo())

	var fila_opcion := HBoxContainer.new()
	caja.add_child(fila_opcion)
	check_prestamo_opcion = CheckBox.new()
	check_prestamo_opcion.text = "Con opción de compra"
	fila_opcion.add_child(check_prestamo_opcion)
	spin_prestamo_opcion = SpinBox.new()
	spin_prestamo_opcion.min_value = 0
	spin_prestamo_opcion.max_value = 1000000000
	spin_prestamo_opcion.step = 5000
	spin_prestamo_opcion.custom_minimum_size = Vector2(200, 44)
	fila_opcion.add_child(spin_prestamo_opcion)
	_activar_formato_miles(spin_prestamo_opcion)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	caja.add_child(acciones)
	var btn := Button.new()
	btn.text = "Pedir préstamo"
	btn.custom_minimum_size = Vector2(220, Tema.ALTO_TACTIL)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tema.primario(btn)
	btn.pressed.connect(_on_pedir_prestamo)
	acciones.add_child(btn)

	var cerrar_prestamo := Button.new()
	cerrar_prestamo.text = "Cerrar"
	cerrar_prestamo.custom_minimum_size = Vector2(200, 48)
	cerrar_prestamo.pressed.connect(func(): dialogo_prestamo.hide())
	acciones.add_child(cerrar_prestamo)

	label_prestamo_estado = RichTextLabel.new()
	label_prestamo_estado.bbcode_enabled = true
	label_prestamo_estado.fit_content = true
	label_prestamo_estado.custom_minimum_size = Vector2(0, 52)
	caja.add_child(label_prestamo_estado)


func _refrescar_prestamo_sueldo() -> void:
	var pct := int(slider_prestamo_sueldo.value)
	var plus: float = float(spin_prestamo_plus.value)
	var texto := "%d%%" % pct
	# Sin investigarlo no sabes lo que cobra, asi que el % es un porcentaje
	# de algo que no ves. El plus, en cambio, sale de tu bolsillo y siempre
	# lo ves en pesos: por eso se muestra igual.
	if prestamo_sueldo_referencia > 0.0:
		var mio: float = prestamo_sueldo_referencia * pct / 100.0
		texto += "  (%s por temporada)" % Economia.formato_dinero(mio)
		label_prestamo_plus.text = "Pagás en total %s" % Economia.formato_dinero(mio + plus)
	else:
		texto += "  (de un sueldo que no conocés)"
		label_prestamo_plus.text = "Sobre lo que cobra hoy"
	label_prestamo_sueldo.text = texto


func _abrir_prestamo(dueno: Team, jugador_id: int) -> void:
	prestamo_dueno = dueno
	prestamo_jugador_id = jugador_id
	var donde := Mercado.ubicar(dueno, jugador_id)
	if donde.is_empty():
		label_mercado_estado.text = "Ese jugador ya no esta en ese club."
		return
	var jugador: Dictionary = donde["jugador"]
	var conocido := Investigadores.conoce(GameState.equipo_jugador, jugador_id)

	var t := "%s (%s) — %s\n" % [_nombre_jugador(jugador), jugador["posicion"], dueno.nombre]
	t += "Un club no presta a un titular suyo, y quiere que le saques de encima al menos el %d%% del sueldo.\n" % [
		int(Prestamos.PORCENTAJE_SUELDO_MINIMO * 100.0)]
	prestamo_sueldo_referencia = Prestamos.sueldo_de_referencia(dueno, jugador) if conocido else 0.0
	spin_prestamo_plus.value = 0
	t += "El reparto del sueldo lo arreglás con el club. Al jugador lo convence el plus.\n"
	if conocido:
		t += "Hoy cobra %s.\n" % Economia.formato_dinero(prestamo_sueldo_referencia)
		spin_prestamo_opcion.value = ceil(
			Prestamos.valor_futuro_estimado(jugador, 1.0) * Prestamos.MARGEN_OPCION
			/ spin_prestamo_opcion.step) * spin_prestamo_opcion.step
	else:
		t += "NO lo investigaste: no sabes lo que cobra ni lo que puede llegar a valer.\n"
		spin_prestamo_opcion.value = 0
	label_prestamo_datos.text = t
	_refrescar_prestamo_sueldo()
	label_prestamo_estado.text = ""
	dialogo_prestamo.popup_centered()


func _on_pedir_prestamo() -> void:
	var idx := option_prestamo_duracion.selected
	var duracion := str(option_prestamo_duracion.get_item_metadata(idx))
	var opcion: float = float(spin_prestamo_opcion.value) if check_prestamo_opcion.button_pressed else 0.0
	var r := GameState.pedir_prestamo(
		prestamo_dueno, prestamo_jugador_id, duracion,
		float(slider_prestamo_sueldo.value) / 100.0, opcion,
		float(spin_prestamo_plus.value))
	if not r["exito"]:
		var extra := ""
		var plus_sugerido: float = float(r.get("plus_sugerido", 0.0))
		if plus_sugerido > 0.0:
			# La cifra exacta sale del sueldo que cobra hoy, y ese dato es
			# de los investigadores. Sin investigarlo solo sabés que falta.
			if prestamo_sueldo_referencia > 0.0:
				extra = " Con un plus de %s lo convencés." % Economia.formato_dinero(
					float(spin_prestamo_plus.value) + plus_sugerido)
			else:
				extra = " Con más plus lo convencés, pero no sabés cuánto: investigalo."
		elif r.has("detalle"):
			extra = " No hay plus que lo dé vuelta: buscá otro."
		if float(r.get("minimo", 0.0)) > 0.0:
			extra = " Pedirían al menos %s." % Economia.formato_dinero(r["minimo"])
		label_prestamo_estado.text = "[color=#ffcf43]%s%s[/color]" % [r["motivo"], extra]
		return
	var cola := ""
	if float(r.get("opcion_compra", 0.0)) > 0.0:
		cola = " Con opción de compra a %s." % Economia.formato_dinero(r["opcion_compra"])
	label_prestamo_estado.text = "[color=#27ae60]Cerrado. Llega a préstamo (fee %s, pagás %s de sueldo).%s[/color]" % [
		Economia.formato_dinero(r["fee"]), Economia.formato_dinero(r["sueldo_propio"]), cola]
	_on_buscar_mercado()


## §9.3: el modal de negociación.
##
## Dos cosas que el jugador no sabía hasta que le pasaban, y que ahora se
## ven ANTES de apretar:
##
##   1. Que después de arreglar con el club todavía falta convencer al
##      futbolista. Los dos tramos están dibujados arriba desde el
##      principio.
##   2. Que ofertar muy abajo no es "negociar duro": te vetan una
##      temporada. La barra de riesgo muestra dónde empieza esa zona.
##
## El modal hace dos trabajos: MANDAR una oferta nueva (desde la solapa
## Jugadores) y VER una ya abierta (desde Ofertas enviadas / recibidas).
var dialogo_negociacion: AcceptDialog
var negociacion_vendedor: Team = null
var negociacion_jugador_id: int = -1
var negociacion_oferta_id: int = -1
var label_negociacion_titulo: Label
var label_negociacion_sub: Label
var boton_negociacion_ficha: Button
var caja_negociacion_datos: HBoxContainer
var caja_negociacion_pasos: HBoxContainer
var label_negociacion_estado: RichTextLabel
var caja_negociacion_monto: VBoxContainer
var caja_negociacion_riesgo: VBoxContainer
var caja_negociacion_contrato: VBoxContainer
var spin_negociacion_monto: SpinBox
var spin_negociacion_sueldo: SpinBox
var spin_negociacion_anios: SpinBox
var boton_negociacion_accion: Button
var boton_negociacion_rechazar: Button
var boton_negociacion_retirar: Button
var boton_negociacion_contra: Button


func _construir_dialogo_negociacion() -> void:
	dialogo_negociacion = AcceptDialog.new()
	dialogo_negociacion.title = "Negociacion"
	dialogo_negociacion.min_size = Vector2(820, 0)
	add_child(dialogo_negociacion)
	Tema.dialogo(dialogo_negociacion)
	dialogo_negociacion.get_ok_button().hide()
	dialogo_negociacion.visibility_changed.connect(_refrescar_ficha_si_visible)

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogo_negociacion.add_child(caja)

	label_negociacion_titulo = Label.new()
	Tema.numero(label_negociacion_titulo, 24)
	boton_negociacion_ficha = _boton_ficha_de_oferta(func(): _ficha_desde_oferta(negociacion_oferta_id))
	caja.add_child(_fila_titulo_oferta(label_negociacion_titulo, boton_negociacion_ficha))

	label_negociacion_sub = Label.new()
	label_negociacion_sub.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(label_negociacion_sub)

	caja_negociacion_pasos = HBoxContainer.new()
	caja.add_child(caja_negociacion_pasos)

	caja_negociacion_datos = HBoxContainer.new()
	caja.add_child(caja_negociacion_datos)

	caja_negociacion_monto = VBoxContainer.new()
	caja.add_child(caja_negociacion_monto)
	var fila_monto := HBoxContainer.new()
	caja_negociacion_monto.add_child(fila_monto)
	fila_monto.add_child(Tema.etiqueta_seccion("Tu oferta"))
	spin_negociacion_monto = SpinBox.new()
	spin_negociacion_monto.min_value = 0
	spin_negociacion_monto.max_value = 1000000000
	# La contraoferta debe aceptar cualquier monto entero, no solo múltiplos
	# de $1.000.
	spin_negociacion_monto.step = 1
	# Tomar el texto escrito también al hacer clic directamente en el botón.
	spin_negociacion_monto.update_on_text_changed = true
	spin_negociacion_monto.custom_minimum_size = Vector2(240, Tema.ALTO_TACTIL)
	spin_negociacion_monto.value_changed.connect(func(_v): _refrescar_riesgo())
	fila_monto.add_child(spin_negociacion_monto)
	_hacer_spin_tactil(spin_negociacion_monto, fila_monto)

	caja_negociacion_riesgo = VBoxContainer.new()
	caja_negociacion_monto.add_child(caja_negociacion_riesgo)

	caja_negociacion_contrato = VBoxContainer.new()
	caja_negociacion_contrato.visible = false
	caja.add_child(caja_negociacion_contrato)
	# Paso 1 por lo mismo que en la renovacion: el paso redondea la cifra
	# escrita y te termina ofreciendo otra.
	spin_negociacion_sueldo = _fila_spin(caja_negociacion_contrato,
		"Sueldo por temporada", 0, 500000000, 1)
	spin_negociacion_anios = _fila_spin(caja_negociacion_contrato,
		"Años de contrato", 1, 5, 1)
	spin_negociacion_anios.value = 3
	var ayuda_sueldo := Label.new()
	ayuda_sueldo.text = "La oferta empieza en $0. Vos decidís cuánto necesita para subir, bajar o cargar con tu equipo."
	ayuda_sueldo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda_sueldo.add_theme_color_override("font_color", Tema.SUAVE)
	caja_negociacion_contrato.add_child(ayuda_sueldo)
	# La clausula la ponés vos: alta lo blinda contra que te lo saquen,
	# pero a él lo encierra y te lo cobra pidiendo más sueldo.

	var fila_botones := HBoxContainer.new()
	caja.add_child(fila_botones)

	boton_negociacion_accion = Button.new()
	boton_negociacion_accion.custom_minimum_size = Vector2(220, Tema.ALTO_TACTIL)
	Tema.primario(boton_negociacion_accion)
	boton_negociacion_accion.pressed.connect(_on_negociacion_accion)
	fila_botones.add_child(boton_negociacion_accion)

	boton_negociacion_contra = Button.new()
	boton_negociacion_contra.text = "Contraofertar"
	boton_negociacion_contra.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	boton_negociacion_contra.visible = false
	boton_negociacion_contra.pressed.connect(_on_negociacion_contraofertar)
	fila_botones.add_child(boton_negociacion_contra)

	boton_negociacion_rechazar = Button.new()
	boton_negociacion_rechazar.text = "Rechazar"
	boton_negociacion_rechazar.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	boton_negociacion_rechazar.visible = false
	boton_negociacion_rechazar.pressed.connect(_on_negociacion_rechazar)
	fila_botones.add_child(boton_negociacion_rechazar)

	boton_negociacion_retirar = Button.new()
	boton_negociacion_retirar.text = "Retirar oferta"
	boton_negociacion_retirar.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	boton_negociacion_retirar.visible = false
	boton_negociacion_retirar.pressed.connect(_on_negociacion_retirar)
	fila_botones.add_child(boton_negociacion_retirar)

	# La clausula ajena: el atajo del que no quiere negociar. Se paga de
	# mas pero la venta es obligatoria y nadie se puede ofender.

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(140, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(func(): dialogo_negociacion.hide())
	fila_botones.add_child(cerrar)

	label_negociacion_estado = RichTextLabel.new()
	label_negociacion_estado.bbcode_enabled = true
	label_negociacion_estado.fit_content = true
	label_negociacion_estado.custom_minimum_size = Vector2(0, 52)
	caja.add_child(label_negociacion_estado)


func _fila_spin(padre: Control, etiqueta: String, minimo: float, maximo: float, paso: float) -> SpinBox:
	var fila := HBoxContainer.new()
	padre.add_child(fila)
	fila.add_child(Componentes.celda(etiqueta, 250, Tema.SUAVE))
	var sb := SpinBox.new()
	sb.min_value = minimo
	sb.max_value = maximo
	sb.step = paso
	# Sin esto el SpinBox solo toma lo tipeado al apretar Enter: si tocabas
	# el boton con el mouse, mandaba el valor viejo.
	sb.update_on_text_changed = true
	sb.custom_minimum_size = Vector2(240, Tema.ALTO_TACTIL)
	fila.add_child(sb)
	_hacer_spin_tactil(sb, fila)
	return sb


## En el celular, tocar el campo levantaba el teclado en pantalla. Apaisado
## tapa más de la mitad del modal: no se veía ni la respuesta ni el botón
## de ofrecer. Los botones de ajuste cambian la cifra sin teclado, y el de
## "Escribir" lo abre solo para quien quiere tipear un número exacto.
func _hacer_spin_tactil(sb: SpinBox, fila: HBoxContainer) -> void:
	var campo := sb.get_line_edit()
	campo.virtual_keyboard_enabled = false
	# Cuando sí se abre, el numérico ocupa menos que el alfabético.
	campo.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	campo.focus_exited.connect(func(): campo.virtual_keyboard_enabled = false)

	# Plata: el ajuste es relativo, porque un sueldo de $300 y un pase de
	# $30 millones no se mueven con el mismo paso. Años: de a uno.
	var es_plata := sb.max_value > 100
	if es_plata:
		_activar_formato_miles(sb)
	var pasos: Array = [0.10, 0.01] if es_plata else [1.0]
	var indice := sb.get_index()
	for delta in pasos:
		var menos := _boton_ajuste_spin(sb, -float(delta), es_plata)
		fila.add_child(menos)
		fila.move_child(menos, indice)
		indice += 1
	pasos.reverse()
	for delta in pasos:
		fila.add_child(_boton_ajuste_spin(sb, float(delta), es_plata))

	var escribir := Button.new()
	escribir.text = "Escribir"
	escribir.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	escribir.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	escribir.pressed.connect(func():
		campo.virtual_keyboard_enabled = true
		campo.grab_focus()
		campo.select_all()
		DisplayServer.virtual_keyboard_show(campo.text, Rect2(),
			DisplayServer.KEYBOARD_TYPE_NUMBER)
	)
	fila.add_child(escribir)


## Los SpinBox muestran plata sin simbolo. Los puntos se agregan mientras se
## escribe, pero el control conserva el numero puro para todos los calculos.
func _activar_formato_miles(sb: SpinBox) -> void:
	if bool(sb.get_meta("formato_miles_activo", false)):
		return
	sb.set_meta("formato_miles_activo", true)
	# El paso grande queda para las flechas. Un paso numerico de 1 evita que
	# escribir los primeros digitos de 1.000.000 los redondee a cero.
	sb.custom_arrow_step = sb.step
	sb.step = 1
	sb.update_on_text_changed = true
	var campo := sb.get_line_edit()
	campo.text_changed.connect(_formatear_campo_dinero.bind(sb))
	sb.value_changed.connect(_mostrar_valor_spin_dinero.bind(sb))
	_formatear_campo_dinero(campo.text, sb)


func _formatear_campo_dinero(texto: String, sb: SpinBox) -> void:
	if bool(sb.get_meta("formateando_miles", false)):
		return
	var campo := sb.get_line_edit()
	var caret_original := campo.caret_column
	var digitos := ""
	var digitos_a_derecha := 0
	for i in range(texto.length()):
		var caracter := texto.substr(i, 1)
		if caracter >= "0" and caracter <= "9":
			digitos += caracter
			if i >= caret_original:
				digitos_a_derecha += 1
	if digitos.is_empty():
		return

	var valor := clampf(float(digitos), sb.min_value, sb.max_value)
	var formateado := _entero_con_puntos(int(round(valor)))
	var nuevo_caret := formateado.length()
	var pendientes := digitos_a_derecha
	while nuevo_caret > 0 and pendientes > 0:
		nuevo_caret -= 1
		var caracter := formateado.substr(nuevo_caret, 1)
		if caracter >= "0" and caracter <= "9":
			pendientes -= 1

	sb.set_meta("formateando_miles", true)
	sb.value = valor
	# Cambiar solo la presentacion no debe volver a pasar los puntos por el
	# parser numerico interno del SpinBox.
	campo.set_block_signals(true)
	campo.text = formateado
	campo.caret_column = nuevo_caret
	campo.set_block_signals(false)
	sb.set_meta("formateando_miles", false)


## Asignar `spin.value` por codigo no emite `text_changed` en el LineEdit.
## Este segundo camino mantiene separados tambien los importes sugeridos.
func _mostrar_valor_spin_dinero(valor: float, sb: SpinBox) -> void:
	if bool(sb.get_meta("formateando_miles", false)):
		return
	var campo := sb.get_line_edit()
	var caret := campo.caret_column
	sb.set_meta("formateando_miles", true)
	campo.set_block_signals(true)
	campo.text = _entero_con_puntos(int(round(valor)))
	campo.caret_column = mini(caret, campo.text.length())
	campo.set_block_signals(false)
	sb.set_meta("formateando_miles", false)


func _entero_con_puntos(valor: int) -> String:
	var digitos := str(valor)
	var resultado := ""
	var contador := 0
	for i in range(digitos.length() - 1, -1, -1):
		resultado = digitos.substr(i, 1) + resultado
		contador += 1
		if contador % 3 == 0 and i > 0:
			resultado = "." + resultado
	return resultado


func _boton_ajuste_spin(sb: SpinBox, delta: float, relativo: bool) -> Button:
	var b := Button.new()
	if relativo:
		b.text = "%+d%%" % int(round(delta * 100))
	else:
		b.text = "%+d" % int(delta)
	b.custom_minimum_size = Vector2(64, Tema.ALTO_TACTIL)
	b.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	b.pressed.connect(func():
		var cambio := delta
		if relativo:
			# Mínimo $1: con el 1% de una cifra chica el botón no movía nada.
			cambio = signf(delta) * maxf(1.0, round(absf(sb.value * delta)))
		sb.value = sb.value + cambio
	)
	return b


## Los dos tramos, dibujados desde el principio. `paso` 1 o 2.
func _dibujar_pasos(paso: int) -> void:
	for hijo in caja_negociacion_pasos.get_children():
		hijo.queue_free()
	for i in [1, 2]:
		var n: int = int(i)
		var nombre := "Acuerdo con el club" if n == 1 else "Contrato con el jugador"
		var hecho: bool = n < paso
		var activo: bool = n == paso
		var color := Tema.VERDE if hecho else (Tema.AMBAR if activo else Tema.SUAVE)
		caja_negociacion_pasos.add_child(Componentes.chip(
			"%d" % n, color, Tema.TINTA_OSCURA if (hecho or activo) else Tema.PANEL))
		caja_negociacion_pasos.add_child(Componentes.celda(nombre, 260, color))


func _caja_dato(etiqueta: String, valor: String, color: Color = Color.TRANSPARENT,
		acento: bool = false) -> Control:
	if color == Color.TRANSPARENT:
		color = Tema.TEXTO
	var caja := PanelContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.PANEL_ALTO
	estilo.corner_radius_top_left = Tema.RADIO
	estilo.corner_radius_top_right = Tema.RADIO
	estilo.corner_radius_bottom_left = Tema.RADIO
	estilo.corner_radius_bottom_right = Tema.RADIO
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	if acento:
		estilo.border_width_top = 1
		estilo.border_width_bottom = 1
		estilo.border_width_left = 1
		estilo.border_width_right = 1
		estilo.border_color = Tema.AMBAR
	caja.add_theme_stylebox_override("panel", estilo)
	var dentro := VBoxContainer.new()
	caja.add_child(dentro)
	dentro.add_child(Tema.etiqueta_seccion(etiqueta))
	var l := Label.new()
	l.text = valor
	Tema.numero(l, 22, color)
	dentro.add_child(l)
	return caja


## La barra de riesgo: dónde empieza la zona en la que se ofenden.
##
## Es lo que convierte "ofertar a ciegas" en una decisión informada. Solo
## aparece si lo investigaste — si no, no sabés cuánto piden, y ese es
## justamente el riesgo que corrés.
func _refrescar_riesgo() -> void:
	if caja_negociacion_riesgo == null:
		return
	for hijo in caja_negociacion_riesgo.get_children():
		hijo.queue_free()
	if negociacion_vendedor == null:
		return
	if not Investigadores.conoce(GameState.equipo_jugador, negociacion_jugador_id):
		var aviso := Label.new()
		aviso.text = "No lo investigaste: no sabés cuánto piden ni dónde está el límite."
		aviso.add_theme_color_override("font_color", Tema.SUAVE)
		caja_negociacion_riesgo.add_child(aviso)
		return
	var donde := Mercado.ubicar(negociacion_vendedor, negociacion_jugador_id)
	if donde.is_empty():
		return
	var pedido := Negociacion.precio_pedido(negociacion_vendedor, donde["jugador"])
	var insulto := pedido * Negociacion.FRACCION_INSULTO
	var monto := float(spin_negociacion_monto.value)

	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 0)
	caja_negociacion_riesgo.add_child(barra)
	for tramo in [[Tema.ROJO, 55], [Tema.AMBAR, 45], [Tema.VERDE, 60]]:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(0, 8)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_stretch_ratio = float(tramo[1])
		var e := StyleBoxFlat.new()
		e.bg_color = tramo[0]
		p.add_theme_stylebox_override("panel", e)
		barra.add_child(p)

	var texto := Label.new()
	texto.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	if monto < insulto:
		texto.text = "Con menos de %s se ofenden y te vetan una temporada." % Economia.formato_dinero(insulto)
		texto.add_theme_color_override("font_color", Tema.ROJO)
	elif monto < pedido * Negociacion.TOLERANCIA_ACEPTACION:
		texto.text = "Alcanza para que te escuchen, pero piden alrededor de %s." % Economia.formato_dinero(pedido)
		texto.add_theme_color_override("font_color", Tema.AMBAR)
	else:
		texto.text = "Tu oferta llega a lo que piden."
		texto.add_theme_color_override("font_color", Tema.VERDE)
	caja_negociacion_riesgo.add_child(texto)


## Abrir para MANDAR una oferta nueva.
func _abrir_negociacion(vendedor: Team, jugador_id: int) -> void:
	negociacion_vendedor = vendedor
	negociacion_jugador_id = jugador_id
	negociacion_oferta_id = -1
	boton_negociacion_ficha.visible = false

	var donde := Mercado.ubicar(vendedor, jugador_id)
	if donde.is_empty():
		label_mercado_estado.text = "Ese jugador ya no esta en ese club."
		return
	var jugador: Dictionary = donde["jugador"]
	var conocido := Investigadores.conoce(GameState.equipo_jugador, jugador_id)

	label_negociacion_titulo.text = _nombre_jugador(jugador)
	label_negociacion_sub.text = "%s  ·  %d años  ·  %s" % [
		jugador["posicion"], int(jugador["edad"]), vendedor.nombre]
	_dibujar_pasos(1)

	for hijo in caja_negociacion_datos.get_children():
		hijo.queue_free()
	if conocido:
		var valor := ValorJugador.calcular(
			jugador, vendedor.animo.get(jugador_id, 50.0), vendedor.contratos.get(jugador_id, 3))
		# Lo que PIDEN, no solo lo que vale: el club suma lo que le duele
		# soltarlo. Precargar el valor a secas hacia que la oferta por
		# defecto se rechazara SIEMPRE.
		var pedido := Negociacion.precio_pedido(vendedor, jugador)
		caja_negociacion_datos.add_child(_caja_dato(
			"Vale", Economia.formato_dinero(valor)))
		caja_negociacion_datos.add_child(_caja_dato(
			"Piden alrededor de", Economia.formato_dinero(pedido), Tema.AMBAR, true))
		caja_negociacion_datos.add_child(_caja_dato(
			"Hoy cobra", Economia.formato_dinero(vendedor.sueldos.get(jugador_id, 0.0))))
		caja_negociacion_datos.add_child(_caja_dato(
			"Le quedan", "%d año(s)" % int(vendedor.contratos.get(jugador_id, 0))))
		spin_negociacion_monto.value = ceil(pedido / spin_negociacion_monto.step) * spin_negociacion_monto.step
	else:
		caja_negociacion_datos.add_child(_caja_dato("Vale", "?", Tema.SUAVE))
		caja_negociacion_datos.add_child(_caja_dato("Piden", "?", Tema.SUAVE))
		caja_negociacion_datos.add_child(_caja_dato("Hoy cobra", "?", Tema.SUAVE))
		caja_negociacion_datos.add_child(_caja_dato(
			"Tu presupuesto",
			Economia.formato_dinero(GameState.equipo_jugador.caja["fichajes"]), Tema.VERDE))
		spin_negociacion_monto.value = 0

	caja_negociacion_monto.visible = true
	caja_negociacion_contrato.visible = false
	boton_negociacion_rechazar.visible = false
	boton_negociacion_retirar.visible = false
	boton_negociacion_contra.visible = false
	boton_negociacion_accion.text = "Enviar oferta"
	boton_negociacion_accion.disabled = false
	boton_negociacion_accion.visible = true
	label_negociacion_estado.text = ""
	_refrescar_riesgo()
	dialogo_negociacion.popup_centered()


## Abrir una negociacion YA ABIERTA, desde las solapas de ofertas.
func _abrir_oferta(oferta_id: int) -> void:
	var o := GameState._oferta_por_id(oferta_id)
	if o.is_empty():
		return
	if str(o.get("tipo", "compra")) == "cesion":
		_abrir_cesion(o)
		return
	negociacion_oferta_id = oferta_id
	negociacion_jugador_id = int(o["jugador_id"])
	negociacion_vendedor = GameState._club_por_nombre(str(o["club"]))

	label_negociacion_titulo.text = str(o["jugador"])
	boton_negociacion_ficha.visible = true
	label_negociacion_sub.text = "%s  ·  %s %s  ·  sobre la mesa %s  ·  ronda %d  ·  %s" % [
		_subtitulo_jugador_de_oferta(o),
		"Oferta de" if bool(o["entrante"]) else "Tu oferta a", str(o["club"]),
		Economia.formato_dinero(o["monto"]), int(o["ronda"]), _estado_legible(o)]

	var a_firmar: bool = str(o["estado"]) == Ofertas.ACUERDO_CLUB and not bool(o["entrante"])
	_dibujar_pasos(2 if a_firmar else 1)

	for hijo in caja_negociacion_datos.get_children():
		hijo.queue_free()

	# Con que se decide. Antes esta caja quedaba VACIA en las ofertas ya
	# abiertas: la unica cifra era el monto sobre la mesa y no habia forma
	# de saber si te estaban ofreciendo bien o te lo estaban robando.
	var veredicto := _datos_de_la_oferta(o)

	var historia := ""
	if veredicto != "":
		historia += veredicto + "\n"
	for linea in o["log"]:
		historia += "[color=#93a79b]%s[/color]
" % str(linea)
	label_negociacion_estado.text = historia

	var me_toca: bool = str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS
	caja_negociacion_monto.visible = me_toca
	caja_negociacion_contrato.visible = a_firmar
	boton_negociacion_rechazar.visible = me_toca
	# Cuando no te toca, Rechazar no aplica: Retirar es la unica salida.
	boton_negociacion_retirar.visible = not me_toca and Ofertas.abierta(o)
	boton_negociacion_contra.visible = me_toca
	boton_negociacion_accion.disabled = not (me_toca or a_firmar)
	boton_negociacion_accion.visible = me_toca or a_firmar

	if me_toca:
		spin_negociacion_monto.value = float(o["monto"])
		boton_negociacion_accion.text = "Aceptar %s" % Economia.formato_dinero(o["monto"])
		_refrescar_riesgo()
	elif a_firmar:
		_precargar_contrato(o)
		boton_negociacion_accion.text = "Firmar contrato"
	dialogo_negociacion.popup_centered()


## Llena la caja de datos del modal de una oferta ya abierta y devuelve el
## veredicto: si lo que hay sobre la mesa alcanza o no.
##
## El dueño del jugador es el OTRO club cuando la oferta la mandaste vos, y
## sos vos cuando la oferta es entrante — de ahi salen el valor, el sueldo
## y el contrato.
func _datos_de_la_oferta(o: Dictionary) -> String:
	var entrante: bool = bool(o["entrante"])
	var dueno: Team = GameState.equipo_jugador if entrante else negociacion_vendedor
	var id := negociacion_jugador_id
	if dueno == null:
		return ""
	# De un jugador ajeno que no investigaste no se sabe nada: taparlo acá
	# es la misma regla que en el mercado.
	if not entrante and not Investigadores.conoce(GameState.equipo_jugador, id):
		caja_negociacion_datos.add_child(_caja_dato("Vale", "?", Tema.SUAVE))
		caja_negociacion_datos.add_child(_caja_dato("Piden", "?", Tema.SUAVE))
		return ""
	var donde := Mercado.ubicar(dueno, id)
	if donde.is_empty():
		return ""
	var jugador: Dictionary = donde["jugador"]
	var vale := ValorJugador.calcular(
		jugador, dueno.animo.get(id, 50.0), dueno.contratos.get(id, 3))
	var pedido := Negociacion.precio_pedido(dueno, jugador)
	var monto := float(o["monto"])

	caja_negociacion_datos.add_child(_caja_dato(
		"Vale", Economia.formato_dinero(vale)))
	caja_negociacion_datos.add_child(_caja_dato(
		"Sobre la mesa" if entrante else "Piden alrededor de",
		Economia.formato_dinero(monto if entrante else pedido), Tema.AMBAR, true))
	caja_negociacion_datos.add_child(_caja_dato(
		"Hoy cobra", Economia.formato_dinero(dueno.sueldos.get(id, 0.0))))
	caja_negociacion_datos.add_child(_caja_dato(
		"Le quedan", "%d año(s)" % int(dueno.contratos.get(id, 0))))

	if not entrante:
		return ""
	# El veredicto de una oferta entrante, en una linea. `pedido` es lo que
	# pediria por el un club de la IA en tu misma situacion: es el precio
	# de mercado, no un capricho.
	if monto >= pedido:
		return "[color=#27ae60]Te ofrecen más de lo que pedirías por él (%s). Es buen negocio.[/color]" % Economia.formato_dinero(pedido)
	if monto >= vale:
		return "[color=#ffcf43]Cubre lo que vale, pero está por debajo de los %s que pedirías vos.[/color]" % Economia.formato_dinero(pedido)
	return "[color=#c0392b]Es menos de lo que vale (%s). Regatealo o rechazalo.[/color]" % Economia.formato_dinero(vale)


func _precargar_contrato(_o: Dictionary) -> void:
	# El contrato lo decide el usuario. Precargar lo que el jugador aceptaria
	# convertia la negociacion en una respuesta revelada por la interfaz y,
	# sin informe, filtraba su nivel a traves de una cifra salarial.
	spin_negociacion_sueldo.value = 0


func _on_negociacion_accion() -> void:
	if negociacion_oferta_id == -1:
		_enviar_oferta_nueva()
		return
	var o := GameState._oferta_por_id(negociacion_oferta_id)
	if o.is_empty():
		return
	if str(o["estado"]) == Ofertas.ACUERDO_CLUB:
		_firmar_contrato()
	else:
		_responder(o, "aceptar")


func _enviar_oferta_nueva() -> void:
	var r := GameState.enviar_oferta(
		negociacion_vendedor, negociacion_jugador_id, float(spin_negociacion_monto.value))
	if not r["exito"]:
		label_negociacion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	label_negociacion_estado.text = "[color=#27ae60]Oferta enviada. %s te contesta en unos dias — la seguis en Ofertas enviadas.[/color]" % negociacion_vendedor.nombre
	boton_negociacion_accion.disabled = true
	_on_buscar_mercado()


## Aceptar manda el monto EXACTO que hay sobre la mesa, no lo que quedo en
## el control: el paso del SpinBox es de $1.000 y redondeaba una oferta de
## $17.695 a $18.000, asi que "Aceptar" terminaba contraofertando sin que
## nadie lo pidiera.
func _responder(o: Dictionary, accion: String) -> void:
	var monto: float = float(o["monto"]) if accion == "aceptar" else float(spin_negociacion_monto.value)
	var r := GameState.responder_oferta(int(o["id"]), accion, monto)
	if not r["exito"]:
		label_negociacion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	dialogo_negociacion.hide()
	_mostrar_solapa_mercado(solapa_mercado_actual)


func _on_negociacion_contraofertar() -> void:
	var o := GameState._oferta_por_id(negociacion_oferta_id)
	if o.is_empty():
		return
	_responder(o, "contraofertar")


func _on_negociacion_rechazar() -> void:
	var o := GameState._oferta_por_id(negociacion_oferta_id)
	if o.is_empty():
		return
	_responder(o, "rechazar")


func _on_negociacion_retirar() -> void:
	var r := GameState.retirar_oferta(negociacion_oferta_id)
	if not r["exito"]:
		label_negociacion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	dialogo_negociacion.hide()
	_mostrar_solapa_mercado(solapa_mercado_actual)


func _firmar_contrato() -> void:
	var r := GameState.cerrar_fichaje(
		negociacion_oferta_id, float(spin_negociacion_sueldo.value),
		int(spin_negociacion_anios.value))
	if not r["exito"]:
		label_negociacion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	label_negociacion_estado.text = "[color=#27ae60]Cerrado. %s es tuyo.[/color]" % _nombre_jugador(r["jugador"])
	boton_negociacion_accion.disabled = true
	_mostrar_solapa_mercado(solapa_mercado_actual)



## Agentes libres: no se paga fee de transferencia, solo el sueldo. Es la
## unica forma de reforzarse sin plata en la caja de fichajes, asi que la
## pantalla lo dice arriba de todo.
##
## La lista es la de TODA la piramide (Piramide.agentes_libres): el que no
## renovo en cualquiera de las diez divisiones aparece aca. Como son
## muchos, se filtra por puesto y se muestran los MAXIMO_LIBRES mejores.
func _construir_panel_libres(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["libres"] = panel

	var aviso := Label.new()
	aviso.text = "Jugadores sin club de todas las divisiones. No se paga pase: negociás años y sueldo, y si arregla entra a tu banco. Se puede fichar cualquier dia del año, con el libro de pases abierto o cerrado. Los otros clubes tambien miran esta lista todos los dias, asi que una ganga no espera. No sale nadie a cambio: necesitas un lugar libre en el plantel (40 como maximo, entre el once y el banco). Al que dejaste ir vos no lo podes volver a fichar: se lo lleva otro."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(aviso)

	var filtros := HBoxContainer.new()
	panel.add_child(filtros)
	for puesto in ["TODOS"] + Mercado.POSICIONES:
		var btn := Button.new()
		btn.text = str(puesto)
		btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			filtro_libres = str(puesto)
			_refrescar_libres()
		)
		filtros.add_child(btn)
	caja_filtros_libres = filtros

	label_libres_estado = Label.new()
	label_libres_estado.text = ""
	label_libres_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_libres_estado.add_theme_color_override("font_color", Tema.AMBAR)
	panel.add_child(label_libres_estado)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_libres_botones = VBoxContainer.new()
	contenedor_libres_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_libres_botones)


## Una tarjeta vacia con un texto explicativo. Se repite en cuatro
## pantallas (libres, prestamos, cantera, noticias) y siempre por el mismo
## motivo: una lista vacia sin explicacion se lee como algo roto.
func _tarjeta_vacia(texto: String) -> Control:
	var caja := Componentes.tarjeta()
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(l)
	return caja


## Una fila "jugador + un boton": la comparten libres y prestamos.
## `habilitado` false deja el boton a la vista pero apagado: la fila tiene
## que seguir contando por que no se puede (ver los libres vetados).
func _fila_jugador_accion(j: Dictionary, detalle: String, texto_boton: String,
		ayuda_boton: String, al_apretar: Callable,
		habilitado: bool = true) -> Control:
	var fila := Componentes.tarjeta()
	var dentro := HBoxContainer.new()
	fila.add_child(dentro)

	var caja_pos := CenterContainer.new()
	caja_pos.custom_minimum_size = Vector2(56, 0)
	caja_pos.add_child(Componentes.chip(str(j["posicion"]), Color("#2f4a3c")))
	dentro.add_child(caja_pos)

	var izq := VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_constant_override("separation", 2)
	dentro.add_child(izq)
	var nombre := Label.new()
	nombre.text = _nombre_jugador(j)
	nombre.clip_text = true
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	izq.add_child(nombre)
	var sub := Label.new()
	sub.text = detalle
	sub.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	sub.add_theme_color_override("font_color", Tema.SUAVE)
	izq.add_child(sub)

	var caja_media := VBoxContainer.new()
	caja_media.custom_minimum_size = Vector2(90, 0)
	caja_media.add_theme_constant_override("separation", 0)
	dentro.add_child(caja_media)
	caja_media.add_child(Tema.etiqueta_seccion("Media"))
	var l_media := Label.new()
	l_media.text = "%.1f" % float(j["media"])
	Tema.numero(l_media, 22, Componentes.color_de_valor(int(j["media"])))
	caja_media.add_child(l_media)

	var btn := Button.new()
	btn.text = texto_boton
	btn.tooltip_text = ayuda_boton
	btn.custom_minimum_size = Vector2(130, Tema.ALTO_TACTIL)
	btn.disabled = not habilitado
	btn.pressed.connect(al_apretar)
	dentro.add_child(btn)
	return fila


func _refrescar_libres() -> void:
	for hijo in contenedor_libres_botones.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador
	if equipo == null:
		return

	for btn in caja_filtros_libres.get_children():
		Tema.seleccionado(btn, str((btn as Button).text) == filtro_libres)

	# Las dos restricciones del fichaje, arriba de todo: el lugar en el
	# plantel y la plata de Contratos. Sin esto, "Negociar" arregla el
	# contrato y recien ahi el juego avisa que no entra nadie.
	var ocupados: int = equipo.todos_los_jugadores().size()
	var lugares: int = Team.PLANTEL_MAXIMO - ocupados
	var cabecera := Label.new()
	# Con los ocupados a la vista: "0 de 18" solo no dice si el problema es
	# que el plantel esta lleno o que el maximo es cero.
	cabecera.text = "Plantel: %d de %d ocupados   ·   te queda%s %d lugar%s   ·   presupuesto de Contratos: %s" % [
		ocupados, Team.PLANTEL_MAXIMO,
		"" if lugares == 1 else "n", lugares, "" if lugares == 1 else "es",
		Economia.formato_dinero(equipo.caja.get("contratos", 0.0))]
	Tema.numero(cabecera, Tema.TAM_BASE)
	cabecera.add_theme_color_override("font_color", Tema.VERDE if lugares > 0 else Tema.ROJO)
	contenedor_libres_botones.add_child(cabecera)

	if lugares <= 0:
		contenedor_libres_botones.add_child(_tarjeta_vacia(
			"Tenes el plantel completo. Un libre no desplaza a nadie: primero hace falta un lugar (una venta, un prestamo o un contrato que se venza)."))

	var pool: Array = GameState.agentes_libres()
	var visibles := []
	for agente in pool:
		if filtro_libres != "TODOS" and str(agente["posicion"]) != filtro_libres:
			continue
		visibles.append(agente)

	if visibles.is_empty():
		contenedor_libres_botones.add_child(_tarjeta_vacia(
			"No hay agentes libres de ese puesto. Aparecen cuando a un club de cualquier division se le vence un contrato y no lo renueva."))
		return

	visibles.sort_custom(func(a, b): return float(a["media"]) > float(b["media"]))

	if visibles.size() > MAXIMO_LIBRES:
		var recorte := Label.new()
		recorte.text = "Hay %d libres de ese puesto. Se muestran los %d de mejor media." % [
			visibles.size(), MAXIMO_LIBRES]
		recorte.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		recorte.add_theme_color_override("font_color", Tema.SUAVE)
		contenedor_libres_botones.add_child(recorte)
		visibles.resize(MAXIMO_LIBRES)

	for agente in visibles:
		var id: int = int(agente["id"])
		var bloqueo := Renovaciones.dias_bloqueado(equipo, id)
		# Lo que pide de entrada, por el contrato de referencia. Es el
		# numero que decide si te lo podes llevar, asi que va en la fila
		# y no escondido adentro del modal.
		var pide := Renovaciones.pide_ahora(
			equipo, agente, Renovaciones.ANIOS_REFERENCIA)
		var detalle := "%d años   ·   potencial %d   ·   pide %s por %d años" % [
			int(agente["edad"]), int(agente["potencial"]),
			Economia.formato_dinero(pide), Renovaciones.ANIOS_REFERENCIA]
		var ultimo := str(agente.get("club_actual", ""))
		if ultimo != "":
			detalle += "   ·   venia de %s" % ultimo
		if bloqueo > 0:
			detalle += "   ·   no te atiende por %d dias" % bloqueo
		# Al que dejaste ir vos lo seguis viendo, pero no lo podes fichar
		# (AgentesLibres.veta_a). Se muestra igual, y con el motivo: es la
		# consecuencia de no haberle renovado, y esconderlo la taparia.
		var vetado := AgentesLibres.veta_a(equipo, agente)
		if vetado:
			detalle += "   ·   lo dejaste ir vos: no lo podes volver a fichar"
		contenedor_libres_botones.add_child(_fila_jugador_accion(
			agente, detalle,
			"No podes" if vetado else "Negociar",
			"Se fue de tu club al no renovarle. Lo puede fichar cualquier otro club, vos no."
				if vetado
				else "Le ofreces años y sueldo. Si arregla, entra a tu banco sin costo de pase.",
			func(): _abrir_fichaje_libre(id),
			not vetado))


## Abre el modal de negociacion para un agente libre. Es el MISMO modal
## que el de una renovacion (ver _construir_dialogo_renovacion): negociar
## con alguien sin club es el mismo ida y vuelta, solo cambia que no cobra
## nada hoy y que al firmar entra al plantel.
func _abrir_fichaje_libre(agente_id: int) -> void:
	renovacion_es_libre = true
	renovacion_jugador_id = agente_id
	renovacion_anios = Renovaciones.ANIOS_REFERENCIA
	label_renovacion_respuesta.text = ""
	if _jugador_de_renovacion().is_empty():
		return
	_refrescar_dialogo_renovacion(true)
	dialogo_renovacion.popup_centered()


## Lista de transferibles (ver core/traspasos.gd): por quien te pueden
## ofertar y por quien no. Un boton por jugador que cicla entre los tres
## estados; el default es Disponible, o sea que entrar aca y no tocar nada
## deja el mercado como estaba.
var contenedor_traspaso: VBoxContainer


func _construir_panel_traspaso(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["traspaso"] = panel

	var aviso := Label.new()
	aviso.text = "Decidi por quien te pueden ofertar. Disponible: llegan ofertas. No disponible: no llega ninguna. Venta rapida: llegan ofertas entre 40% y 50% mas baratas y el comprador casi no acepta que le pidas mas. Tocá el boton para cambiar el estado."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(aviso)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_traspaso = VBoxContainer.new()
	contenedor_traspaso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_traspaso)


## Titulares, banco y reservas: son los jugadores del plantel por los que
## pueden llegar ofertas (Ofertas.generar_entrantes). La cantera queda fuera.
func _refrescar_traspaso() -> void:
	for hijo in contenedor_traspaso.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador
	var lista := []
	for j in equipo.jugadores:
		lista.append({"jugador": j, "origen": "titular"})
	for j in equipo.banco:
		lista.append({"jugador": j, "origen": "banco"})
	for j in equipo.reservas:
		lista.append({"jugador": j, "origen": "reserva"})

	if lista.is_empty():
		contenedor_traspaso.add_child(_tarjeta_vacia("No tenes jugadores en el plantel."))
		return

	for entrada in lista:
		var j: Dictionary = entrada["jugador"]
		var id: int = int(j["id"])
		var estado := Traspasos.estado(equipo, id)
		var valor := ValorJugador.calcular(
			j, equipo.animo.get(id, 50.0), equipo.contratos.get(id, 3))
		contenedor_traspaso.add_child(_fila_jugador_accion(
			j,
			"%s   ·   %d años   ·   vale %s" % [
				entrada["origen"], int(j["edad"]), Economia.formato_dinero(valor)],
			str(Traspasos.ETIQUETAS[estado]),
			str(Traspasos.AYUDAS[estado]),
			func(): _on_ciclar_traspaso(id)))


func _on_ciclar_traspaso(jugador_id: int) -> void:
	var equipo := GameState.equipo_jugador
	Traspasos.fijar(equipo, jugador_id,
		Traspasos.siguiente(Traspasos.estado(equipo, jugador_id)))
	_refrescar_traspaso()


## Cesion (core/cesiones.gd): la lista de a quien te pueden pedir a
## prestamo y las opciones de compra de los que llegaron cedidos.
##
## Antes esto era un boton "Ceder" que mandaba al jugador a un club al
## azar de tu division, sin negociar nada. Ahora funciona como la solapa
## Traspaso: vos abris la puerta, los pedidos llegan solos a Ofertas
## recibidas y los terminos se discuten ahi.
var contenedor_cesiones: VBoxContainer
var contenedor_cedidos: VBoxContainer


## Club > Cedidos: seguimiento deportivo de los jugadores propios que
## estan jugando a prestamo en otro club.
func _construir_panel_cedidos(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.add_theme_constant_override("separation", 8)
	padre.add_child(panel)
	paneles["cedidos"] = panel

	var aviso := Label.new()
	aviso.text = "Jugadores del club cedidos a otros equipos y su rendimiento durante el prestamo."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(aviso)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_cedidos = VBoxContainer.new()
	contenedor_cedidos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_cedidos.add_theme_constant_override("separation", 0)
	scroll.add_child(contenedor_cedidos)


func _refrescar_cedidos() -> void:
	for hijo in contenedor_cedidos.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador
	if equipo == null or equipo.prestados_afuera.is_empty():
		contenedor_cedidos.add_child(_tarjeta_vacia(
			"No tenes jugadores cedidos a otros clubes."))
		return

	contenedor_cedidos.add_child(_encabezado_de_columnas([
		["Jugador", 210], ["Club", 210],
		["GRL", 70, HORIZONTAL_ALIGNMENT_RIGHT],
		["PJ", 70, HORIZONTAL_ALIGNMENT_RIGHT],
		["Goles", 70, HORIZONTAL_ALIGNMENT_RIGHT],
		["Asist.", 70, HORIZONTAL_ALIGNMENT_RIGHT],
		["Vuelve", 140]]))

	var indice := 0
	for id in equipo.prestados_afuera:
		var info: Dictionary = equipo.prestados_afuera[id]
		var destino_dato = info.get("club")
		var destino: Team = destino_dato as Team
		var club := destino.nombre if destino != null else str(destino_dato)
		var jugador: Dictionary = _buscar_jugador_por_id(destino, int(id)) \
			if destino != null else {}
		var fila := Componentes.fila(indice % 2 == 0)
		var dentro := Componentes.contenido(fila)
		dentro.add_child(Componentes.celda(
			_nombre_jugador(jugador) if not jugador.is_empty() else "Jugador #%s" % id,
			210, Tema.TEXTO))
		dentro.add_child(Componentes.celda(club, 210, Tema.SUAVE))
		dentro.add_child(Componentes.celda_numero(
			"%.1f" % float(jugador.get("media", 0.0)), 70,
			Componentes.color_de_valor(int(jugador.get("media", 0))),
			HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(Componentes.celda_numero(
			str(int(jugador.get("partidos_prestamo", 0))), 70,
			Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(Componentes.celda_numero(
			str(int(jugador.get("goles_prestamo", 0))), 70,
			Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(Componentes.celda_numero(
			str(int(jugador.get("asistencias_prestamo", 0))), 70,
			Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(Componentes.celda(
			"Temporada %.1f" % float(info["temporada_retorno"]), 140, Tema.AMBAR))
		contenedor_cedidos.add_child(fila)
		indice += 1


func _construir_panel_prestamos(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["prestamos"] = panel

	var aviso := Label.new()
	aviso.text = "Marca a quien estas dispuesto a ceder. Los pedidos llegan a Mercado > Ofertas recibidas, y ahi negociás duracion, fee, cuanto del sueldo te sacan de encima y la opcion de compra. El jugador tiene la ultima palabra. Para PEDIR prestado, anda a Mercado > Jugadores."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(aviso)

	label_prestamos_estado = Label.new()
	label_prestamos_estado.text = ""
	label_prestamos_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_prestamos_estado.add_theme_color_override("font_color", Tema.AMBAR)
	panel.add_child(label_prestamos_estado)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(caja)

	contenedor_cesiones = VBoxContainer.new()
	contenedor_cesiones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(contenedor_cesiones)


func _refrescar_prestamos() -> void:
	for hijo in contenedor_cesiones.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador

	# Las opciones de compra que TENES abiertas. Van arriba de todo porque
	# tienen fecha de vencimiento: al volver el prestamo, la chance se
	# pierde (ver Prestamos.procesar_retornos).
	var abiertas: Array = GameState.opciones_de_compra_abiertas()
	if not abiertas.is_empty():
		contenedor_cesiones.add_child(Tema.etiqueta_seccion("Opciones de compra abiertas"))
		for entrada in abiertas:
			var jo: Dictionary = entrada["jugador"]
			var ido: int = int(jo["id"])
			contenedor_cesiones.add_child(_fila_jugador_accion(
				jo,
				"a prestamo de %s   ·   la chance vence en la temporada %.1f" % [
					str(entrada["dueno"]), float(entrada["temporada_retorno"])],
				"Comprar %s" % Economia.formato_dinero(float(entrada["precio"])),
				"Te lo quedas al precio pactado cuando te lo cedieron. Si dejas vencer el prestamo, vuelve a su club.",
				func(): _on_ejercer_opcion(ido)))

	contenedor_cesiones.add_child(Tema.etiqueta_seccion("Lista de cedibles"))
	var lista := []
	for j in equipo.jugadores:
		lista.append({"jugador": j, "origen": "titular"})
	for j in equipo.banco:
		lista.append({"jugador": j, "origen": "banco"})
	for j in equipo.reservas:
		lista.append({"jugador": j, "origen": "reserva"})
	for j in equipo.cantera:
		lista.append({"jugador": j, "origen": "cantera"})

	if lista.is_empty():
		contenedor_cesiones.add_child(_tarjeta_vacia("No tenes jugadores en el plantel."))
		return

	for entrada in lista:
		var j: Dictionary = entrada["jugador"]
		var id: int = int(j["id"])
		var estado := Cesiones.estado(equipo, id)
		contenedor_cesiones.add_child(_fila_jugador_accion(
			j,
			"%s   ·   %d años   ·   potencial %d" % [
				str(entrada["origen"]), int(j["edad"]), int(j["potencial"])],
			str(Cesiones.ETIQUETAS[estado]),
			str(Cesiones.AYUDAS[estado]),
			func(): _on_ciclar_cesion(id)))


func _on_ejercer_opcion(jugador_id: int) -> void:
	var r := GameState.ejercer_opcion_de_compra(jugador_id)
	if r["exito"]:
		label_prestamos_estado.text = "Ejerciste la opcion: %s es tuyo por %s (sueldo %s, %d años)." % [
			_nombre_jugador(r["jugador"]), Economia.formato_dinero(r["precio"]),
			Economia.formato_dinero(r["sueldo"]), int(r["anios"])]
	else:
		label_prestamos_estado.text = "No se pudo: %s" % r["motivo"]
	_refrescar_prestamos()
	_refrescar_plantel()
	_refrescar_economia()


func _on_ciclar_cesion(jugador_id: int) -> void:
	var equipo := GameState.equipo_jugador
	Cesiones.fijar(equipo, jugador_id,
		Cesiones.siguiente(Cesiones.estado(equipo, jugador_id)))
	_refrescar_prestamos()

## Instalaciones del club (§9.5): mejoras permanentes pagadas con el
## presupuesto de Mejoras, ver core/instalaciones.gd.
const NOMBRES_INSTALACIONES := {
	"estadio": "Estadio",
	"medica": "Médica",
	"juveniles": "Juveniles",
	"scouting": "Scouting",
	"entrenamiento": "Entrenamiento",
}

## Que hace cada area, en una linea. Va aparte del nombre porque el nombre
## se lee de un vistazo y esto se lee cuando dudas.
const QUE_HACE_INSTALACION := {
	"estadio": "Mas aforo: entra mas gente y suben los ingresos por entradas.",
	"medica": "Menos lesiones y recuperacion de fatiga mas rapida entre fechas.",
	"juveniles": "Camada de cantera mas grande y con mejor techo.",
	"scouting": "Reportes de potencial mas precisos: el rango de los juveniles se achica.",
	"entrenamiento": "Todo el plantel crece un poco mas rapido.",
}

## Que pestaña de Instalaciones esta abierta. Mejoras e investigadores no
## tienen nada que ver entre si salvo que se pagan con la misma caja, y
## apiladas en un solo scroll no se entendia donde empezaba una y
## terminaba la otra.
var solapa_instalaciones: String = "mejoras"
var contenedor_instalaciones_solapas: HBoxContainer
var dialogo_investigador: AcceptDialog
var contenedor_investigador_dialogo: VBoxContainer
var label_investigador_dialogo: Label


## Los efectos CONCRETOS de un nivel, para poder comparar el actual con el
## siguiente. Sin esto "subir a nivel 3 cuesta $72.000" no dice nada:
## no se sabe que se compra.
func _efecto_instalacion(categoria: String, nivel: int) -> String:
	# Todo sale de Instalaciones: las formulas estaban copiadas aca y
	# quedaron mintiendo cuando los niveles pasaron de cinco a diez.
	var t := Instalaciones.progreso(nivel)
	match categoria:
		"estadio":
			if nivel <= 1:
				return "aforo base"
			return "aforo +%d%%" % round(t * Instalaciones.BONUS_AFORO_MAX * 100.0)
		"medica":
			return "lesiones −%d%%, recuperacion +%d%%" % [
				round(t * Instalaciones.REDUCCION_LESION_MAX * 100.0),
				round(t * Instalaciones.BONUS_RECUPERACION_MAX * 100.0)]
		"juveniles":
			# La calidad se SUMA al nivel del club: en la mitad de abajo de
			# la escala la academia saca chicos peores que el club.
			return "camada de %d, calidad %+d" % [
				Instalaciones.CAMADA_MIN + int(round(
					t * float(Instalaciones.CAMADA_MAX - Instalaciones.CAMADA_MIN))),
				int(round((t - 0.5) * Instalaciones.CALIDAD_JUVENILES_RANGO))]
		"scouting":
			return "potencial de juveniles ±%d" % Scout.margen(
				Instalaciones.nivel_scout_de_nivel(nivel))
		"entrenamiento":
			return "crecimiento +%d%%" % round(t * Instalaciones.BONUS_ENTRENAMIENTO_MAX * 100.0)
	return ""


## Los niveles como puntos llenos y vacios: cuanto te queda por mejorar se
## ve sin leer "3/5".
func _puntos_de_nivel(nivel: int, maximo: int) -> Label:
	var l := Label.new()
	l.text = "●".repeat(nivel) + "○".repeat(maximo - nivel)
	l.add_theme_color_override("font_color", Tema.AMBAR)
	return l


## Club › Renovaciones. Los contratos que se vencen al final de ESTA
## temporada y la negociacion para retenerlos.
##
## Antes esta pantalla no existia y al club del jugador humano se le
## renovaba todo solo, con el sueldo recalculado al valor de hoy: la masa
## salarial subia sola todos los años contra un ingreso con techo, y el
## club no tenia forma de decir que no. Poder dejar ir a un veterano caro
## es el freno que le faltaba a la economia (ver core/renovaciones.gd).
var contenedor_renovaciones: VBoxContainer
var label_renovaciones_estado: Label
## Los años elegidos por jugador. Se guardan acá y no en el Team porque
## son una oferta que todavia no existe: hasta que no firma, no pasa nada.
var anios_renovacion: Dictionary = {}


func _construir_panel_renovaciones(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["renovaciones"] = panel

	label_renovaciones_estado = Label.new()
	label_renovaciones_estado.text = ""
	label_renovaciones_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_renovaciones_estado.add_theme_color_override("font_color", Tema.AMBAR)
	panel.add_child(label_renovaciones_estado)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_renovaciones = VBoxContainer.new()
	contenedor_renovaciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_renovaciones)


func _refrescar_renovaciones() -> void:
	if contenedor_renovaciones == null:
		return
	for hijo in contenedor_renovaciones.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	if equipo == null:
		return

	var disponible: float = equipo.caja.get("contratos", 0.0)
	var cabecera := Label.new()
	cabecera.text = "Presupuesto de Contratos: %s" % Economia.formato_dinero(disponible)
	Tema.numero(cabecera, Tema.TAM_BASE)
	cabecera.add_theme_color_override(
		"font_color", Tema.VERDE if disponible > 0.0 else Tema.ROJO)
	contenedor_renovaciones.add_child(cabecera)

	var pendientes := Renovaciones.pendientes(equipo)
	if pendientes.is_empty():
		var vacio := Label.new()
		vacio.text = "No se te vence ningun contrato. Aca aparecen los que quedan con un año o menos: si no arreglas antes del cierre, se van libres."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vacio.add_theme_color_override("font_color", Tema.SUAVE)
		contenedor_renovaciones.add_child(vacio)
		return

	var aviso := Label.new()
	aviso.text = "Se van libres al cerrar la temporada si no firman. Sentate a negociar con el boton: se puede ir y venir hasta arreglar, pero una oferta muy por debajo de lo que pide lo ofende y no te atiende por dos meses."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	contenedor_renovaciones.add_child(aviso)

	for i in range(pendientes.size()):
		contenedor_renovaciones.add_child(
			_fila_renovacion(equipo, pendientes[i], i % 2 == 0))


## Una linea por jugador y un solo boton. Lo que cobra y cuanto le queda
## se ven de la lista; el resto es la negociacion, y esa vive en el modal.
func _fila_renovacion(equipo: Team, jugador: Dictionary, par: bool) -> Control:
	var id: int = jugador["id"]
	var bloqueo := Renovaciones.dias_bloqueado(equipo, id)
	var restante: int = int(equipo.contratos.get(id, 0))

	var fila_panel := Componentes.fila(par)
	var fila := Componentes.contenido(fila_panel)

	fila.add_child(Componentes.celda(_nombre_jugador(jugador), 220))
	fila.add_child(Componentes.celda(str(jugador["posicion"]), 60, Tema.SUAVE))
	fila.add_child(Componentes.celda_numero("%d años" % int(jugador.get("edad", 25)), 80, Tema.SUAVE))
	fila.add_child(Componentes.celda_numero(str(int(jugador["media"])), 60,
		Componentes.color_de_valor(int(jugador["media"]))))
	fila.add_child(Componentes.celda_numero(
		Economia.formato_dinero(float(equipo.sueldos.get(id, 0.0))), 120))
	fila.add_child(Componentes.celda(
		"le queda %d año%s" % [restante, "" if restante == 1 else "s"], 130,
		Tema.ROJO if restante <= 1 else Tema.AMBAR))

	if bloqueo > 0:
		# Se ofendio: no hay boton, hay un cartel con lo que falta. Sin
		# esto la pantalla mentia, porque el modal se abria igual y
		# rebotaba toda oferta.
		fila.add_child(Componentes.celda(
			"no te atiende (%d dias)" % bloqueo, 220, Tema.ROJO))
	else:
		var btn := Componentes.boton_de_celda("Renovar", 220)
		btn.pressed.connect(func(): _abrir_renovacion(id))
		fila.add_child(btn)

	return fila_panel


## §9.3: el modal de renovacion. Es un ida y vuelta, no un boton de
## comprar: le ofreces años y plata, y contesta. Ver core/renovaciones.gd
## para las tres respuestas posibles y cuanto cede en cada ronda.
var dialogo_renovacion: AcceptDialog
var renovacion_jugador_id: int = -1
## El mismo modal atiende las dos negociaciones que hay: renovar a uno del
## plantel y fichar a un agente libre (Mercado > Libres). Cambia de donde
## se busca al jugador y que se hace cuando acepta; el ida y vuelta es el
## mismo, y por eso es un solo modal y no dos.
var renovacion_es_libre: bool = false
var renovacion_anios: int = Renovaciones.ANIOS_REFERENCIA
var label_renovacion_titulo: Label
var label_renovacion_sub: Label
var caja_renovacion_anios: HBoxContainer
var spin_renovacion_sueldo: SpinBox
var label_renovacion_costo: Label
var label_renovacion_respuesta: RichTextLabel
var boton_renovacion_ofrecer: Button


func _construir_dialogo_renovacion() -> void:
	dialogo_renovacion = AcceptDialog.new()
	dialogo_renovacion.title = "Renovacion"
	dialogo_renovacion.min_size = Vector2(760, 0)
	add_child(dialogo_renovacion)
	Tema.dialogo(dialogo_renovacion)
	# La fila nativa queda debajo de todo el contenido y en celulares bajos
	# podia salir de la pantalla. Las dos acciones viven juntas dentro del
	# cuerpo, siempre visibles y sin sumar otra fila al alto del modal.
	dialogo_renovacion.get_ok_button().hide()

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 4)
	dialogo_renovacion.add_child(caja)

	label_renovacion_titulo = Label.new()
	Tema.numero(label_renovacion_titulo, 24)
	caja.add_child(label_renovacion_titulo)

	label_renovacion_sub = Label.new()
	label_renovacion_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_renovacion_sub.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(label_renovacion_sub)

	caja.add_child(Tema.etiqueta_seccion("Años de contrato"))
	caja_renovacion_anios = HBoxContainer.new()
	caja.add_child(caja_renovacion_anios)
	for n in range(Renovaciones.ANIOS_MIN, Renovaciones.ANIOS_MAX + 1):
		var btn := Button.new()
		btn.text = str(n)
		btn.custom_minimum_size = Vector2(Tema.ALTO_TACTIL * 1.6, Tema.ALTO_TACTIL)
		btn.pressed.connect(func():
			renovacion_anios = n
			# Cambiar los años cambia lo que pide, asi que la oferta
			# arranca de nuevo en la cifra nueva.
			_refrescar_dialogo_renovacion(true)
		)
		caja_renovacion_anios.add_child(btn)

	var contrato := VBoxContainer.new()
	caja.add_child(contrato)
	# Paso 1: SpinBox redondea el valor al multiplo del paso mas cercano.
	# Con paso 100, ofrecer 323 se guardaba como 300 y el jugador rechazaba
	# siempre la misma cifra, escribieras lo que escribieras.
	spin_renovacion_sueldo = _fila_spin(contrato, "Sueldo por temporada", 0, 500000000, 1)
	spin_renovacion_sueldo.value_changed.connect(
		func(_v): _actualizar_costo_renovacion())

	label_renovacion_costo = Label.new()
	label_renovacion_costo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(label_renovacion_costo)

	label_renovacion_respuesta = RichTextLabel.new()
	label_renovacion_respuesta.bbcode_enabled = true
	label_renovacion_respuesta.fit_content = true
	# Dos lineas alcanzan para la contraoferta; antes reservaba 110 px aun
	# vacio y empujaba las acciones fuera de la pantalla.
	label_renovacion_respuesta.custom_minimum_size = Vector2(0, 52)
	caja.add_child(label_renovacion_respuesta)

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	caja.add_child(acciones)
	boton_renovacion_ofrecer = Componentes.boton_de_accion("Ofrecer", 240)
	boton_renovacion_ofrecer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_renovacion_ofrecer.pressed.connect(_on_ofrecer_renovacion)
	acciones.add_child(boton_renovacion_ofrecer)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(160, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(dialogo_renovacion.hide)
	acciones.add_child(cerrar)


func _jugador_de_renovacion() -> Dictionary:
	var equipo := GameState.equipo_jugador
	if equipo == null:
		return {}
	if renovacion_es_libre:
		for a in GameState.agentes_libres():
			if int(a["id"]) == renovacion_jugador_id:
				return a
		return {}
	for j in equipo.todos_los_jugadores():
		if int(j["id"]) == renovacion_jugador_id:
			return j
	return {}


func _abrir_renovacion(id: int) -> void:
	renovacion_es_libre = false
	renovacion_jugador_id = id
	var equipo := GameState.equipo_jugador
	renovacion_anios = maxi(
		Renovaciones.ANIOS_REFERENCIA, int(equipo.contratos.get(id, 1)))
	label_renovacion_respuesta.text = ""
	_refrescar_dialogo_renovacion(true)
	dialogo_renovacion.popup_centered()


## `reiniciar_oferta` pone en el spin lo que el jugador pide hoy. Se hace
## al abrir y al cambiar los años; no despues de una contraoferta, donde
## la cifra que el jugador acaba de pedir ya es la que corresponde.
func _refrescar_dialogo_renovacion(reiniciar_oferta: bool) -> void:
	var equipo := GameState.equipo_jugador
	var jugador := _jugador_de_renovacion()
	if jugador.is_empty():
		return
	var id: int = jugador["id"]

	label_renovacion_titulo.text = "%s (%s, %d años, media %d)" % [
		_nombre_jugador(jugador), jugador["posicion"],
		int(jugador.get("edad", 25)), int(jugador["media"])]

	var cobra: float = float(equipo.sueldos.get(id, 0.0))
	var pide := Renovaciones.pide_ahora(equipo, jugador, renovacion_anios)
	var restante: int = int(equipo.contratos.get(id, 0))
	if renovacion_es_libre:
		dialogo_renovacion.title = "Fichaje libre"
		var lugares: int = Team.PLANTEL_MAXIMO - equipo.todos_los_jugadores().size()
		label_renovacion_sub.text = "Esta sin club: no se paga pase, solo el sueldo. Por %d año%s pide %s. Tenes %s en el presupuesto de Contratos y %d lugar%s en el plantel." % [
			renovacion_anios, "" if renovacion_anios == 1 else "s",
			Economia.formato_dinero(pide),
			Economia.formato_dinero(equipo.caja.get("contratos", 0.0)),
			lugares, "" if lugares == 1 else "es"]
	else:
		dialogo_renovacion.title = "Renovacion"
		label_renovacion_sub.text = "Cobra %s y le queda%s %d año%s. Por %d año%s pide %s. Tenes %s en el presupuesto de Contratos." % [
			Economia.formato_dinero(cobra), "n" if restante != 1 else "", restante,
			"" if restante == 1 else "s", renovacion_anios,
			"" if renovacion_anios == 1 else "s", Economia.formato_dinero(pide),
			Economia.formato_dinero(equipo.caja.get("contratos", 0.0))]

	for i in range(caja_renovacion_anios.get_child_count()):
		var btn: Button = caja_renovacion_anios.get_child(i)
		btn.disabled = (i + Renovaciones.ANIOS_MIN == renovacion_anios)

	if reiniciar_oferta:
		spin_renovacion_sueldo.value = round(pide)

	_actualizar_costo_renovacion()

	var bloqueo := Renovaciones.dias_bloqueado(equipo, id)
	boton_renovacion_ofrecer.disabled = bloqueo > 0


## Lo que la renovacion le saca al presupuesto de Contratos, en plata y al
## momento. El modal antes decia solo "se descuenta la diferencia con lo
## que ya cobra" y la resta la tenia que hacer el jugador de cabeza: el
## sueldo viejo estaba en una frase, el ofrecido en el spin y el saldo en
## otra frase. Con tres numeros sueltos, cualquier renovacion parecia
## descontar de mas. Ahora la cuenta esta hecha y se actualiza mientras
## moves la oferta.
func _actualizar_costo_renovacion() -> void:
	if label_renovacion_costo == null:
		return
	var equipo := GameState.equipo_jugador
	var jugador := _jugador_de_renovacion()
	if equipo == null or jugador.is_empty():
		return

	var cobra: float = float(equipo.sueldos.get(int(jugador["id"]), 0.0))
	var ofrecido: float = spin_renovacion_sueldo.value
	var disponible: float = equipo.caja.get("contratos", 0.0)
	var descuento: float = ofrecido - cobra

	# Un libre no cobra nada hoy: se descuenta el sueldo ENTERO, no una
	# diferencia. La cuenta de abajo hablaria de "los $0 que ya cobra".
	if renovacion_es_libre:
		var resto: float = disponible - ofrecido
		if resto >= 0.0:
			label_renovacion_costo.text = "Si firma por %s se descuenta todo de Contratos: no cobra nada hoy. Te quedan %s." % [
				Economia.formato_dinero(ofrecido), Economia.formato_dinero(resto)]
			label_renovacion_costo.add_theme_color_override("font_color", Tema.VERDE)
		else:
			label_renovacion_costo.text = "Si firma por %s se descuenta todo de Contratos y te faltan %s." % [
				Economia.formato_dinero(ofrecido), Economia.formato_dinero(-resto)]
			label_renovacion_costo.add_theme_color_override("font_color", Tema.ROJO)
		return

	# Ofrecerle lo mismo o menos no cuesta nada: el club ya venia pagando
	# ese sueldo, asi que el presupuesto no se mueve.
	if descuento <= 0.0:
		label_renovacion_costo.text = "Si firma por %s no se descuenta nada: no le subis el sueldo. Te siguen quedando %s." % [
			Economia.formato_dinero(ofrecido), Economia.formato_dinero(disponible)]
		label_renovacion_costo.add_theme_color_override("font_color", Tema.VERDE)
		return

	var queda: float = disponible - descuento
	var cuenta := "Si firma por %s se descuentan %s (%s menos los %s que ya cobra)." % [
		Economia.formato_dinero(ofrecido), Economia.formato_dinero(descuento),
		Economia.formato_dinero(ofrecido), Economia.formato_dinero(cobra)]
	if queda >= 0.0:
		label_renovacion_costo.text = "%s Te quedan %s." % [
			cuenta, Economia.formato_dinero(queda)]
		label_renovacion_costo.add_theme_color_override("font_color", Tema.VERDE)
	else:
		label_renovacion_costo.text = "%s Te faltan %s." % [
			cuenta, Economia.formato_dinero(-queda)]
		label_renovacion_costo.add_theme_color_override("font_color", Tema.ROJO)


func _on_ofrecer_renovacion() -> void:
	var equipo := GameState.equipo_jugador
	var jugador := _jugador_de_renovacion()
	if jugador.is_empty():
		return
	var ofrecido: float = spin_renovacion_sueldo.value

	var r := Renovaciones.ofrecer(equipo, jugador, renovacion_anios, ofrecido)
	match str(r["respuesta"]):
		"acepta":
			var firma := (
				GameState.fichar_agente_libre(
					int(jugador["id"]), renovacion_anios, ofrecido)
				if renovacion_es_libre
				else Renovaciones.firmar(equipo, jugador, renovacion_anios, ofrecido))
			if renovacion_es_libre:
				if bool(firma.get("exito", false)):
					label_libres_estado.text = "Ficha un %s de media %d por %d año%s a %s. Entra al banco." % [
						str(jugador["posicion"]), int(jugador["media"]),
						int(firma["anios"]), "" if int(firma["anios"]) == 1 else "s",
						Economia.formato_dinero(float(firma["sueldo"]))]
					label_libres_estado.add_theme_color_override("font_color", Tema.VERDE)
					dialogo_renovacion.hide()
				else:
					label_renovacion_respuesta.text = "[color=#%s]Arreglaron, pero no pudiste ficharlo: %s[/color]" % [
						Tema.ROJO.to_html(false), str(firma.get("motivo", ""))]
				_refrescar_libres()
				_refrescar_economia()
				_refrescar_plantel()
				return
			if bool(firma.get("exito", false)):
				label_renovaciones_estado.text = "%s renueva por %d año%s a %s." % [
					_nombre_jugador(jugador), int(firma["anios"]),
					"" if int(firma["anios"]) == 1 else "s",
					Economia.formato_dinero(float(firma["sueldo"]))]
				label_renovaciones_estado.add_theme_color_override("font_color", Tema.VERDE)
				dialogo_renovacion.hide()
			else:
				label_renovacion_respuesta.text = "[color=#%s]Acepto, pero no pudiste firmar: %s[/color]" % [
					Tema.ROJO.to_html(false), str(firma.get("motivo", ""))]
		"contraoferta":
			var pide: float = float(r["pide"])
			var pide_anios: int = int(r["anios"])
			var texto := "[color=#%s]Ronda %d.[/color] Le ofreciste %s y no le alcanza. Baja a [b]%s[/b]" % [
				Tema.AMBAR.to_html(false), int(r["ronda"]),
				Economia.formato_dinero(float(r["ofreciste"])),
				Economia.formato_dinero(pide)]
			if pide_anios != renovacion_anios:
				texto += ", pero te pide [b]%d años[/b] en vez de %d." % [
					pide_anios, renovacion_anios]
				renovacion_anios = pide_anios
			else:
				texto += "."
			texto += "\nVenia pidiendo %s." % Economia.formato_dinero(float(r["pedia"]))
			label_renovacion_respuesta.text = texto
			_refrescar_dialogo_renovacion(false)
			spin_renovacion_sueldo.value = round(
				Renovaciones.pide_ahora(equipo, jugador, renovacion_anios))
		"insulto":
			label_renovacion_respuesta.text = "[color=#%s]Se ofendio.[/color] Pedia %s y le ofreciste mucho menos. Corta la negociacion y no te atiende por %d dias." % [
				Tema.ROJO.to_html(false), Economia.formato_dinero(float(r["pide"])),
				int(r["dias"])]
			boton_renovacion_ofrecer.disabled = true
		"se_cansa":
			label_renovacion_respuesta.text = "[color=#%s]Se canso de negociar.[/color] Habia bajado hasta %s y le seguiste ofreciendo %s. Corta por %d dias." % [
				Tema.ROJO.to_html(false), Economia.formato_dinero(float(r["pide"])),
				Economia.formato_dinero(float(r["ofreciste"])), int(r["dias"])]
			boton_renovacion_ofrecer.disabled = true
		_:
			label_renovacion_respuesta.text = "[color=#%s]No te atiende: faltan %d dias.[/color]" % [
				Tema.ROJO.to_html(false), int(r.get("dias", 0))]

	_refrescar_renovaciones()
	_refrescar_libres()
	_refrescar_economia()
	_refrescar_plantel()



func _construir_panel_instalaciones(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["instalaciones"] = panel

	contenedor_instalaciones_solapas = HBoxContainer.new()
	panel.add_child(contenedor_instalaciones_solapas)
	for par in [["mejoras", "Mejoras"], ["investigadores", "Investigadores"]]:
		var clave: String = par[0]
		var btn := Button.new()
		btn.text = str(par[1])
		btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
		btn.pressed.connect(func():
			solapa_instalaciones = clave
			_refrescar_instalaciones()
		)
		contenedor_instalaciones_solapas.add_child(btn)

	label_instalaciones_estado = Label.new()
	label_instalaciones_estado.text = ""
	label_instalaciones_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_instalaciones_estado.add_theme_color_override("font_color", Tema.AMBAR)
	panel.add_child(label_instalaciones_estado)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_instalaciones_botones = VBoxContainer.new()
	contenedor_instalaciones_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_instalaciones_botones)


func _refrescar_instalaciones() -> void:
	for hijo in contenedor_instalaciones_botones.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador

	for btn in contenedor_instalaciones_solapas.get_children():
		var clave := "mejoras"
		if str((btn as Button).text) == "Investigadores":
			clave = "investigadores"
		Tema.seleccionado(btn, clave == solapa_instalaciones)

	# La caja de Mejoras es la restriccion de las dos solapas, asi que va
	# siempre a la vista: sin esto "Mejorar" aparece apagado y no se
	# entiende por que.
	var caja := Componentes.tarjeta()
	var dentro := HBoxContainer.new()
	caja.add_child(dentro)
	var izq := VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_constant_override("separation", 0)
	dentro.add_child(izq)
	izq.add_child(Tema.etiqueta_seccion("Presupuesto de Mejoras disponible"))
	var l := Label.new()
	l.text = Economia.formato_dinero(equipo.caja.get("mejoras", 0.0))
	Tema.numero(l, 26, Tema.VERDE if equipo.caja.get("mejoras", 0.0) > 0.0 else Tema.ROJO)
	izq.add_child(l)
	var nota := Label.new()
	nota.text = "Las mejoras y los investigadores salen de esta misma caja: compiten entre si."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(420, 0)
	nota.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	nota.add_theme_color_override("font_color", Tema.SUAVE)
	dentro.add_child(nota)
	contenedor_instalaciones_botones.add_child(caja)

	match solapa_instalaciones:
		"investigadores":
			_refrescar_investigadores_instalaciones(equipo)
		_:
			_refrescar_mejoras(equipo)


## Las cinco areas. Cada una dice lo que da AHORA y lo que daria con el
## nivel siguiente: sin eso, "subir a nivel 3 cuesta $72.000" no informa
## nada, porque no se sabe que se compra.
func _refrescar_mejoras(equipo: Team) -> void:
	var disponible: float = equipo.caja.get("mejoras", 0.0)
	for categoria in Instalaciones.CATEGORIAS:
		var nivel: int = equipo.instalaciones.get(categoria, 1)
		var al_maximo: bool = nivel >= Instalaciones.NIVEL_MAXIMO
		var costo: float = 0.0 if al_maximo else Instalaciones.costo_siguiente_nivel(nivel)

		var tarjeta := Componentes.tarjeta(Tema.VERDE if al_maximo else Color.TRANSPARENT)
		contenedor_instalaciones_botones.add_child(tarjeta)
		var fila := HBoxContainer.new()
		tarjeta.add_child(fila)

		var izq := VBoxContainer.new()
		izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		izq.add_theme_constant_override("separation", 3)
		fila.add_child(izq)

		var cabecera := HBoxContainer.new()
		izq.add_child(cabecera)
		var nombre := Label.new()
		nombre.text = str(NOMBRES_INSTALACIONES[categoria])
		Tema.numero(nombre, Tema.TAM_BASE)
		cabecera.add_child(nombre)
		cabecera.add_child(_puntos_de_nivel(nivel, Instalaciones.NIVEL_MAXIMO))
		var n := Label.new()
		n.text = "nivel %d de %d" % [nivel, Instalaciones.NIVEL_MAXIMO]
		n.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		n.add_theme_color_override("font_color", Tema.SUAVE)
		cabecera.add_child(n)

		var que := Label.new()
		que.text = str(QUE_HACE_INSTALACION[categoria])
		que.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		que.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		que.add_theme_color_override("font_color", Tema.SUAVE)
		izq.add_child(que)

		var salto := Label.new()
		if al_maximo:
			salto.text = "Ahora: %s   ·   ya esta al maximo" % _efecto_instalacion(categoria, nivel)
			salto.add_theme_color_override("font_color", Tema.VERDE)
		else:
			salto.text = "Ahora %s   →   con nivel %d %s" % [
				_efecto_instalacion(categoria, nivel), nivel + 1,
				_efecto_instalacion(categoria, nivel + 1)]
			salto.add_theme_color_override("font_color", Tema.CELESTE)
		salto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		salto.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		izq.add_child(salto)

		var der := VBoxContainer.new()
		der.custom_minimum_size = Vector2(230, 0)
		der.add_theme_constant_override("separation", 3)
		fila.add_child(der)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
		var cat: String = categoria
		btn.pressed.connect(func(): _on_mejorar_instalacion(cat))
		if al_maximo:
			btn.text = "Al maximo"
			btn.disabled = true
		else:
			btn.text = "Mejorar por %s" % Economia.formato_dinero(costo)
			btn.disabled = disponible < costo
		der.add_child(btn)

		# Un boton apagado sin motivo es lo que hacia que no se entendiera
		# como mejorar: ahora dice cuanto falta.
		if not al_maximo and disponible < costo:
			var falta := Label.new()
			falta.text = "te faltan %s" % Economia.formato_dinero(costo - disponible)
			falta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			falta.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
			falta.add_theme_color_override("font_color", Tema.ROJO)
			der.add_child(falta)


## §9.4: la red de investigadores vive en Instalaciones porque es lo que
## es — una inversion permanente del club, pagada con Mejoras, que compite
## con el estadio y la cantera por la misma plata. A quien estas mirando
## con ella se ve en Mercado › Investigaciones.
##
## Se muestran como SEIS slots en una grilla de 3x2, ocupados o vacios. Un
## slot vacio es un boton de contratar: asi la pantalla dice de un vistazo
## cuanto lugar te queda, en vez de una lista de contratados seguida de
## otra lista de diez precios.
func _refrescar_investigadores_instalaciones(equipo: Team) -> void:
	var explica := Label.new()
	explica.text = "Las estrellas son VELOCIDAD, no calidad: el informe siempre sale completo, uno de 10★ solo tarda menos."
	explica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explica.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	explica.add_theme_color_override("font_color", Tema.SUAVE)
	contenedor_instalaciones_botones.add_child(explica)

	var grilla := GridContainer.new()
	grilla.columns = 3
	grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grilla.add_theme_constant_override("h_separation", 10)
	grilla.add_theme_constant_override("v_separation", 10)
	contenedor_instalaciones_botones.add_child(grilla)

	for i in range(Investigadores.SLOTS):
		if i < equipo.investigadores.size():
			grilla.add_child(_cubo_investigador(equipo, equipo.investigadores[i]))
		else:
			grilla.add_child(_cubo_slot_libre(equipo))


## Alto de cada cubo. Calibrado para que las DOS filas de la grilla
## entren juntas en una pantalla de 648: con 168 la de abajo quedaba
## cortada y habia que scrollear para ver la mitad de tus slots.
const ALTO_CUBO_INVESTIGADOR := 140


func _cubo_investigador(equipo: Team, inv: Dictionary) -> Control:
	var ocupado: bool = int(inv["objetivo"]) != -1
	var tarjeta := Componentes.tarjeta(Tema.VERDE if ocupado else Tema.BORDE)
	tarjeta.custom_minimum_size = Vector2(0, ALTO_CUBO_INVESTIGADOR)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	tarjeta.add_child(caja)

	var nombre := Label.new()
	nombre.text = str(inv.get("nombre", "Ojeador"))
	nombre.clip_text = true
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tema.numero(nombre, Tema.TAM_BASE)
	caja.add_child(nombre)

	var estrellas := Label.new()
	estrellas.text = "★".repeat(int(inv["estrellas"]))
	estrellas.clip_text = true
	estrellas.add_theme_color_override("font_color", Tema.AMBAR)
	caja.add_child(estrellas)

	var dias := Label.new()
	dias.text = "informe en %d dias" % int(Investigadores.dias_de_informe(int(inv["estrellas"])))
	dias.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	dias.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(dias)

	var estado := Label.new()
	if ocupado:
		var quien := str(inv.get("nombre_objetivo", ""))
		estado.text = "investigando a %s" % (quien if quien != "" else str(inv.get("club_objetivo", "alguien")))
		estado.add_theme_color_override("font_color", Tema.VERDE)
	else:
		estado.text = "libre, esperando orden"
		estado.add_theme_color_override("font_color", Tema.SUAVE)
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	estado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	estado.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	caja.add_child(estado)

	var id_inv := int(inv["id"])
	var btn := Button.new()
	btn.text = "Despedir"
	btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	btn.tooltip_text = "No hay devolucion, y un informe a medio hacer se pierde."
	btn.pressed.connect(func():
		Investigadores.despedir(equipo, id_inv)
		label_instalaciones_estado.text = "Se fue %s: quedo un slot libre." % str(
			inv.get("nombre", "el investigador"))
		_refrescar_instalaciones()
	)
	caja.add_child(btn)
	return tarjeta


func _cubo_slot_libre(equipo: Team) -> Control:
	var tarjeta := Componentes.tarjeta()
	tarjeta.custom_minimum_size = Vector2(0, ALTO_CUBO_INVESTIGADOR)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel")
	estilo.bg_color = Tema.PANEL

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	tarjeta.add_child(caja)

	var vacio := Label.new()
	vacio.text = "Slot libre"
	vacio.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(vacio)

	var hueco := Control.new()
	hueco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(hueco)

	var btn := Button.new()
	btn.text = "Contratar investigador"
	btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	btn.clip_text = true
	if equipo.investigadores.is_empty():
		Tema.primario(btn)
	btn.pressed.connect(_abrir_dialogo_investigador)
	caja.add_child(btn)
	return tarjeta


## El menu de contratacion. Va en un modal y no en la pantalla porque son
## diez opciones que solo se miran en el momento de contratar: abajo de la
## grilla convertian la pantalla en la lista larga que se queria evitar.
func _construir_dialogo_investigador() -> void:
	dialogo_investigador = AcceptDialog.new()
	dialogo_investigador.title = "Contratar un investigador"
	dialogo_investigador.min_size = Vector2(720, 0)
	# Un tope duro: sin esto el dialogo crece con su contenido —diez filas
	# de opciones— y se pasa del alto de la pantalla, dejando el boton de
	# cerrar afuera. Que scrollee la lista, no la ventana.
	dialogo_investigador.max_size = Vector2(760, 560)
	add_child(dialogo_investigador)
	Tema.dialogo(dialogo_investigador)
	dialogo_investigador.get_ok_button().hide()

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogo_investigador.add_child(caja)

	label_investigador_dialogo = Label.new()
	label_investigador_dialogo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_investigador_dialogo.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_investigador_dialogo.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(label_investigador_dialogo)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Con 380 el dialogo crecia mas alto que la pantalla y el boton de
	# cerrar quedaba abajo del borde.
	scroll.custom_minimum_size = Vector2(0, 260)
	caja.add_child(scroll)
	contenedor_investigador_dialogo = VBoxContainer.new()
	contenedor_investigador_dialogo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_investigador_dialogo)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(dialogo_investigador.hide)
	caja.add_child(cerrar)


func _abrir_dialogo_investigador() -> void:
	_refrescar_dialogo_investigador()
	dialogo_investigador.popup_centered()


func _refrescar_dialogo_investigador() -> void:
	for hijo in contenedor_investigador_dialogo.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var disponible: float = equipo.caja.get("mejoras", 0.0)
	var libres: int = Investigadores.SLOTS - equipo.investigadores.size()

	label_investigador_dialogo.text = "Te quedan %d slot%s de %d. Presupuesto de Mejoras: %s. Las estrellas son VELOCIDAD: el informe siempre sale completo." % [
		libres, "" if libres == 1 else "s", Investigadores.SLOTS,
		Economia.formato_dinero(disponible)]

	for estrellas in range(Investigadores.ESTRELLAS_MIN, Investigadores.ESTRELLAS_MAX + 1):
		var costo := Investigadores.costo(estrellas)
		var motivo := ""
		if libres <= 0:
			motivo = "sin slots"
		elif disponible < costo:
			motivo = "faltan %s" % Economia.formato_dinero(costo - disponible)
		var e := estrellas
		var fila := Componentes.fila(estrellas % 2 == 0)
		var dentro := Componentes.contenido(fila)

		var l_estrellas := Label.new()
		l_estrellas.text = "★".repeat(estrellas)
		l_estrellas.custom_minimum_size = Vector2(190, 0)
		l_estrellas.clip_text = true
		l_estrellas.add_theme_color_override("font_color", Tema.AMBAR)
		dentro.add_child(l_estrellas)

		dentro.add_child(Componentes.celda(
			"informe en %d dias" % int(Investigadores.dias_de_informe(estrellas)),
			190, Tema.TEXTO))
		dentro.add_child(Componentes.celda_numero(
			Economia.formato_dinero(costo), 130, Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT))

		var der := VBoxContainer.new()
		der.custom_minimum_size = Vector2(170, 0)
		der.add_theme_constant_override("separation", 2)
		dentro.add_child(der)
		var btn := Button.new()
		btn.text = "Contratar"
		btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
		btn.disabled = motivo != ""
		btn.pressed.connect(func():
			_on_contratar_investigador(e)
			_refrescar_dialogo_investigador()
		)
		der.add_child(btn)
		if motivo != "":
			var l := Label.new()
			l.text = motivo
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
			l.add_theme_color_override("font_color", Tema.ROJO)
			der.add_child(l)

		contenedor_investigador_dialogo.add_child(fila)


func _on_contratar_investigador(estrellas: int) -> void:
	var r := Investigadores.contratar(GameState.equipo_jugador, estrellas, GameState.rng)
	if r["exito"]:
		label_instalaciones_estado.text = "%s se suma al club: %d estrella%s por %s." % [
			str(r["investigador"]["nombre"]), estrellas,
			"" if estrellas == 1 else "s", Economia.formato_dinero(r["costo"])]
	else:
		label_instalaciones_estado.text = "No se pudo: %s" % r["motivo"]
	_refrescar_instalaciones()
	_refrescar_economia()


func _buscar_jugador_por_id(equipo: Team, jugador_id: int) -> Dictionary:
	for j in equipo.jugadores + equipo.banco + equipo.reservas + equipo.cantera:
		if int(j["id"]) == jugador_id:
			return j
	return {}


func _equipo_de_jugador_en_liga(liga: Liga, jugador_id: int) -> Team:
	for equipo in liga.equipos:
		if not _buscar_jugador_por_id(equipo, jugador_id).is_empty():
			return equipo
	return null


func _on_mejorar_instalacion(categoria: String) -> void:
	var resultado := GameState.mejorar_instalacion(categoria)
	if resultado["exito"]:
		label_instalaciones_estado.text = "%s ahora esta en nivel %d." % [NOMBRES_INSTALACIONES[categoria], resultado["nivel"]]
	else:
		label_instalaciones_estado.text = "No se pudo: %s" % resultado["motivo"]

	_refrescar_instalaciones()
	_refrescar_economia()


## Selección nacional — muestra la convocatoria actual (recalculada al
## toque, en vivo: no hace falta esperar al amistoso de fin de temporada
## para ver quién entraría hoy) con el club de origen de cada uno, y
## resalta a los que son de tu propio equipo.
## La seleccion: los mejores de TODA la piramide, no de tu division. Que
## te convoquen a alguien es la senal mas clara de que un jugador tuyo
## esta entre los mejores del pais, asi que los tuyos van resaltados.
func _construir_panel_seleccion(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["seleccion"] = panel

	var aviso := Label.new()
	aviso.text = "Convocatoria actual de Uruguay: los mejores de toda la piramide. Juega un amistoso al cerrar cada temporada."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(aviso)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_seleccion = VBoxContainer.new()
	contenedor_seleccion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_seleccion.add_theme_constant_override("separation", 0)
	scroll.add_child(contenedor_seleccion)


func _fila_convocado(j: Dictionary, clubes_por_jugador: Dictionary, par: bool) -> Control:
	var club: Team = clubes_por_jugador.get(j["id"])
	var mio: bool = club == GameState.equipo_jugador
	var fila := Componentes.fila(par)
	if mio:
		var e: StyleBoxFlat = fila.get_theme_stylebox("panel").duplicate()
		e.bg_color = Tema.PANEL_ALTO
		e.border_width_left = 4
		e.border_color = Tema.AMBAR
		fila.add_theme_stylebox_override("panel", e)
	var dentro := Componentes.contenido(fila)

	var caja_pos := CenterContainer.new()
	caja_pos.custom_minimum_size = Vector2(56, 0)
	caja_pos.add_child(Componentes.chip(str(j["posicion"]), Color("#2f4a3c")))
	dentro.add_child(caja_pos)

	var color: Color = Tema.AMBAR if mio else Tema.TEXTO
	dentro.add_child(Componentes.celda(_nombre_jugador(j), 230, color))
	dentro.add_child(Componentes.celda(
		club.nombre if club != null else "?", 230,
		Tema.AMBAR if mio else Tema.SUAVE))
	dentro.add_child(Componentes.celda_numero("%.1f" % float(j["media"]), 80, color,
		HORIZONTAL_ALIGNMENT_RIGHT))
	# La media va alineada a la derecha, asi que sin este hueco su ultimo
	# digito queda pegado a la columna siguiente y se leen como un numero.
	var hueco := Control.new()
	hueco.custom_minimum_size = Vector2(24, 0)
	dentro.add_child(hueco)
	var veces: int = GameState.seleccion.convocatorias.get(j["id"], 0)
	dentro.add_child(Componentes.celda(
		"%d convocatoria%s" % [veces, "s" if veces != 1 else ""], 190, Tema.SUAVE))
	return fila


func _refrescar_seleccion() -> void:
	if contenedor_seleccion == null:
		return
	for hijo in contenedor_seleccion.get_children():
		hijo.queue_free()

	var convocatoria := GameState.seleccion.previsualizar(GameState.piramide)
	var uruguay: Team = convocatoria["equipo"]
	var clubes: Dictionary = convocatoria["clubes_por_jugador"]

	var propios := 0
	for j in uruguay.jugadores + uruguay.banco:
		if clubes.get(j["id"]) == GameState.equipo_jugador:
			propios += 1
	var resumen := Tema.etiqueta_seccion(
		"Titulares (%d)  ·  tuyos convocados: %d" % [uruguay.jugadores.size(), propios])
	contenedor_seleccion.add_child(resumen)
	for i in range(uruguay.jugadores.size()):
		contenedor_seleccion.add_child(
			_fila_convocado(uruguay.jugadores[i], clubes, i % 2 == 0))

	contenedor_seleccion.add_child(Tema.etiqueta_seccion(
		"Banco (%d)" % uruguay.banco.size()))
	for i in range(uruguay.banco.size()):
		contenedor_seleccion.add_child(
			_fila_convocado(uruguay.banco[i], clubes, i % 2 == 0))


## §17: los juveniles sin debutar. Lo que se decide aca es a quien
## PROMOVER, y eso cuesta: el promovido entra al banco y el peor suplente
## queda libre. Por eso la pantalla muestra el potencial —lo unico que
## importa de un pibe— y lo muestra como un RANGO: el scout no sabe el
## numero exacto, y cuanto mejor el scout, mas angosto el rango.
func _construir_panel_cantera(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["cantera"] = panel

	label_cantera_mentor = Label.new()
	label_cantera_mentor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_cantera_mentor.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_cantera_mentor.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(label_cantera_mentor)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_cantera_botones = VBoxContainer.new()
	contenedor_cantera_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_cantera_botones)


## La ficha de un juvenil. El potencial va como barra con el rango que da
## el scout, y no como numero: un "potencial 74" que en realidad es
## 66-82 miente, y el margen es justamente lo que se compra mejorando el
## scouting.
func _tarjeta_juvenil(equipo: Team, juvenil: Dictionary, nivel_scout: int) -> Control:
	var margen := Scout.margen(nivel_scout)
	var pot_min: int = clamp(int(juvenil["potencial"]) - margen, 0, 99)
	var pot_max: int = clamp(int(juvenil["potencial"]) + margen, 0, 99)

	var tarjeta := Componentes.tarjeta(Componentes.color_de_valor(pot_max))
	var fila := HBoxContainer.new()
	tarjeta.add_child(fila)

	var caja_pos := CenterContainer.new()
	caja_pos.custom_minimum_size = Vector2(56, 0)
	caja_pos.add_child(Componentes.chip(str(juvenil["posicion"]), Color("#2f4a3c")))
	fila.add_child(caja_pos)

	var izq := VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_constant_override("separation", 2)
	fila.add_child(izq)
	var nombre := Label.new()
	nombre.text = _nombre_jugador(juvenil)
	nombre.clip_text = true
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	izq.add_child(nombre)
	var sub := Label.new()
	sub.text = "%d años   ·   media %.1f%s" % [
		int(juvenil["edad"]), float(juvenil["media"]), _tag_habilidad(juvenil)]
	sub.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	sub.add_theme_color_override("font_color", Tema.SUAVE)
	izq.add_child(sub)

	var caja_pot := VBoxContainer.new()
	caja_pot.custom_minimum_size = Vector2(240, 0)
	caja_pot.add_theme_constant_override("separation", 2)
	fila.add_child(caja_pot)
	caja_pot.add_child(Tema.etiqueta_seccion("Potencial (scout nivel %d)" % nivel_scout))
	var l_pot := Label.new()
	l_pot.text = "%d – %d" % [pot_min, pot_max]
	Tema.numero(l_pot, 22, Componentes.color_de_valor(pot_max))
	caja_pot.add_child(l_pot)
	var rango := Label.new()
	rango.text = "margen ±%d — un scout mejor lo achica" % margen
	rango.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	rango.add_theme_color_override("font_color", Tema.SUAVE)
	caja_pot.add_child(rango)

	var btn := Button.new()
	btn.text = "Promover"
	btn.custom_minimum_size = Vector2(140, Tema.ALTO_TACTIL)
	btn.tooltip_text = "Entra al banco si hay lugar, y si no a reservas. Con el plantel lleno, el peor suplente de ese puesto queda libre."
	var id: int = int(juvenil["id"])
	btn.pressed.connect(func(): _on_promover_juvenil(id))
	fila.add_child(btn)
	return tarjeta


func _refrescar_cantera() -> void:
	for hijo in contenedor_cantera_botones.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador

	var mentor: Dictionary = {}
	for j in equipo.todos_los_jugadores() + equipo.cantera:
		if Mentores.es_mentor(j):
			mentor = j
			break
	if mentor.is_empty():
		label_cantera_mentor.text = "Sin mentor: nadie de 28 o mas con Lider nato, Profesional o Metodico. Con uno, los de 21 o menos crecen mas rapido."
	else:
		var rasgo := "?"
		for candidato in Mentores.BONUS_POR_RASGO:
			if Personalidad.tiene(mentor, candidato):
				rasgo = candidato
				break
		label_cantera_mentor.text = "Mentor: %s (%s, %d años) — los de 21 o menos crecen mas rapido. Promover manda al banco: el peor suplente queda libre." % [
			_nombre_jugador(mentor), rasgo, int(mentor["edad"])]

	if equipo.cantera.is_empty():
		var vacio := Componentes.tarjeta()
		var l := Label.new()
		l.text = "No hay juveniles esta temporada. La camada nueva llega al cerrar la temporada; las Instalaciones deciden cuantos y de que nivel."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Tema.SUAVE)
		vacio.add_child(l)
		contenedor_cantera_botones.add_child(vacio)
		return

	var nivel_scout: int = equipo.scouts[0]["nivel"] if not equipo.scouts.is_empty() else 1
	for juvenil in equipo.cantera:
		contenedor_cantera_botones.add_child(
			_tarjeta_juvenil(equipo, juvenil, nivel_scout))


func _on_promover_juvenil(id: int) -> void:
	GameState.equipo_jugador.promover_juvenil(id)
	_refrescar_cantera()
	_refrescar_plantel()


## SPONSORS: los diez lugares de la camiseta.
##
## Te escriben solos cuando te va bien, ocupan un lugar, pagan por temporada
## de liga y te cortan el contrato si no cumplís lo que pidieron. La
## decisión está en que no llegan ofertas si no hay lugar libre: si
## llenaste los diez con kioscos del barrio, el sponsor grande no te
## escribe hasta que le hagas sitio.
##
## La lógica vive en core/sponsors.gd; acá solo se dibuja.
func _construir_panel_sponsors(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["sponsors"] = panel

	label_sponsors_estado = Label.new()
	label_sponsors_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label_sponsors_estado)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_sponsors = VBoxContainer.new()
	contenedor_sponsors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_sponsors.add_theme_constant_override("separation", 8)
	scroll.add_child(contenedor_sponsors)


func _mostrar_sponsors() -> void:
	_ocultar_todos()
	paneles["sponsors"].visible = true
	_refrescar_sponsors()


func _refrescar_sponsors() -> void:
	for hijo in contenedor_sponsors.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var libres: int = Sponsors.LUGARES - equipo.sponsors.size()

	var acumulado := 0.0
	for s in equipo.sponsors:
		acumulado += Sponsors.acumulado_de(s)
	var resumen := "%d de %d lugares ocupados   ·   %s por temporada   ·   %s ganados hasta hoy" % [
		equipo.sponsors.size(), Sponsors.LUGARES,
		Economia.formato_dinero(Sponsors.pago_por_temporada(equipo)),
		Economia.formato_dinero(acumulado)]
	label_sponsors_estado.text = resumen

	# --- Ofertas ----------------------------------------------------------
	contenedor_sponsors.add_child(Tema.etiqueta_seccion("Ofertas"))
	if equipo.sponsors_ofertas.is_empty():
		var texto := "No hay ofertas ahora. Llegan solas, y llegan más seguido cuanto mejor vayas en la tabla."
		if libres <= 0:
			texto = "No te queda ningún lugar libre, así que no te va a escribir nadie. Cancelá un contrato si querés que te lleguen ofertas mejores."
		contenedor_sponsors.add_child(_tarjeta_texto(texto))
	else:
		for o in equipo.sponsors_ofertas:
			contenedor_sponsors.add_child(_tarjeta_oferta_sponsor(o, libres > 0))

	# --- Contratos --------------------------------------------------------
	contenedor_sponsors.add_child(Tema.etiqueta_seccion(
		"Tus sponsors  ·  cobran por cada partido de liga"))
	if equipo.sponsors.is_empty():
		contenedor_sponsors.add_child(_tarjeta_texto(
			"Todavía no firmaste con nadie. Los diez lugares están libres."))
	for s in equipo.sponsors:
		contenedor_sponsors.add_child(_tarjeta_sponsor(s))
	if libres > 0 and not equipo.sponsors.is_empty():
		contenedor_sponsors.add_child(_tarjeta_texto(
			"%d lugar%s libre%s." % [libres, "" if libres == 1 else "es", "" if libres == 1 else "s"]))


func _tarjeta_texto(texto: String) -> Control:
	var tarjeta := Componentes.tarjeta()
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Tema.SUAVE)
	tarjeta.add_child(l)
	return tarjeta


func _tarjeta_oferta_sponsor(o: Dictionary, hay_lugar: bool) -> Control:
	var tarjeta := Componentes.tarjeta(Tema.AMBAR)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	tarjeta.add_child(caja)

	var datos := VBoxContainer.new()
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	datos.add_theme_constant_override("separation", 2)
	caja.add_child(datos)

	var nombre := Label.new()
	nombre.text = str(o["nombre"])
	Tema.numero(nombre, Tema.TAM_BASE, Tema.TEXTO)
	datos.add_child(nombre)
	datos.add_child(_texto_suave("%s por temporada   ·   %s   ·   caduca en %d día(s)" % [
		Economia.formato_dinero(o["pago"]),
		str(Sponsors.TEXTO_REQUISITO.get(str(o["requisito"]), "")),
		int(o["dias"])]))
	datos.add_child(_texto_suave(
		Sponsors.texto_minimos(str(o["requisito"]), GameState.division_jugador)))

	var nombre_sponsor := str(o["nombre"])
	var btn_ok := Button.new()
	btn_ok.text = "Aceptar"
	btn_ok.custom_minimum_size = Vector2(130, Tema.ALTO_TACTIL)
	btn_ok.disabled = not hay_lugar
	if not hay_lugar:
		btn_ok.tooltip_text = "No te quedan lugares libres."
	btn_ok.pressed.connect(func(): _on_aceptar_sponsor(nombre_sponsor))
	caja.add_child(btn_ok)

	var btn_no := Button.new()
	btn_no.text = "Rechazar"
	btn_no.custom_minimum_size = Vector2(130, Tema.ALTO_TACTIL)
	btn_no.pressed.connect(func():
		Sponsors.rechazar(GameState.equipo_jugador, nombre_sponsor)
		_refrescar_sponsors())
	caja.add_child(btn_no)
	return tarjeta


func _tarjeta_sponsor(s: Dictionary) -> Control:
	var tarjeta := Componentes.tarjeta(Tema.VERDE)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	tarjeta.add_child(caja)

	var datos := VBoxContainer.new()
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	datos.add_theme_constant_override("separation", 2)
	caja.add_child(datos)

	var nombre := Label.new()
	nombre.text = str(s["nombre"])
	Tema.numero(nombre, Tema.TAM_BASE, Tema.TEXTO)
	datos.add_child(nombre)
	datos.add_child(_texto_suave("%s por temporada   ·   %s   ·   lleva ganados %s en %d de %d fechas" % [
		Economia.formato_dinero(s["pago"]),
		str(Sponsors.TEXTO_REQUISITO.get(str(s["requisito"]), "")),
		Economia.formato_dinero(Sponsors.acumulado_de(s)),
		mini(int(s["partidos"]), Sponsors.partidos_de_liga()),
		Sponsors.partidos_de_liga()]))

	# Si el requisito no se está cumpliendo AHORA, se avisa: enterarte al
	# cerrar la temporada de que perdiste a tu mejor sponsor es tarde.
	var tabla := GameState.liga_jugador().tabla_ordenada()
	var puesto: int = tabla.find(GameState.equipo_jugador.nombre) + 1
	var llega_al_nombre := Sponsors.tiene_el_nombre(
		GameState.equipo_jugador, str(s["requisito"]), GameState.division_jugador)
	if not llega_al_nombre or (puesto > 0
			and not Sponsors.cumple(str(s["requisito"]), puesto, tabla.size())):
		var aviso := Label.new()
		aviso.text = "Si la temporada terminara hoy, cortan el contrato."
		if not llega_al_nombre:
			# El club se le quedo chico: no alcanza con salir bien en la
			# tabla, hay que decirle POR QUE lo pierde.
			aviso.text += " " + Sponsors.texto_minimos(
				str(s["requisito"]), GameState.division_jugador)
		aviso.add_theme_color_override("font_color", Tema.ROJO)
		aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		datos.add_child(aviso)

	var nombre_sponsor := str(s["nombre"])
	var btn := Button.new()
	btn.text = "Cancelar"
	btn.custom_minimum_size = Vector2(130, Tema.ALTO_TACTIL)
	btn.tooltip_text = "Libera el lugar para que te puedan escribir sponsors mejores."
	btn.pressed.connect(func():
		Sponsors.cancelar(GameState.equipo_jugador, nombre_sponsor)
		_refrescar_sponsors())
	caja.add_child(btn)
	return tarjeta


func _on_aceptar_sponsor(nombre: String) -> void:
	var r := Sponsors.aceptar(
		GameState.equipo_jugador, nombre, GameState.temporada_actual)
	if not r["exito"]:
		label_sponsors_estado.text = str(r["motivo"])
		return
	_refrescar_sponsors()


## EL RESUMEN DE LA TEMPORADA: la pantalla que cierra el año.
##
## Antes esto era un AcceptDialog con una linea de texto y, si el cierre
## caia avanzando dias, con las 225 novedades de los 200 clubes adentro:
## crecia mas alto que la pantalla, el boton de cerrar quedaba afuera y el
## juego se trababa sin forma de pasar a la temporada siguiente.
##
## Ahora es una pantalla propia con la tabla final, los mejores de la liga
## y todos los campeones del año, y un solo boton para arrancar la que
## viene. Es un CanvasLayer y no un panel mas porque tiene que taparlo
## todo: la temporada termino y no hay nada mas que hacer hasta empezar la
## siguiente.
func _construir_pantalla_resumen() -> void:
	capa_resumen = CanvasLayer.new()
	capa_resumen.layer = 11
	capa_resumen.visible = false
	add_child(capa_resumen)

	var fondo := PanelContainer.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.FONDO
	fondo.add_theme_stylebox_override("panel", estilo)
	capa_resumen.add_child(fondo)

	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_%s" % lado, 16)
	fondo.add_child(margen)

	contenedor_resumen_temporada = VBoxContainer.new()
	contenedor_resumen_temporada.add_theme_constant_override("separation", 8)
	margen.add_child(contenedor_resumen_temporada)


func _mostrar_resumen_temporada() -> void:
	if GameState.resumen_temporada.is_empty():
		return
	_refrescar_resumen_temporada()
	capa_resumen.visible = true


func _refrescar_resumen_temporada() -> void:
	for hijo in contenedor_resumen_temporada.get_children():
		hijo.queue_free()
	var r: Dictionary = GameState.resumen_temporada

	var titulo := Label.new()
	titulo.text = "Terminó la temporada %d  ·  %d" % [
		int(r.get("temporada", 0)), int(r.get("anio", 0))]
	Tema.numero(titulo, 28, Tema.AMBAR)
	contenedor_resumen_temporada.add_child(titulo)

	var puesto := int(r.get("posicion", 0))
	var sub := Label.new()
	sub.text = "%s terminó %d° de %d en la División %d." % [
		GameState.equipo_jugador.nombre, puesto,
		int(r.get("total", 0)), int(r.get("division", 0))]
	sub.add_theme_color_override("font_color", Tema.VERDE if puesto <= 3 else Tema.SUAVE)
	contenedor_resumen_temporada.add_child(sub)

	var columnas := HBoxContainer.new()
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columnas.add_theme_constant_override("separation", 12)
	contenedor_resumen_temporada.add_child(columnas)

	# --- Izquierda: la tabla final ----------------------------------------
	var izq := VBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.add_theme_constant_override("separation", 2)
	columnas.add_child(izq)
	izq.add_child(Tema.etiqueta_seccion("Tabla final"))
	# Sin encabezado, "38 30 2 6 +141 92" no se entiende.
	izq.add_child(_encabezado_resumen_tabla())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	izq.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 0)
	scroll.add_child(lista)
	var mio: String = GameState.equipo_jugador.nombre
	var tabla: Array = r.get("tabla", [])
	for i in range(tabla.size()):
		lista.add_child(_fila_resumen_tabla(tabla[i], i + 1, mio))

	# --- Derecha: los mejores y los campeones -----------------------------
	var der := VBoxContainer.new()
	der.custom_minimum_size = Vector2(480, 0)
	der.add_theme_constant_override("separation", 8)
	columnas.add_child(der)

	der.add_child(Tema.etiqueta_seccion("Los mejores de la División %d" % int(r.get("division", 0))))
	var tarjeta := Componentes.tarjeta()
	der.add_child(tarjeta)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	tarjeta.add_child(caja)
	for par in [["goleadores", "goles", "Goleador"],
			["asistencias", "asistencias", "Asistencias"],
			["vallas", "vallas", "Vallas invictas"]]:
		caja.add_child(_linea_del_mejor(r, str(par[0]), str(par[1]), str(par[2]), mio))

	der.add_child(Tema.etiqueta_seccion("Campeones"))
	var t2 := Componentes.tarjeta()
	der.add_child(t2)
	var caja2 := VBoxContainer.new()
	caja2.add_theme_constant_override("separation", 4)
	t2.add_child(caja2)
	var campeones: Array = r.get("campeones", [])
	if campeones.is_empty():
		caja2.add_child(_texto_suave("No se coronó nadie."))
	for c in campeones:
		var fila := HBoxContainer.new()
		caja2.add_child(fila)
		fila.add_child(Componentes.celda(str(c["que"]), 200, Tema.SUAVE,
			HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO))
		var quien := str(c["quien"])
		fila.add_child(Componentes.celda(quien, 260,
			Tema.VERDE if quien == mio else Tema.TEXTO,
			HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO))

	var relleno := Control.new()
	relleno.size_flags_vertical = Control.SIZE_EXPAND_FILL
	der.add_child(relleno)

	var btn := Button.new()
	btn.text = "Comenzar la temporada %d" % (int(r.get("temporada", 0)) + 1)
	btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	Tema.primario(btn)
	btn.pressed.connect(func():
		capa_resumen.visible = false
		_mostrar_seccion("jugar")
		# Despues del resumen y no antes: el cartel pide una decision
		# ("entendido") y arriba de la pantalla de cierre no se ve.
		_mostrar_vencimientos_si_hay())
	der.add_child(btn)


func _encabezado_resumen_tabla() -> Control:
	var fila := Componentes.fila(false)
	var dentro := Componentes.contenido(fila)
	dentro.add_child(Componentes.acento_lateral(Color.TRANSPARENT))
	var cols := [["#", 40, HORIZONTAL_ALIGNMENT_RIGHT],
		["Equipo", 220, HORIZONTAL_ALIGNMENT_LEFT],
		["PJ", 40, HORIZONTAL_ALIGNMENT_RIGHT], ["PG", 40, HORIZONTAL_ALIGNMENT_RIGHT],
		["PE", 40, HORIZONTAL_ALIGNMENT_RIGHT], ["PP", 40, HORIZONTAL_ALIGNMENT_RIGHT],
		["DG", 48, HORIZONTAL_ALIGNMENT_RIGHT], ["Pts", 48, HORIZONTAL_ALIGNMENT_RIGHT]]
	for c in cols:
		var l := Componentes.celda(str(c[0]), int(c[1]), Tema.SUAVE, int(c[2]))
		l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		dentro.add_child(l)
	return fila


func _fila_resumen_tabla(f: Dictionary, puesto: int, mio: String) -> Control:
	var nombre := str(f.get("equipo", ""))
	var soy_yo: bool = nombre == mio
	var fila := Componentes.fila(puesto % 2 == 0)
	var dentro := Componentes.contenido(fila)
	dentro.add_child(Componentes.acento_lateral(
		Tema.AMBAR if soy_yo else Color.TRANSPARENT))
	var color: Color = Tema.AMBAR if soy_yo else Tema.TEXTO
	dentro.add_child(Componentes.celda_numero(str(puesto), 40, Tema.SUAVE,
		HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
	dentro.add_child(Componentes.celda(nombre, 220, color,
		HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO))
	for clave in ["pj", "pg", "pe", "pp"]:
		dentro.add_child(Componentes.celda_numero(str(int(f.get(clave, 0))), 40,
			Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
	var dg := int(f.get("dg", 0))
	dentro.add_child(Componentes.celda_numero(("+%d" % dg) if dg > 0 else str(dg), 48,
		Tema.VERDE if dg > 0 else (Tema.ROJO if dg < 0 else Tema.SUAVE),
		HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
	dentro.add_child(Componentes.celda_numero(str(int(f.get("pts", 0))), 48, color,
		HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
	return fila


func _linea_del_mejor(r: Dictionary, clave: String, campo: String,
		titulo: String, mio: String) -> Control:
	var fila := HBoxContainer.new()
	fila.add_child(Componentes.celda(titulo, 150, Tema.SUAVE,
		HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO))
	var lista: Array = r.get(clave, [])
	if lista.is_empty():
		fila.add_child(_texto_suave("—"))
		return fila
	var mejor: Dictionary = lista[0]
	var es_mio: bool = str(mejor.get("equipo", "")) == mio
	fila.add_child(Componentes.celda(str(mejor.get("nombre", "")), 190,
		Tema.VERDE if es_mio else Tema.TEXTO, HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO))
	fila.add_child(Componentes.celda_numero(str(int(mejor.get(campo, 0))), 36,
		Tema.AMBAR, HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
	fila.add_child(Componentes.celda(str(mejor.get("equipo", "")), 0, Tema.SUAVE,
		HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO))
	return fila


## EL LABORATORIO: disparar una animación sin esperar a que salga sola.
##
## Una expulsión aparece en 1 de cada 2 partidos y un penal en 1 de cada
## 5, así que para mirar cómo quedó una animación había que jugar hasta
## que la suerte la trajera. Acá se elige la situación y se ve en el acto,
## con el motor de verdad: se monta la jugada y se tickea igual que en un
## partido, así que lo que se ve es exactamente lo que va a pasar.
##
## La lógica de montar cada situación vive en core/laboratorio.gd.
var laboratorio_estado: Label
## Si el clip que se esta viendo salio del laboratorio: al terminar se
## vuelve ahi y no al club.
var viendo_laboratorio := false


func _construir_panel_laboratorio(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["laboratorio"] = panel

	laboratorio_estado = Label.new()
	laboratorio_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	laboratorio_estado.text = "Elegí una jugada y se reproduce con el motor de verdad, sin esperar a que salga en un partido."
	laboratorio_estado.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(laboratorio_estado)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 8)
	scroll.add_child(lista)

	for s in Laboratorio.SITUACIONES:
		lista.add_child(_fila_de_laboratorio(s))


func _fila_de_laboratorio(s: Dictionary) -> Control:
	var tarjeta := Componentes.tarjeta()
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	tarjeta.add_child(caja)

	var datos := VBoxContainer.new()
	datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	datos.add_theme_constant_override("separation", 2)
	caja.add_child(datos)
	var titulo := Label.new()
	titulo.text = str(s["nombre"])
	Tema.numero(titulo, Tema.TAM_BASE)
	datos.add_child(titulo)
	datos.add_child(_texto_suave(str(s["que"])))

	var clave := str(s["clave"])
	var btn := Button.new()
	btn.text = "Reproducir"
	btn.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	Tema.primario(btn)
	btn.pressed.connect(func(): _reproducir_laboratorio(clave))
	caja.add_child(btn)
	return tarjeta


func _mostrar_laboratorio() -> void:
	_ocultar_todos()
	paneles["laboratorio"].visible = true


func _reproducir_laboratorio(clave: String) -> void:
	# Tu club contra el próximo rival, o contra el primero de la liga que
	# no seas vos: así se ve con tus colores y tus jugadores.
	var local: Team = GameState.equipo_jugador
	var visitante: Team = _proximo_rival()
	if visitante == null:
		for e in GameState.liga_jugador().equipos:
			if e != local:
				visitante = e
				break
	if visitante == null:
		laboratorio_estado.text = "No encontré un rival contra quien montarla."
		return

	# Se juega con COPIAS de los dos equipos. El motor lesiona y suspende
	# de verdad —_chequear_lesion escribe en lesiones y una roja suma una
	# fecha a suspendidos, y reset_partido() no limpia ninguna de las dos—
	# asi que sin copiar, mirar una animacion te podia romper un titular.
	var copia_local := Team.cargar(local.guardar())
	var copia_visitante := Team.cargar(visitante.guardar())

	# Rng aparte y con SEMILLA FIJA: montar una jugada no tiene por que
	# mover el resto de la partida, y ademas la misma jugada tiene que dar
	# siempre lo mismo. Si el resultado cambia entre una reproduccion y la
	# siguiente no se puede comparar nada ni saber si un cambio la mejoro.
	var rng := RandomNumberGenerator.new()
	rng.seed = Laboratorio.SEMILLA
	var r := Laboratorio.generar(clave, copia_local, copia_visitante, rng)
	if r["fotogramas"].is_empty():
		laboratorio_estado.text = "Esa jugada no genero nada."
		return
	if clave == "tiro_efecto":
		for ev in r["eventos"]:
			if str(ev.get("tipo", "")) == "tiro_puerta":
				laboratorio_estado.text = "Tiro con efecto listo: curva %.1f m · calidad %.0f%%." % [
					float(ev.get("curva_m", 0.0)), float(ev.get("calidad_tiro", 0.0)) * 100.0]
				break
	elif clave.begins_with("regate_"):
		laboratorio_estado.text = "%s: gesto completo y salida con la pelota." % [
			Laboratorio.nombre_de(clave)]
	elif clave == "lesion":
		laboratorio_estado.text = "Lesion: caída, salida por el lateral y entrada del reemplazo listas."

	# Al terminar (o al tocar Menu) se vuelve ACA, no al club: se esta
	# probando animaciones y lo normal es querer ver la siguiente.
	viendo_laboratorio = true
	_ocultar_todos()
	paneles["partido_animado"].visible = true
	if resumen_partido != null:
		resumen_partido.visible = false
	var colores := ColoresClub.par_equipos(copia_local, copia_visitante)
	vista_partido.iniciar(
		r["fotogramas"], colores[0], colores[1],
		copia_local.nombre, copia_visitante.nombre,
		VistaPartido.construir_nombres(copia_local, copia_visitante),
		VistaCancha.nivel_estadio_desde_calidad(copia_local.calidad_cancha),
		copia_local.color_short, copia_visitante.color_short,
		_nombre_marcador(copia_local), _nombre_marcador(copia_visitante),
		copia_local.identidad_visual(), copia_visitante.identidad_visual())
	vista_partido.velocidad = velocidad_partido_elegida


## LA VITRINA: todo lo que ganó el club, arriba el resumen y abajo el
## detalle temporada por temporada.
##
## El feed de noticias cuenta cada título el día que pasa y después lo
## entierra bajo doscientas noticias más; la tabla y el cuadro solo saben
## de la temporada en curso. Sin esto no había ningún lado donde ver que
## ganaste algo hace cuatro años.
const ORDEN_VITRINA := ["Copa de Campeones", "Copa de Guerreros",
	"Copa de Emergentes", "Copa del Rey", "Liga", "Copa de división"]


func _construir_panel_vitrina(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["vitrina"] = panel

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_vitrina = VBoxContainer.new()
	contenedor_vitrina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_vitrina.add_theme_constant_override("separation", 10)
	scroll.add_child(contenedor_vitrina)


func _mostrar_vitrina() -> void:
	_ocultar_todos()
	paneles["vitrina"].visible = true
	_refrescar_vitrina()


func _refrescar_vitrina() -> void:
	for hijo in contenedor_vitrina.get_children():
		hijo.queue_free()

	var lista: Array = GameState.vitrina
	if lista.is_empty():
		var vacio := Componentes.tarjeta()
		var l := Label.new()
		l.text = "La vitrina está vacía. Se llena sola: acá van las ligas, las copas de división, la Copa del Rey y las internacionales que gane %s." % GameState.equipo_jugador.nombre
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Tema.SUAVE)
		vacio.add_child(l)
		contenedor_vitrina.add_child(vacio)
		return

	# El resumen: cuántos de cada uno. Es lo que se mira primero — "tres
	# ligas y una copa" se lee de un vistazo, una lista de doce líneas no.
	var cuentas := {}
	for t in lista:
		var titulo := str(t["titulo"])
		cuentas[titulo] = int(cuentas.get(titulo, 0)) + 1

	contenedor_vitrina.add_child(Tema.etiqueta_seccion(
		"%d título%s en total" % [lista.size(), "" if lista.size() == 1 else "s"]))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	contenedor_vitrina.add_child(fila)
	# En el orden de importancia y no en el que se ganaron: la vitrina de
	# un club se lee de arriba para abajo, no por fecha.
	for titulo in ORDEN_VITRINA:
		if cuentas.has(titulo):
			fila.add_child(_caja_numero(titulo, str(int(cuentas[titulo])), Tema.AMBAR))
	for titulo in cuentas:
		if not ORDEN_VITRINA.has(titulo):
			fila.add_child(_caja_numero(titulo, str(int(cuentas[titulo])), Tema.AMBAR))

	contenedor_vitrina.add_child(Tema.etiqueta_seccion("Uno por uno"))
	# Del más reciente al más viejo, que es como se pregunta "¿qué ganamos
	# el año pasado?".
	for i in range(lista.size() - 1, -1, -1):
		contenedor_vitrina.add_child(_fila_de_vitrina(lista[i]))


func _fila_de_vitrina(t: Dictionary) -> Control:
	var tarjeta := Componentes.tarjeta(Tema.AMBAR)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	tarjeta.add_child(caja)

	var anio := Label.new()
	anio.text = str(int(t.get("anio", 0)))
	anio.custom_minimum_size = Vector2(76, 0)
	Tema.numero(anio, Tema.TAM_BASE, Tema.SUAVE)
	caja.add_child(anio)

	var titulo := Label.new()
	titulo.text = str(t["titulo"])
	titulo.custom_minimum_size = Vector2(260, 0)
	Tema.numero(titulo, Tema.TAM_BASE, Tema.AMBAR)
	caja.add_child(titulo)

	var detalle := Label.new()
	detalle.text = "%s  ·  temporada %d" % [str(t.get("detalle", "")), int(t.get("temporada", 0))]
	detalle.add_theme_color_override("font_color", Tema.SUAVE)
	detalle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.add_child(detalle)
	return tarjeta


## HISTORIA DE LOS CLUBES: en que division estuvo cada uno, año a año, y
## que gano. Sale de Team.historial_temporadas y GameState.historial_copas
## (ver core/historial.gd). Se puede mirar cualquier club de la piramide,
## no solo el propio: el rival de la fecha tambien tiene historia.
const COL_ANIO := 64
const COL_DIVISION := 70
const COL_PUESTO := 96
const COL_MOVIMIENTO := 120


func _construir_panel_historia_clubes(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.add_theme_constant_override("separation", 8)
	padre.add_child(panel)
	paneles["historia_clubes"] = panel

	# Division primero y club despues: los 200 clubes en un solo
	# desplegable eran una lista que no se terminaba nunca.
	var filtros := HBoxContainer.new()
	filtros.add_theme_constant_override("separation", 12)
	panel.add_child(filtros)
	option_historia_division = OptionButton.new()
	option_historia_division.custom_minimum_size = Vector2(160, Tema.ALTO_TACTIL)
	option_historia_division.item_selected.connect(func(i):
		# Al cambiar de division se muestra el primero de la tabla.
		var equipos: Array = GameState.piramide.divisiones[i].equipos
		if not equipos.is_empty():
			historia_club_elegido = equipos[0].nombre
		_refrescar_historia_club())
	filtros.add_child(_grupo_filtro("División", option_historia_division))
	option_historia_club = OptionButton.new()
	option_historia_club.custom_minimum_size = Vector2(360, Tema.ALTO_TACTIL)
	option_historia_club.item_selected.connect(func(i):
		historia_club_elegido = str(option_historia_club.get_item_metadata(i))
		_refrescar_historia_club())
	filtros.add_child(_grupo_filtro("Club", option_historia_club))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_historia_club = VBoxContainer.new()
	contenedor_historia_club.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_historia_club.add_theme_constant_override("separation", 0)
	scroll.add_child(contenedor_historia_club)


func _mostrar_historia_clubes() -> void:
	_ocultar_todos()
	paneles["historia_clubes"].visible = true
	if _club_de_la_piramide(historia_club_elegido) == null:
		historia_club_elegido = GameState.equipo_jugador.nombre
	_refrescar_historia_club()


## Desde un nombre de club tocado en otra pantalla (la carrera de un
## jugador, el palmares). Va por la seccion para que la subsolapa quede
## marcada.
func _abrir_historia_de_club(nombre: String) -> void:
	historia_club_elegido = nombre
	_mostrar_seccion("partido", "historia_clubes")


func _club_de_la_piramide(nombre: String) -> Team:
	for liga in GameState.piramide.divisiones:
		for e in liga.equipos:
			if e.nombre == nombre:
				return e
	return null


func _refrescar_historia_club() -> void:
	# Los desplegables se rearman cada vez: entre temporada y temporada
	# los clubes cambian de division.
	var division := 0
	var elegido := _club_de_la_piramide(historia_club_elegido)
	if elegido != null:
		division = maxi(elegido.division_actual, 0)
	option_historia_division.clear()
	for d in range(GameState.piramide.divisiones.size()):
		option_historia_division.add_item("División %d" % (d + 1))
	option_historia_division.select(division)
	option_historia_club.clear()
	var nombres := []
	for e in GameState.piramide.divisiones[division].equipos:
		nombres.append(e.nombre)
	nombres.sort()
	for nombre in nombres:
		option_historia_club.add_item(nombre)
		var i := option_historia_club.item_count - 1
		option_historia_club.set_item_metadata(i, nombre)
		if nombre == historia_club_elegido:
			option_historia_club.select(i)

	for hijo in contenedor_historia_club.get_children():
		hijo.queue_free()
	var club := _club_de_la_piramide(historia_club_elegido)
	if club == null:
		return
	var temporadas: Array = club.historial_temporadas
	var titulos := Historial.titulos_de_club(GameState.historial_copas, club.nombre)

	var ascensos := 0
	var descensos := 0
	for i in range(temporadas.size()):
		var mov := _movimiento_de_temporada(club, i)
		if mov < 0:
			ascensos += 1
		elif mov > 0:
			descensos += 1
	var cajas := HBoxContainer.new()
	cajas.add_theme_constant_override("separation", 10)
	contenedor_historia_club.add_child(cajas)
	cajas.add_child(_caja_numero("Temporadas", str(temporadas.size()), Tema.TEXTO))
	cajas.add_child(_caja_numero("Títulos", str(titulos.size()), Tema.AMBAR))
	cajas.add_child(_caja_numero("Ascensos", str(ascensos), Tema.VERDE))
	cajas.add_child(_caja_numero("Descensos", str(descensos), Tema.ROJO))

	if temporadas.is_empty():
		contenedor_historia_club.add_child(_texto_suave(
			"Todavía no terminó ninguna temporada con el historial activo. Se llena solo al cerrar cada una."))
		return

	if not titulos.is_empty():
		contenedor_historia_club.add_child(Tema.etiqueta_seccion("Títulos"))
		for i in range(titulos.size()):
			var t: Dictionary = titulos[i]
			var fila := Componentes.fila(i % 2 == 0)
			var dentro := Componentes.contenido(fila)
			dentro.add_child(Componentes.celda_numero(
				str(Historial.anio_de(int(t["temporada"]))), COL_ANIO, Tema.SUAVE))
			dentro.add_child(Componentes.celda(str(t["competencia"]), Componentes.COL_EQUIPO + 120, Tema.AMBAR))
			contenedor_historia_club.add_child(fila)

	contenedor_historia_club.add_child(Tema.etiqueta_seccion("Temporada por temporada"))
	contenedor_historia_club.add_child(_encabezado_de_columnas([
		["Año", COL_ANIO], ["División", COL_DIVISION], ["Puesto", COL_PUESTO],
		["Pts", Componentes.COL_PUNTOS], ["", COL_MOVIMIENTO]]))
	# Del mas nuevo al mas viejo: la pregunta es "¿como nos fue el año
	# pasado?", no "¿como arrancamos?".
	for i in range(temporadas.size() - 1, -1, -1):
		var t: Dictionary = temporadas[i]
		var fila := Componentes.fila(i % 2 == 0)
		var dentro := Componentes.contenido(fila)
		var campeon := int(t["posicion"]) == 1
		dentro.add_child(Componentes.celda_numero(
			str(Historial.anio_de(int(t["temporada"]))), COL_ANIO, Tema.SUAVE))
		dentro.add_child(Componentes.celda("Div %d" % int(t["division"]), COL_DIVISION))
		dentro.add_child(Componentes.celda_numero(
			"%d° de %d" % [int(t["posicion"]), int(t["total"])], COL_PUESTO,
			Tema.AMBAR if campeon else Tema.TEXTO))
		dentro.add_child(Componentes.celda_numero(
			str(int(t.get("pts", 0))), Componentes.COL_PUNTOS, Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
		var mov := _movimiento_de_temporada(club, i)
		var texto_mov := "Campeón" if campeon else ""
		var color_mov := Tema.AMBAR
		if mov < 0:
			texto_mov = "Campeón · ascenso" if campeon else "Ascenso"
			color_mov = Tema.VERDE
		elif mov > 0:
			texto_mov = "Descenso"
			color_mov = Tema.ROJO
		dentro.add_child(Componentes.celda(texto_mov, COL_MOVIMIENTO, color_mov))
		contenedor_historia_club.add_child(fila)


## Cuantas divisiones se movio el club DESPUES de la temporada `i`:
## negativo sube, positivo baja. La ultima se compara con la division
## actual, porque la siguiente temporada todavia no cerro.
func _movimiento_de_temporada(club: Team, i: int) -> int:
	var temporadas: Array = club.historial_temporadas
	var desde := int(temporadas[i]["division"])
	var hasta := club.division_actual + 1
	if i + 1 < temporadas.size():
		hasta = int(temporadas[i + 1]["division"])
	return hasta - desde


func _encabezado_de_columnas(cols: Array) -> PanelContainer:
	var fila := Componentes.fila(false)
	var dentro := Componentes.contenido(fila)
	for c in cols:
		var l := Componentes.celda(str(c[0]), int(c[1]), Tema.SUAVE,
			int(c[2]) if c.size() > 2 else HORIZONTAL_ALIGNMENT_LEFT)
		l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		dentro.add_child(l)
	return fila


## Un nombre de club que lleva a su historia. Si el club no esta en la
## piramide (uno del exterior) queda como texto: no tiene historia que
## mostrar.
func _celda_de_club(nombre: String, ancho: int, color: Color) -> Control:
	if _club_de_la_piramide(nombre) == null:
		return Componentes.celda(nombre, ancho, color)
	var b := Componentes.boton_de_celda(nombre, ancho, HORIZONTAL_ALIGNMENT_LEFT, color)
	b.pressed.connect(func(): _abrir_historia_de_club(nombre))
	return b


## PALMARES: quien gano cada competencia y quien la gano mas veces.
## Todas las competencias y todos los clubes, no solo el propio (eso es
## la vitrina).
func _competencias_del_palmares() -> Array:
	var lista := ["Copa de Campeones", "Copa de Guerreros", "Copa de Emergentes", "Copa del Rey"]
	for d in range(GameState.piramide.divisiones.size()):
		lista.append("Liga · División %d" % (d + 1))
	for d in range(GameState.piramide.divisiones.size()):
		lista.append("Copa de la División %d" % (d + 1))
	return lista


func _construir_panel_palmares(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.add_theme_constant_override("separation", 8)
	padre.add_child(panel)
	paneles["palmares"] = panel

	option_palmares = OptionButton.new()
	option_palmares.custom_minimum_size = Vector2(360, Tema.ALTO_TACTIL)
	option_palmares.item_selected.connect(func(i):
		palmares_elegido = option_palmares.get_item_text(i)
		_refrescar_palmares())
	panel.add_child(_grupo_filtro("Competencia", option_palmares))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_palmares = VBoxContainer.new()
	contenedor_palmares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_palmares.add_theme_constant_override("separation", 0)
	scroll.add_child(contenedor_palmares)


func _mostrar_palmares() -> void:
	_ocultar_todos()
	paneles["palmares"].visible = true
	# Arranca en la liga propia: es la que el jugador conoce.
	if palmares_elegido == "":
		palmares_elegido = "Liga · División %d" % (GameState.division_jugador + 1)
	_refrescar_palmares()


func _refrescar_palmares() -> void:
	option_palmares.clear()
	for nombre in _competencias_del_palmares():
		option_palmares.add_item(nombre)
		if nombre == palmares_elegido:
			option_palmares.select(option_palmares.item_count - 1)

	for hijo in contenedor_palmares.get_children():
		hijo.queue_free()
	var lista: Array = GameState.historial_copas.get(palmares_elegido, [])
	if lista.is_empty():
		contenedor_palmares.add_child(_texto_suave(
			"Todavía no hay campeones anotados. Se anota cada uno al cerrar la temporada."))
		return
	var mio: String = GameState.equipo_jugador.nombre

	contenedor_palmares.add_child(Tema.etiqueta_seccion("Más ganadores"))
	contenedor_palmares.add_child(_encabezado_de_columnas([
		["#", Componentes.COL_POSICION, HORIZONTAL_ALIGNMENT_RIGHT],
		["Club", Componentes.COL_EQUIPO],
		["Títulos", Componentes.COL_PUNTOS, HORIZONTAL_ALIGNMENT_RIGHT],
		["Subcamp.", Componentes.COL_PUNTOS + 20, HORIZONTAL_ALIGNMENT_RIGHT]]))
	var ranking := Historial.ranking_de_titulos(lista)
	for i in range(ranking.size()):
		var r: Dictionary = ranking[i]
		var color: Color = Tema.AMBAR if str(r["club"]) == mio else Tema.TEXTO
		var fila := Componentes.fila(i % 2 == 0)
		var dentro := Componentes.contenido(fila)
		dentro.add_child(Componentes.celda_numero(
			str(i + 1), Componentes.COL_POSICION, Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(_celda_de_club(str(r["club"]), Componentes.COL_EQUIPO, color))
		dentro.add_child(Componentes.celda_numero(
			str(int(r["titulos"])), Componentes.COL_PUNTOS, color, HORIZONTAL_ALIGNMENT_RIGHT))
		dentro.add_child(Componentes.celda_numero(
			str(int(r["subcampeonatos"])), Componentes.COL_PUNTOS + 20, Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT))
		contenedor_palmares.add_child(fila)

	contenedor_palmares.add_child(Tema.etiqueta_seccion("Año por año"))
	contenedor_palmares.add_child(_encabezado_de_columnas([
		["Año", COL_ANIO], ["Campeón", Componentes.COL_EQUIPO],
		["Subcampeón", Componentes.COL_EQUIPO]]))
	for i in range(lista.size() - 1, -1, -1):
		var t: Dictionary = lista[i]
		var fila := Componentes.fila(i % 2 == 0)
		var dentro := Componentes.contenido(fila)
		dentro.add_child(Componentes.celda_numero(
			str(Historial.anio_de(int(t["temporada"]))), COL_ANIO, Tema.SUAVE))
		var campeon := str(t["campeon"])
		dentro.add_child(_celda_de_club(campeon, Componentes.COL_EQUIPO,
			Tema.AMBAR if campeon == mio else Tema.TEXTO))
		dentro.add_child(_celda_de_club(str(t.get("subcampeon", "")), Componentes.COL_EQUIPO, Tema.SUAVE))
		contenedor_palmares.add_child(fila)


## LA CARRERA de un jugador, dentro de la ficha: por que clubes paso y que
## hizo en cada uno. Es publica —los goles los vio todo el mundo—, asi que
## no espera al informe del investigador.
func _carrera_en_ficha(equipo: Team, j: Dictionary) -> void:
	var tarjeta := Componentes.tarjeta()
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	tarjeta.add_child(caja)
	var nombre := Label.new()
	nombre.text = "%s   %s" % [_nombre_jugador(j), equipo.nombre]
	Tema.numero(nombre, 26)
	caja.add_child(nombre)
	var tot := Historial.totales(j)
	var datos := Label.new()
	datos.text = "%s  ·  %d años  ·  %d partidos, %d goles, %d asistencias en %d club%s" % [
		str(j["posicion"]), int(j["edad"]), int(tot["pj"]), int(tot["goles"]),
		int(tot["asistencias"]), int(tot["clubes"]), "" if int(tot["clubes"]) == 1 else "es"]
	datos.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(datos)
	contenedor_ficha.add_child(tarjeta)

	Historial.completar_grl_actual(j)
	var carrera: Array = j.get("carrera", [])
	if carrera.is_empty():
		contenedor_ficha.add_child(_texto_suave(
			"Todavía no jugó ningún partido desde que se lleva el historial."))
		return

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor_ficha.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 0)
	scroll.add_child(lista)
	lista.add_child(_encabezado_de_columnas([
		["Año", COL_ANIO], ["Club", Componentes.COL_EQUIPO], ["División", COL_DIVISION],
		["GRL", Componentes.COL_MEDIA, HORIZONTAL_ALIGNMENT_RIGHT],
		["Cambio", 72, HORIZONTAL_ALIGNMENT_RIGHT],
		["PJ", Componentes.COL_JUGADOS, HORIZONTAL_ALIGNMENT_RIGHT],
		["Goles", Componentes.COL_GOLES, HORIZONTAL_ALIGNMENT_RIGHT],
		["Asist.", Componentes.COL_GOLES, HORIZONTAL_ALIGNMENT_RIGHT]]))
	for i in range(carrera.size() - 1, -1, -1):
		var f: Dictionary = carrera[i]
		var en_curso := int(f["temporada"]) == Historial.temporada
		var fila := Componentes.fila(i % 2 == 0)
		var dentro := Componentes.contenido(fila)
		dentro.add_child(Componentes.celda_numero(
			str(Historial.anio_de(int(f["temporada"]))), COL_ANIO,
			Tema.AMBAR if en_curso else Tema.SUAVE))
		dentro.add_child(_celda_de_club(str(f["club"]), Componentes.COL_EQUIPO, Tema.TEXTO))
		var div := int(f.get("division", 0))
		dentro.add_child(Componentes.celda(
			"Div %d" % div if div > 0 else "Exterior", COL_DIVISION, Tema.SUAVE))
		var grl_texto := "—"
		var color_grl := Tema.SUAVE
		if f.has("grl"):
			grl_texto = "%.1f" % float(f["grl"])
			color_grl = Componentes.color_de_valor(int(f["grl"]))
		dentro.add_child(Componentes.celda_numero(
			grl_texto, Componentes.COL_MEDIA, color_grl, HORIZONTAL_ALIGNMENT_RIGHT))
		var cambio = Historial.cambio_grl(carrera, i)
		var cambio_texto := "—"
		var color_cambio := Tema.SUAVE
		if cambio != null:
			var valor := float(cambio)
			cambio_texto = "%+.1f" % valor
			color_cambio = Tema.VERDE if valor > 0.0 else (Tema.ROJO if valor < 0.0 else Tema.SUAVE)
		dentro.add_child(Componentes.celda_numero(
			cambio_texto, 72, color_cambio, HORIZONTAL_ALIGNMENT_RIGHT))
		for clave in ["pj", "goles", "asistencias"]:
			var ancho := Componentes.COL_JUGADOS if clave == "pj" else Componentes.COL_GOLES
			dentro.add_child(Componentes.celda_numero(
				str(int(f[clave])), ancho, Tema.TEXTO, HORIZONTAL_ALIGNMENT_RIGHT))
		lista.add_child(fila)


## La pantalla de COPAS: el cuadro de cada una, como en un cuadro de
## verdad — cada cruce alineado entre los dos de los que sale.
##
## Cinco solapas: la copa de tu division, la Copa del Rey (los 200 clubes
## de las diez divisiones) y las tres internacionales. Hasta ahora las
## copas existian y se jugaban solas: lo unico que se veia de ellas era
## una linea en el feed de noticias cuando salia el campeon.
##
## El armado del cuadro vive en core/cuadro_copa.gd — aca solo se pinta.
const COPAS := [
	["copa_interna", "Interna"],
	["copa_rey", "Rey"],
	["copa_campeones", "Campeones"],
	["copa_guerreros", "Guerreros"],
	["copa_emergentes", "Emergentes"],
]

## Alto de la celda de la PRIMERA columna. Cada columna a la derecha vale
## el doble, que es lo que hace que cada cruce quede centrado entre los
## dos de los que sale sin tener que calcular una sola coordenada.
const ALTO_CRUCE := 60
const ANCHO_CRUCE := 186


func _construir_panel_copas(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["copas"] = panel

	label_copa_titulo = Label.new()
	Tema.numero(label_copa_titulo, Tema.TAM_BASE)
	panel.add_child(label_copa_titulo)

	label_copa_camino = Label.new()
	# Una sola linea: el cuadro necesita todo el alto que se le pueda dar,
	# y con autowrap esta cabecera se comia dos renglones mas.
	label_copa_camino.clip_text = true
	label_copa_camino.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label_copa_camino.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	panel.add_child(label_copa_camino)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_copa = VBoxContainer.new()
	contenedor_copa.add_theme_constant_override("separation", 12)
	scroll.add_child(contenedor_copa)


func _mostrar_copa_interna() -> void:
	_mostrar_copa("copa_interna")


func _mostrar_copa_rey() -> void:
	_mostrar_copa("copa_rey")


func _mostrar_copa_campeones() -> void:
	_mostrar_copa("copa_campeones")


func _mostrar_copa_guerreros() -> void:
	_mostrar_copa("copa_guerreros")


func _mostrar_copa_emergentes() -> void:
	_mostrar_copa("copa_emergentes")


func _mostrar_copa(clave: String) -> void:
	copa_elegida = clave
	_ocultar_todos()
	paneles["copas"].visible = true
	_refrescar_copas()


func _refrescar_copas() -> void:
	for hijo in contenedor_copa.get_children():
		hijo.queue_free()
	label_copa_camino.text = ""
	label_copa_camino.add_theme_color_override("font_color", Tema.SUAVE)
	# Semibold SIEMPRE, no solo en campeon y eliminado: el label es chico
	# (TAM_CHICO) y en gris el trazo regular casi no se leia mientras la
	# copa sigue viva.
	var fuente_camino := Tema.negrita()
	if fuente_camino != null:
		label_copa_camino.add_theme_font_override("font", fuente_camino)

	match copa_elegida:
		"copa_interna":
			# `copas_division` esta VACIO hasta la fecha
			# FECHAS_PARA_COPA_DIVISION: la copa de division se sortea con
			# la tabla en curso, no al empezar la temporada. Un indice
			# directo ahi rompe la pantalla, asi que se pasa null y
			# _pintar_copa_viva dibuja "todavia no arranco".
			var interna: Copa = null
			if GameState.division_jugador < GameState.copas_division.size():
				interna = GameState.copas_division[GameState.division_jugador]
			_pintar_copa_viva(interna,
				"interna", "Copa de la División %d" % (GameState.division_jugador + 1),
				"Los %d mejores de tu división por la tabla a las %d fechas, a partido único." % [
					ClasificacionCopas.CUPOS_COPA_DIVISION, GameState.FECHAS_PARA_COPA_DIVISION])
		"copa_rey":
			_pintar_copa_viva(GameState.copa_nacional, "rey", "Copa del Rey",
				"Los %d clasificados de las diez divisiones, a partido único." % ClasificacionCopas.total_copa_nacional())
		_:
			_pintar_copa_internacional(copa_elegida.replace("copa_", ""))


## Una copa que se esta jugando ahora (la interna y el Rey): sale del
## objeto Copa vivo, con su ronda pendiente incluida.
##
## El cuadro se REINICIA con la temporada: en cuanto arranca la nueva se
## pinta el cuadro nuevo, aunque todavia no se haya jugado una ronda (la
## primera ronda ya esta sorteada, asi que hay cuadro que mirar). Antes
## se mostraba el cuadro terminado del año pasado mientras el nuevo no
## tuviera historial, y desde afuera parecia que la copa vieja seguia
## viva. El campeon de la que se jugo queda en el resumen de temporada y
## en la vitrina, que es donde se lo busca.
func _pintar_copa_viva(copa: Copa, clave_pasada: String, titulo: String,
		subtitulo: String) -> void:
	# El cuadro pasado solo sale si NO hay cuadro nuevo que mostrar: una
	# division de un solo equipo no arma copa, y ahi es mejor ver la
	# ultima que se jugo que una pantalla vacia.
	if _copa_sin_cuadro(copa) and GameState.copas_pasadas.has(clave_pasada):
		_pintar_copa_pasada(clave_pasada, titulo)
		return
	# El titulo dice la temporada, igual que el del cuadro pasado: es lo
	# que deja ver de un vistazo cual de los dos cuadros se esta mirando.
	var encabezado := "%s — temporada %d" % [titulo, GameState.temporada_actual]
	if copa == null:
		label_copa_titulo.text = encabezado
		contenedor_copa.add_child(_parrafo_de_copa("Esta copa todavía no arrancó."))
		return
	label_copa_titulo.text = encabezado
	var mio: String = GameState.equipo_jugador.nombre
	var pendientes := []
	for p in copa.partidos_pendientes:
		pendientes.append([p[0].nombre, p[1].nombre])
	var bye := []
	for e in copa.equipos_con_bye:
		bye.append(e.nombre)
	var camino := CuadroCopa.camino_de(copa.historial, pendientes, bye,
		copa.campeon.nombre if copa.campeon != null else "", mio)
	label_copa_camino.text = "%s   ·   %s" % [subtitulo, camino]
	if camino.begins_with("Campeón"):
		label_copa_camino.add_theme_color_override("font_color", Tema.VERDE)
	elif camino.begins_with("Eliminado"):
		label_copa_camino.add_theme_color_override("font_color", Tema.ROJO)

	if _copa_sin_cuadro(copa):
		contenedor_copa.add_child(_parrafo_de_copa("Esta copa todavía no arrancó."))
		return
	_pintar_cuadro(CuadroCopa.desde_copa(copa), mio)


## Una copa sin cuadro: ni rondas jugadas ni cruces pendientes. Pasa
## cuando la copa no se pudo armar (un solo equipo) o todavia no se
## armo.
func _copa_sin_cuadro(copa: Copa) -> bool:
	if copa == null:
		return true
	return copa.historial.is_empty() and copa.partidos_pendientes.is_empty()


## El cuadro terminado de la temporada pasada, con su campeon.
func _pintar_copa_pasada(clave: String, titulo: String) -> void:
	var guardadas: Dictionary = GameState.copas_pasadas
	var datos: Dictionary = guardadas[clave]
	var mio: String = GameState.equipo_jugador.nombre
	var campeon := str(datos.get("campeon", ""))
	if clave == "interna":
		titulo = "Copa de la División %d" % int(guardadas.get("division", 0))
	label_copa_titulo.text = "%s — temporada %d" % [
		titulo, int(guardadas.get("temporada", 0))]
	var partes := ["La copa de esta temporada todavía no tiene cuadro."]
	if campeon != "":
		partes.append("Campeón: %s" % campeon)
	partes.append(CuadroCopa.camino_de(datos.get("rondas", []), [], [], campeon, mio))
	label_copa_camino.text = "   ·   ".join(partes)
	if campeon == mio:
		label_copa_camino.add_theme_color_override("font_color", Tema.VERDE)
	_pintar_cuadro(CuadroCopa.desde_datos(datos), mio)


## Las tres internacionales se juegan repartidas en la temporada, una
## ronda por semana, asi que el resumen se rehace despues de cada ronda y
## esta pantalla muestra la copa EN CURSO (ver
## TemporadaInternacional.resumen). Cuando la temporada cierra, el mismo
## resumen queda como foto de la que se jugo.
func _pintar_copa_internacional(clave: String) -> void:
	var guardadas: Dictionary = GameState.copas_internacionales
	if not guardadas.has(clave):
		label_copa_titulo.text = "Copa de %s" % clave.capitalize()
		contenedor_copa.add_child(_parrafo_de_copa(
			"Las copas internacionales se juegan entre semana, con los cupos que "
			+ "reparte el coeficiente de cada país. Esta todavía no arrancó: "
			+ "primero se juega la previa."))
		return

	var datos: Dictionary = guardadas[clave]
	label_copa_titulo.text = "%s — temporada %d" % [
		str(datos["nombre"]), int(guardadas.get("temporada", 0))]
	var mio: String = GameState.equipo_jugador.nombre
	var campeon := str(datos.get("campeon", ""))
	var partes := []
	# En que anda la copa hoy: la fase de liga primero, el cuadro despues.
	var fecha := int(datos.get("fecha", 0))
	var fechas := int(datos.get("fechas", 0))
	if campeon != "":
		partes.append("campeón %s" % campeon)
	elif fecha < fechas:
		partes.append("fase de liga, fecha %d de %d" % [fecha, fechas])
	else:
		partes.append("eliminación directa")
	partes.append(CuadroCopa.camino_de(datos.get("rondas", []), [], [], campeon, mio))
	label_copa_camino.text = "   ·   ".join(partes)
	if campeon == mio:
		label_copa_camino.add_theme_color_override("font_color", Tema.VERDE)

	# El cuadro recien existe cuando termina la fase de liga: hasta
	# entonces lo unico que hay para mirar es la tabla.
	if datos.get("rondas", []).is_empty():
		contenedor_copa.add_child(_parrafo_de_copa(
			"La eliminación directa todavía no arrancó: primero se juegan las "
			+ "fechas de la fase de liga y el playoff de octavos."))
	else:
		_pintar_cuadro(CuadroCopa.desde_datos(datos), mio)

	# La fase de liga es la mitad de la competencia: sin ella no se
	# entiende por que ocho entraron directo a octavos y otros dieciseis
	# tuvieron que jugar un playoff.
	var tabla: Array = datos.get("tabla", [])
	if not tabla.is_empty():
		contenedor_copa.add_child(Tema.etiqueta_seccion(
			"Fase de liga  ·  del 1° al 8° van directo a octavos, del 9° al 24° juegan el playoff"))
		contenedor_copa.add_child(_tabla_fase_de_liga(tabla, mio))


func _pintar_cuadro(cuadro: Dictionary, mio: String) -> void:
	# Las dos aclaraciones en UNA linea: cada renglon de arriba es un
	# renglon menos de cuadro.
	var notas := []
	var ocultas := int(cuadro.get("rondas_ocultas", 0))
	if ocultas > 0:
		notas.append("El cuadro arranca en %s (antes se jugaron %d ronda%s con demasiados cruces para mostrarlas)" % [
			str(cuadro["columnas"][0]["titulo"]).to_lower(), ocultas,
			"" if ocultas == 1 else "s"])
	var esperando: Array = cuadro.get("esperando", [])
	if not esperando.is_empty():
		notas.append("%d club%s pasan sin jugar esta ronda%s" % [
			esperando.size(), "" if esperando.size() == 1 else "es",
			", el tuyo incluido" if esperando.has(mio) else ""])
	if not notas.is_empty():
		var nota := _texto_suave("%s." % "  ·  ".join(notas))
		nota.autowrap_mode = TextServer.AUTOWRAP_OFF
		nota.clip_text = true
		nota.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		contenedor_copa.add_child(nota)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	contenedor_copa.add_child(fila)

	var columnas: Array = cuadro["columnas"]
	for c in range(columnas.size()):
		var col: Dictionary = columnas[c]
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 0)
		fila.add_child(caja)
		var titulo := Label.new()
		titulo.text = str(col["titulo"])
		titulo.custom_minimum_size = Vector2(ANCHO_CRUCE, 0)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		titulo.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		titulo.add_theme_color_override("font_color", Tema.AMBAR)
		caja.add_child(titulo)
		# Cada columna a la derecha duplica el alto de celda: es lo que
		# alinea cada cruce con los dos de los que sale.
		var alto: int = ALTO_CRUCE * int(pow(2, c))
		for cruce in col["cruces"]:
			caja.add_child(_celda_de_cruce(cruce, alto, mio))

	var campeon := str(cuadro.get("campeon", ""))
	if campeon != "":
		var caja_campeon := VBoxContainer.new()
		fila.add_child(caja_campeon)
		var t := Label.new()
		t.text = "Campeón"
		t.custom_minimum_size = Vector2(ANCHO_CRUCE, 0)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		t.add_theme_color_override("font_color", Tema.AMBAR)
		caja_campeon.add_child(t)
		var centro := CenterContainer.new()
		centro.custom_minimum_size = Vector2(
			ANCHO_CRUCE, ALTO_CRUCE * int(pow(2, columnas.size() - 1)))
		caja_campeon.add_child(centro)
		var tarjeta := Componentes.tarjeta(Tema.AMBAR)
		tarjeta.custom_minimum_size = Vector2(ANCHO_CRUCE, 0)
		centro.add_child(tarjeta)
		var l := Label.new()
		l.text = campeon
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Tema.numero(l, Tema.TAM_CHICO, Tema.AMBAR if campeon != mio else Tema.VERDE)
		tarjeta.add_child(l)


func _celda_de_cruce(cruce: Dictionary, alto: int, mio: String) -> Control:
	var centro := CenterContainer.new()
	centro.custom_minimum_size = Vector2(ANCHO_CRUCE, alto)

	if bool(cruce.get("bye", false)):
		var suave := _texto_suave("%s\npasó sin jugar" % str(cruce.get("equipo", "")))
		suave.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		suave.custom_minimum_size = Vector2(ANCHO_CRUCE, 0)
		centro.add_child(suave)
		return centro

	var jugado: bool = bool(cruce.get("jugado", false))
	var ganador := str(cruce.get("ganador", ""))
	var acento := Color.TRANSPARENT
	if str(cruce["local"]) == mio or str(cruce["visitante"]) == mio:
		acento = Tema.AMBAR
	var tarjeta := Componentes.tarjeta(acento)
	tarjeta.custom_minimum_size = Vector2(ANCHO_CRUCE, 0)
	# Menos margen adentro que una tarjeta normal: en una celda de 186 px
	# los 16 de cada lado se los sacan al nombre del club, que es lo unico
	# que hay que poder leer.
	var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel")
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	centro.add_child(tarjeta)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 1)
	tarjeta.add_child(caja)

	for lado in ["local", "visitante"]:
		var nombre := str(cruce[lado])
		var goles: int = int(cruce["gl"] if lado == "local" else cruce["gv"])
		var linea := HBoxContainer.new()
		caja.add_child(linea)
		var color := Tema.TEXTO
		if jugado:
			color = Tema.VERDE if nombre == ganador else Tema.SUAVE
		if nombre == mio:
			color = Tema.AMBAR
		var l := Componentes.celda(nombre, ANCHO_CRUCE - 42, color,
			HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO)
		linea.add_child(l)
		linea.add_child(Componentes.celda_numero(
			str(goles) if jugado else "-", 26, color,
			HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))

	# Como se definio, si no fue en los 90: es la mitad de la historia de
	# un cruce de copa y en el marcador no se ve.
	var definicion := str(cruce.get("definicion", ""))
	if jugado and definicion != "" and definicion != "90 minutos":
		var extra := str(cruce.get("penales_texto", "")).strip_edges()
		caja.add_child(_texto_mini(extra if extra != "" else "(en el alargue)"))
	elif not jugado:
		caja.add_child(_texto_mini("por jugarse"))
	return centro


## Un parrafo adentro del scroll del cuadro. Necesita ancho PROPIO: ese
## scroll tambien scrollea a lo ancho, asi que el ancho disponible que les
## pasa a sus hijos es cero y una etiqueta con autowrap se parte en una
## letra por linea. Se veia en el mensaje de "todavia no se jugo ninguna
## copa internacional", escrito en vertical.
func _parrafo_de_copa(texto: String) -> Label:
	var l := _texto_suave(texto)
	l.custom_minimum_size = Vector2(880, 0)
	return l


func _texto_mini(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	l.add_theme_color_override("font_color", Tema.SUAVE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _tabla_fase_de_liga(tabla: Array, mio: String) -> Control:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	var cols := [["#", 40], ["Equipo", 240], ["PJ", 46], ["PG", 46], ["PE", 46],
		["PP", 46], ["GF", 46], ["GC", 46], ["DG", 52], ["Pts", 52]]
	var enc := Componentes.fila(false)
	var dentro := Componentes.contenido(enc)
	for c in cols:
		var l := Componentes.celda(str(c[0]), int(c[1]), Tema.SUAVE,
			HORIZONTAL_ALIGNMENT_RIGHT if c[0] != "Equipo" else HORIZONTAL_ALIGNMENT_LEFT)
		l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		dentro.add_child(l)
	caja.add_child(enc)

	for i in range(tabla.size()):
		var f: Dictionary = tabla[i]
		var nombre := str(f["equipo"])
		var soy_yo: bool = nombre == mio
		var fila := Componentes.fila(i % 2 == 0)
		var d := Componentes.contenido(fila)
		var color: Color = Tema.AMBAR if soy_yo else Tema.TEXTO
		d.add_child(Componentes.celda_numero(str(i + 1), 40, Tema.SUAVE,
			HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
		d.add_child(Componentes.celda(nombre, 240, color,
			HORIZONTAL_ALIGNMENT_LEFT, Tema.TAM_CHICO))
		for clave in ["pj", "pg", "pe", "pp", "gf", "gc"]:
			d.add_child(Componentes.celda_numero(str(int(f.get(clave, 0))), 46,
				Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
		var dg := int(f.get("dg", 0))
		d.add_child(Componentes.celda_numero(("+%d" % dg) if dg > 0 else str(dg), 52,
			Tema.VERDE if dg > 0 else (Tema.ROJO if dg < 0 else Tema.SUAVE),
			HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
		d.add_child(Componentes.celda_numero(str(int(f.get("pts", 0))), 52, color,
			HORIZONTAL_ALIGNMENT_RIGHT, Tema.TAM_CHICO))
		caja.add_child(fila)
	return caja


## Las noticias de la temporada, separadas por categoria y con los
## jugadores que se nombran clickeables.
##
## Antes era una sola lista de treinta tarjetas donde todos los hechos se
## leian igual, y el jugador que se mencionaba era
## texto muerto: para saber quien era habia que ir al buscador del mercado
## y filtrar a ciegas. Ahora el nombre abre su ficha de mercado y, si
## tenes un investigador libre, se lo manda desde ahi mismo.
func _construir_panel_noticias(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["noticias"] = panel

	var barra := HBoxContainer.new()
	panel.add_child(barra)
	for entrada in Noticias.SOLAPAS:
		var btn := Button.new()
		btn.text = str(entrada[1])
		btn.custom_minimum_size = Vector2(0, 44)
		var clave := str(entrada[0])
		btn.pressed.connect(func():
			noticias_solapa = clave
			_refrescar_noticias())
		barra.add_child(btn)
		botones_solapa_noticias[clave] = btn

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_noticias = VBoxContainer.new()
	contenedor_noticias.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_noticias)


## Le pone color a la noticia segun de que hable. Es lo unico que
## distingue un ascenso de un descenso cuando hay treinta seguidas.
func _acento_de_noticia(texto: String) -> Color:
	var t := texto.to_lower()
	# El descenso primero: "desciende" no contiene "ascien" (lleva una "e"
	# delante), pero conviene no depender de eso.
	if t.contains("descen") or t.contains("descien") or t.contains("quiebra"):
		return Tema.ROJO
	if t.contains("ascen") or t.contains("ascien") or t.contains("campe") \
			or t.contains("gana"):
		return Tema.VERDE
	if t.contains("fich") or t.contains("transfer") or t.contains("prestamo"):
		return Tema.CELESTE
	return Tema.BORDE


const VACIO_POR_SOLAPA := {
	"todas": "Todavia no hay noticias.",
	"fichajes": "Todavia no se movio nadie.",
	"campeones": "Todavia no se corono nadie: los titulos se reparten al cerrar la temporada.",
	"club": "Todavia no jugaste ningun partido.",
}


func _refrescar_noticias() -> void:
	if contenedor_noticias == null:
		return
	for clave in botones_solapa_noticias:
		Tema.seleccionado(botones_solapa_noticias[clave], clave == noticias_solapa)
	for hijo in contenedor_noticias.get_children():
		hijo.queue_free()
	if noticias_solapa == "club":
		_refrescar_tab_club()
		return

	var lista := Noticias.filtrar(GameState.noticias, noticias_solapa)
	if lista.is_empty():
		var vacio := Componentes.tarjeta()
		var l := Label.new()
		l.text = str(VACIO_POR_SOLAPA.get(noticias_solapa, "Todavia no hay nada aca."))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Tema.SUAVE)
		vacio.add_child(l)
		contenedor_noticias.add_child(vacio)
		return

	# De la mas NUEVA a la mas vieja, que es como estan guardadas
	# (_agregar_noticia mete adelante). Estaba recorrida al reves y lo
	# primero que se leia era lo mas viejo del feed.
	for n in lista:
		contenedor_noticias.add_child(_tarjeta_de_noticia(n))


## Historial del club dentro de Noticias: una tarjeta por partido, con una
## lectura corta de la causa principal. Los datos vienen congelados desde
## GameState para que el analisis no cambie al avanzar la temporada.
func _refrescar_tab_club() -> void:
	var historial: Array = GameState.historial_partidos
	if historial.is_empty():
		var vacio := Componentes.tarjeta()
		var l := Label.new()
		l.text = str(VACIO_POR_SOLAPA["club"])
		l.add_theme_color_override("font_color", Tema.SUAVE)
		vacio.add_child(l)
		contenedor_noticias.add_child(vacio)
		return
	for reg in historial:
		contenedor_noticias.add_child(_tarjeta_de_partido_club(reg))


func _tarjeta_de_partido_club(reg: Dictionary) -> Control:
	var tarjeta := Componentes.tarjeta(_color_del_resultado(reg))
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	tarjeta.add_child(caja)

	var encabezado := Label.new()
	encabezado.text = "Temporada %d  ·  %s  ·  %s" % [
		int(reg.get("temporada", 1)),
		str(reg.get("torneo", "")) if str(reg.get("torneo", "")) != "" else "Fecha %d" % int(reg.get("fecha", 0)),
		Calendario.texto_medio(int(reg.get("dia", 0)))]
	encabezado.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	encabezado.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(encabezado)

	var marcador := Label.new()
	var local: String = str(reg.get("local", ""))
	marcador.text = "%s   %d - %d   %s" % [
		local, int(reg.get("gl", 0)), int(reg.get("gv", 0)), str(reg.get("visitante", ""))]
	marcador.text += "  ·  %s" % _resultado_de_club(reg)
	marcador.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tema.numero(marcador, 20, _color_del_resultado(reg))
	caja.add_child(marcador)

	var analisis := Label.new()
	analisis.text = "Analisis: " + _analisis_de_partido(reg)
	analisis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analisis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(analisis)

	var datos := _texto_estadisticas_club(reg)
	if datos != "":
		var estadisticas := Label.new()
		estadisticas.text = datos
		estadisticas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		estadisticas.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		estadisticas.add_theme_color_override("font_color", Tema.SUAVE)
		caja.add_child(estadisticas)
	return tarjeta


func _resultado_de_club(reg: Dictionary) -> String:
	var mio: String = GameState.equipo_jugador.nombre
	var ganador := str(reg.get("ganador", ""))
	if ganador != "":
		return "Ganaste" if ganador == mio else "Perdiste"
	var propios: int = int(reg.get("gl", 0)) if str(reg.get("local", "")) == mio else int(reg.get("gv", 0))
	var ajenos: int = int(reg.get("gv", 0)) if str(reg.get("local", "")) == mio else int(reg.get("gl", 0))
	if propios > ajenos:
		return "Ganaste"
	if propios < ajenos:
		return "Perdiste"
	return "Empate"


func _datos_lado_club(reg: Dictionary, local: bool) -> Dictionary:
	var datos: Dictionary = reg.get("analisis", {})
	var clave := "local" if local else "visitante"
	return datos.get(clave, {})


func _analisis_de_partido(reg: Dictionary) -> String:
	var resultado := _resultado_de_club(reg)
	if bool(reg.get("forfeit", false)):
		if resultado == "Perdiste":
			return "Fue un partido administrativo: no pudimos presentar el equipo completo."
		if resultado == "Empate":
			return "Fue un empate administrativo: ninguno pudo presentar el equipo completo."
		return "Ganamos por un partido administrativo."
	var soy_local: bool = str(reg.get("local", "")) == GameState.equipo_jugador.nombre
	var yo := _datos_lado_club(reg, soy_local)
	var rival := _datos_lado_club(reg, not soy_local)
	var stats: Dictionary = reg.get("stats", {})
	var stats_yo: Dictionary = stats.get("local" if soy_local else "visitante", {})
	var stats_rival: Dictionary = stats.get("visitante" if soy_local else "local", {})
	var media_yo := float(yo.get("media", 0.0))
	var media_rival := float(rival.get("media", 0.0))
	var division_yo := int(yo.get("division", 0))
	var division_rival := int(rival.get("division", 0))
	if str(reg.get("definicion", "90 minutos")) == "penales":
		return "Ganamos en los penales despues de empatar en el partido." if resultado == "Ganaste" else "Se perdio en los penales despues de empatar en el partido."

	# Primero la diferencia de calidad. Es la explicacion mas clara en una
	# copa desigual y evita inventar una causa tactica para un 0-3 esperable.
	if media_yo > 0.0 and media_rival > 0.0 \
			and (absf(media_yo - media_rival) >= 6.0 \
			or (division_yo > 0 and division_rival > 0 \
			and abs(division_yo - division_rival) >= 2)):
		if resultado == "Perdiste" and media_rival > media_yo:
			return "Se perdio porque tenian mas calidad que nosotros."
		if resultado == "Ganaste" and media_yo > media_rival:
			return "Ganamos porque teniamos mas calidad que ellos."
		if resultado == "Empate":
			if media_rival > media_yo:
				return "Empatamos contra un rival de mayor calidad; fue un buen resultado."
			return "Empatamos pese a tener mas calidad; nos falto resolverlo."

	var tiros_yo := int(stats_yo.get("tiros", 0))
	var tiros_rival := int(stats_rival.get("tiros", 0))
	var arco_yo := int(stats_yo.get("tiros_al_arco", 0))
	var arco_rival := int(stats_rival.get("tiros_al_arco", 0))
	var atajadas_rival := int(rival.get("atajadas", -1))
	var atajadas_yo := int(yo.get("atajadas", -1))
	if resultado == "Ganaste" and atajadas_rival == 0 and arco_yo > 0:
		return "Ganamos porque el golero rival no tapo ningun tiro al arco."
	if resultado == "Perdiste" and atajadas_yo == 0 and arco_rival > 0:
		return "Se perdio porque nuestro golero no tapo ningun tiro al arco."
	if resultado == "Ganaste" and arco_yo >= arco_rival + 2:
		return "Ganamos porque fuimos mas peligrosos: %d tiros al arco contra %d." % [arco_yo, arco_rival]
	if resultado == "Perdiste" and arco_rival >= arco_yo + 2:
		return "Se perdio porque ellos generaron mas peligro: %d tiros al arco contra %d." % [arco_rival, arco_yo]
	if tiros_yo >= 5 and tiros_yo - arco_yo >= 4 and resultado != "Ganaste":
		return "Nos falto punteria: tuvimos %d tiros y solo %d fueron al arco." % [tiros_yo, arco_yo]
	if yo.has("tactica") and float(yo.get("tactica", 100.0)) < 45.0:
		return "La nueva tactica todavia no estaba asimilada por el equipo."
	if yo.has("animo") and float(yo.get("animo", 50.0)) < 38.0:
		return "El animo bajo del plantel pudo pesar en el partido."
	if resultado == "Ganaste":
		return "Ganamos en un partido parejo y aprovechamos mejor nuestras chances."
	if resultado == "Perdiste":
		return "Se perdio en un partido parejo; falto aprovechar mejor las chances."
	return "Fue un partido parejo y termino en empate."


func _texto_estadisticas_club(reg: Dictionary) -> String:
	var stats: Dictionary = reg.get("stats", {})
	if stats.is_empty():
		return "Estadisticas: no disponibles para este partido."
	var soy_local: bool = str(reg.get("local", "")) == GameState.equipo_jugador.nombre
	var yo: Dictionary = stats.get("local" if soy_local else "visitante", {})
	var rival: Dictionary = stats.get("visitante" if soy_local else "local", {})
	# Partidas viejas pueden traer el contenedor `stats`, pero con todo en
	# cero. Mostrar 50/50 y 0 tiros seria inventar datos, especialmente en
	# una derrota amplia. El motor nuevo guarda acciones reales.
	var hay_datos := int(yo.get("acciones", 0)) > 0 or int(rival.get("acciones", 0)) > 0 \
			or int(yo.get("tiros", 0)) > 0 or int(rival.get("tiros", 0)) > 0 \
			or int(yo.get("pases_intentados", 0)) > 0 or int(rival.get("pases_intentados", 0)) > 0
	if not hay_datos:
		return "Estadisticas: no disponibles para este partido."
	return "Estadisticas: tiros %d-%d  ·  al arco %d-%d  ·  posesion %.0f%%-%.0f%%" % [
		int(yo.get("tiros", 0)), int(rival.get("tiros", 0)),
		int(yo.get("tiros_al_arco", 0)), int(rival.get("tiros_al_arco", 0)),
		float(yo.get("posesion_pct", 50.0)), float(rival.get("posesion_pct", 50.0))]


func _tarjeta_de_noticia(n: Dictionary) -> Control:
	var texto := str(n["texto"])
	var tarjeta := Componentes.tarjeta(_acento_de_noticia(texto))
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("normal_font_size", Tema.TAM_BASE)
	l.text = _texto_con_menciones(texto, n.get("jugadores", []))
	l.meta_clicked.connect(func(meta): _abrir_ficha_de_mencion(str(meta)))
	tarjeta.add_child(l)
	return tarjeta


## Convierte el nombre de cada jugador mencionado en un enlace. El meta
## que viaja es "id|club": el club hace falta para mandar un investigador,
## que trabaja sobre un jugador DE un club.
##
## Se reemplaza solo la PRIMERA aparicion: en "X ficha a Juan Perez de Y",
## el nombre aparece una vez y alcanza; si por alguna razon apareciera dos
## veces, dos enlaces al mismo lugar solo ensucian la linea.
func _texto_con_menciones(texto: String, menciones: Array) -> String:
	var salida := texto
	for m in menciones:
		var nombre := str(m.get("nombre", "")).strip_edges()
		if nombre == "" or not salida.contains(nombre):
			continue
		salida = salida.replace(nombre, "[url=%d|%s][color=#8ecae6]%s[/color][/url]" % [
			int(m.get("id", -1)), str(m.get("club", "")), nombre])
	return salida


func _abrir_ficha_de_mencion(meta: String) -> void:
	var partes := meta.split("|", true, 1)
	if partes.is_empty():
		return
	_mostrar_modal_jugador(int(partes[0]))


# ---------------------------------------------------------------------------
# El modal del jugador mencionado
# ---------------------------------------------------------------------------
## Lo mismo que se ve de el en el mercado, sin salir de la noticia: quien
## es, que se sabe de el y el boton para mandarle un investigador. Es un
## CanvasLayer y no un panel mas porque tiene que taparlo todo sin
## participar del baile de mostrar/ocultar paneles — igual que la pantalla
## de inicio.
func _construir_modal_jugador() -> void:
	capa_modal_jugador = CanvasLayer.new()
	capa_modal_jugador.layer = 9
	capa_modal_jugador.visible = false
	add_child(capa_modal_jugador)

	var fondo := PanelContainer.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.65)
	fondo.add_theme_stylebox_override("panel", estilo)
	capa_modal_jugador.add_child(fondo)

	var centro := CenterContainer.new()
	fondo.add_child(centro)
	var caja := Componentes.modal()
	caja.custom_minimum_size = Vector2(520, 0)
	caja.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centro.add_child(caja)

	contenedor_modal_jugador = VBoxContainer.new()
	contenedor_modal_jugador.add_theme_constant_override("separation", 8)
	caja.add_child(contenedor_modal_jugador)


func _mostrar_modal_jugador(jugador_id: int) -> void:
	modal_jugador_id = jugador_id
	capa_modal_jugador.visible = true
	_refrescar_modal_jugador()


func _cerrar_modal_jugador() -> void:
	capa_modal_jugador.visible = false


func _refrescar_modal_jugador() -> void:
	for hijo in contenedor_modal_jugador.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador
	var indice := _indice_de_jugadores()
	if not indice.has(modal_jugador_id):
		# Pudo colgarse, retirarse o irse al pool de libres entre que salio
		# la noticia y la fuiste a leer.
		contenedor_modal_jugador.add_child(_texto_suave(
			"Ese jugador ya no esta en ningun club de la piramide."))
		contenedor_modal_jugador.add_child(_boton_cerrar_modal())
		return

	var entrada: Dictionary = indice[modal_jugador_id]
	var j: Dictionary = entrada["jugador"]
	var club: Team = entrada["club"]
	var propio: bool = club == equipo
	# BusquedaMercado.ficha pide la entrada con la forma del buscador
	# (equipo/origen); el indice la arma con "club" y sin origen.
	var f := BusquedaMercado.ficha(equipo, {
		"jugador": j, "equipo": club,
		"division": int(entrada["division"]), "origen": "plantel"})

	var titulo := Label.new()
	titulo.text = _nombre_jugador(j)
	Tema.numero(titulo, 24)
	contenedor_modal_jugador.add_child(titulo)

	var sub := Label.new()
	sub.text = "%s  ·  %d años  ·  %s  ·  División %d" % [
		j["posicion"], int(j["edad"]), club.nombre, int(entrada["division"])]
	sub.add_theme_color_override("font_color", Tema.CELESTE if not propio else Tema.AMBAR)
	contenedor_modal_jugador.add_child(sub)

	if propio:
		contenedor_modal_jugador.add_child(_texto_suave("Es tuyo."))

	# De un ajeno sin informe no se sabe NADA de esto: es exactamente el
	# agujero que el investigador viene a llenar.
	var conocido: bool = propio or bool(f["conocido"])
	if conocido:
		var nums := HBoxContainer.new()
		contenedor_modal_jugador.add_child(nums)
		nums.add_child(_caja_numero("Media", "%.1f" % float(j["media"]), Tema.TEXTO))
		nums.add_child(_caja_numero("Techo", str(int(j["potencial"])), Tema.AMBAR))
		var animo := int(club.animo.get(modal_jugador_id, 50))
		nums.add_child(_caja_numero("Ánimo", str(animo), Componentes.color_de_valor(animo)))
		nums.add_child(_caja_numero("Valor", Economia.formato_dinero(
			ValorJugador.calcular(j, club.animo.get(modal_jugador_id, 50.0),
				club.contratos.get(modal_jugador_id, 3))), Tema.VERDE))
		contenedor_modal_jugador.add_child(_texto_suave(
			"Contrato %d año(s)  ·  sueldo %s" % [
				int(club.contratos.get(modal_jugador_id, 0)),
				Economia.formato_dinero(club.sueldos.get(modal_jugador_id, 0))]))
	elif float(f["progreso"]) >= 0.0:
		contenedor_modal_jugador.add_child(Componentes.bloque_investigando(
			460, Investigadores.progreso(equipo, modal_jugador_id),
			_dias_que_faltan(equipo, modal_jugador_id)))
	else:
		contenedor_modal_jugador.add_child(_texto_suave(
			"No lo investigaste: no se le ve la media, ni el valor, ni el sueldo."))

	if club.esta_lesionado(modal_jugador_id):
		var les: Dictionary = club.lesiones[modal_jugador_id]
		var l := Label.new()
		l.text = "Lesionado: %s, %d días" % [les["tipo"], int(les["dias_restantes"])]
		l.add_theme_color_override("font_color", Tema.ROJO)
		contenedor_modal_jugador.add_child(l)

	var acciones := HBoxContainer.new()
	contenedor_modal_jugador.add_child(acciones)

	if conocido:
		var btn_ficha := Button.new()
		btn_ficha.text = "Ficha completa"
		btn_ficha.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
		btn_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id := modal_jugador_id
		var dueno: Team = null if propio else club
		btn_ficha.pressed.connect(func():
			_cerrar_modal_jugador()
			_mostrar_ficha(id, dueno))
		acciones.add_child(btn_ficha)

	if not propio and not conocido:
		var btn_inv := Button.new()
		btn_inv.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
		btn_inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if float(f["progreso"]) >= 0.0:
			btn_inv.text = "Ya lo estás investigando"
			btn_inv.disabled = true
		elif Investigadores.libres(equipo).is_empty():
			btn_inv.text = "Sin investigadores libres"
			btn_inv.disabled = true
			btn_inv.tooltip_text = "Se contratan en Equipo › Instalaciones."
		else:
			btn_inv.text = "Investigar"
			btn_inv.add_theme_color_override("font_color", Tema.AMBAR)
			btn_inv.pressed.connect(func():
				label_modal_jugador_estado = _asignar_investigador(club, modal_jugador_id)
				_refrescar_modal_jugador())
		acciones.add_child(btn_inv)

	acciones.add_child(_boton_cerrar_modal())

	if not label_modal_jugador_estado.is_empty():
		var aviso := Label.new()
		aviso.text = label_modal_jugador_estado
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso.add_theme_color_override("font_color", Tema.AMBAR)
		aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		contenedor_modal_jugador.add_child(aviso)
		label_modal_jugador_estado = ""


func _boton_cerrar_modal() -> Button:
	var btn := Button.new()
	btn.text = "Cerrar"
	btn.custom_minimum_size = Vector2(120, Tema.ALTO_TACTIL)
	btn.pressed.connect(_cerrar_modal_jugador)
	return btn


## Guardado de partida (§12) — un solo slot: Guardar pisa lo que hubiera,
## Cargar reemplaza TODO el estado en memoria por lo del archivo, Borrar
## elimina el archivo (no toca la partida en curso). Cargar/Borrar quedan
## deshabilitados si no hay ningun archivo guardado.
func _construir_panel_partida_guardado(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["partida_guardado"] = panel

	var tarjeta := Componentes.tarjeta()
	panel.add_child(tarjeta)
	var dentro := VBoxContainer.new()
	tarjeta.add_child(dentro)

	dentro.add_child(Tema.etiqueta_seccion("Guardado local · un solo espacio"))

	label_partida_estado = Label.new()
	label_partida_estado.text = ""
	label_partida_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dentro.add_child(label_partida_estado)

	var advertencia := Label.new()
	advertencia.text = "Guardar pisa lo que hubiera. Cargar reemplaza TODO lo que este pasando ahora por lo del archivo. Borrar elimina el ARCHIVO y no toca la partida en curso: para arrancar de cero con otro club y otro mundo, usa Partida nueva."
	advertencia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advertencia.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	advertencia.add_theme_color_override("font_color", Tema.SUAVE)
	dentro.add_child(advertencia)

	var barra := HBoxContainer.new()
	dentro.add_child(barra)

	# Guardar es la accion principal de la pantalla: la unica ambar.
	var boton_guardar := Button.new()
	boton_guardar.text = "Guardar partida"
	boton_guardar.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	Tema.primario(boton_guardar)
	boton_guardar.pressed.connect(_on_guardar_partida)
	barra.add_child(boton_guardar)

	boton_cargar_partida = Button.new()
	boton_cargar_partida.text = "Cargar partida"
	boton_cargar_partida.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	boton_cargar_partida.pressed.connect(_on_cargar_partida)
	barra.add_child(boton_cargar_partida)

	boton_partida_nueva = Button.new()
	boton_partida_nueva.text = "Partida nueva"
	boton_partida_nueva.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	boton_partida_nueva.tooltip_text = "Tira la partida actual y genera un mundo nuevo desde cero."
	boton_partida_nueva.pressed.connect(func(): dialogo_partida_nueva.popup_centered())
	barra.add_child(boton_partida_nueva)

	dialogo_partida_nueva = ConfirmationDialog.new()
	dialogo_partida_nueva.title = "Empezar una partida nueva"
	dialogo_partida_nueva.dialog_text = "Se tira TODO lo que estas jugando —tu club, la temporada, el mercado— y se genera un mundo nuevo: otros 200 clubes, otro equipo, division 10 y fecha 1.\n\nEl archivo guardado NO se toca: si tenias uno, sigue ahi y podes volver con Cargar."
	dialogo_partida_nueva.ok_button_text = "Empezar de cero"
	dialogo_partida_nueva.cancel_button_text = "Cancelar"
	dialogo_partida_nueva.confirmed.connect(_on_partida_nueva)
	add_child(dialogo_partida_nueva)
	Tema.dialogo(dialogo_partida_nueva, true)

	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(hueco)

	# Borrar lejos de las otras dos y en rojo: es la unica que no se puede
	# deshacer.
	boton_borrar_partida = Button.new()
	boton_borrar_partida.text = "Borrar guardado"
	boton_borrar_partida.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	boton_borrar_partida.add_theme_color_override("font_color", Tema.ROJO)
	boton_borrar_partida.pressed.connect(func(): dialogo_borrar_partida.popup_centered())
	barra.add_child(boton_borrar_partida)

	# Borrar el guardado no se puede deshacer y hasta ahora un solo toque
	# alcanzaba. Va con confirmacion, como cualquier cosa que no tiene
	# vuelta atras.
	dialogo_borrar_partida = ConfirmationDialog.new()
	dialogo_borrar_partida.title = "Borrar la partida guardada"
	dialogo_borrar_partida.dialog_text = "Se borra el archivo guardado y no se puede recuperar.\n\nLa partida que estás jugando ahora NO se toca: sigue como está, solo que sin copia de respaldo."
	dialogo_borrar_partida.ok_button_text = "Borrar"
	dialogo_borrar_partida.cancel_button_text = "Cancelar"
	dialogo_borrar_partida.confirmed.connect(_on_borrar_partida)
	add_child(dialogo_borrar_partida)
	Tema.dialogo(dialogo_borrar_partida)
	Tema.peligro(dialogo_borrar_partida.get_ok_button())


func _construir_panel_opciones(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["opciones"] = panel

	var tarjeta := Componentes.tarjeta()
	panel.add_child(tarjeta)
	var dentro := VBoxContainer.new()
	dentro.add_child(Tema.etiqueta_seccion("Preferencias de juego"))
	tarjeta.add_child(dentro)

	option_fps = OptionButton.new()
	for fps in OPCIONES_FPS:
		option_fps.add_item(str(fps))
	option_fps.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	option_fps.item_selected.connect(_on_fps_seleccionado)
	dentro.add_child(_grupo_filtro("FPS", option_fps))

	option_velocidad_partido = OptionButton.new()
	for velocidad in OPCIONES_VELOCIDAD_PARTIDO:
		option_velocidad_partido.add_item(str(int(velocidad)) + "x")
	option_velocidad_partido.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
	option_velocidad_partido.item_selected.connect(_on_velocidad_partido_seleccionada)
	dentro.add_child(_grupo_filtro("Velocidad de partido", option_velocidad_partido))

	option_tema = OptionButton.new()
	option_tema.add_item("Oscuro")
	option_tema.add_item("Claro")
	option_tema.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	option_tema.item_selected.connect(_on_tema_seleccionado)
	dentro.add_child(_grupo_filtro("Tema visual", option_tema))


func _mostrar_opciones() -> void:
	_ocultar_todos()
	paneles["opciones"].visible = true
	option_fps.select(OPCIONES_FPS.find(fps_elegido))
	option_velocidad_partido.select(OPCIONES_VELOCIDAD_PARTIDO.find(velocidad_partido_elegida))
	option_tema.select(OPCIONES_TEMA.find(tema_visual))


func _on_fps_seleccionado(indice: int) -> void:
	fps_elegido = int(OPCIONES_FPS[indice])
	Engine.max_fps = fps_elegido
	_guardar_opciones()


func _on_velocidad_partido_seleccionada(indice: int) -> void:
	velocidad_partido_elegida = float(OPCIONES_VELOCIDAD_PARTIDO[indice])
	if vista_partido != null and is_instance_valid(vista_partido):
		vista_partido.velocidad = velocidad_partido_elegida
	_guardar_opciones()


func _on_tema_seleccionado(indice: int) -> void:
	var nuevo := str(OPCIONES_TEMA[indice])
	if nuevo == tema_visual:
		return
	tema_visual = nuevo
	_guardar_opciones()
	_recarga_por_tema = true
	_seccion_antes_del_tema = seccion_actual
	_panel_antes_del_tema = panel_de_seccion_actual
	get_tree().call_deferred("reload_current_scene")


func _cargar_opciones() -> void:
	var archivo := ConfigFile.new()
	if archivo.load(RUTA_OPCIONES) != OK:
		return
	fps_elegido = int(archivo.get_value("video", "fps", 60))
	velocidad_partido_elegida = float(archivo.get_value("partido", "velocidad", 1.0))
	tema_visual = str(archivo.get_value("video", "tema", "oscuro"))
	if not OPCIONES_FPS.has(fps_elegido):
		fps_elegido = 60
	if OPCIONES_VELOCIDAD_PARTIDO.find(velocidad_partido_elegida) == -1:
		velocidad_partido_elegida = 1.0
	if not OPCIONES_TEMA.has(tema_visual):
		tema_visual = "oscuro"


func _guardar_opciones() -> void:
	var archivo := ConfigFile.new()
	archivo.set_value("video", "fps", fps_elegido)
	archivo.set_value("video", "tema", tema_visual)
	archivo.set_value("partido", "velocidad", velocidad_partido_elegida)
	archivo.save(RUTA_OPCIONES)


func _refrescar_partida_guardado() -> void:
	var hay_guardado := GameState.hay_partida_guardada()
	boton_cargar_partida.disabled = not hay_guardado
	boton_borrar_partida.disabled = not hay_guardado

	# Un boton apagado y mudo se lee como un boton roto: se toca, no pasa
	# nada, y la conclusion es que el juego fallo. Los dos dicen por que
	# no se pueden usar, y cuando SI hay guardado la pantalla dice de
	# cuando es, que es lo unico que hace falta para decidir si cargarlo.
	if not hay_guardado:
		var motivo := "Todavia no guardaste nada, asi que Cargar y Borrar no tienen nada que hacer."
		boton_cargar_partida.tooltip_text = motivo
		boton_borrar_partida.tooltip_text = motivo
		if label_partida_estado.text == "":
			label_partida_estado.text = motivo
		return

	var info := GameState.info_partida_guardada()
	boton_cargar_partida.tooltip_text = "Reemplaza TODO lo que este pasando ahora por lo del archivo."
	boton_borrar_partida.tooltip_text = "Borra el archivo. No toca la partida en curso."
	if label_partida_estado.text == "":
		label_partida_estado.text = "Guardado del %s  ·  %.1f MB." % [
			str(info.get("cuando", "?")), float(info.get("megas", 0.0))]


func _on_guardar_partida() -> void:
	GameState.guardar_partida()
	label_partida_estado.text = "Partida guardada: temporada %d, division %d, %s." % [
		GameState.temporada_actual, GameState.division_jugador + 1, GameState.equipo_jugador.nombre
	]
	_refrescar_partida_guardado()


func _on_cargar_partida() -> void:
	if GameState.cargar_partida():
		label_partida_estado.text = "Partida cargada: temporada %d, division %d, %s." % [
			GameState.temporada_actual, GameState.division_jugador + 1, GameState.equipo_jugador.nombre
		]
		_refrescar_historial_partidos()
		_mostrar_plantel()
	else:
		label_partida_estado.text = "No se pudo cargar la partida (archivo corrupto o inexistente)."
	_refrescar_partida_guardado()


## Repinta la pantalla de Partido con el último partido jugado. Hace
## falta al CARGAR: el resultado viaja en el guardado, pero la pantalla se
## había armado con el texto inicial y se quedaba diciendo "todavía no
## jugaste ninguna fecha" con una temporada entera encima.
func _mostrar_historial_partidos() -> void:
	_ocultar_todos()
	paneles["historial"].visible = true
	_refrescar_historial_partidos()


## La lista de partidos y el detalle del elegido.
##
## Antes esto mostraba SOLO el ultimo partido, y lo hacia leyendo
## GameState.ultimos_eventos — que se pisan en cuanto jugas otro. Ahora se
## lee del historial guardado, que trae el resumen ya calculado de cada
## partido y sobrevive al guardado.
func _refrescar_historial_partidos() -> void:
	if contenedor_lista_partidos == null:
		return
	for hijo in contenedor_lista_partidos.get_children():
		hijo.queue_free()
	for hijo in contenedor_ultimo_partido.get_children():
		hijo.queue_free()

	var historial: Array = GameState.historial_partidos
	if historial.is_empty():
		contenedor_lista_partidos.add_child(_texto_suave("Todavia no jugaste ningun partido."))
		return

	historial_elegido = clampi(historial_elegido, 0, historial.size() - 1)
	for i in range(historial.size()):
		contenedor_lista_partidos.add_child(_fila_de_historial(historial[i], i))
	_detalle_de_partido(historial[historial_elegido])


## De que torneo fue el partido, en corto para que entre en la fila. Un
## cruce de copa no tiene numero de fecha: lo que lo ubica es la copa.
func _etiqueta_de_torneo(reg: Dictionary) -> String:
	var torneo := str(reg.get("torneo", ""))
	if torneo == "":
		return "F%d" % int(reg.get("fecha", 0))
	return torneo.replace("Copa ", "C.")


## Una linea de la lista: fecha, rival y resultado, con el color de si
## ganaste. El elegido queda marcado.
func _fila_de_historial(reg: Dictionary, indice: int) -> Control:
	var mio: String = GameState.equipo_jugador.nombre
	var propios: int = int(reg["gl"]) if str(reg["local"]) == mio else int(reg["gv"])
	var ajenos: int = int(reg["gv"]) if str(reg["local"]) == mio else int(reg["gl"])
	var rival: String = str(reg["visitante"]) if str(reg["local"]) == mio else str(reg["local"])
	var color := Tema.VERDE if propios > ajenos else (Tema.ROJO if propios < ajenos else Tema.SUAVE)

	var btn := Button.new()
	btn.text = "T%d %s   %s %d-%d   %s" % [
		int(reg.get("temporada", 1)), _etiqueta_de_torneo(reg),
		"L" if str(reg["local"]) == mio else "V", propios, ajenos, rival]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_color_override("font_color", color)
	btn.tooltip_text = "%s  ·  Division %d" % [
		Calendario.texto_medio(int(reg.get("dia", 0))), int(reg.get("division", 0))]
	Tema.seleccionado(btn, indice == historial_elegido)
	btn.pressed.connect(func():
		historial_elegido = indice
		_refrescar_historial_partidos())
	return btn


## El detalle: marcador, las cuatro comparaciones y la linea de tiempo.
func _detalle_de_partido(reg: Dictionary) -> void:
	contenedor_ultimo_partido.add_child(_tarjeta_marcador(reg))
	contenedor_ultimo_partido.add_child(Tema.etiqueta_seccion("Cómo se jugó"))
	for fila in _filas_de_estadisticas(reg):
		contenedor_ultimo_partido.add_child(fila)

	var hitos: Array = reg.get("hitos", [])
	contenedor_ultimo_partido.add_child(Tema.etiqueta_seccion(
		"Lo que paso" if not hitos.is_empty() else "No paso nada para contar"))
	for i in range(hitos.size()):
		contenedor_ultimo_partido.add_child(_fila_hito(hitos[i], i % 2 == 0))


## El marcador, grande, con tu equipo marcado en ambar.
func _tarjeta_marcador(r: Dictionary) -> Control:
	var tarjeta := Componentes.tarjeta(_color_del_resultado(r))
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 2)
	tarjeta.add_child(caja)

	var fecha := Label.new()
	fecha.text = "Temporada %d  ·  %s  ·  %s" % [
		int(r.get("temporada", 1)),
		str(r.get("torneo", "")) if str(r.get("torneo", "")) != "" else "fecha %d" % int(r.get("fecha", 0)),
		Calendario.texto_medio(int(r.get("dia", 0)))]
	fecha.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	fecha.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(fecha)

	var fila := HBoxContainer.new()
	caja.add_child(fila)
	var mio: String = GameState.equipo_jugador.nombre
	var equipo_local := _equipo_por_nombre(str(r["local"]))
	var equipo_visitante := _equipo_por_nombre(str(r["visitante"]))
	var l_local := Label.new()
	l_local.text = _nombre_marcador(equipo_local) if equipo_local != null else str(r["local"])
	l_local.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l_local.clip_text = true
	Tema.numero(l_local, 22, Tema.AMBAR if str(r["local"]) == mio else Tema.TEXTO)
	fila.add_child(l_local)

	var marcador := Label.new()
	marcador.text = "  %d - %d  " % [int(r["gl"]), int(r["gv"])]
	Tema.numero(marcador, 30)
	fila.add_child(marcador)

	var l_visita := Label.new()
	l_visita.text = _nombre_marcador(equipo_visitante) if equipo_visitante != null else str(r["visitante"])
	l_visita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_visita.clip_text = true
	Tema.numero(l_visita, 22, Tema.AMBAR if str(r["visitante"]) == mio else Tema.TEXTO)
	fila.add_child(l_visita)
	return tarjeta


## Verde si ganaste, rojo si perdiste. El borde de la tarjeta dice el
## resultado antes de que leas los numeros.
func _color_del_resultado(r: Dictionary) -> Color:
	var mio: String = GameState.equipo_jugador.nombre
	var ganador := str(r.get("ganador", ""))
	if ganador != "":
		return Tema.VERDE if ganador == mio else Tema.ROJO
	var propios: int = int(r["gl"]) if str(r["local"]) == mio else int(r["gv"])
	var ajenos: int = int(r["gv"]) if str(r["local"]) == mio else int(r["gl"])
	if propios > ajenos:
		return Tema.VERDE
	if propios < ajenos:
		return Tema.ROJO
	return Tema.BORDE


## Las cuatro comparaciones con barra. Las comparten esta pantalla y el
## cuadro de fin de partido: son la misma informacion y no tenian por que
## verse distintas.
func _filas_de_estadisticas(r: Dictionary) -> Array:
	var stats := EstadisticasPartido.calcular(
		GameState.ultimos_eventos, str(r["local"]), str(r["visitante"]))
	var loc: Dictionary = stats[str(r["local"])]
	var vis: Dictionary = stats[str(r["visitante"])]
	return [
		_fila_estadistica("Posesión", "%.0f%%" % loc["posesion_pct"],
			"%.0f%%" % vis["posesion_pct"],
			float(loc["posesion_pct"]), float(vis["posesion_pct"])),
		_fila_estadistica("Tiros", str(loc["tiros"]), str(vis["tiros"]),
			float(loc["tiros"]), float(vis["tiros"])),
		_fila_estadistica("Tiros al arco", str(loc["tiros_al_arco"]),
			str(vis["tiros_al_arco"]),
			float(loc["tiros_al_arco"]), float(vis["tiros_al_arco"])),
		_fila_estadistica("Pases completados",
			"%d/%d" % [loc["pases_completados"], loc["pases_intentados"]],
			"%d/%d" % [vis["pases_completados"], vis["pases_intentados"]],
			float(loc["pases_completados"]), float(vis["pases_completados"])),
	]


func _fila_hito(h: Dictionary, par: bool) -> Control:
	var fila := Componentes.fila(par)
	var dentro := Componentes.contenido(fila)

	var minuto := Componentes.celda_numero(
		"%d'" % int(h["minuto"]), 54, Tema.SUAVE, HORIZONTAL_ALIGNMENT_RIGHT)
	dentro.add_child(minuto)

	var texto := ""
	var color := Tema.TEXTO
	match str(h["tipo"]):
		"gol":
			texto = "GOL de %s" % str(h["quien"])
			color = Tema.VERDE
		"tarjeta":
			var d := str(h["detalle"])
			texto = "Amarilla a %s" % str(h["quien"])
			color = Tema.AMBAR
			if d.begins_with("roja"):
				texto = "ROJA a %s" % str(h["quien"])
				if d == "roja_doble_amarilla":
					texto += " (doble amarilla)"
				color = Tema.ROJO
		"cambio":
			texto = "Cambio: sale %s (%s)" % [str(h["quien"]), str(h["detalle"])]
			color = Tema.SUAVE

	var caja_pos := CenterContainer.new()
	caja_pos.custom_minimum_size = Vector2(16, 0)
	var punto := Panel.new()
	punto.custom_minimum_size = Vector2(8, 8)
	var e := StyleBoxFlat.new()
	e.bg_color = color
	e.corner_radius_top_left = 4
	e.corner_radius_top_right = 4
	e.corner_radius_bottom_left = 4
	e.corner_radius_bottom_right = 4
	punto.add_theme_stylebox_override("panel", e)
	caja_pos.add_child(punto)
	dentro.add_child(caja_pos)

	var l := Label.new()
	l.text = texto
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.add_theme_color_override("font_color", color)
	dentro.add_child(l)

	var club := Componentes.celda(str(h["equipo"]), 180, Tema.SUAVE)
	club.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dentro.add_child(club)
	return fila


## De id de jugador a nombre, buscando en los dos planteles del partido.
func _nombre_de_id(r: Dictionary, id: int) -> String:
	for nombre in [str(r.get("local", "")), str(r.get("visitante", ""))]:
		var equipo := _equipo_por_nombre(nombre)
		if equipo == null:
			continue
		var j := _buscar_jugador_por_id(equipo, id)
		if not j.is_empty():
			return _nombre_jugador(j)
	return "?"


## Empezar de cero de verdad. "Borrar guardado" solo borraba el ARCHIVO y
## dejaba la partida corriendo igual, asi que quien queria arrancar una
## nueva tocaba borrar, no pasaba nada visible, y con razon concluia que
## el juego estaba roto.
func _on_partida_nueva() -> void:
	GameState.partida_nueva()
	# Todo lo que la UI tenia en la mano apunta a jugadores y clubes del
	# mundo viejo, que ya no existen.
	plantel_elegido = -1
	ficha_jugador_id = -1
	resultados_mercado = []
	filtros_mercado = BusquedaMercado.filtros_vacios()
	_refrescar_historial_partidos()
	_refrescar_formacion()
	_refrescar_plantel()
	_refrescar_tabla()
	_refrescar_economia()
	_refrescar_cantera()
	_refrescar_noticias()
	_refrescar_instalaciones()
	_refrescar_renovaciones()
	_refrescar_partida_guardado()
	_mostrar_seccion("jugar")


func _on_borrar_partida() -> void:
	GameState.borrar_partida()
	# Se comprueba que HAYA desaparecido en vez de dar por hecho que si.
	if GameState.hay_partida_guardada():
		label_partida_estado.text = "No se pudo borrar el archivo guardado."
	else:
		label_partida_estado.text = "Guardado borrado. Tu partida en curso sigue igual."
	_refrescar_partida_guardado()


## Texto de cierre de temporada, con la posicion final — se usa tanto al
## jugar la ultima fecha a mano como al usar el boton de debug que simula
## el resto de la temporada de una.
func _texto_cierre_temporada() -> String:
	var pos: Dictionary = GameState.ultima_posicion_final
	return "\n¡Termino la temporada! Quedaste %d° de %d en la Division %d. Ahora en Division %d." % [
		pos.get("posicion", 0), pos.get("total", 0), pos.get("division", 0), GameState.division_jugador + 1
	]


func _on_jugar_fecha() -> void:
	if (not GameState.hay_fecha_pendiente() and not GameState.hay_partido_de_copa_hoy()
			and not GameState.hay_partido_internacional_hoy()
			and not GameState.hay_partido_de_playoff_hoy()):
		return
	# Ningun lesionado ni suspendido sale a la cancha. Si hay alguno en el
	# once, el partido espera a que se resuelva (ver el modal de
	# alineacion): o lo arregla el juego, o lo arregla el jugador en
	# Formacion y vuelve a darle a Jugar.
	if _avisar_alineacion():
		return
	await _jugar_el_partido_de_hoy()


## Juega el partido y muestra directamente el resumen final, dejando la
## cancha congelada en el último fotograma detrás del cartel.
func _on_saltar_a_resultado() -> void:
	if (not GameState.hay_fecha_pendiente() and not GameState.hay_partido_de_copa_hoy()
			and not GameState.hay_partido_internacional_hoy()
			and not GameState.hay_partido_de_playoff_hoy()):
		return
	if _avisar_alineacion():
		return
	# Resolver sin abrir la vista ni reproducir fotogramas.
	await _jugar_el_partido_de_hoy(false)
	# El resultado queda como modal sobre la portada actualizada.
	_mostrar_seccion("jugar")
	_mostrar_resumen_partido()


## Hoy toca liga o toca copa, nunca las dos: el calendario no avanza
## mientras haya un cruce de copa esperando (GameState.avanzar_un_dia).
## Existe para que el modal de alineacion no tenga que saber cual es.
func _jugar_el_partido_de_hoy(mostrar_partido: bool = true) -> void:
	# Los dos await dejan que Godot dibuje el aviso antes de lanzar la
	# simulacion. La simulacion corre en otro hilo: ver _en_segundo_plano.
	var texto_previo := ""
	var hay_boton := is_instance_valid(boton_jugar_partido)
	if hay_boton:
		texto_previo = boton_jugar_partido.text
		boton_jugar_partido.text = TEXTO_CARGANDO_PARTIDO
		boton_jugar_partido.disabled = true
	await get_tree().process_frame
	await get_tree().process_frame
	if GameState.hay_partido_de_copa_hoy():
		await _jugar_copa_ya(mostrar_partido)
	elif GameState.hay_partido_internacional_hoy():
		await _jugar_internacional_ya(mostrar_partido)
	elif GameState.hay_partido_de_playoff_hoy():
		await _jugar_playoff_ya(mostrar_partido)
	else:
		await _jugar_fecha_ya(mostrar_partido)
	# El boton puede haber muerto durante el partido: _refrescar_portada
	# reconstruye la caja entera. Por eso se revalida antes de tocarlo.
	if hay_boton and is_instance_valid(boton_jugar_partido):
		boton_jugar_partido.text = texto_previo
		boton_jugar_partido.disabled = false


## Corre `trabajo` en otro hilo y espera a que termine sin congelar la
## pantalla. Una fecha simula 100 partidos: en la PC tarda 2,2 s y en el
## celular varias veces más. En el hilo principal la app quedaba trabada
## todo ese tiempo, y Android la marca como "no responde" a los 5 s.
##
## Mientras corre, un velo toma todos los toques. GameState no está
## protegido contra dos hilos a la vez: si el usuario abre otra pantalla
## y la UI lee el plantel mientras la simulación lo modifica, la lectura
## puede ver datos a medio escribir.
func _en_segundo_plano(trabajo: Callable) -> void:
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.0, 0.35)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aviso := Label.new()
	aviso.text = TEXTO_CARGANDO_PARTIDO
	aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aviso.grow_vertical = Control.GROW_DIRECTION_BOTH
	velo.add_child(aviso)
	add_child(velo)
	var tarea := WorkerThreadPool.add_task(trabajo, true, "Simular fecha")
	while not WorkerThreadPool.is_task_completed(tarea):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(tarea)
	velo.queue_free()


## El cruce de copa, ya con el once en orden. Mismo recorrido que el de
## liga: se juega, se refresca todo y se abre la pantalla del partido.
func _jugar_copa_ya(mostrar_partido: bool = true) -> void:
	if not GameState.hay_partido_de_copa_hoy():
		return
	await _en_segundo_plano(GameState.jugar_partido_de_copa)
	_despues_del_partido_de_torneo(mostrar_partido)


## El partido internacional de hoy: una fecha de la fase de liga, la
## previa, el playoff o una ronda del knockout. Mismo recorrido que el
## cruce de copa.
func _jugar_internacional_ya(mostrar_partido: bool = true) -> void:
	if not GameState.hay_partido_internacional_hoy():
		return
	await _en_segundo_plano(GameState.jugar_partido_internacional)
	_despues_del_partido_de_torneo(mostrar_partido)


## El playoff de ascenso, despues de la ultima fecha. Mismo recorrido que
## el cruce de copa.
func _jugar_playoff_ya(mostrar_partido: bool = true) -> void:
	if not GameState.hay_partido_de_playoff_hoy():
		return
	await _en_segundo_plano(GameState.jugar_partido_de_playoff)
	_despues_del_partido_de_torneo(mostrar_partido)


func _despues_del_partido_de_torneo(mostrar_partido: bool = true) -> void:
	_refrescar_historial_partidos()
	_refrescar_plantel()
	_refrescar_portada_si_visible()
	_refrescar_barra_contexto()
	if mostrar_partido and not GameState.ultimos_fotogramas.is_empty():
		_mostrar_partido_animado()


## El partido en si, ya con el once en orden.
func _jugar_fecha_ya(mostrar_partido: bool = true) -> void:
	if not GameState.hay_fecha_pendiente():
		return

	var temporada_antes := GameState.temporada_actual
	await _en_segundo_plano(GameState.jugar_siguiente_fecha)

	_refrescar_historial_partidos()
	var cerro_temporada: bool = GameState.temporada_actual != temporada_antes

	_refrescar_tabla()
	_refrescar_plantel()
	_refrescar_portada_si_visible()
	_refrescar_barra_contexto()

	# El partido se VE. Antes se simulaba en silencio, te aparecia el
	# marcador ya hecho y recien despues podias pedir la repeticion, que es
	# como leer el diario antes de mirar el partido. Ahora se abre solo, y
	# adentro estan los controles para acelerar (x1 a x16) o saltar directo
	# al resultado.
	if mostrar_partido and not GameState.ultimos_fotogramas.is_empty():
		_mostrar_partido_animado()
	# El resumen va DESPUES del partido animado: primero se mira el ultimo
	# partido del año y despues se cierra el año.
	if mostrar_partido and cerro_temporada:
		_mostrar_resumen_temporada()


func _on_simular_temporada() -> void:
	if not GameState.hay_fecha_pendiente():
		return

	# Simular una temporada entera bloquea el hilo unos segundos. Los dos
	# await dejan que Godot dibuje el aviso ANTES de empezar a laburar:
	# sin ellos la pantalla se congela sin explicacion.
	_mostrar_novedades("Simulando la temporada, esto tarda unos segundos...")
	await get_tree().process_frame
	await get_tree().process_frame

	var temporada_antes := GameState.temporada_actual
	GameState.simular_temporada_completa()
	dialogo_novedades.hide()

	if GameState.temporada_actual != temporada_antes:
		_mostrar_resumen_temporada()

	# A diferencia de "jugar fecha", esto simula muchas fechas de una — no
	# tiene sentido mostrar el log/animado de sólo el último partido
	# jugado, como si fuera el único que pasó.
	GameState.ultimo_resultado = {}
	GameState.ultimo_log = []
	GameState.ultimos_eventos = []
	_refrescar_historial_partidos()

	_refrescar_tabla()
	_refrescar_plantel()
	_refrescar_portada_si_visible()


func _mostrar_plantel() -> void:
	_ocultar_todos()
	paneles["plantel"].visible = true
	# Los desplegables se sincronizan aca: son del equipo, no de la
	# pantalla, y pueden haber cambiado desde otro lado.
	if option_estilo != null:
		option_estilo.select(maxi(Estilos.LISTA.find(GameState.equipo_jugador.estilo), 0))
	if option_cambios != null:
		option_cambios.select(maxi(
			OPCIONES_CAMBIOS.find(GameState.equipo_jugador.config_cambios), 0))
	if check_rotacion != null:
		check_rotacion.set_pressed_no_signal(GameState.equipo_jugador.rotacion_automatica)
	_refrescar_plantel()


func _mostrar_tabla() -> void:
	_ocultar_todos()
	paneles["tabla"].visible = true
	_refrescar_tabla()


## Salir del partido devuelve al CLUB, que es desde donde se sigue
## jugando: ahi estan "Avanzar un dia" e "Ir al proximo partido".
##
## Antes iba al panel Partido y, como no pasaba por _mostrar_seccion, el
## riel seguia marcando Club: se veia el boton Club resaltado con el
## contenido de Partido adelante, y tocar Club parecia no hacer nada
## porque ya estaba "elegido".
func _volver_al_club() -> void:
	_mostrar_seccion("jugar")


func _mostrar_partido() -> void:
	_ocultar_todos()
	paneles["partido"].visible = true
	var idx_actual := Estilos.LISTA.find(GameState.equipo_jugador.estilo)
	option_estilo.select(max(idx_actual, 0))
	var idx_cambios := OPCIONES_CAMBIOS.find(GameState.equipo_jugador.config_cambios)
	option_cambios.select(max(idx_cambios, 0))
	check_rotacion.set_pressed_no_signal(GameState.equipo_jugador.rotacion_automatica)
	_refrescar_portada_si_visible()


## Despues de jugar, la portada muestra el estado nuevo del club. Si no
## esta a la vista, se arma sola la proxima vez que se abre.
func _refrescar_portada_si_visible() -> void:
	if paneles.has("portada") and paneles["portada"].visible:
		_refrescar_portada()


## §8.6.3/§8.6.5: le muestra al jugador con qué rival juega la próxima
## fecha y cómo pega el choque de estilos, para que elija táctica con
## información en vez de a ciegas.
## Si el proximo partido lo juega de local.
func _juega_de_local() -> bool:
	if not GameState.hay_fecha_pendiente():
		return false
	var liga := GameState.liga_jugador()
	for partido in liga.fixture[GameState.fecha_actual]:
		if liga.equipos[partido[0]] == GameState.equipo_jugador:
			return true
	return false


## Pasa el dia (o los dias, hasta el partido) y CUENTA que paso.
##
## Contar es la mitad del punto: un boton que avanza el dia sin decir nada
## seria un boton que no informa. Y el salto al proximo partido frena en
## cuanto pasa algo —una respuesta de un club, una lesion, una noticia—
## porque saltar a ciegas seria volver al problema que esto viene a
## resolver: enterarse de todo junto cuando ya no se puede hacer nada.
func _avanzar_dias(hasta_el_partido: bool) -> void:
	var temporada_antes := GameState.temporada_actual
	var novedades: Array = GameState.avanzar_hasta_el_partido() if hasta_el_partido 		else GameState.avanzar_un_dia()
	_refrescar_portada()
	_refrescar_plantel()
	_refrescar_mercado()
	_refrescar_portada_si_visible()
	_refrescar_barra_contexto()
	# El cierre de temporada tiene su propia pantalla: el cartel de
	# novedades con las 225 lineas del cierre adentro era justamente lo que
	# trababa el juego. Lo que no entra sigue estando en Noticias.
	if GameState.temporada_actual != temporada_antes:
		_mostrar_resumen_temporada()
		return
	if not novedades.is_empty():
		_mostrar_novedades("%s

%s" % [
			Calendario.texto_largo(GameState.dia_absoluto),
			_texto_de_novedades(novedades)])


## Cuantas novedades entran en el cartel antes de mandar el resto a
## Noticias. El cierre de temporada genera 225 lineas —los 200 clubes de
## la piramide fichando, liberando y subiendo juveniles— y un cartel con
## eso adentro no se lee: es una pared de texto donde lo tuyo esta perdido.
const MAX_NOVEDADES := 24


## El texto del cartel. Lo TUYO primero: el cierre de temporada mete al
## final las noticias de rutina de los 200 clubes, y como se leen de la
## mas nueva a la mas vieja, terminaban arriba y tu posicion final, tu
## objetivo y tu ascenso quedaban debajo de doscientas lineas de "un MCO
## queda libre de un club que no conoces".
func _texto_de_novedades(novedades: Array) -> String:
	var mio: String = GameState.equipo_jugador.nombre
	var mias := []
	var resto := []
	for n in novedades:
		if str(n).contains(mio):
			mias.append(str(n))
		else:
			resto.append(str(n))

	var lineas := []
	for n in mias:
		lineas.append("  ·  %s" % n)
	var cupo: int = maxi(MAX_NOVEDADES - lineas.size(), 0)
	for i in range(mini(cupo, resto.size())):
		lineas.append("  ·  %s" % resto[i])
	var quedaron: int = resto.size() - mini(cupo, resto.size())
	if quedaron > 0:
		lineas.append("")
		lineas.append("Y %d novedad(es) mas del resto de la piramide, en Mas › Noticias." % quedaron)
	return "
".join(lineas)


## En que puesto va un club en la tabla de SU division. La division se
## nombra solo cuando no es la del jugador: en la Copa Nacional el rival
## puede ser de otra, y ahi el puesto solo enganaria — un 2° de la
## Division 3 es muchisimo mas equipo que un 2° de la Division 10.
func _texto_posicion(club: Team) -> String:
	var division: int = GameState.division_de(club)
	var tabla: Array = GameState.piramide.divisiones[division].tabla_ordenada()
	var puesto: int = tabla.find(club.nombre) + 1
	if puesto <= 0:
		return "sin puesto"
	if division == GameState.division_jugador:
		return "%d°" % puesto
	return "%d° · Div. %d" % [puesto, division + 1]


func _proximo_rival() -> Team:
	var liga := GameState.liga_jugador()
	if not GameState.hay_fecha_pendiente():
		return null
	var fecha: Array = liga.fixture[GameState.fecha_actual]
	for partido in fecha:
		var home: Team = liga.equipos[partido[0]]
		var away: Team = liga.equipos[partido[1]]
		if home == GameState.equipo_jugador:
			return away
		if away == GameState.equipo_jugador:
			return home
	return null


## Lo que se sabe del proximo rival. Devuelve el texto en vez de escribir
## en un label: lo pinta la portada, que es donde se decide con que estilo
## salir a jugarle.
## `rival` llega de afuera y no se busca aca: el de copa no sale del
## fixture de la liga (ver GameState.rival_de_copa).
func _texto_informe_rival(rival: Team, de_local: bool) -> String:
	if rival == null:
		return ""
	var dt_texto := "DT sin datos"
	if not rival.dt.is_empty():
		dt_texto = "DT %d/10 (%s)" % [rival.dt["nivel"], rival.dt["rasgo"]]
	var clasico_texto := ""
	if Rivalidad.es_clasico(GameState.equipo_jugador, rival):
		clasico_texto = "  ·  CLÁSICO"
	return "%s  ·  Estilo %s  ·  %s%s" % [
		"Local" if de_local else "Visitante", rival.estilo, dt_texto, clasico_texto]


func _on_estilo_seleccionado(idx: int) -> void:
	GameState.equipo_jugador.estilo = Estilos.LISTA[idx]
	_refrescar_familiaridad(GameState.equipo_jugador)
	_refrescar_portada_si_visible()


func _on_config_cambios_seleccionado(idx: int) -> void:
	GameState.equipo_jugador.config_cambios = OPCIONES_CAMBIOS[idx]


func _mostrar_partido_animado() -> void:
	_ocultar_todos()
	paneles["partido_animado"].visible = true
	if resumen_partido != null:
		resumen_partido.visible = false
	var r: Dictionary = GameState.ultimo_resultado
	# El estilo del rival ya no hace falta acá: dejó de ser un ajuste
	# visual y pasó a mover a los jugadores dentro del propio motor
	# (MotorEspacial._objetivo_sin_pelota), así que llega en las
	# coordenadas de cada fotograma.
	#
	# GameState guarda el resultado con los NOMBRES de los equipos, pero la
	# vista necesita los Team: las claves de los fotogramas se resuelven a
	# apellidos con el plantel, y la textura de la cancha sale de la
	# calidad de cancha del local. Se buscan en toda la piramide y no solo
	# en la liga del jugador: en la Copa Nacional el rival puede ser de
	# cualquiera de las diez divisiones.
	var local: Team = _equipo_por_nombre(str(r["local"]))
	var visitante: Team = _equipo_por_nombre(str(r["visitante"]))
	if local == null or visitante == null:
		return
	var colores := ColoresClub.par_equipos(local, visitante)
	vista_partido.iniciar(
		GameState.ultimos_fotogramas, colores[0], colores[1],
		local.nombre, visitante.nombre,
		VistaPartido.construir_nombres(local, visitante),
		VistaCancha.nivel_estadio_desde_calidad(local.calidad_cancha),
		local.color_short, visitante.color_short,
		_nombre_marcador(local), _nombre_marcador(visitante),
		local.identidad_visual(), visitante.identidad_visual())
	vista_partido.velocidad = velocidad_partido_elegida


func _equipo_por_nombre(nombre: String) -> Team:
	for e in GameState.liga_jugador().equipos:
		if e.nombre == nombre:
			return e
	for liga in GameState.piramide.divisiones:
		for e in liga.equipos:
			if e.nombre == nombre:
				return e
	return null


func _nombre_marcador(equipo: Team) -> String:
	if equipo == null:
		return ""
	var corto := equipo.abreviacion.strip_edges()
	return corto if corto != "" else equipo.nombre


func _mostrar_economia() -> void:
	_ocultar_todos()
	paneles["economia"].visible = true
	_refrescar_economia()


func _mostrar_mercado() -> void:
	_ocultar_todos()
	paneles["mercado"].visible = true
	label_mercado_estado.text = ""
	# La solapa que estaba abierta y no siempre "jugadores": se vuelve al
	# mercado desde la ficha, y si saliste de Investigaciones aterrizabas
	# en otra solapa con la lista sin refrescar detras.
	_mostrar_solapa_mercado(solapa_mercado_actual)


func _mostrar_libres() -> void:
	_ocultar_todos()
	paneles["libres"].visible = true
	label_libres_estado.text = ""
	_refrescar_libres()


func _mostrar_traspaso() -> void:
	_ocultar_todos()
	paneles["traspaso"].visible = true
	_refrescar_traspaso()


func _mostrar_prestamos() -> void:
	_ocultar_todos()
	paneles["prestamos"].visible = true
	label_prestamos_estado.text = ""
	_refrescar_prestamos()


func _mostrar_cedidos() -> void:
	_ocultar_todos()
	paneles["cedidos"].visible = true
	_refrescar_cedidos()


func _mostrar_instalaciones() -> void:
	_ocultar_todos()
	paneles["instalaciones"].visible = true
	label_instalaciones_estado.text = ""
	_refrescar_instalaciones()


func _mostrar_renovaciones() -> void:
	_ocultar_todos()
	paneles["renovaciones"].visible = true
	label_renovaciones_estado.text = ""
	_refrescar_renovaciones()


func _mostrar_seleccion() -> void:
	_ocultar_todos()
	paneles["seleccion"].visible = true
	_refrescar_seleccion()


func _mostrar_cantera() -> void:
	_ocultar_todos()
	paneles["cantera"].visible = true
	_refrescar_cantera()


func _mostrar_noticias() -> void:
	_ocultar_todos()
	paneles["noticias"].visible = true
	_refrescar_noticias()


func _mostrar_partida_panel() -> void:
	_ocultar_todos()
	paneles["partida_guardado"].visible = true
	label_partida_estado.text = ""
	_refrescar_partida_guardado()


# ---------------------------------------------------------------------------
# Scroll con el dedo
# ---------------------------------------------------------------------------
## Arrastrar en CUALQUIER punto de una lista la desliza.
##
## El ScrollContainer de Godot trae scroll tactil propio, pero acá no se
## puede confiar en el: depende de que control se coma el evento del dedo
## antes de que llegue al ScrollContainer. Medido inyectando eventos de
## dedo de verdad, con un arrastre de 200 px desde el medio de la lista:
##
##   plantel  0 -> 476 px   (scrollea, pero se pasa 2,4 veces)
##   tabla    0 ->   0 px   (no scrollea)
##
## O sea que en una pantalla anda de mas y en la otra no anda, y en el
## telefono eso quiere decir que hay listas cuya unica forma de bajar es
## acertarle a la barrita, que con el dedo es imposible.
##
## Por eso se maneja acá, en _input: llega ANTES que el ruteo de la GUI,
## asi que da igual quien se lo hubiera comido despues, y el arrastre
## mueve la lista exactamente lo que se movio el dedo — las dos pantallas
## dan 200 -> 200.
##
## Umbral en pixeles antes de que el gesto cuente como scroll. Por debajo
## es un toque y tiene que llegar al boton que haya abajo.
const UMBRAL_ARRASTRE := 12.0

var _scroll_arrastrado: ScrollContainer = null
var _scroll_ultimo := Vector2.ZERO
var _scroll_recorrido := 0.0
var _scroll_activo := false


func _input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		if evento.pressed:
			_scroll_arrastrado = _scroll_bajo(self, evento.position)
			_scroll_ultimo = evento.position
			_scroll_recorrido = 0.0
			_scroll_activo = false
		else:
			_scroll_arrastrado = null
			_scroll_activo = false
		return
	if not (evento is InputEventScreenDrag) or _scroll_arrastrado == null:
		return
	if not is_instance_valid(_scroll_arrastrado):
		_scroll_arrastrado = null
		return

	var delta: Vector2 = evento.position - _scroll_ultimo
	_scroll_ultimo = evento.position
	_scroll_recorrido += delta.length()
	if not _scroll_activo:
		if _scroll_recorrido < UMBRAL_ARRASTRE:
			return
		_scroll_activo = true
	_scroll_arrastrado.scroll_vertical -= int(delta.y)
	_scroll_arrastrado.scroll_horizontal -= int(delta.x)
	# Consumido: mientras se arrastra, los botones de abajo no ven nada.
	get_viewport().set_input_as_handled()


## El ScrollContainer mas PROFUNDO que este debajo de ese punto y que
## tenga algo para scrollear. El mas profundo y no el primero porque hay
## pantallas con un scroll adentro de otro (el cuadro de una copa scrollea
## a lo ancho adentro de la pantalla que scrollea a lo alto).
func _scroll_bajo(nodo: Node, punto: Vector2) -> ScrollContainer:
	for i in range(nodo.get_child_count() - 1, -1, -1):
		var hijo: Node = nodo.get_child(i)
		if hijo is CanvasItem and not (hijo as CanvasItem).visible:
			continue
		var encontrado := _scroll_bajo(hijo, punto)
		if encontrado != null:
			return encontrado
	if nodo is ScrollContainer and (nodo as ScrollContainer).is_visible_in_tree():
		var sc := nodo as ScrollContainer
		if not Rect2(sc.get_global_rect()).has_point(punto):
			return null
		var hay_alto: bool = sc.get_v_scroll_bar().max_value > sc.size.y + 1.0
		var hay_ancho: bool = sc.get_h_scroll_bar().max_value > sc.size.x + 1.0
		if hay_alto or hay_ancho:
			return sc
	return null


## La zona muerta del scroll tactil PROPIO de Godot. Queda alta a
## proposito: el scroll con el dedo lo maneja _input (ver UMBRAL_ARRASTRE)
## y esto es solo para que el del motor no se despierte tambien y termine
## scrolleando dos veces el mismo gesto.
const ZONA_MUERTA_SCROLL := 30


## Recorre todo lo construido y lo deja usable con el dedo. Se hace de una
## pasada al final de _ready() en vez de recordar cada propiedad en cada
## panel: hay diez ScrollContainer repartidos por la UI y olvidarse de uno
## deja esa pantalla sin scroll, que es un bug silencioso y molesto.
func _ajustar_para_tactil(nodo: Node) -> void:
	if nodo is ScrollContainer:
		nodo.scroll_deadzone = ZONA_MUERTA_SCROLL
	elif nodo is RichTextLabel:
		# PASS y no STOP: el texto sigue recibiendo el toque (los nombres
		# del plantel son enlaces) pero ademas lo deja pasar al scroll de
		# arriba, asi se puede deslizar arrastrando sobre la lista.
		nodo.mouse_filter = Control.MOUSE_FILTER_PASS
	for hijo in nodo.get_children():
		_ajustar_para_tactil(hijo)


## §UI: el armazón conserva las secciones y subsolapas originales. Solo cambia
## su tratamiento visual; ningún destino se mueve de lugar.
##
## Al costado y no abajo porque el juego es apaisado: el alto son 648 px
## lógicos y es lo escaso, mientras que a lo ancho sobra. Una barra abajo
## se comería justo el espacio que necesitan las listas.
##
## Cada sección agrupa las pantallas que se usan juntas. Los paneles no se
## tocan: siguen siendo los mismos nodos en `paneles`, solo cambia por
## dónde se llega.
const SECCIONES := [
	{"clave": "jugar", "nombre": "Jugar", "paneles": []},
	{"clave": "equipo", "nombre": "Equipo", "paneles": [
		["plantel", "Plantel"], ["formacion", "Formacion"],
		["roles", "Roles"], ["entrenamiento", "Entrenamiento"],
		["jugadas", "Jugadas"]]},
	{"clave": "club", "nombre": "Club", "paneles": [
		["renovaciones", "Renovaciones"], ["instalaciones", "Instalaciones"],
		["cedidos", "Cedidos"], ["cantera", "Cantera"]]},
	{"clave": "finanzas", "nombre": "Economia", "paneles": [
		["economia", "Presupuesto"], ["sponsors", "Sponsors"]]},
	{"clave": "partido", "nombre": "Liga", "paneles": [
		["tabla", "Tabla"], ["jugadores_liga", "Jugadores"],
		["historial", "Historial"], ["historia_clubes", "Clubes"]]},
	{"clave": "copas", "nombre": "Copas", "paneles": [
		["copa_interna", "Interna"], ["copa_rey", "Rey"],
		["copa_campeones", "Campeones"], ["copa_guerreros", "Guerreros"],
		["copa_emergentes", "Emergentes"], ["palmares", "Palmarés"]]},
	{"clave": "mercado", "nombre": "Mercado", "paneles": [
		["mercado", "Mercado"], ["libres", "Libres"], ["traspaso", "Traspaso"],
		["prestamos", "Cesion"]]},
	{"clave": "mas", "nombre": "Mas", "paneles": [
		["noticias", "Noticias"], ["vitrina", "Vitrina"],
		["seleccion", "Seleccion"], ["laboratorio", "Laboratorio"],
		["partida", "Partida"], ["opciones", "Opciones"]]},
]

var seccion_actual: String = "jugar"
var panel_de_seccion_actual: String = ""
var botones_seccion: Dictionary = {}
var barra_subsolapas: HBoxContainer
var label_barra_club: Label
var label_barra_posicion: Label
var label_barra_plata: Label
var label_barra_fecha: Label
var label_barra_mercado: Label
var escudo_barra


func _construir_riel(padre: HBoxContainer) -> void:
	var marco := PanelContainer.new()
	marco.custom_minimum_size = Vector2(190, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.RIEL
	estilo.border_width_right = 4
	estilo.border_color = Tema.BORDE_RIEL
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 20
	estilo.content_margin_bottom = 14
	marco.add_theme_stylebox_override("panel", estilo)
	padre.add_child(marco)

	var riel := VBoxContainer.new()
	riel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marco.add_child(riel)

	var marca_caja := VBoxContainer.new()
	marca_caja.add_theme_constant_override("separation", -6)
	riel.add_child(marca_caja)
	for parte in [["SUPER", Tema.TEXTO], ["POCKET", Tema.AMBAR], ["STARS", Tema.TEXTO]]:
		var marca := Label.new()
		marca.text = str(parte[0])
		Tema.numero(marca, 19, parte[1])
		marca_caja.add_child(marca)
	var aire_marca := Control.new()
	aire_marca.custom_minimum_size.y = 22
	riel.add_child(aire_marca)

	for seccion in SECCIONES:
		var clave := str(seccion["clave"])
		var btn := Button.new()
		btn.text = str(seccion["nombre"])
		btn.custom_minimum_size = Vector2(0, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tema.boton_riel(btn)
		btn.pressed.connect(func(): _mostrar_seccion(clave))
		riel.add_child(btn)
		botones_seccion[clave] = btn
	var separador := Control.new()
	separador.size_flags_vertical = Control.SIZE_EXPAND_FILL
	riel.add_child(separador)


## La barra de contexto: quién sos, dónde estás y cuánta plata tenés. Antes
## nada de esto se veía sin entrar a tres pantallas distintas.
func _construir_barra_contexto(padre: VBoxContainer) -> void:
	var marco := PanelContainer.new()
	marco.custom_minimum_size.y = 70
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.BARRA
	estilo.border_width_bottom = 3
	estilo.border_color = Tema.BORDE
	estilo.content_margin_left = 24
	estilo.content_margin_right = 24
	estilo.content_margin_top = 10
	estilo.content_margin_bottom = 10
	marco.add_theme_stylebox_override("panel", estilo)
	padre.add_child(marco)

	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 18)
	marco.add_child(barra)

	escudo_barra = ESCUDO_CLUB_SCRIPT.new()
	escudo_barra.custom_minimum_size = Vector2(42, 42)
	escudo_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.add_child(escudo_barra)

	var meta_club := VBoxContainer.new()
	meta_club.add_theme_constant_override("separation", 0)
	meta_club.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.add_child(meta_club)

	label_barra_club = Label.new()
	Tema.numero(label_barra_club, Tema.TAM_BASE, Tema.TEXTO)
	meta_club.add_child(label_barra_club)

	label_barra_posicion = Label.new()
	label_barra_posicion.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_barra_posicion.add_theme_color_override("font_color", Tema.SUAVE)
	meta_club.add_child(label_barra_posicion)

	# Solo aparece con el mercado abierto: fuera de la ventana no se puede
	# ofertar ni te ofertan, y eso hay que verlo sin entrar a Mercado.
	label_barra_mercado = Label.new()
	Tema.numero(label_barra_mercado, Tema.TAM_CHICO, Tema.VERDE)
	label_barra_mercado.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.add_child(label_barra_mercado)

	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(espacio)

	var dato_fichajes := VBoxContainer.new()
	dato_fichajes.add_theme_constant_override("separation", 0)
	dato_fichajes.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dato_fichajes.add_child(Tema.etiqueta_seccion("Fichajes"))
	label_barra_plata = Label.new()
	Tema.numero(label_barra_plata, Tema.TAM_BASE, Tema.VERDE)
	dato_fichajes.add_child(label_barra_plata)
	barra.add_child(dato_fichajes)

	var dato_fecha := VBoxContainer.new()
	dato_fecha.add_theme_constant_override("separation", 0)
	dato_fecha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dato_fecha.add_child(Tema.etiqueta_seccion("Fecha"))
	label_barra_fecha = Label.new()
	Tema.numero(label_barra_fecha, Tema.TAM_BASE, Tema.TEXTO)
	dato_fecha.add_child(label_barra_fecha)
	barra.add_child(dato_fecha)

	# Un respiro al final: sin esto el ultimo dato de la barra queda
	# pegado al borde derecho de la pantalla y se ve cortado. Se veia en
	# cualquier captura, con la fecha partida al medio.
	var margen_derecho := Control.new()
	margen_derecho.custom_minimum_size = Vector2(14, 0)
	barra.add_child(margen_derecho)


func _refrescar_barra_contexto() -> void:
	if label_barra_club == null:
		return
	var equipo := GameState.equipo_jugador
	if escudo_barra != null:
		escudo_barra.configurar(equipo.escudo_forma, equipo.logo_forma,
			equipo.color_escudo, equipo.color_logo)
	label_barra_club.text = equipo.nombre
	var tabla := GameState.liga_jugador().tabla_ordenada()
	var puesto: int = tabla.find(equipo.nombre) + 1
	# Las fechas jugadas y las que son en total: sin eso, el puesto no
	# dice si va bien o si todavia no arranco la temporada.
	label_barra_posicion.text = "Division %d  ·  %d° de %d  ·  %d de %d fechas" % [
		GameState.division_jugador + 1, puesto, tabla.size(),
		GameState.fecha_actual, GameState.liga_jugador().fixture.size()]
	if label_barra_mercado != null:
		var dias := GameState.dias_de_mercado()
		label_barra_mercado.visible = dias >= 0
		# Con la cuenta regresiva: sin ella el ultimo dia te agarra sin
		# avisar y perdes la negociacion que tenias en curso.
		label_barra_mercado.text = "   PERIODO DE TRANSFERENCIAS  ·  %s" % (
			"ultimo dia" if dias == 0 else "%d dias" % dias)
	label_barra_plata.text = Economia.formato_dinero(equipo.caja["fichajes"])
	# La fecha del calendario, no el numero de jornada: es el dato que se
	# mira todo el tiempo desde que los dias pasan de a uno.
	var fecha_actual := Calendario.fecha(GameState.dia_absoluto)
	label_barra_fecha.text = "%s/%d" % [Calendario.texto_corto(
		GameState.dia_absoluto), int(fecha_actual["year"])]


## `panel_destino` elige la subsolapa de llegada. Sin eso, un boton que lleva a un
## lugar puntual aterrizaba en la primera subsolapa de la seccion.
func _mostrar_seccion(clave: String, panel_destino: String = "") -> void:
	seccion_actual = clave
	for c in botones_seccion:
		Tema.seleccionado(botones_seccion[c], c == clave)

	for hijo in barra_subsolapas.get_children():
		hijo.queue_free()

	var seccion := {}
	for s in SECCIONES:
		if str(s["clave"]) == clave:
			seccion = s
	var subpaneles: Array = seccion.get("paneles", [])

	if clave == "jugar":
		_mostrar_portada()
		return

	for entrada in subpaneles:
		var btn := Button.new()
		btn.text = str(entrada[1])
		var panel := str(entrada[0])
		btn.set_meta("panel", panel)
		btn.pressed.connect(func(): _mostrar_panel_de_seccion(panel))
		barra_subsolapas.add_child(btn)
	if panel_destino != "":
		_mostrar_panel_de_seccion(panel_destino)
	elif not subpaneles.is_empty():
		_mostrar_panel_de_seccion(str(subpaneles[0][0]))


## Muestra un panel y marca su subsolapa. Reusa los `_mostrar_*` que ya
## existian para que cada panel siga refrescandose como siempre.
func _mostrar_panel_de_seccion(clave: String) -> void:
	var metodos := {
		"plantel": "_mostrar_plantel", "formacion": "_mostrar_formacion",
		"entrenamiento": "_mostrar_entrenamiento",
		"jugadas": "_mostrar_jugadas",
		"cantera": "_mostrar_cantera", "instalaciones": "_mostrar_instalaciones",
		"renovaciones": "_mostrar_renovaciones", "cedidos": "_mostrar_cedidos",
		"roles": "_mostrar_roles",
		"tabla": "_mostrar_tabla", "jugadores_liga": "_mostrar_jugadores_liga",
		"historial": "_mostrar_historial_partidos",
		"copa_interna": "_mostrar_copa_interna", "copa_rey": "_mostrar_copa_rey",
		"copa_campeones": "_mostrar_copa_campeones",
		"copa_guerreros": "_mostrar_copa_guerreros",
		"copa_emergentes": "_mostrar_copa_emergentes",
		"mercado": "_mostrar_mercado", "libres": "_mostrar_libres",
		"traspaso": "_mostrar_traspaso",
		"prestamos": "_mostrar_prestamos", "economia": "_mostrar_economia",
		"noticias": "_mostrar_noticias", "vitrina": "_mostrar_vitrina",
		"historia_clubes": "_mostrar_historia_clubes", "palmares": "_mostrar_palmares",
		"laboratorio": "_mostrar_laboratorio",
		"sponsors": "_mostrar_sponsors", "seleccion": "_mostrar_seleccion",
		"partida": "_mostrar_partida_panel",
		"opciones": "_mostrar_opciones",
	}
	if metodos.has(clave):
		call(str(metodos[clave]))
	panel_de_seccion_actual = clave
	for hijo in barra_subsolapas.get_children():
		if hijo is Button:
			Tema.seleccionado(hijo, str(hijo.get_meta("panel", "")) == clave)
	_refrescar_barra_contexto()


## La PORTADA: la pantalla que contesta "que hago ahora".
##
## Antes el juego abria en Plantel, que no dice nada de lo que hay
## pendiente: las ofertas por responder se perdian en el feed de noticias
## y los informes terminados no avisaban en ningun lado.
func _mostrar_portada() -> void:
	_ocultar_todos()
	paneles["portada"].visible = true
	_refrescar_portada()
	_refrescar_barra_contexto()


func _construir_panel_portada(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["portada"] = panel

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_portada = VBoxContainer.new()
	contenedor_portada.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_portada)


func _tarjeta(padre: Control, acento: Color = Color.TRANSPARENT) -> VBoxContainer:
	var caja := PanelContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if acento != Color.TRANSPARENT:
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Tema.PANEL
		estilo.corner_radius_top_left = Tema.RADIO
		estilo.corner_radius_top_right = Tema.RADIO
		estilo.corner_radius_bottom_left = Tema.RADIO
		estilo.corner_radius_bottom_right = Tema.RADIO
		estilo.border_width_top = 2
		estilo.border_width_bottom = 2
		estilo.border_width_right = 2
		estilo.border_width_left = 6
		estilo.border_color = acento
		estilo.shadow_color = Color("#070907")
		estilo.shadow_size = 2
		estilo.shadow_offset = Vector2(3, 3)
		estilo.content_margin_left = 16
		estilo.content_margin_right = 16
		estilo.content_margin_top = 12
		estilo.content_margin_bottom = 12
		caja.add_theme_stylebox_override("panel", estilo)
	padre.add_child(caja)
	var dentro := VBoxContainer.new()
	caja.add_child(dentro)
	return dentro


func _refrescar_portada() -> void:
	for hijo in contenedor_portada.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador

	# --- El dia de hoy, con lo que se puede hacer hoy -----------------------
	#
	# Antes esta tarjeta era solo "proximo partido" y el boton jugaba la
	# fecha, pasando los 7 dias de un saque. Ahora es el calendario: dice
	# que dia es, y el boton juega el partido o pasa el dia segun toque.
	# Hoy puede tocar liga o copa, nunca las dos: el calendario no avanza
	# mientras haya un cruce de copa esperando. La copa se pregunta
	# primero porque es la que frena el dia.
	var copa: Copa = GameState.copa_de_hoy()
	var hay_copa: bool = copa != null
	# La internacional se pregunta despues de la copa domestica y por el
	# mismo motivo: tambien frena el dia. Las dos nunca caen el mismo
	# miercoles (ver GameState.FECHAS_ENTRE_RONDAS_INTERNACIONAL), pero al
	# cerrar la temporada se drenan las rondas que sobraron y ahi si
	# pueden quedar las dos esperando el mismo dia. Se juega primero la
	# copa y despues la internacional.
	var hay_internacional: bool = not hay_copa and GameState.hay_partido_internacional_hoy()
	# El playoff de ascenso cae despues de la ultima fecha y tambien frena
	# el dia. Va ultimo: las copas que sobran se drenan ese mismo dia.
	var hay_playoff: bool = (not hay_copa and not hay_internacional
		and GameState.hay_partido_de_playoff_hoy())
	var hay_partido: bool = GameState.hay_partido_hoy() or hay_copa or hay_internacional or hay_playoff
	var termino_fixture: bool = not GameState.hay_fecha_pendiente()
	var rival: Team = _proximo_rival()
	var de_local: bool = _juega_de_local()
	if hay_copa:
		rival = GameState.rival_de_copa()
		de_local = GameState.copa_de_local()
	elif hay_internacional:
		rival = GameState.rival_internacional()
		de_local = GameState.internacional_de_local()
	elif hay_playoff:
		rival = GameState.rival_de_playoff()
		de_local = GameState.playoff_de_local()
	var partido_destacado := rival != null
	var caja_partido := _tarjeta(contenedor_portada, Tema.VERDE if partido_destacado else Tema.BORDE)
	if partido_destacado:
		var panel_partido := caja_partido.get_parent() as PanelContainer
		var estilo_partido: StyleBoxFlat = panel_partido.get_theme_stylebox("panel").duplicate()
		estilo_partido.bg_color = Color("#3eaa57")
		estilo_partido.border_color = Color("#245f38")
		estilo_partido.border_width_top = 3
		estilo_partido.border_width_bottom = 5
		estilo_partido.border_width_left = 3
		estilo_partido.border_width_right = 3
		estilo_partido.content_margin_left = 24
		estilo_partido.content_margin_right = 24
		estilo_partido.content_margin_top = 20
		estilo_partido.content_margin_bottom = 20
		panel_partido.add_theme_stylebox_override("panel", estilo_partido)
	var encabezado := Calendario.texto_largo(GameState.dia_absoluto)
	if hay_copa:
		encabezado = "%s  ·  %s  ·  %s" % [encabezado, copa.nombre, copa.ronda_actual()]
	elif hay_internacional:
		encabezado = "%s  ·  %s" % [encabezado, GameState.torneo_internacional_de_hoy()]
	elif hay_playoff:
		encabezado = "%s  ·  %s" % [encabezado, GameState.torneo_playoff_de_hoy()]
	elif rival != null:
		encabezado = "PROXIMO PARTIDO  ·  %s" % Calendario.en_cuantos_dias(
			GameState.dias_hasta_el_partido())
	var etiqueta_partido := Tema.etiqueta_seccion(encabezado)
	if partido_destacado:
		etiqueta_partido.add_theme_color_override("font_color", Color("#fff17d"))
		Tema.sombra_texto(etiqueta_partido)
	caja_partido.add_child(etiqueta_partido)
	var titulo := Label.new()
	if rival == null:
		titulo.text = "Temporada terminada."
	else:
		titulo.text = "%s (%s)  VS  %s (%s)" % [equipo.nombre,
			_texto_posicion(equipo), rival.nombre, _texto_posicion(rival)]
	Tema.numero(titulo, 28, Color("#fff8df") if partido_destacado else Tema.SUAVE)
	if partido_destacado:
		Tema.sombra_texto(titulo)
	caja_partido.add_child(titulo)

	# Segunda y ultima linea: condicion de local, estilo y DT rival.
	if rival != null:
		var informe := Label.new()
		informe.text = _texto_informe_rival(rival, de_local)
		informe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		informe.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		informe.add_theme_color_override("font_color", Tema.SUAVE)
		if partido_destacado:
			informe.add_theme_color_override("font_color", Color("#eaffdc"))
			Tema.sombra_texto(informe)
		caja_partido.add_child(informe)

	var fila_acciones := HBoxContainer.new()
	caja_partido.add_child(fila_acciones)
	if hay_partido:
		var btn_jugar := Button.new()
		btn_jugar.text = "Jugar el partido"
		if hay_copa:
			btn_jugar.text = "Jugar el partido de copa"
		elif hay_internacional:
			btn_jugar.text = "Jugar el partido internacional"
		elif hay_playoff:
			btn_jugar.text = "Jugar el playoff de ascenso"
		btn_jugar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_jugar.size_flags_stretch_ratio = 2.0
		Tema.primario(btn_jugar)
		btn_jugar.disabled = rival == null
		boton_jugar_partido = btn_jugar
		btn_jugar.pressed.connect(func():
			await _on_jugar_fecha()
			_refrescar_portada()
		)
		fila_acciones.add_child(btn_jugar)
	else:
		var btn_dia := Button.new()
		btn_dia.text = "Avanzar un dia"
		btn_dia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_dia.size_flags_stretch_ratio = 2.0
		Tema.primario(btn_dia)
		btn_dia.pressed.connect(func(): _avanzar_dias(false))
		fila_acciones.add_child(btn_dia)
		var btn_salto := Button.new()
		btn_salto.text = "Ir al fin de la liga" if termino_fixture else "Ir al proximo partido"
		btn_salto.custom_minimum_size.y = Tema.ALTO_TACTIL
		btn_salto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_salto.size_flags_stretch_ratio = 1.0
		btn_salto.tooltip_text = (
			"Pasa los dias hasta cerrar la liga, pero frena si aparece un partido o algo que necesita una decision."
			if termino_fixture else
			"Pasa los dias de corrido, pero frena si pasa algo que necesita una decision."
		)
		btn_salto.pressed.connect(func(): _avanzar_dias(true))
		fila_acciones.add_child(btn_salto)
	if hay_partido:
		var btn_form := Button.new()
		btn_form.text = "Saltar a resultado"
		btn_form.custom_minimum_size.y = Tema.ALTO_TACTIL
		btn_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_form.size_flags_stretch_ratio = 1.0
		btn_form.disabled = rival == null
		btn_form.pressed.connect(_on_saltar_a_resultado)
		fila_acciones.add_child(btn_form)

	# Simular tambien vive aca y no solo en Partido: la portada es desde
	# donde se juega, y mandar al jugador a otra seccion a buscar el boton
	# que salta la temporada es pedirle que adivine donde esta.
	var btn_simular := Button.new()
	btn_simular.text = TEXTO_SIMULAR_TEMPORADA
	btn_simular.custom_minimum_size.y = Tema.ALTO_TACTIL
	btn_simular.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_simular.size_flags_stretch_ratio = 1.0
	btn_simular.tooltip_text = "Juega de una todas las fechas que quedan, las tuyas incluidas: no vas a poder tocar nada hasta el final."
	btn_simular.disabled = rival == null
	btn_simular.pressed.connect(func():
		_on_simular_temporada()
		_refrescar_portada()
	)
	fila_acciones.add_child(btn_simular)

	# Futbol concreto, no una curva abstracta: resultados, goles y goleador.
	# El rival usa la misma ficha para que la comparacion sea inmediata.
	contenedor_portada.add_child(Tema.etiqueta_seccion("Tu equipo y el rival"))
	var comparacion := HBoxContainer.new()
	comparacion.add_theme_constant_override("separation", 12)
	contenedor_portada.add_child(comparacion)
	_agregar_resumen_club(comparacion, equipo, "TU EQUIPO", Tema.CELESTE)
	if rival != null:
		_agregar_resumen_club(comparacion, rival, "PRÓXIMO RIVAL", Tema.ROJO)

	# --- Lo que esta esperando una decision --------------------------------
	var pendientes := _pendientes_de_portada()
	contenedor_portada.add_child(Tema.etiqueta_seccion(
		"Te toca decidir" if not pendientes.is_empty() else "Nada pendiente"))
	if pendientes.is_empty():
		var vacio := Label.new()
		vacio.text = "No hay ofertas por responder ni informes nuevos."
		vacio.add_theme_color_override("font_color", Tema.SUAVE)
		contenedor_portada.add_child(vacio)
	for p in pendientes:
		var caja := _tarjeta(contenedor_portada, p["color"])
		var fila := HBoxContainer.new()
		caja.add_child(fila)
		var texto := VBoxContainer.new()
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(texto)
		var l1 := Label.new()
		l1.text = str(p["titulo"])
		texto.add_child(l1)
		var l2 := Label.new()
		l2.text = str(p["detalle"])
		l2.add_theme_color_override("font_color", Tema.SUAVE)
		l2.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		texto.add_child(l2)
		var btn := Button.new()
		btn.text = str(p["accion"])
		btn.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
		btn.pressed.connect(p["al_tocar"])
		fila.add_child(btn)

	# --- Anuncios descartables ---------------------------------------------
	# Solo hechos que afectan al club propio. El feed Noticias conserva el
	# mundo entero; esto es la bandeja corta de resultados importantes.
	var fila_titulo_anuncios := HBoxContainer.new()
	contenedor_portada.add_child(fila_titulo_anuncios)
	var titulo_anuncios := Tema.etiqueta_seccion("Anuncios")
	titulo_anuncios.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_titulo_anuncios.add_child(titulo_anuncios)
	if not GameState.anuncios_portada.is_empty():
		var descartar_todos := Button.new()
		descartar_todos.text = "Descartar todos"
		descartar_todos.pressed.connect(func():
			GameState.descartar_todos_los_anuncios()
			_refrescar_portada())
		fila_titulo_anuncios.add_child(descartar_todos)
	if GameState.anuncios_portada.is_empty():
		var sin_anuncios := Label.new()
		sin_anuncios.text = "No hay anuncios nuevos."
		sin_anuncios.add_theme_color_override("font_color", Tema.SUAVE)
		contenedor_portada.add_child(sin_anuncios)
	for anuncio in GameState.anuncios_portada:
		var tipo := str(anuncio.get("tipo", "club"))
		var color := Tema.VERDE if tipo == "exito" else (
			Tema.CELESTE if tipo == "entrenamiento" else Tema.AMBAR)
		var caja_anuncio := _tarjeta(contenedor_portada, color)
		var fila_anuncio := HBoxContainer.new()
		caja_anuncio.add_child(fila_anuncio)
		var texto_anuncio := Label.new()
		texto_anuncio.text = str(anuncio.get("texto", ""))
		texto_anuncio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_anuncio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila_anuncio.add_child(texto_anuncio)
		var id_anuncio := int(anuncio.get("id", -1))
		var descartar := Button.new()
		descartar.text = "Descartar"
		descartar.custom_minimum_size = Vector2(130, Tema.ALTO_TACTIL)
		descartar.pressed.connect(func():
			GameState.descartar_anuncio_portada(id_anuncio)
			_refrescar_portada())
		fila_anuncio.add_child(descartar)



## Ficha corta con la tabla y los goleadores reales de la division.
func _agregar_resumen_club(padre: Control, club: Team, rotulo: String,
		acento: Color) -> void:
	var caja := _tarjeta(padre, acento)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(Tema.etiqueta_seccion(rotulo))

	var nombre := Label.new()
	nombre.text = club.nombre
	Tema.numero(nombre, 22, Tema.TEXTO)
	caja.add_child(nombre)

	var division := GameState.division_de(club)
	if division < 0 or division >= GameState.piramide.divisiones.size():
		return
	var liga: Liga = GameState.piramide.divisiones[division]
	var fila: Dictionary = liga.tabla.get(club.nombre, {})
	var goleador := _goleador_del_club(liga, club)
	var nombre_goleador := "Todavia sin goles"
	var goles_goleador := ""
	if goleador.is_empty():
		pass
	else:
		nombre_goleador = str(goleador["nombre"])
		goles_goleador = "%d gol%s" % [int(goleador["goles"]),
			"" if int(goleador["goles"]) == 1 else "es"]

	# Tres tercios reales. Cada fila usa todo el ancho y comparte exactamente
	# los mismos comienzos de columna, sin anchos inventados ni espacio muerto.
	_agregar_fila_resumen(caja, [
		"Ganados  %d" % int(fila.get("pg", 0)),
		"Empatados  %d" % int(fila.get("pe", 0)),
		"Perdidos  %d" % int(fila.get("pp", 0))])
	_agregar_fila_resumen(caja, ["Goleador", nombre_goleador, goles_goleador], Tema.AMBAR)


func _agregar_fila_resumen(padre: VBoxContainer, textos: Array,
		color: Color = Color.TRANSPARENT) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 0)
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(fila)
	for texto in textos:
		# El Control define el tercio. El Label anclado no puede agrandarlo por
		# tener un nombre largo, que era lo que desalineaba las columnas.
		var espacio := Control.new()
		espacio.custom_minimum_size.y = 28
		espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		espacio.size_flags_stretch_ratio = 1.0
		fila.add_child(espacio)
		var etiqueta := Label.new()
		etiqueta.text = str(texto)
		etiqueta.clip_text = true
		etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if color != Color.TRANSPARENT:
			etiqueta.add_theme_color_override("font_color", color)
		espacio.add_child(etiqueta)
		etiqueta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _goleador_del_club(liga: Liga, club: Team) -> Dictionary:
	var mejor := {}
	for jugador in club.todos_los_jugadores():
		var fila: Dictionary = liga.estadisticas.get(str(int(jugador["id"])), {})
		var goles := int(fila.get("goles", 0))
		if goles <= int(mejor.get("goles", 0)):
			continue
		mejor = {"nombre": _nombre_jugador(jugador), "goles": goles}
	return mejor


## Lo que esta esperando una decision tuya, ahora. Solo cosas accionables:
## una lista de "novedades" que no se pueden tocar no sirve de nada.
func _pendientes_de_portada() -> Array:
	var equipo := GameState.equipo_jugador
	var salida := []
	for o in equipo.ofertas:
		# Cada boton abre SU oferta. Antes todos llevaban a la tabla del
		# mercado y habia que ir a la solapa y buscar la fila a mano.
		var ir_a_oferta := func(): _ir_a_oferta(int(o["id"]), bool(o["entrante"]))
		if str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS:
			salida.append({
				"al_tocar": ir_a_oferta,
				"color": Tema.ROJO,
				"titulo": "%s ofrece %s por %s" % [
					str(o["club"]), Economia.formato_dinero(o["monto"]), str(o["jugador"])]
					if bool(o["entrante"]) else
					"%s te contraoferta por %s" % [str(o["club"]), str(o["jugador"])],
				"detalle": "%s  ·  ronda %d" % [str(o["posicion"]), int(o["ronda"])],
				"accion": "Ver oferta",
			})
		elif str(o["estado"]) == Ofertas.ACUERDO_CLUB and not bool(o["entrante"]):
			salida.append({
				"al_tocar": ir_a_oferta,
				"color": Tema.AMBAR,
				"titulo": "Acordaste %s por %s" % [
					Economia.formato_dinero(o["monto"]), str(o["jugador"])],
				"detalle": "Falta firmar el contrato con el jugador.",
				"accion": "Firmar",
			})
	# El veto no genera oferta abierta ni informe: la negociacion ya murio.
	# Sin este cartel la unica señal era una linea de noticias, y el jugador
	# se enteraba de que estaba vetado recién al ir a fichar.
	for o in Ofertas.vetos_sin_ver(equipo):
		var faltan := int(o.get("veto_hasta", GameState.temporada_actual)) - GameState.temporada_actual + 1
		var cuando := "Vuelven a escucharte la temporada que viene."
		if faltan > 1:
			cuando = "No te escuchan por %d temporadas mas." % faltan
		var acusar := func():
			Ofertas.marcar_veto_visto(o)
			_refrescar_portada()
		salida.append({
			"color": Tema.ROJO,
			"titulo": "%s te veto por %s" % [str(o["club"]), str(o["jugador"])],
			"detalle": "Se ofendieron con tu oferta de %s. %s" % [
				Economia.formato_dinero(o["monto"]), cuando],
			"accion": "Aceptar",
			"al_tocar": acusar,
		})
	# Un informe deja de ser novedad al abrirlo. Si terminaron varios, queda
	# el siguiente en la cola para que ningun resultado tape a otro.
	var indice := _indice_de_jugadores()
	while not equipo.informes_sin_ver.is_empty():
		var primero := int(equipo.informes_sin_ver[0])
		if equipo.conocimiento.has(primero) and indice.has(primero):
			break
		equipo.informes_sin_ver.pop_front()
	var id_informe := -1 if equipo.informes_sin_ver.is_empty() else int(equipo.informes_sin_ver[0])
	if id_informe != -1:
		var dato_informe: Dictionary = indice[id_informe]
		var nombre_informe := _nombre_jugador(dato_informe["jugador"])
		var ver_informe := func():
			equipo.informes_sin_ver.erase(id_informe)
			_mostrar_seccion("mercado", "mercado")
			_mostrar_solapa_mercado("investigaciones")
			_mostrar_modal_jugador(id_informe)
		salida.append({
			"color": Tema.CELESTE,
			"titulo": "Informe de %s listo" % nombre_informe,
			"detalle": "%s · Ya podes ver su ficha completa." % str(dato_informe["club"].nombre),
			"accion": "Ver",
			"al_tocar": ver_informe,
		})
	return salida


## Lleva a la solapa de la oferta y la abre encima. La solapa queda debajo
## para que al cerrar el modal se vuelva a la lista de esa oferta.
func _ir_a_oferta(oferta_id: int, entrante: bool) -> void:
	_mostrar_seccion("mercado", "mercado")
	_mostrar_solapa_mercado("recibidas" if entrante else "enviadas")
	_abrir_oferta(oferta_id)



# ---------------------------------------------------------------------------
# Entrenamiento
# ---------------------------------------------------------------------------

## Ejercicios y carga viven ACA y no en Formacion. Estaban metidos en la
## fila de la formacion, al lado del desplegable tactico, como si fueran
## parte de armar el equipo: eran combos sin explicacion en una pantalla
## que habla de otra cosa. Son las decisiones que gobiernan como crece el
## plantel y merecen su propia seccion, con lo que hace cada opcion a la
## vista y no escondido en un tooltip.
var contenedor_entrenamiento: VBoxContainer
var option_carga_entr: OptionButton


func _construir_panel_entrenamiento(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["entrenamiento"] = panel

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_entrenamiento = VBoxContainer.new()
	contenedor_entrenamiento.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_entrenamiento.add_theme_constant_override("separation", 10)
	scroll.add_child(contenedor_entrenamiento)


func _mostrar_entrenamiento() -> void:
	_ocultar_todos()
	paneles["entrenamiento"].visible = true
	_refrescar_entrenamiento()


func _refrescar_entrenamiento() -> void:
	if contenedor_entrenamiento == null:
		return
	for hijo in contenedor_entrenamiento.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador

	# --- Carga: cuanto se entrena --------------------------------------
	var caja_carga := _tarjeta(contenedor_entrenamiento, Tema.BORDE)
	caja_carga.add_child(Tema.etiqueta_seccion("Carga  ·  cuanto se entrena"))
	var fila_carga := HBoxContainer.new()
	fila_carga.add_theme_constant_override("separation", 10)
	caja_carga.add_child(fila_carga)
	option_carga_entr = OptionButton.new()
	option_carga_entr.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	for nivel in CargaEntrenamiento.NIVELES:
		option_carga_entr.add_item(CargaEntrenamiento.ETIQUETAS[nivel])
	var idx_carga := CargaEntrenamiento.NIVELES.find(equipo.carga_entrenamiento)
	if idx_carga >= 0:
		option_carga_entr.selected = idx_carga
	option_carga_entr.item_selected.connect(func(i):
		_on_carga_elegida(i)
		_refrescar_entrenamiento())
	fila_carga.add_child(option_carga_entr)
	caja_carga.add_child(_texto_suave(
		"Mas carga hace crecer mas rapido, pero recuperas peor entre partidos y te lesionas mas. " \
		+ "Lo que decide la progresion es el PROMEDIO de la temporada, no la carga de hoy."))

	# La tabla completa: sin verla, elegir es adivinar.
	for nivel in CargaEntrenamiento.NIVELES:
		var actual: bool = nivel == equipo.carga_entrenamiento
		var fila := Componentes.fila(CargaEntrenamiento.NIVELES.find(nivel) % 2 == 0)
		var dentro := Componentes.contenido(fila)
		dentro.add_child(Componentes.celda(
			str(CargaEntrenamiento.ETIQUETAS[nivel]), 150,
			Tema.AMBAR if actual else Tema.TEXTO))
		dentro.add_child(Componentes.celda_numero(
			"crecimiento x%.2f" % CargaEntrenamiento.factor_crecimiento(nivel), 170, Tema.SUAVE))
		dentro.add_child(Componentes.celda_numero(
			"recuperacion x%.2f" % CargaEntrenamiento.factor_recuperacion(nivel), 180, Tema.SUAVE))
		dentro.add_child(Componentes.celda_numero(
			"lesiones x%.2f" % CargaEntrenamiento.factor_lesion(nivel), 150, Tema.SUAVE))
		caja_carga.add_child(fila)
	if equipo.carga_semanas > 0.0:
		caja_carga.add_child(_texto_suave(
			"Esta temporada venis en x%.2f de crecimiento acumulado." % equipo.factor_carga_temporada()))

	# --- Ejercicios: que se entrena -------------------------------------
	for ranura in Entrenamiento.RANURAS:
		_caja_ranura(ranura, equipo)

	# Cuanto pesa cada ejercicio en la temporada: cambiar a mitad de ano
	# reparte, no reinicia, y eso hay que poder verlo.
	var reparto := equipo.reparto_ejercicios()
	if not reparto.is_empty():
		var partes := []
		for ejercicio in reparto:
			partes.append("%s %d%%" % [
				Entrenamiento.ETIQUETAS.get(ejercicio, "Libre"),
				int(round(float(reparto[ejercicio]) * 100.0))])
		contenedor_entrenamiento.add_child(_texto_suave(
			"Lo que va pesando esta temporada: %s." % ", ".join(partes)))


## Una tarjeta por ranura: el desplegable y la tabla de sus ejercicios.
func _caja_ranura(ranura: String, equipo: Team) -> void:
	var puesto: String = equipo.ejercicio_fisico if ranura == Entrenamiento.FISICO else equipo.ejercicio_tactico
	var ejercicios: Array = Entrenamiento.EJERCICIOS[ranura]
	var caja := _tarjeta(contenedor_entrenamiento, Tema.BORDE)
	caja.add_child(Tema.etiqueta_seccion(
		"Físico  ·  cómo se prepara" if ranura == Entrenamiento.FISICO else "Táctico  ·  qué se practica"))
	var opcion := OptionButton.new()
	opcion.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	for ejercicio in ejercicios:
		opcion.add_item(Entrenamiento.ETIQUETAS[ejercicio])
	opcion.selected = maxi(0, ejercicios.find(puesto))
	opcion.item_selected.connect(func(i):
		_on_ejercicio_elegido(ranura, i)
		_refrescar_entrenamiento())
	caja.add_child(opcion)
	if ranura == Entrenamiento.FISICO:
		caja.add_child(_texto_suave(
			"El ejercicio queda puesto hasta que lo cambies. Da un bonus en los partidos mientras " \
			+ "esta puesto, y al cierre de temporada hace crecer mas sus atributos. El crecimiento " \
			+ "tiene presupuesto FIJO: lo que ganan esos atributos se lo sacas al resto, que crece " \
			+ "mas despacio. Los arqueros crecen parejo."))
	for ejercicio in ejercicios:
		caja.add_child(_fila_ejercicio(ejercicio, ejercicio == puesto, ejercicios.find(ejercicio)))


## Una fila por ejercicio, con lo que da en el partido y cuanto multiplica.
func _fila_ejercicio(ejercicio: String, actual: bool, indice: int) -> Control:
	var fila := Componentes.fila(indice % 2 == 0)
	if actual:
		var e: StyleBoxFlat = fila.get_theme_stylebox("panel").duplicate()
		e.bg_color = Tema.PANEL_ALTO
		e.border_width_left = 3
		e.border_color = Tema.AMBAR
		fila.add_theme_stylebox_override("panel", e)
	var dentro := Componentes.contenido(fila)
	dentro.add_child(Componentes.celda(
		str(Entrenamiento.ETIQUETAS[ejercicio]), 150, Tema.AMBAR if actual else Tema.TEXTO))

	var atributos: Array = Entrenamiento.atributos_de(ejercicio)
	# Los multiplicadores reales, con la cuenta del propio sistema y no a
	# ojo: la ranura sola, toda la temporada.
	var texto_mult := "todo parejo"
	if not atributos.is_empty():
		var mult := Entrenamiento.multiplicadores({ejercicio: 1.0}, PlayerGenerator.get_all_attributes())
		var resto := ""
		for attr in mult:
			if not atributos.has(attr):
				resto = attr
				break
		texto_mult = "x%.2f   resto x%.2f" % [float(mult[atributos[0]]), float(mult.get(resto, 1.0))]
	# 250 y no 190: con menos, "el resto x0.79" se cortaba justo en el
	# numero, que es el dato por el que se elige.
	dentro.add_child(Componentes.celda_numero(texto_mult, 250, Tema.SUAVE))

	var detalle := Label.new()
	detalle.text = "%s %s" % [
		Entrenamiento.DESCRIPCIONES.get(ejercicio, ""),
		"" if atributos.is_empty() else "(%s)" % ", ".join(atributos)]
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	detalle.add_theme_color_override("font_color", Tema.SUAVE)
	dentro.add_child(detalle)
	return fila


## JUGADAS PREPARADAS (core/jugadas.gd) — lo que el plantel ensaya.
##
## Un cuadrado por jugada, como en Roles. Se toca uno libre y, con la
## confirmacion, empieza a ensayarse. Mientras dura, los demas quedan
## trabados: la regla es de a una y sin abandonar.
var contenedor_jugadas: VBoxContainer
var grilla_jugadas: GridContainer
var dialogo_jugada: ConfirmationDialog
var jugada_a_confirmar: String = ""


func _construir_panel_jugadas(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["jugadas"] = panel

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	contenedor_jugadas = VBoxContainer.new()
	contenedor_jugadas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_jugadas.add_theme_constant_override("separation", 10)
	scroll.add_child(contenedor_jugadas)

	dialogo_jugada = ConfirmationDialog.new()
	dialogo_jugada.title = "Empezar a ensayar"
	dialogo_jugada.ok_button_text = "Empezar"
	dialogo_jugada.cancel_button_text = "Cancelar"
	dialogo_jugada.confirmed.connect(func():
		Jugadas.empezar(GameState.equipo_jugador, jugada_a_confirmar)
		_refrescar_jugadas())
	add_child(dialogo_jugada)
	Tema.dialogo(dialogo_jugada, true)


func _mostrar_jugadas() -> void:
	_ocultar_todos()
	paneles["jugadas"].visible = true
	_refrescar_jugadas()


func _refrescar_jugadas() -> void:
	if contenedor_jugadas == null:
		return
	for hijo in contenedor_jugadas.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var liga := GameState.liga_jugador()
	var aprendidas: Array[String] = []
	var pendientes: Array[String] = []
	for jugada in Jugadas.LISTA:
		var id := str(jugada)
		if Jugadas.sabe(equipo, id):
			aprendidas.append(id)
		elif id != equipo.jugada_en_curso:
			pendientes.append(id)

	# Una sola cabecera concentra el estado. Antes había dos párrafos de
	# instrucciones y la misma información volvía a aparecer en la grilla.
	var caja := _tarjeta(contenedor_jugadas,
		Tema.AMBAR if equipo.jugada_en_curso != "" else Tema.BORDE)
	if equipo.jugada_en_curso == "":
		caja.add_child(Tema.etiqueta_seccion("Próximo ensayo"))
		var fila_vacia := HBoxContainer.new()
		fila_vacia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caja.add_child(fila_vacia)
		var titulo_vacio := Label.new()
		titulo_vacio.text = "Repertorio completo" if pendientes.is_empty() else "Elegí una jugada"
		titulo_vacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tema.numero(titulo_vacio, 24)
		fila_vacia.add_child(titulo_vacio)
		fila_vacia.add_child(Componentes.chip("%d de %d aprendidas" % [
			aprendidas.size(), Jugadas.LISTA.size()], Tema.PANEL_ALTO, Tema.SUAVE))
		caja.add_child(_texto_suave(
			"Tu equipo ya aprendió todas las jugadas disponibles." if pendientes.is_empty() \
			else "Se ensayan de a una. Al completarla, queda en tu repertorio para siempre."))
	else:
		caja.add_child(Tema.etiqueta_seccion("Ensayando ahora"))
		var fila_actual := HBoxContainer.new()
		fila_actual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caja.add_child(fila_actual)
		var nombre := Label.new()
		nombre.text = str(Jugadas.NOMBRE[equipo.jugada_en_curso])
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tema.numero(nombre, 24, Tema.TEXTO)
		fila_actual.add_child(nombre)
		var porcentaje := Label.new()
		porcentaje.text = "%d%%" % int(round(Jugadas.progreso(equipo) * 100.0))
		Tema.numero(porcentaje, 24, Tema.AMBAR)
		fila_actual.add_child(porcentaje)
		var barra := ProgressBar.new()
		barra.min_value = 0.0
		barra.max_value = 1.0
		barra.value = Jugadas.progreso(equipo)
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 10)
		caja.add_child(barra)
		var detalle := _texto_suave("Faltan unas %d semanas  ·  ritmo actual ×%.2f" % [
			int(ceil(Jugadas.semanas_restantes(equipo))), Jugadas.ritmo(equipo)])
		detalle.tooltip_text = "El ritmo mejora con la carga y con el ejercicio táctico Jugadas armadas."
		caja.add_child(detalle)

	grilla_jugadas = GridContainer.new()
	grilla_jugadas.columns = 2
	grilla_jugadas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grilla_jugadas.add_theme_constant_override("h_separation", 10)
	grilla_jugadas.add_theme_constant_override("v_separation", 10)
	# Mientras hay un ensayo en curso, las opciones bloqueadas no aportan
	# ninguna accion y ocupan casi toda la pantalla.
	if equipo.jugada_en_curso == "" and not pendientes.is_empty():
		# La grilla vive dentro del mismo VBox que el resumen. Asi no existe
		# ningun contenedor intermedio capaz de abrir un hueco entre ambos.
		caja.add_child(grilla_jugadas)
		for id in pendientes:
			grilla_jugadas.add_child(_cuadrado_de_jugada(equipo, id, liga))

	if not aprendidas.is_empty():
		contenedor_jugadas.add_child(Tema.etiqueta_seccion("Repertorio aprendido"))
		var repertorio := GridContainer.new()
		repertorio.columns = 2
		repertorio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		repertorio.add_theme_constant_override("h_separation", 10)
		repertorio.add_theme_constant_override("v_separation", 8)
		contenedor_jugadas.add_child(repertorio)
		for id in aprendidas:
			repertorio.add_child(_jugada_aprendida_compacta(id))


func _jugada_aprendida_compacta(id: String) -> Control:
	var tarjeta := Componentes.tarjeta(Tema.VERDE)
	var fila := HBoxContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tarjeta.add_child(fila)
	var nombre := Label.new()
	nombre.text = str(Jugadas.NOMBRE[id])
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.tooltip_text = str(Jugadas.DESCRIPCION[id])
	fila.add_child(nombre)
	fila.add_child(Componentes.chip("Aprendida", Tema.PANEL_ALTO, Tema.VERDE))
	return tarjeta


## Opción pendiente: descripción breve y una acción visible, sin convertir
## toda la tarjeta en un botón invisible.
func _cuadrado_de_jugada(equipo: Team, id: String, liga: Liga) -> Control:
	var libre := Jugadas.puede_empezar(equipo, id)

	var tarjeta := Componentes.tarjeta(Tema.CELESTE if libre else Color.TRANSPARENT)
	tarjeta.custom_minimum_size = Vector2(0, 164)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not libre:
		tarjeta.modulate = Color(1, 1, 1, 0.68)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	tarjeta.add_child(col)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	col.add_child(fila)
	var nombre := Label.new()
	nombre.text = str(Jugadas.NOMBRE[id])
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tema.numero(nombre, Tema.TAM_BASE)
	fila.add_child(nombre)
	fila.add_child(Componentes.chip("%d sem." % int(Jugadas.semanas_de(id)),
		Tema.PANEL_ALTO, Tema.SUAVE))

	col.add_child(_texto_suave(str(Jugadas.DESCRIPCION[id])))
	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(espacio)
	var pie := HBoxContainer.new()
	pie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(pie)

	# Cuantos rivales de la division la saben: si la saben, la leen y la
	# ventaja se achica a la mitad (Jugadas.LECTURA_DEL_RIVAL).
	var texto_rivales := ""
	if liga != null:
		var cuantos := 0
		for e in liga.equipos:
			if e != equipo and Jugadas.sabe(e, id):
				cuantos += 1
		texto_rivales = "%d rivales la conocen" % cuantos if cuantos > 0 else "Ningún rival la conoce"
	var rivales := Label.new()
	rivales.text = texto_rivales
	rivales.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rivales.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	rivales.add_theme_color_override("font_color", Tema.SUAVE)
	rivales.tooltip_text = "Si el rival también la conoce, la ventaja de la jugada se reduce."
	pie.add_child(rivales)

	if libre:
		var boton := Button.new()
		boton.text = "Ensayar"
		boton.custom_minimum_size.x = 104
		boton.tooltip_text = "Empezar a ensayar esta jugada"
		boton.pressed.connect(func(): _pedir_jugada(id))
		pie.add_child(boton)
	else:
		pie.add_child(Componentes.chip("Después", Tema.PANEL_ALTO, Tema.SUAVE))
	return tarjeta


func _pedir_jugada(id: String) -> void:
	var equipo := GameState.equipo_jugador
	jugada_a_confirmar = id
	dialogo_jugada.dialog_text = "%s\n\n%s\n\nTarda unas %d semanas al ritmo de hoy. Hasta terminarla no podés ensayar otra ni abandonarla." % [
		str(Jugadas.NOMBRE[id]), str(Jugadas.DESCRIPCION[id]),
		int(ceil(Jugadas.semanas_de(id) / maxf(Jugadas.ritmo(equipo), 0.01)))]
	dialogo_jugada.popup_centered()


func _texto_suave(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	l.add_theme_color_override("font_color", Tema.SUAVE)
	return l


## ROLES (core/roles.gd) — quien patea que y quien lleva la cinta.
##
## Cinco cuadrados, uno por rol. Cada uno muestra quien lo ocupa hoy y si
## lo eligio el club o lo esta resolviendo el juego solo. Se toca el
## cuadrado y se abre la lista del plantel para cambiarlo.
##
## Existe porque hasta ahora no lo elegia nadie: el motor buscaba al mejor
## del atributo que correspondia, y en los penales eso incluia al arquero.
func _construir_panel_roles(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["roles"] = panel

	panel.add_child(_texto_suave(
		"Tocá un rol para cambiar quién lo ocupa. Si no elegís a nadie, "
		+ "lo resuelve el juego con el mejor del plantel. El elegido pierde "
		+ "el puesto mientras esté lesionado o suspendido, y lo patea otro "
		+ "si no está en la cancha en ese momento."))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_roles = GridContainer.new()
	contenedor_roles.columns = 3
	contenedor_roles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_roles.add_theme_constant_override("h_separation", 10)
	contenedor_roles.add_theme_constant_override("v_separation", 10)
	scroll.add_child(contenedor_roles)


func _mostrar_roles() -> void:
	_ocultar_todos()
	paneles["roles"].visible = true
	_refrescar_roles()


func _refrescar_roles() -> void:
	if contenedor_roles == null:
		return
	for hijo in contenedor_roles.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	for clave in Roles.CLAVES:
		contenedor_roles.add_child(_cuadrado_de_rol(equipo, str(clave)))


## El cuadrado de un rol. El boton transparente de arriba de todo es lo
## que lo hace clickeable entero: un Button no puede tener adentro una
## columna de labels acomodada, asi que se dibuja la tarjeta y se le
## apoya el boton encima ocupando todo.
func _cuadrado_de_rol(equipo: Team, clave: String) -> Control:
	var elegido := Roles.elegido(equipo, clave)
	var ocupante := Roles.resolver(equipo, clave)
	var automatico: bool = elegido == Roles.AUTOMATICO

	var tarjeta := Componentes.tarjeta(Tema.AMBAR if not automatico else Color.TRANSPARENT)
	tarjeta.custom_minimum_size = Vector2(0, 150)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	tarjeta.add_child(caja)

	caja.add_child(Tema.etiqueta_seccion(str(Roles.NOMBRE[clave])))

	var jugador := _jugador_del_plantel(equipo, ocupante)
	if jugador.is_empty():
		var vacio := Label.new()
		vacio.text = "Sin nadie"
		Tema.numero(vacio, Tema.TAM_BASE, Tema.SUAVE)
		caja.add_child(vacio)
	else:
		var nombre := Label.new()
		nombre.text = "%s %s" % [str(jugador["nombre"]), str(jugador["apellido"])]
		nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		Tema.numero(nombre, Tema.TAM_BASE, Tema.TEXTO)
		caja.add_child(nombre)

		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		caja.add_child(fila)
		fila.add_child(Componentes.chip(str(jugador["posicion"]), Tema.PANEL_ALTO, Tema.SUAVE))
		var valor := Label.new()
		valor.text = "%s %d" % [_etiqueta_de_atributo(clave), int(Roles.valor_de(jugador, clave))]
		valor.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		valor.add_theme_color_override(
			"font_color", Componentes.color_de_valor(int(Roles.valor_de(jugador, clave))))
		fila.add_child(valor)

	var estado := Label.new()
	estado.text = "Automático" if automatico else "Elegido por vos"
	estado.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	estado.add_theme_color_override("font_color", Tema.SUAVE if automatico else Tema.AMBAR)
	caja.add_child(estado)

	# El aviso importa: un pateador designado que esta afuera no patea, y
	# enterarte en el partido es tarde.
	if not automatico and not jugador.is_empty() and not equipo.puede_jugar(int(jugador["id"])):
		var aviso := Label.new()
		aviso.text = "No disponible: lo cubre otro."
		aviso.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		aviso.add_theme_color_override("font_color", Tema.ROJO)
		caja.add_child(aviso)

	var espacio := Control.new()
	espacio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja.add_child(espacio)

	caja.add_child(_texto_suave(str(Roles.DESCRIPCION[clave])))

	var tapa := Button.new()
	tapa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tapa.flat = true
	tapa.tooltip_text = "Cambiar quién ocupa este rol"
	tapa.pressed.connect(func(): _abrir_modal_roles(clave))
	tarjeta.add_child(tapa)
	return tarjeta


func _etiqueta_de_atributo(clave: String) -> String:
	var atributo := str(Roles.ATRIBUTO.get(clave, ""))
	if atributo == "":
		return "Media"
	if atributo == "tiros_libres":
		return "Tiros libres"
	return atributo.capitalize()


func _jugador_del_plantel(equipo: Team, jugador_id: int) -> Dictionary:
	if jugador_id < 0:
		return {}
	for j in equipo.todos_los_jugadores():
		if int(j["id"]) == jugador_id:
			return j
	return {}


## El modal del dorsal: los 99 numeros en una grilla. Grilla y no un
## campo de texto porque en el celular escribir un numero abre el teclado
## y encima no muestra cual esta ocupado, que es la mitad de la decision.
func _construir_modal_dorsal() -> void:
	capa_modal_dorsal = CanvasLayer.new()
	capa_modal_dorsal.layer = 9
	capa_modal_dorsal.visible = false
	add_child(capa_modal_dorsal)

	var fondo := PanelContainer.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.65)
	fondo.add_theme_stylebox_override("panel", estilo)
	capa_modal_dorsal.add_child(fondo)

	var centro := CenterContainer.new()
	fondo.add_child(centro)
	var caja := Componentes.modal()
	caja.custom_minimum_size = Vector2(620, 560)
	caja.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centro.add_child(caja)

	contenedor_modal_dorsal = VBoxContainer.new()
	contenedor_modal_dorsal.add_theme_constant_override("separation", 8)
	caja.add_child(contenedor_modal_dorsal)


func _abrir_modal_dorsal(jugador_id: int) -> void:
	modal_dorsal_id = jugador_id
	capa_modal_dorsal.visible = true
	_refrescar_modal_dorsal()


func _cerrar_modal_dorsal() -> void:
	capa_modal_dorsal.visible = false


func _refrescar_modal_dorsal() -> void:
	for hijo in contenedor_modal_dorsal.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var j := _jugador_del_plantel(equipo, modal_dorsal_id)
	if j.is_empty():
		_cerrar_modal_dorsal()
		return
	var mio := equipo.dorsal_de(modal_dorsal_id)

	var titulo := Label.new()
	titulo.text = "%s  ·  numero %d" % [_nombre_jugador(j), mio]
	Tema.numero(titulo, 26, Tema.TEXTO)
	contenedor_modal_dorsal.add_child(titulo)
	contenedor_modal_dorsal.add_child(_texto_suave(
		"Elegi el numero nuevo. Si ya lo lleva un companero, se lo intercambian: el otro se queda con el %d." % mio))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	contenedor_modal_dorsal.add_child(scroll)

	var grilla := GridContainer.new()
	grilla.columns = 10
	grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grilla)

	for numero in range(1, Team.DORSAL_MAXIMO + 1):
		var duenio := equipo.jugador_con_dorsal(numero)
		var btn := Button.new()
		btn.text = str(numero)
		btn.custom_minimum_size = Vector2(52, Tema.ALTO_TACTIL)
		if duenio == modal_dorsal_id:
			Tema.seleccionado(btn, true)
		elif duenio != 0:
			# Ambar = ocupado. No se bloquea: tocarlo es justamente como se
			# pide el intercambio.
			btn.add_theme_color_override("font_color", Tema.AMBAR)
			btn.tooltip_text = str(_jugador_del_plantel(equipo, duenio).get("apellido", ""))
		var elegido := numero
		btn.pressed.connect(func(): _elegir_dorsal(elegido))
		grilla.add_child(btn)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(_cerrar_modal_dorsal)
	contenedor_modal_dorsal.add_child(cerrar)


func _elegir_dorsal(numero: int) -> void:
	GameState.equipo_jugador.asignar_dorsal(modal_dorsal_id, numero)
	_cerrar_modal_dorsal()
	_refrescar_ficha()


## El modal de un rol: la lista del plantel ordenada por el atributo que
## le sirve a ESE rol, mas la opcion de dejarlo en automatico.
func _construir_modal_roles() -> void:
	capa_modal_roles = CanvasLayer.new()
	capa_modal_roles.layer = 9
	capa_modal_roles.visible = false
	add_child(capa_modal_roles)

	var fondo := PanelContainer.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.65)
	fondo.add_theme_stylebox_override("panel", estilo)
	capa_modal_roles.add_child(fondo)

	var centro := CenterContainer.new()
	fondo.add_child(centro)
	var caja := Componentes.modal()
	caja.custom_minimum_size = Vector2(560, 540)
	caja.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centro.add_child(caja)

	contenedor_modal_roles = VBoxContainer.new()
	contenedor_modal_roles.add_theme_constant_override("separation", 8)
	caja.add_child(contenedor_modal_roles)


func _abrir_modal_roles(clave: String) -> void:
	modal_rol_clave = clave
	capa_modal_roles.visible = true
	_refrescar_modal_roles()


func _cerrar_modal_roles() -> void:
	capa_modal_roles.visible = false


func _refrescar_modal_roles() -> void:
	for hijo in contenedor_modal_roles.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var clave := modal_rol_clave

	var titulo := Label.new()
	titulo.text = str(Roles.NOMBRE[clave])
	Tema.numero(titulo, 26, Tema.TEXTO)
	contenedor_modal_roles.add_child(titulo)
	contenedor_modal_roles.add_child(_texto_suave(str(Roles.DESCRIPCION[clave])))

	var elegido := Roles.elegido(equipo, clave)
	var automatico := Roles.automatico(equipo, clave)

	var btn_auto := Button.new()
	var quien := _jugador_del_plantel(equipo, automatico)
	btn_auto.text = "Automático" if quien.is_empty() else "Automático (hoy: %s)" % str(quien["apellido"])
	btn_auto.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	Tema.seleccionado(btn_auto, elegido == Roles.AUTOMATICO)
	btn_auto.pressed.connect(func(): _elegir_para_rol(Roles.AUTOMATICO))
	contenedor_modal_roles.add_child(btn_auto)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	contenedor_modal_roles.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	scroll.add_child(lista)

	var titulares := {}
	for j in equipo.jugadores:
		titulares[int(j["id"])] = true

	for j in Roles.candidatos(equipo, clave):
		var id := int(j["id"])
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var marca := "" if titulares.has(id) else "  ·  banco"
		if not equipo.puede_jugar(id):
			marca = "  ·  no disponible"
		btn.text = "%-3s  %s %s   %s %d%s" % [
			str(j["posicion"]), str(j["nombre"]), str(j["apellido"]),
			_etiqueta_de_atributo(clave), int(Roles.valor_de(j, clave)), marca]
		Tema.seleccionado(btn, id == elegido)
		btn.pressed.connect(func(): _elegir_para_rol(id))
		lista.add_child(btn)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(120, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(_cerrar_modal_roles)
	contenedor_modal_roles.add_child(cerrar)


func _elegir_para_rol(jugador_id: int) -> void:
	Roles.asignar(GameState.equipo_jugador, modal_rol_clave, jugador_id)
	_cerrar_modal_roles()
	_refrescar_roles()


## ALINEACION (core/alineacion.gd) — el aviso de que tenes titulares que
## no pueden jugar.
##
## Sale al darle a Jugar, antes del partido. Antes no salia nada: el
## lesionado salia a la cancha igual y lo sacaban en la primera ventana de
## cambios, asi que tener el plantel roto no se notaba.
func _construir_modal_alineacion() -> void:
	capa_modal_alineacion = CanvasLayer.new()
	capa_modal_alineacion.layer = 10
	capa_modal_alineacion.visible = false
	add_child(capa_modal_alineacion)

	var fondo := PanelContainer.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0.72)
	fondo.add_theme_stylebox_override("panel", estilo)
	capa_modal_alineacion.add_child(fondo)

	var centro := CenterContainer.new()
	fondo.add_child(centro)
	var caja := Componentes.modal(Tema.ROJO)
	caja.custom_minimum_size = Vector2(600, 0)
	caja.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centro.add_child(caja)

	contenedor_modal_alineacion = VBoxContainer.new()
	contenedor_modal_alineacion.add_theme_constant_override("separation", 10)
	caja.add_child(contenedor_modal_alineacion)


## true si habia algo que avisar (y entonces el partido NO se juega
## todavia). false si el once esta sano y se puede seguir de largo.
func _avisar_alineacion() -> bool:
	var equipo := GameState.equipo_jugador
	if not Alineacion.hay_problema(equipo):
		return false
	capa_modal_alineacion.visible = true
	_refrescar_modal_alineacion()
	return true


func _cerrar_modal_alineacion() -> void:
	capa_modal_alineacion.visible = false


func _refrescar_modal_alineacion() -> void:
	for hijo in contenedor_modal_alineacion.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var pasos := Alineacion.plan(equipo)

	var titulo := Label.new()
	titulo.text = "Tenés %d titular%s que no puede jugar" % [
		pasos.size(), "" if pasos.size() == 1 else "es"]
	Tema.numero(titulo, 26, Tema.TEXTO)
	contenedor_modal_alineacion.add_child(titulo)

	# La lista puede llegar a once jugadores. Queda acotada y scrollea para
	# que las decisiones y Cerrar nunca bajen fuera del celular.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(
		0, mini(260, maxi(80, pasos.size() * 70)))
	contenedor_modal_alineacion.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	scroll.add_child(lista)

	for paso in pasos:
		var sale: Dictionary = paso["sale"]
		var entra: Dictionary = paso["entra"]
		var fila := Componentes.tarjeta()
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 2)
		fila.add_child(caja)

		var quien := Label.new()
		quien.text = "%s  %s %s" % [
			str(sale["posicion"]), str(sale["nombre"]), str(sale["apellido"])]
		Tema.numero(quien, Tema.TAM_BASE, Tema.TEXTO)
		caja.add_child(quien)

		var porque := Label.new()
		porque.text = str(paso["motivo"]).capitalize()
		porque.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		porque.add_theme_color_override("font_color", Tema.ROJO)
		caja.add_child(porque)

		var reemplazo := Label.new()
		if entra.is_empty():
			reemplazo.text = "No hay suplente sano para reemplazarlo."
			reemplazo.add_theme_color_override("font_color", Tema.AMBAR)
		else:
			reemplazo.text = "Entra %s %s (%s, media %d)" % [
				str(entra["nombre"]), str(entra["apellido"]),
				str(entra["posicion"]), int(entra["media"])]
			reemplazo.add_theme_color_override("font_color", Tema.VERDE)
		reemplazo.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		caja.add_child(reemplazo)
		lista.add_child(fila)

	var sin_cubrir := Alineacion.sin_cubrir(equipo)
	if sin_cubrir > 0:
		contenedor_modal_alineacion.add_child(_texto_suave(
			"Los que no tienen reemplazo se quedan en el once: sacarlos te dejaría "
			+ "con menos de once. Si te faltan demasiados, el partido se pierde "
			+ "por no presentarte."))

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	contenedor_modal_alineacion.add_child(acciones)

	var btn_auto := Button.new()
	btn_auto.text = "Cambiar automáticamente"
	btn_auto.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	btn_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tema.primario(btn_auto)
	btn_auto.pressed.connect(_on_arreglar_alineacion)
	acciones.add_child(btn_auto)

	var btn_mano := Button.new()
	btn_mano.text = "Cambiar a mano"
	btn_mano.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	btn_mano.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mano.pressed.connect(func():
		_cerrar_modal_alineacion()
		# A Formacion, que es donde se mueve gente entre el once y el
		# banco. De ahi el jugador vuelve solo y le da a Jugar otra vez.
		_mostrar_seccion("equipo", "formacion"))
	acciones.add_child(btn_mano)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "Cerrar"
	btn_cerrar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	btn_cerrar.pressed.connect(_cerrar_modal_alineacion)
	contenedor_modal_alineacion.add_child(btn_cerrar)


## Arregla el once y sigue derecho al partido: el que aprieta
## "automaticamente" ya dijo que no quiere decidir nada, hacerle apretar
## Jugar de nuevo seria pedirle lo mismo dos veces.
func _on_arreglar_alineacion() -> void:
	var hechos := Alineacion.arreglar(GameState.equipo_jugador)
	_cerrar_modal_alineacion()
	_refrescar_plantel()
	# Si no habia a quien poner, se juega igual: el partido no se puede
	# posponer y el motor se arregla con los que haya. Si faltan
	# demasiados, lo resuelve Liga._resolver_forfeit.
	await _jugar_el_partido_de_hoy()
	_refrescar_portada()


## El modal de una CESION entrante (core/cesiones.gd). A diferencia de una
## compra, acá no hay un solo numero que mover: se discuten cinco cosas a
## la vez, y por eso el modal muestra los topes del que pide al lado de
## cada campo. Sin los topes, contraofertar era tirar numeros a ver cual
## pegaba.
var dialogo_cesion: AcceptDialog
var cesion_oferta_id: int = -1
var label_cesion_titulo: Label
var label_cesion_sub: Label
var boton_cesion_ficha: Button
var option_cesion_duracion: OptionButton
var spin_cesion_fee: SpinBox
var label_cesion_fee: Label
var slider_cesion_sueldo: HSlider
var label_cesion_sueldo: Label
var check_cesion_opcion: CheckBox
var spin_cesion_opcion: SpinBox
var label_cesion_opcion: Label
var spin_cesion_plus: SpinBox
var label_cesion_plus: Label
var label_cesion_estado: RichTextLabel
var boton_cesion_aceptar: Button
var boton_cesion_contra: Button
var boton_cesion_rechazar: Button
var boton_cesion_retirar: Button
var cesion_topes: Dictionary = {}


func _construir_dialogo_cesion() -> void:
	dialogo_cesion = AcceptDialog.new()
	dialogo_cesion.title = "Cesion"
	dialogo_cesion.min_size = Vector2(720, 0)
	add_child(dialogo_cesion)
	Tema.dialogo(dialogo_cesion)
	dialogo_cesion.get_ok_button().hide()

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogo_cesion.add_child(caja)

	label_cesion_titulo = Label.new()
	Tema.numero(label_cesion_titulo, 24)
	boton_cesion_ficha = _boton_ficha_de_oferta(func(): _ficha_desde_oferta(cesion_oferta_id))
	caja.add_child(_fila_titulo_oferta(label_cesion_titulo, boton_cesion_ficha))

	label_cesion_sub = Label.new()
	label_cesion_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_cesion_sub.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(label_cesion_sub)

	var fila_dur := HBoxContainer.new()
	caja.add_child(fila_dur)
	fila_dur.add_child(_etiqueta("Dura"))
	option_cesion_duracion = OptionButton.new()
	for clave in Prestamos.DURACIONES:
		option_cesion_duracion.add_item(Prestamos.ETIQUETAS_DURACION[clave])
		option_cesion_duracion.set_item_metadata(option_cesion_duracion.item_count - 1, clave)
	fila_dur.add_child(option_cesion_duracion)

	var fila_fee := HBoxContainer.new()
	caja.add_child(fila_fee)
	fila_fee.add_child(_etiqueta("Fee"))
	spin_cesion_fee = SpinBox.new()
	spin_cesion_fee.min_value = 0
	spin_cesion_fee.max_value = 1000000000
	spin_cesion_fee.step = 1000
	spin_cesion_fee.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	fila_fee.add_child(spin_cesion_fee)
	_activar_formato_miles(spin_cesion_fee)
	label_cesion_fee = Label.new()
	label_cesion_fee.add_theme_color_override("font_color", Tema.SUAVE)
	fila_fee.add_child(label_cesion_fee)

	var fila_sueldo := HBoxContainer.new()
	caja.add_child(fila_sueldo)
	fila_sueldo.add_child(_etiqueta("Te cubren del sueldo"))
	slider_cesion_sueldo = HSlider.new()
	slider_cesion_sueldo.min_value = int(Prestamos.PORCENTAJE_SUELDO_MINIMO * 100.0)
	slider_cesion_sueldo.max_value = 100
	slider_cesion_sueldo.step = 5
	slider_cesion_sueldo.custom_minimum_size = Vector2(240, Tema.ALTO_TACTIL)
	fila_sueldo.add_child(slider_cesion_sueldo)
	label_cesion_sueldo = Label.new()
	fila_sueldo.add_child(label_cesion_sueldo)
	slider_cesion_sueldo.value_changed.connect(func(_v): _refrescar_cesion_numeros())

	var fila_opcion := HBoxContainer.new()
	caja.add_child(fila_opcion)
	check_cesion_opcion = CheckBox.new()
	check_cesion_opcion.text = "Con opcion de compra"
	fila_opcion.add_child(check_cesion_opcion)
	spin_cesion_opcion = SpinBox.new()
	spin_cesion_opcion.min_value = 0
	spin_cesion_opcion.max_value = 1000000000
	spin_cesion_opcion.step = 5000
	spin_cesion_opcion.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	fila_opcion.add_child(spin_cesion_opcion)
	_activar_formato_miles(spin_cesion_opcion)
	label_cesion_opcion = Label.new()
	label_cesion_opcion.add_theme_color_override("font_color", Tema.SUAVE)
	fila_opcion.add_child(label_cesion_opcion)

	var fila_plus := HBoxContainer.new()
	caja.add_child(fila_plus)
	fila_plus.add_child(_etiqueta("Plus al jugador"))
	spin_cesion_plus = SpinBox.new()
	spin_cesion_plus.min_value = 0
	spin_cesion_plus.max_value = 100000000
	spin_cesion_plus.step = 500
	spin_cesion_plus.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	fila_plus.add_child(spin_cesion_plus)
	_activar_formato_miles(spin_cesion_plus)
	label_cesion_plus = Label.new()
	label_cesion_plus.add_theme_color_override("font_color", Tema.SUAVE)
	fila_plus.add_child(label_cesion_plus)

	var fila_botones := HBoxContainer.new()
	caja.add_child(fila_botones)
	boton_cesion_aceptar = Button.new()
	boton_cesion_aceptar.text = "Aceptar"
	boton_cesion_aceptar.custom_minimum_size = Vector2(180, 48)
	boton_cesion_aceptar.pressed.connect(_on_cesion_aceptar)
	fila_botones.add_child(boton_cesion_aceptar)
	boton_cesion_contra = Button.new()
	boton_cesion_contra.text = "Contraofertar"
	boton_cesion_contra.custom_minimum_size = Vector2(180, 48)
	boton_cesion_contra.pressed.connect(_on_cesion_contraofertar)
	fila_botones.add_child(boton_cesion_contra)
	boton_cesion_rechazar = Button.new()
	boton_cesion_rechazar.text = "Rechazar"
	boton_cesion_rechazar.custom_minimum_size = Vector2(180, 48)
	boton_cesion_rechazar.pressed.connect(_on_cesion_rechazar)
	fila_botones.add_child(boton_cesion_rechazar)
	boton_cesion_retirar = Button.new()
	boton_cesion_retirar.text = "Echarse atrás"
	boton_cesion_retirar.custom_minimum_size = Vector2(180, 48)
	boton_cesion_retirar.pressed.connect(_on_cesion_retirar)
	fila_botones.add_child(boton_cesion_retirar)
	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(dialogo_cesion.hide)
	caja.add_child(cerrar)

	label_cesion_estado = RichTextLabel.new()
	label_cesion_estado.bbcode_enabled = true
	label_cesion_estado.fit_content = true
	label_cesion_estado.custom_minimum_size = Vector2(0, 52)
	caja.add_child(label_cesion_estado)


## Los topes del que pide, al lado de cada campo. Es la unica forma de
## saber hasta donde apretar sin quemar una ronda por prueba y error.
func _refrescar_cesion_numeros() -> void:
	var pct := int(slider_cesion_sueldo.value)
	label_cesion_sueldo.text = "%d%%" % pct
	if cesion_topes.is_empty():
		return
	var sueldo: float = float(cesion_topes["sueldo"])
	label_cesion_sueldo.text = "%d%% — te queda pagando %s" % [
		pct, Economia.formato_dinero(sueldo * (1.0 - pct / 100.0))]
	label_cesion_fee.text = "llegan hasta %s" % Economia.formato_dinero(cesion_topes["fee"])
	label_cesion_opcion.text = "llegan hasta %s" % Economia.formato_dinero(cesion_topes["opcion_compra"])
	label_cesion_plus.text = "llegan hasta %s" % Economia.formato_dinero(cesion_topes["plus_sueldo"])


func _abrir_cesion(o: Dictionary) -> void:
	cesion_oferta_id = int(o["id"])
	cesion_topes = GameState.topes_de_cesion(o)

	label_cesion_titulo.text = "%s (%s)" % [str(o["jugador"]), str(o["posicion"])]
	label_cesion_sub.text = "%s  ·  %s lo pide a prestamo  ·  ronda %d  ·  %s" % [
		_subtitulo_jugador_de_oferta(o), str(o["club"]), int(o["ronda"]), _estado_legible(o)]

	for i in range(option_cesion_duracion.item_count):
		if str(option_cesion_duracion.get_item_metadata(i)) == str(o["duracion"]):
			option_cesion_duracion.selected = i
	spin_cesion_fee.value = float(o["monto"])
	slider_cesion_sueldo.value = clampf(round(float(o["porcentaje_sueldo"]) * 100.0 / 5.0) * 5.0,
		slider_cesion_sueldo.min_value, 100.0)
	check_cesion_opcion.button_pressed = float(o["opcion_compra"]) > 0.0
	spin_cesion_opcion.value = float(o["opcion_compra"])
	spin_cesion_plus.value = float(o.get("plus_sueldo", 0.0))
	_refrescar_cesion_numeros()

	var me_toca: bool = str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS
	boton_cesion_aceptar.visible = me_toca
	boton_cesion_contra.visible = me_toca
	boton_cesion_rechazar.visible = me_toca
	# Igual que en las compras: si no te toca, Rechazar no aplica.
	boton_cesion_retirar.visible = not me_toca and Ofertas.abierta(o)
	option_cesion_duracion.disabled = not me_toca
	spin_cesion_fee.editable = me_toca
	slider_cesion_sueldo.editable = me_toca
	check_cesion_opcion.disabled = not me_toca
	spin_cesion_opcion.editable = me_toca
	spin_cesion_plus.editable = me_toca

	var historia := ""
	for linea in o["log"]:
		historia += "[color=#93a79b]%s[/color]\n" % str(linea)
	label_cesion_estado.text = historia
	dialogo_cesion.popup_centered()


func _terminos_de_cesion() -> Dictionary:
	return {
		"monto": float(spin_cesion_fee.value),
		"porcentaje_sueldo": float(slider_cesion_sueldo.value) / 100.0,
		"opcion_compra": float(spin_cesion_opcion.value) if check_cesion_opcion.button_pressed else 0.0,
		"plus_sueldo": float(spin_cesion_plus.value),
		"duracion": str(option_cesion_duracion.get_item_metadata(option_cesion_duracion.selected)),
	}


func _on_cesion_aceptar() -> void:
	var r := GameState.responder_oferta(cesion_oferta_id, "aceptar")
	if not r["exito"]:
		label_cesion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	label_cesion_estado.text = "[color=#27ae60]Aceptaste. Ahora falta que el jugador quiera ir.[/color]"
	boton_cesion_aceptar.visible = false
	boton_cesion_contra.visible = false
	boton_cesion_rechazar.visible = false
	_mostrar_solapa_mercado(solapa_mercado_actual)


func _on_cesion_contraofertar() -> void:
	var r := GameState.contraofertar_cesion(cesion_oferta_id, _terminos_de_cesion())
	if not r["exito"]:
		label_cesion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	dialogo_cesion.hide()
	_mostrar_solapa_mercado(solapa_mercado_actual)


func _on_cesion_retirar() -> void:
	var r := GameState.retirar_oferta(cesion_oferta_id)
	if not r["exito"]:
		label_cesion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	dialogo_cesion.hide()
	_mostrar_solapa_mercado(solapa_mercado_actual)


func _on_cesion_rechazar() -> void:
	var r := GameState.responder_oferta(cesion_oferta_id, "rechazar")
	if not r["exito"]:
		label_cesion_estado.text = "[color=#ffcf43]%s[/color]" % r["motivo"]
		return
	dialogo_cesion.hide()
	_mostrar_solapa_mercado(solapa_mercado_actual)
