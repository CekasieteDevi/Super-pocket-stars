extends Control

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
## De que club es el jugador de la ficha. null = uno propio. Si es ajeno,
## la ficha se dibuja en modo AJENO: sin lo que solo sabe un club de su
## propia gente y sin las habilidades dormidas (ver _refrescar_ficha).
var ficha_club: Team = null
var boton_volver_ficha: Button
var option_formacion: OptionButton
var barra_familiaridad: ProgressBar
var label_familiaridad: Label
var label_carga_efecto: Label
var contenedor_formacion: VBoxContainer
var cancha_formacion: CanchaFormacion
var label_formacion_estado: Label
## Jugador tocado primero en la pantalla de formacion, a la espera del
## segundo para intercambiarlos. -1 = nadie seleccionado.
var contenedor_tabla: VBoxContainer
var _fila_propia_tabla: Control = null
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
var option_estilo: OptionButton
var option_cambios: OptionButton

const OPCIONES_CAMBIOS := ["equilibrado", "descanso", "rendimiento"]
const ETIQUETAS_CAMBIOS := {"equilibrado": "Equilibrado", "descanso": "Priorizar descanso", "rendimiento": "Priorizar rendimiento"}
var vista_partido: VistaPartido
var resumen_partido: CenterContainer
var contenedor_resumen: VBoxContainer
var contenedor_economia: VBoxContainer
var lista_cantera: RichTextLabel
var contenedor_cantera_botones: VBoxContainer
var contenedor_noticias: VBoxContainer
var noticias_solapa: String = "todas"
var botones_solapa_noticias: Dictionary = {}
var capa_modal_jugador: CanvasLayer
var contenedor_modal_jugador: VBoxContainer
var modal_jugador_id: int = -1
var label_modal_jugador_estado: String = ""
var label_mercado_estado: Label
var contenedor_libres_botones: VBoxContainer
var label_libres_estado: Label
var contenedor_prestamos_ceder_botones: VBoxContainer
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
var campo_nombre_club: LineEdit
var fila_camiseta: HBoxContainer
var fila_short: HBoxContainer
var boton_comenzar: Button
var boton_cargar_inicio: Button
var label_inicio_estado: Label
var color_camiseta_elegido := 0
var color_short_elegido := 8
var dialogo_borrar_partida: ConfirmationDialog
var boton_partida_nueva: Button
var dialogo_partida_nueva: ConfirmationDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# El sistema visual entero vive en ui/tema.gd y se hereda desde la raiz.
	theme = Tema.construir()

	# Raiz apaisada: el riel de secciones al COSTADO y el contenido al lado.
	# Al costado y no abajo porque el alto (648 px logicos) es lo escaso en
	# apaisado, mientras que a lo ancho sobra.
	var raiz := HBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	_construir_riel(raiz)

	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(columna)

	_construir_barra_contexto(columna)

	var sub_scroll := ScrollContainer.new()
	sub_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sub_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_child(sub_scroll)
	barra_subsolapas = HBoxContainer.new()
	sub_scroll.add_child(barra_subsolapas)

	var margen := MarginContainer.new()
	margen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margen.add_theme_constant_override("margin_bottom", 10)
	margen.add_theme_constant_override("margin_right", 10)
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
	_construir_panel_entrenamiento(contenedor)
	_construir_panel_partido_animado(contenedor)
	_construir_panel_economia(contenedor)
	_construir_panel_mercado(contenedor)
	_construir_panel_libres(contenedor)
	_construir_panel_prestamos(contenedor)
	_construir_panel_instalaciones(contenedor)
	_construir_panel_seleccion(contenedor)
	_construir_panel_cantera(contenedor)
	_construir_panel_noticias(contenedor)
	_construir_panel_partida_guardado(contenedor)
	_construir_panel_ficha(contenedor)
	_construir_panel_formacion(contenedor)
	_construir_dialogo_novedades()
	_construir_dialogo_negociacion()
	_construir_dialogo_prestamo()
	_construir_dialogo_investigador()

	# Al final, cuando ya esta todo construido: deja las listas
	# deslizables con el dedo (ver _ajustar_para_tactil).
	_ajustar_para_tactil(self)

	_construir_modal_jugador()
	_construir_pantalla_inicio()
	_mostrar_seccion("club")
	_mostrar_inicio()


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
	caja.custom_minimum_size = Vector2(560, 0)
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

	formulario_inicio.add_child(Tema.etiqueta_seccion("Camiseta"))
	fila_camiseta = _fila_de_colores(true)
	formulario_inicio.add_child(fila_camiseta)

	formulario_inicio.add_child(Tema.etiqueta_seccion("Pantalón"))
	fila_short = _fila_de_colores(false)
	formulario_inicio.add_child(fila_short)

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
	boton_comenzar.text = "Comenzar"
	boton_comenzar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton_comenzar.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	Tema.primario(boton_comenzar)
	boton_comenzar.pressed.connect(_on_comenzar_partida)
	acciones.add_child(boton_comenzar)


## Los diez colores como botones cuadrados. Se marca el elegido con un
## borde ambar: sobre una fila de colores, cualquier otra señal (un tilde,
## una sombra) se pierde contra el propio color del boton.
func _fila_de_colores(es_camiseta: bool) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	for i in range(ColoresClub.PALETA.size()):
		var c: Color = ColoresClub.PALETA[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.tooltip_text = ColoresClub.NOMBRES[i]
		_pintar_muestra(b, c, false)
		var idx := i
		b.pressed.connect(func():
			if es_camiseta:
				color_camiseta_elegido = idx
			else:
				color_short_elegido = idx
			_refrescar_colores_elegidos())
		fila.add_child(b)
	return fila


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
	for i in range(fila_camiseta.get_child_count()):
		_pintar_muestra(fila_camiseta.get_child(i), ColoresClub.PALETA[i],
			i == color_camiseta_elegido)
	for i in range(fila_short.get_child_count()):
		_pintar_muestra(fila_short.get_child(i), ColoresClub.PALETA[i],
			i == color_short_elegido)
	_validar_club_nuevo()


## Comenzar solo se habilita con un nombre usable, y si no lo es dice por
## que: un boton apagado y mudo se lee como un boton roto.
func _validar_club_nuevo() -> void:
	var nombre := campo_nombre_club.text.strip_edges()
	var motivo := ""
	if nombre == "":
		motivo = "Poné el nombre de tu club."
	elif GameState.piramide != null and GameState.piramide.existe_nombre(nombre):
		motivo = "Ya hay un club con ese nombre en la pirámide. Elegí otro."
	elif color_camiseta_elegido == color_short_elegido:
		motivo = "La camiseta y el pantalón no pueden ser del mismo color."
	boton_comenzar.disabled = motivo != ""
	label_inicio_estado.text = motivo


func _mostrar_inicio() -> void:
	capa_inicio.visible = true
	menu_inicio.visible = true
	formulario_inicio.visible = false
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
	GameState.partida_nueva(-1, campo_nombre_club.text.strip_edges(),
		ColoresClub.PALETA[color_camiseta_elegido],
		ColoresClub.PALETA[color_short_elegido])
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
	_refrescar_partida_guardado()
	capa_inicio.visible = false
	_mostrar_seccion("club")


## Fix 10: nombre y apellido del jugador, para las listas de la UI.
func _nombre_jugador(j: Dictionary) -> String:
	return "%s %s" % [j.get("nombre", "?"), j.get("apellido", "")]


## §5: si tiene una habilidad, la muestra con una estrella por nivel
## (bronce=★, plata=★★, oro=★★★) — atenuada entre parentesis si todavia
## no se manifesto (no llego a la media minima) para que se note que esta
## "dormida", no activa.
## `ajeno` = es un jugador de otro club, y ahi una habilidad DORMIDA no se
## muestra — ver BusquedaMercado.habilidad_visible.
func _tag_habilidad(j: Dictionary, ajeno: bool = false) -> String:
	var h: Dictionary = BusquedaMercado.habilidad_visible(j, ajeno)
	if h.is_empty():
		return ""
	var estrellas := "★".repeat(h.get("nivel", 1))
	if Habilidades.tiene_manifestada(j, h["nombre"]):
		return "  [%s %s]" % [h["nombre"], estrellas]
	return "  (%s %s, dormida)" % [h["nombre"], estrellas]


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

	# Estilo de juego y cambios automaticos viven ACA, con el plantel: son
	# decisiones sobre los once que van a jugar. Estaban en la pantalla de
	# resultados, que es donde se MIRA lo que ya paso.
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 12)
	raiz.add_child(barra)

	option_estilo = OptionButton.new()
	for estilo in Estilos.LISTA:
		option_estilo.add_item(estilo)
	option_estilo.custom_minimum_size = Vector2(190, Tema.ALTO_TACTIL)
	option_estilo.item_selected.connect(_on_estilo_seleccionado)
	barra.add_child(_grupo_filtro("Estilo de juego", option_estilo))

	option_cambios = OptionButton.new()
	for opcion in OPCIONES_CAMBIOS:
		option_cambios.add_item(ETIQUETAS_CAMBIOS[opcion])
	option_cambios.custom_minimum_size = Vector2(230, Tema.ALTO_TACTIL)
	option_cambios.item_selected.connect(_on_config_cambios_seleccionado)
	barra.add_child(_grupo_filtro("Cambios automaticos", option_cambios))

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

	contenedor_lista_plantel.add_child(Tema.etiqueta_seccion("Banco (%d)" % equipo.banco.size()))
	for i in range(equipo.banco.size()):
		contenedor_lista_plantel.add_child(_fila_jugador(equipo, equipo.banco[i], i % 2 == 0, true))

	_refrescar_ficha_lateral()


## Una fila del plantel. TODA la fila es tocable, no solo el nombre.
func _fila_jugador(equipo: Team, j: Dictionary, par: bool, es_banco: bool) -> Control:
	var id := int(j["id"])
	var elegido := id == plantel_elegido
	var fila := Componentes.fila(par or elegido)
	if elegido:
		var estilo: StyleBoxFlat = fila.get_theme_stylebox("panel")
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
	btn.custom_minimum_size = Vector2(0, Tema.ALTO_TACTIL)
	btn.pressed.connect(func():
		plantel_elegido = id
		_refrescar_plantel()
	)
	dentro.add_child(btn)

	if id == equipo.capitan_id:
		dentro.add_child(Componentes.chip("C", Tema.AMBAR, Tema.FONDO))
	if bool(j.get("es_canterano", false)):
		dentro.add_child(Componentes.chip("cantera", Color("#2a3a4a"), Tema.CELESTE))

	dentro.add_child(Componentes.celda_numero("%.1f" % float(j["media"]), 62))
	dentro.add_child(Componentes.celda("→%d" % int(j["potencial"]), 52, Tema.SUAVE))

	# Estado: lo unico que hace falta saber de un vistazo al armar el equipo.
	var estado := "Listo"
	var color := Tema.VERDE
	if equipo.esta_lesionado(id):
		var les: Dictionary = equipo.lesiones[id]
		estado = "%d d" % int(les["dias_restantes"])
		color = Tema.ROJO
	elif int(equipo.suspendidos.get(id, 0)) > 0:
		estado = "Susp."
		color = Tema.ROJO
	dentro.add_child(Componentes.celda(estado, 66, color))

	# Ficha y no "Subir": cambiar jugadores de lugar se hace arrastrando en
	# Formacion, que es donde se ve la cancha. Tener las dos formas en dos
	# pantallas distintas confundia mas de lo que ayudaba.
	var btn_ficha := Button.new()
	btn_ficha.text = "Ficha"
	btn_ficha.custom_minimum_size = Vector2(84, 0)
	btn_ficha.pressed.connect(func(): _mostrar_ficha(id))
	dentro.add_child(btn_ficha)
	return fila


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

	var titulo := Label.new()
	titulo.text = _nombre_jugador(j)
	Tema.numero(titulo, 24)
	caja.add_child(titulo)

	var sub := Label.new()
	sub.text = "%s  ·  %d años  ·  %s" % [j["posicion"], int(j["edad"]), j["genetica_tier"]]
	sub.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(sub)

	var rasgos: Dictionary = j.get("personalidades", {})
	if not rasgos.is_empty():
		var fila_rasgos := HBoxContainer.new()
		caja.add_child(fila_rasgos)
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
		caja.add_child(l)

	# Los tres numeros que se miran primero.
	var fila_nums := HBoxContainer.new()
	caja.add_child(fila_nums)
	fila_nums.add_child(_caja_numero("Media", "%.1f" % float(j["media"]), Tema.TEXTO))
	fila_nums.add_child(_caja_numero("Techo", str(int(j["potencial"])), Tema.AMBAR))
	var animo := int(equipo.animo.get(plantel_elegido, 50))
	fila_nums.add_child(_caja_numero("Ánimo", str(animo), Componentes.color_de_valor(animo)))

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
		fondo.bg_color = Color("#2a3a33")
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
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	caja.add_theme_stylebox_override("panel", estilo)
	var dentro := VBoxContainer.new()
	caja.add_child(dentro)
	dentro.add_child(Tema.etiqueta_seccion(etiqueta))
	var l := Label.new()
	l.text = valor
	Tema.numero(l, 26, color)
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
	boton_volver_ficha.pressed.connect(func():
		if ficha_club != null:
			_mostrar_mercado()
		else:
			_mostrar_plantel()
	)
	panel.add_child(boton_volver_ficha)

	# Todo se repinta de cero en _refrescar_ficha: la ficha cambia entera
	# entre un jugador y otro (un arquero trae seis atributos mas) y no
	# hay nada que valga la pena conservar entre una y otra.
	contenedor_ficha = VBoxContainer.new()
	contenedor_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor_ficha.add_theme_constant_override("separation", 8)
	panel.add_child(contenedor_ficha)


## club = null para uno propio; el Team dueño si es ajeno (viene del
## mercado, y solo se llega hasta aca con el informe terminado).
func _mostrar_ficha(jugador_id: int, club: Team = null) -> void:
	ficha_jugador_id = jugador_id
	ficha_club = club
	_ocultar_todos()
	paneles["ficha"].visible = true
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
	boton_volver_ficha.text = "< Volver al mercado" if ajeno else "< Volver al plantel"

	# De un ajeno solo se llega hasta aca con el informe terminado, pero se
	# vuelve a chequear igual: la ficha se puede quedar abierta mientras
	# pasa el tiempo y el jugador puede haber cambiado de club.
	if ajeno and not Investigadores.conoce(GameState.equipo_jugador, ficha_jugador_id):
		contenedor_ficha.add_child(_texto_suave("Todavia no lo investigaste."))
		return

	# _buscar_jugador_por_id ya mira titulares, banco y cantera.
	var j := _buscar_jugador_por_id(equipo, ficha_jugador_id)
	if j.is_empty():
		contenedor_ficha.add_child(_texto_suave(
			"Ese jugador ya no esta en %s." % (equipo.nombre if ajeno else "el plantel")))
		return

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

	# Rasgos y habilidad en la misma linea: son tres chips, no tres
	# parrafos, y arriba de todo hay que ahorrar alto.
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
	if ajeno:
		nums.add_child(_caja_numero("Valor", Economia.formato_dinero(
			ValorJugador.calcular(j, equipo.animo.get(id, 50.0),
				equipo.contratos.get(id, 3))), Tema.VERDE))
	else:
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
	if equipo.clausulas.has(id):
		pie.append("cláusula %s" % Economia.formato_dinero(equipo.clausulas[id]))
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
## un desplegable por slot: con 18 jugadores un OptionButton por fila son
## 18 listas de 18, y en un celular eso no se toca.
func _construir_panel_formacion(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["formacion"] = panel

	# Los tres controles en UNA fila y sus explicaciones en el tooltip: en
	# tres filas con su texto debajo se comian 200 px de alto y la cancha
	# —que es el contenido de esta pantalla— quedaba cortada.
	var fila := HBoxContainer.new()
	panel.add_child(fila)

	fila.add_child(Tema.etiqueta_seccion("Formación"))
	option_formacion = OptionButton.new()
	for nombre in Formaciones.lista():
		option_formacion.add_item(nombre)
	option_formacion.item_selected.connect(_on_formacion_elegida)
	fila.add_child(option_formacion)

	# Carga y foco se mudaron a la solapa Entrenamiento. Aca eran dos
	# desplegables sin explicacion al lado del selector tactico, como si
	# fueran parte de armar el equipo: nadie entendia que hacian.

	# §7.4.5: cuanto conoce el equipo la tactica puesta. Va PEGADO a los
	# desplegables que la cambian: es el dato con el que se decide si el
	# cambio conviene, y verlo despues de cambiar llega tarde.
	var caja_fam := HBoxContainer.new()
	caja_fam.add_theme_constant_override("separation", 10)
	panel.add_child(caja_fam)
	var titulo_fam := Tema.etiqueta_seccion("Familiaridad tactica")
	titulo_fam.custom_minimum_size = Vector2(200, 0)
	caja_fam.add_child(titulo_fam)
	barra_familiaridad = ProgressBar.new()
	barra_familiaridad.min_value = 0.0
	barra_familiaridad.max_value = 100.0
	barra_familiaridad.show_percentage = false
	barra_familiaridad.custom_minimum_size = Vector2(240, 8)
	barra_familiaridad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo_fam := StyleBoxFlat.new()
	fondo_fam.bg_color = Color("#2a3a33")
	barra_familiaridad.add_theme_stylebox_override("background", fondo_fam)
	caja_fam.add_child(barra_familiaridad)
	label_familiaridad = Label.new()
	label_familiaridad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_familiaridad.clip_text = true
	label_familiaridad.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	caja_fam.add_child(label_familiaridad)

	var pie := HBoxContainer.new()
	panel.add_child(pie)

	label_formacion_estado = Label.new()
	label_formacion_estado.text = "Arrastrá un jugador sobre otro para cambiarlos de lugar."
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
	pie.add_child(label_carga_efecto)

	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(cuerpo)

	cancha_formacion = CanchaFormacion.new()
	cancha_formacion.intercambio_pedido.connect(_on_intercambio_arrastrado)
	cuerpo.add_child(cancha_formacion)

	# El banco al costado y no abajo: tiene que ser un destino de arrastre
	# visible al mismo tiempo que la cancha, si no hay que soltar a ciegas.
	var lado := VBoxContainer.new()
	lado.custom_minimum_size = Vector2(CuboJugador.ANCHO + 34, 0)
	cuerpo.add_child(lado)
	lado.add_child(Tema.etiqueta_seccion("Banco"))
	var scroll_banco := ScrollContainer.new()
	scroll_banco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lado.add_child(scroll_banco)
	contenedor_formacion = VBoxContainer.new()
	scroll_banco.add_child(contenedor_formacion)


func _mostrar_formacion() -> void:
	_ocultar_todos()
	paneles["formacion"].visible = true
	_refrescar_formacion()


## §7.4.1: la carga se elige entre fecha y fecha. Lo que decide la
## progresión es el PROMEDIO de la temporada, así que bajarla una semana
## apretada no arruina el año.
func _on_carga_elegida(idx: int) -> void:
	GameState.equipo_jugador.carga_entrenamiento = CargaEntrenamiento.NIVELES[idx]
	_refrescar_formacion()


## §7.4.2: se puede cambiar cuando quieras. Lo que pesa al cierre de
## temporada es cuantas SEMANAS estuvo puesta cada area, asi que cambiar a
## mitad de año reparte en vez de reiniciar.
func _on_foco_equipo_elegido(idx: int) -> void:
	GameState.equipo_jugador.foco_equipo = FocoEquipo.AREAS[idx]
	_refrescar_formacion()


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


## Cuanto pesa cada area en lo que va de la temporada. Sin esto, cambiar
## de foco a mitad de año no se ve por ningun lado.
func _reparto_foco_texto(equipo: Team) -> String:
	var reparto := equipo.reparto_foco()
	if reparto.size() <= 1:
		return ""
	var partes := []
	for area in reparto:
		partes.append("%s %d%%" % [FocoEquipo.ETIQUETAS.get(area, area), int(round(float(reparto[area]) * 100.0))])
	return "
   Temporada hasta ahora: %s" % ", ".join(partes)


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
	label_familiaridad.tooltip_text = "Cada formacion + estilo se entrena por separado. Un plan nuevo arranca en frio y resta hasta que el equipo lo asimila; el foco de equipo tactico lo acelera. Cambiar solo una de las dos mitades arrastra parte de lo que ya sabias."


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
	# depende del foco, asi que el dato tiene que estar a mano.
	label_carga_efecto.text = "Carga %s  ·  foco %s" % [
		CargaEntrenamiento.ETIQUETAS.get(equipo.carga_entrenamiento, "?"),
		FocoEquipo.ETIQUETAS.get(equipo.foco_equipo, "?")]
	label_carga_efecto.tooltip_text = _texto_carga(equipo)

	_refrescar_familiaridad(equipo)

	cancha_formacion.mostrar(equipo)

	for hijo in contenedor_formacion.get_children():
		hijo.queue_free()
	for j in equipo.banco:
		var cubo := CuboJugador.crear(j, str(j["posicion"]), equipo, true)
		cubo.intercambio_pedido.connect(_on_intercambio_arrastrado)
		contenedor_formacion.add_child(cubo)

	# La RESERVA no se arrastra a la cancha, y es a proposito: un canterano
	# no es parte del plantel de 18. Para usarlo hay que promoverlo, y eso
	# tiene un costo real —desplaza al peor del banco, que queda libre— asi
	# que es una decision, no un arrastre.
	if not equipo.cantera.is_empty():
		contenedor_formacion.add_child(Tema.etiqueta_seccion("Reserva"))
		var aclaracion := Label.new()
		aclaracion.text = "No juegan hasta promoverlos: el promovido entra al banco y el peor suplente queda libre."
		aclaracion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aclaracion.add_theme_color_override("font_color", Tema.SUAVE)
		aclaracion.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		contenedor_formacion.add_child(aclaracion)
		for j in equipo.cantera:
			var caja := VBoxContainer.new()
			caja.add_theme_constant_override("separation", 2)
			contenedor_formacion.add_child(caja)
			var cubo := CuboJugador.crear(j, str(j["posicion"]), equipo, true)
			# Sin arrastre: no hay a donde soltarlo que signifique algo.
			cubo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cubo.modulate = Color(1, 1, 1, 0.72)
			caja.add_child(cubo)
			var id_j := int(j["id"])
			var btn := Button.new()
			btn.text = "Promover"
			btn.pressed.connect(func(): _on_promover_desde_formacion(id_j))
			caja.add_child(btn)


func _on_promover_desde_formacion(jugador_id: int) -> void:
	var r := GameState.equipo_jugador.promover_juvenil(jugador_id)
	if r.is_empty():
		label_formacion_estado.text = "No se pudo promover a ese juvenil."
		return
	label_formacion_estado.text = "%s sube al banco; queda libre %s." % [
		_nombre_jugador(r["promovido"]), _nombre_jugador(r["saliente"])]
	_refrescar_formacion()
	_refrescar_plantel()


## Arrastraste uno sobre otro: se intercambian, esten en la cancha o en el
## banco. Team.intercambiar ya sabia hacer las dos cosas.
func _on_intercambio_arrastrado(id_origen: int, id_destino: int) -> void:
	if GameState.equipo_jugador.intercambiar(id_origen, id_destino):
		_refrescar_formacion()
		_refrescar_plantel()


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
		if soy_yo:
			_fila_propia_tabla = fila
		pos += 1

	_centrar_tabla_en_mi_club.call_deferred()


## Deja tu fila a la vista al abrir. Va diferido porque recien despues de
## que el contenedor se acomoda las filas tienen posicion: pedido en el
## mismo cuadro, todas estan en y=0 y el scroll no se mueve.
func _centrar_tabla_en_mi_club() -> void:
	if _fila_propia_tabla == null or not is_instance_valid(_fila_propia_tabla):
		return
	var scroll := _fila_propia_tabla.get_parent().get_parent() as ScrollContainer
	if scroll == null:
		return
	scroll.scroll_vertical = int(maxf(0.0,
		_fila_propia_tabla.position.y - scroll.size.y * 0.5))


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
		dentro.add_child(Componentes.celda(
			str(f["nombre"]), Componentes.COL_NOMBRE + 40, color))
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
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["partido_animado"] = panel

	vista_partido = VistaPartido.new()
	vista_partido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vista_partido)
	vista_partido.hud.menu_pedido.connect(_volver_al_club)
	# Al terminar NO se cierra solo. Aparece el resumen encima de la
	# cancha y de ahi se sale a mano: cerrar de una no dejaba ver el
	# ultimo minuto ni enterarse de como termino.
	vista_partido.terminado.connect(func():
		if paneles["partido_animado"].visible:
			_mostrar_resumen_partido())

	_construir_resumen_partido(panel)


## El cuadro de fin de partido: marcador grande y las estadisticas.
##
## Va ENCIMA de la cancha y no en otra pantalla, para poder mirar el
## ultimo fotograma mientras se leen los numeros.
func _construir_resumen_partido(padre: Control) -> void:
	resumen_partido = CenterContainer.new()
	resumen_partido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resumen_partido.visible = false
	padre.add_child(resumen_partido)

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
	marcador.text = "%s   %d - %d   %s" % [r["local"], r["gl"], r["gv"], r["visitante"]]
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
	if propios > ajenos:
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
		_volver_al_club())
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
	var local := _equipo_de_la_liga(str(r.get("local", "")))
	var visitante := _equipo_de_la_liga(str(r.get("visitante", "")))
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
## unico que se puede gastar hoy; lo asignado y lo gastado van abajo,
## chicos, y la barra los muestra de un vistazo.
func _caja_presupuesto(categoria: String, asignado: float, usado: float,
		restante: float) -> Control:
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
	barra.value = clampf(usado / asignado, 0.0, 1.0) if asignado > 0.0 else 0.0
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 6)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("#2a3a33")
	barra.add_theme_stylebox_override("background", fondo)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Tema.ROJO if restante < 0.0 else Tema.AMBAR
	barra.add_theme_stylebox_override("fill", relleno)
	dentro.add_child(barra)

	var pie := Label.new()
	pie.text = "gastaste %s de %s" % [
		Economia.formato_dinero(usado), Economia.formato_dinero(asignado)]
	pie.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	pie.add_theme_color_override("font_color", Tema.SUAVE)
	pie.clip_text = true
	dentro.add_child(pie)
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
		var usado: float = equipo.caja_al_cierre.get(categoria, 0.0) - restante
		grilla.add_child(_caja_presupuesto(
			str(categoria).capitalize(), asignado, usado, restante))

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
		vacio.text = "Todavia no cerraste una temporada. La plata entra al terminar la fecha 38: entradas, sponsor y premio segun donde termines en la tabla."
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vacio.add_theme_color_override("font_color", Tema.SUAVE)
		caja_balance.add_child(vacio)
	else:
		caja_balance.add_child(_linea_balance(
			"Ingresos", informe["ingresos"], Tema.VERDE, 0, true))
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
	fila_club.add_child(_caja_numero("Hinchas", "%.1f" % equipo.fans,
		Componentes.color_de_valor(int(equipo.fans))))
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
	filtros.add_child(_grupo_filtro("Division", option_div_mercado))

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
func _on_buscar_mercado() -> void:
	filtros_mercado = {
		"posicion": "" if option_pos_mercado.selected <= 0 else option_pos_mercado.get_item_text(option_pos_mercado.selected),
		"division": option_div_mercado.selected - 1,
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

	contenedor_mercado_tabla.add_child(_encabezado_mercado())
	# Un tope: la piramide tiene ~3.600 jugadores y dibujarlos a todos cuelga
	# la pantalla. Con los filtros y el orden, 60 alcanzan.
	for i in range(min(60, fichas.size())):
		contenedor_mercado_tabla.add_child(_fila_mercado(fichas[i], i % 2 == 0))


## El encabezado. Cada columna visible es un boton que ordena; las tapadas
## no, porque ordenar por algo que no conoces no significa nada.
func _encabezado_mercado() -> Control:
	var fila := Componentes.fila(false)
	var dentro := Componentes.contenido(fila)
	for col in BusquedaMercado.COLUMNAS:
		var clave := str(col["clave"])
		var ancho: int = _ancho_de_columna(clave)
		var btn := Button.new()
		btn.text = str(col["titulo"])
		if orden_mercado == clave:
			btn.text += "  ↑" if orden_mercado_asc else "  ↓"
		btn.custom_minimum_size = Vector2(ancho, 0)
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", Componentes.TAM_TABLA)
		btn.add_theme_color_override("font_color",
			Tema.AMBAR if orden_mercado == clave else Tema.SUAVE)
		btn.pressed.connect(func(): _on_ordenar_mercado(clave))
		dentro.add_child(btn)
	dentro.add_child(Componentes.celda("Club", Componentes.COL_CLUB, Tema.SUAVE,
		HORIZONTAL_ALIGNMENT_LEFT, Componentes.TAM_TABLA))
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
	return 90


func _fila_mercado(f: Dictionary, par: bool) -> Control:
	var equipo := GameState.equipo_jugador
	var fila := Componentes.fila(par)
	var dentro := Componentes.contenido(fila)
	var vendedor: Team = f["equipo"]
	var jugador_id := int(f["id"])
	var conocido: bool = bool(f["conocido"])

	# Nombre: entra a la ficha, pero solo si lo investigaste.
	var btn_nombre := Button.new()
	btn_nombre.text = str(f["nombre"])
	btn_nombre.tooltip_text = str(f["nombre"])
	btn_nombre.custom_minimum_size = Vector2(Componentes.COL_NOMBRE, 0)
	btn_nombre.add_theme_font_size_override("font_size", Componentes.TAM_TABLA)
	btn_nombre.flat = true
	btn_nombre.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn_nombre.clip_text = true
	btn_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_nombre.disabled = not conocido
	if conocido:
		btn_nombre.add_theme_color_override("font_color", Tema.CELESTE)
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
	var btn_inv := Button.new()
	btn_inv.custom_minimum_size = Vector2(Componentes.COL_ACCION, 0)
	btn_inv.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	if conocido:
		var quedan := Investigadores.vigencia(equipo, jugador_id)
		btn_inv.text = "Vence pronto" if quedan < 120 else "Conocido"
		btn_inv.tooltip_text = "El informe vence en %d días." % quedan
		btn_inv.disabled = true
	elif float(f["progreso"]) >= 0.0:
		btn_inv.text = "En curso"
		btn_inv.disabled = true
	else:
		btn_inv.text = "Investigar"
		btn_inv.disabled = Investigadores.libres(equipo).is_empty()
		if btn_inv.disabled:
			btn_inv.tooltip_text = "No tenes investigadores libres. Se contratan en Equipo › Instalaciones."
		btn_inv.add_theme_color_override("font_color", Tema.AMBAR)
		btn_inv.pressed.connect(func(): _on_investigar(vendedor, jugador_id))
	dentro.add_child(btn_inv)

	var negociando := false
	for o in equipo.ofertas:
		if int(o["jugador_id"]) == jugador_id and Ofertas.abierta(o):
			negociando = true

	if Negociacion.bloqueado(vendedor, jugador_id, GameState.temporada_actual):
		dentro.add_child(_boton_fichar_apagado("Vetado",
			"Te ofendieron con la ultima oferta. Vuelven a escucharte la temporada que viene."))
	elif negociando:
		dentro.add_child(_boton_fichar_apagado("En curso",
			"Ya tenes una negociacion abierta por el. Miralo en Ofertas enviadas."))
	else:
		var menu := MenuButton.new()
		menu.text = "Fichar"
		menu.custom_minimum_size = Vector2(Componentes.COL_FICHAR, 0)
		menu.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		menu.flat = false
		var pop := menu.get_popup()
		pop.add_item("Comprar", 0)
		pop.add_item("Pedir a préstamo", 1)
		pop.id_pressed.connect(func(id: int):
			if id == 0:
				_abrir_negociacion(vendedor, jugador_id)
			else:
				_abrir_prestamo(vendedor, jugador_id)
		)
		dentro.add_child(menu)
	return fila


## El lugar del boton Fichar cuando no se puede fichar. Ocupa el MISMO
## ancho: si desapareciera, la fila se desalinearia con las de al lado.
func _boton_fichar_apagado(texto: String, ayuda: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = ayuda
	b.disabled = true
	b.custom_minimum_size = Vector2(Componentes.COL_FICHAR, 0)
	b.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	return b



## Cuantos dias le faltan al informe de este jugador. -1 si no hay ninguno.
func _dias_que_faltan(equipo: Team, jugador_id: int) -> int:
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == jugador_id:
			return int(ceil(
				Investigadores.dias_de_informe(int(inv["estrellas"])) - float(inv["dias"])))
	return -1


## §9.4: la solapa de INVESTIGACIONES — a quien estas mirando y a quien
## ya conoces. Contratar y despedir investigadores no vive aca sino en
## Instalaciones, que es donde se decide en que gasta el club.
##
## Los conocidos van ordenados por lo que les queda de vigencia, del que
## esta por vencer al que recien empieza: lo accionable primero.
## Mercado › Investigaciones: a quien estas mirando y a quien ya conoces.
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

	var libres := 0
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == -1:
			libres += 1

	var cabecera := Componentes.tarjeta(
		Tema.ROJO if equipo.investigadores.is_empty() else Color.TRANSPARENT)
	contenedor_investigaciones.add_child(cabecera)
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
		_mostrar_seccion("equipo")
		_mostrar_panel_de_seccion("instalaciones")
	)
	fila_cab.add_child(btn_contratar)

	# --- En curso ----------------------------------------------------------
	contenedor_investigaciones.add_child(Tema.etiqueta_seccion("Informes en curso"))
	var en_curso := 0
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == -1:
			continue
		en_curso += 1
		var total := Investigadores.dias_de_informe(int(inv["estrellas"]))
		var pct: float = float(inv["dias"]) / total if total > 0.0 else 0.0
		var faltan: int = int(ceil(total - float(inv["dias"])))
		var quien := str(inv.get("nombre_objetivo", ""))
		if quien == "":
			quien = "un jugador"

		var tarjeta := Componentes.tarjeta(Tema.AMBAR)
		contenedor_investigaciones.add_child(tarjeta)
		var fila := HBoxContainer.new()
		tarjeta.add_child(fila)

		var datos := VBoxContainer.new()
		datos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		datos.add_theme_constant_override("separation", 3)
		fila.add_child(datos)
		var l_nombre := Label.new()
		l_nombre.text = quien
		l_nombre.clip_text = true
		l_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		datos.add_child(l_nombre)
		var l_club := Label.new()
		l_club.text = "%s   ·   investigador de %d★" % [
			str(inv.get("club_objetivo", "")), int(inv["estrellas"])]
		l_club.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		l_club.add_theme_color_override("font_color", Tema.SUAVE)
		datos.add_child(l_club)
		datos.add_child(Componentes.bloque_investigando(0, pct, faltan))

		var id_inv := int(inv["id"])
		var btn := Button.new()
		btn.text = "Cancelar"
		btn.custom_minimum_size = Vector2(150, Tema.ALTO_TACTIL)
		btn.tooltip_text = "Se pierde lo avanzado: el investigador vuelve a quedar libre."
		btn.pressed.connect(func():
			Investigadores.cancelar(equipo, id_inv)
			_refrescar_investigaciones()
		)
		fila.add_child(btn)

	if en_curso == 0:
		contenedor_investigaciones.add_child(_tarjeta_vacia(
			"Nadie bajo la lupa. Los investigadores libres estan esperando orden: elegi a quien mirar desde la solapa Jugadores."))

	# --- Conocidos ---------------------------------------------------------
	contenedor_investigaciones.add_child(Tema.etiqueta_seccion(
		"Conocidos (%d)  ·  un informe dura %d dias y despues el jugador vuelve a quedar tapado" % [
			equipo.conocimiento.size(), Investigadores.DIAS_VIGENCIA]))

	if equipo.conocimiento.is_empty():
		contenedor_investigaciones.add_child(_tarjeta_vacia(
			"Todavia no terminaste ningun informe."))
		return

	# Ordenados por lo que les queda: el que esta por vencer primero, que es
	# el unico que pide una decision.
	var conocidos := []
	for id in equipo.conocimiento:
		conocidos.append({"id": int(id), "dias": float(equipo.conocimiento[id])})
	conocidos.sort_custom(func(a, b): return float(a["dias"]) < float(b["dias"]))

	contenedor_investigaciones.add_child(_encabezado_conocidos())
	for i in range(conocidos.size()):
		var c: Dictionary = conocidos[i]
		var id: int = int(c["id"])
		var dato: Dictionary = indice.get(id, {})
		var dias: int = int(ceil(float(c["dias"])))
		var fila := Componentes.fila(i % 2 == 0)
		var dentro := Componentes.contenido(fila)

		if dato.is_empty():
			dentro.add_child(Componentes.celda(
				"(ya no esta en la piramide)", 260, Tema.SUAVE))
			dentro.add_child(Componentes.celda("", 210))
			dentro.add_child(Componentes.celda("", 250))
		else:
			var j: Dictionary = dato["jugador"]
			dentro.add_child(Componentes.celda(_nombre_jugador(j), 260))
			dentro.add_child(Componentes.celda("%s  ·  D%d" % [
				dato["club"].nombre, int(dato["division"])], 210, Tema.SUAVE))
			dentro.add_child(Componentes.celda("%s  ·  media %.1f  ·  %d años" % [
				j["posicion"], float(j["media"]), int(j["edad"])], 250, Tema.SUAVE))

		# Menos de 120 dias es menos de media temporada: alcanza para
		# decidir si conviene volver a mirarlo antes de que se tape.
		var pronto: bool = dias < 120
		dentro.add_child(Componentes.celda(
			("VENCE PRONTO · %d dias" % dias) if pronto else ("vence en %d dias" % dias),
			220, Tema.ROJO if pronto else Tema.SUAVE))
		contenedor_investigaciones.add_child(fila)


func _encabezado_conocidos() -> Control:
	var fila := Componentes.fila(false)
	var dentro := Componentes.contenido(fila)
	for par in [["Jugador", 260], ["Club", 210], ["Datos", 250], ["Informe", 220]]:
		var l := Componentes.celda(str(par[0]), int(par[1]), Tema.SUAVE)
		l.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
		dentro.add_child(l)
	return fila


## id -> {jugador, club, division} de toda la piramide. Se arma una vez
## por refresco: el conocimiento guarda solo el id, y buscar cada uno por
## separado seria recorrer 3.600 jugadores por fila.
func _indice_de_jugadores() -> Dictionary:
	var indice := {}
	for d in range(GameState.piramide.divisiones.size()):
		for club in GameState.piramide.divisiones[d].equipos:
			for j in club.jugadores + club.banco + club.cantera:
				indice[int(j["id"])] = {"jugador": j, "club": club, "division": d + 1}
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
	var texto := "%s (%s) — %s — %s — %s" % [
		str(o["jugador"]), str(o["posicion"]), str(o["club"]),
		Economia.formato_dinero(o["monto"]), _estado_legible(o)]
	var l := _etiqueta(texto)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(l)
	var btn := Button.new()
	btn.text = "Ver oferta"
	btn.custom_minimum_size = Vector2(130, 44)
	var id := int(o["id"])
	btn.pressed.connect(func(): _abrir_oferta(id))
	fila.add_child(btn)
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


func _construir_dialogo_novedades() -> void:
	dialogo_novedades = AcceptDialog.new()
	dialogo_novedades.title = "Novedades"
	dialogo_novedades.ok_button_text = "Entendido"
	add_child(dialogo_novedades)


var dialogo_prestamo: AcceptDialog
var prestamo_dueno: Team = null
var prestamo_jugador_id: int = -1
var option_prestamo_duracion: OptionButton
var slider_prestamo_sueldo: HSlider
var label_prestamo_sueldo: Label
var check_prestamo_opcion: CheckBox
var spin_prestamo_opcion: SpinBox
var label_prestamo_datos: Label
var label_prestamo_estado: RichTextLabel


func _construir_dialogo_prestamo() -> void:
	dialogo_prestamo = AcceptDialog.new()
	dialogo_prestamo.title = "Prestamo"
	dialogo_prestamo.ok_button_text = "Cerrar"
	dialogo_prestamo.min_size = Vector2(640, 440)
	add_child(dialogo_prestamo)

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

	var btn := Button.new()
	btn.text = "Pedir préstamo"
	btn.custom_minimum_size = Vector2(220, Tema.ALTO_TACTIL)
	Tema.primario(btn)
	btn.pressed.connect(_on_pedir_prestamo)
	caja.add_child(btn)

	var cerrar_prestamo := Button.new()
	cerrar_prestamo.text = "Cerrar"
	cerrar_prestamo.custom_minimum_size = Vector2(200, 48)
	cerrar_prestamo.pressed.connect(func(): dialogo_prestamo.hide())
	caja.add_child(cerrar_prestamo)

	label_prestamo_estado = RichTextLabel.new()
	label_prestamo_estado.bbcode_enabled = true
	label_prestamo_estado.fit_content = true
	label_prestamo_estado.custom_minimum_size = Vector2(0, 120)
	caja.add_child(label_prestamo_estado)


func _refrescar_prestamo_sueldo() -> void:
	var pct := int(slider_prestamo_sueldo.value)
	var texto := "%d%%" % pct
	if prestamo_dueno != null and Investigadores.conoce(GameState.equipo_jugador, prestamo_jugador_id):
		var sueldo: float = float(prestamo_dueno.sueldos.get(prestamo_jugador_id, 0.0))
		texto += "  (%s por temporada)" % Economia.formato_dinero(sueldo * pct / 100.0)
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
	if conocido:
		t += "Hoy cobra %s.\n" % Economia.formato_dinero(dueno.sueldos.get(jugador_id, 0.0))
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
		float(slider_prestamo_sueldo.value) / 100.0, opcion)
	if not r["exito"]:
		var extra := ""
		if float(r.get("minimo", 0.0)) > 0.0:
			extra = " Pedirían al menos %s." % Economia.formato_dinero(r["minimo"])
		label_prestamo_estado.text = "[color=#d4a017]%s%s[/color]" % [r["motivo"], extra]
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
var caja_negociacion_datos: HBoxContainer
var caja_negociacion_pasos: HBoxContainer
var label_negociacion_estado: RichTextLabel
var caja_negociacion_monto: VBoxContainer
var caja_negociacion_riesgo: VBoxContainer
var caja_negociacion_contrato: VBoxContainer
var spin_negociacion_monto: SpinBox
var spin_negociacion_sueldo: SpinBox
var spin_negociacion_anios: SpinBox
var spin_negociacion_clausula: SpinBox
var boton_negociacion_accion: Button
var boton_negociacion_rechazar: Button
var boton_negociacion_contra: Button
var boton_negociacion_clausula: Button


func _construir_dialogo_negociacion() -> void:
	dialogo_negociacion = AcceptDialog.new()
	dialogo_negociacion.title = "Negociacion"
	dialogo_negociacion.ok_button_text = "Cerrar"
	dialogo_negociacion.min_size = Vector2(820, 560)
	add_child(dialogo_negociacion)

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogo_negociacion.add_child(caja)

	label_negociacion_titulo = Label.new()
	Tema.numero(label_negociacion_titulo, 24)
	caja.add_child(label_negociacion_titulo)

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
	spin_negociacion_monto.step = 1000
	spin_negociacion_monto.custom_minimum_size = Vector2(240, Tema.ALTO_TACTIL)
	spin_negociacion_monto.value_changed.connect(func(_v): _refrescar_riesgo())
	fila_monto.add_child(spin_negociacion_monto)

	caja_negociacion_riesgo = VBoxContainer.new()
	caja_negociacion_monto.add_child(caja_negociacion_riesgo)

	caja_negociacion_contrato = VBoxContainer.new()
	caja_negociacion_contrato.visible = false
	caja.add_child(caja_negociacion_contrato)
	spin_negociacion_sueldo = _fila_spin(caja_negociacion_contrato,
		"Sueldo por temporada", 0, 500000000, 500)
	spin_negociacion_anios = _fila_spin(caja_negociacion_contrato,
		"Años de contrato", 1, 5, 1)
	spin_negociacion_anios.value = 3
	# La clausula la ponés vos: alta lo blinda contra que te lo saquen,
	# pero a él lo encierra y te lo cobra pidiendo más sueldo.
	spin_negociacion_clausula = _fila_spin(caja_negociacion_contrato,
		"Cláusula de rescisión", 0, 5000000000, 5000)

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

	# La clausula ajena: el atajo del que no quiere negociar. Se paga de
	# mas pero la venta es obligatoria y nadie se puede ofender.
	boton_negociacion_clausula = Button.new()
	boton_negociacion_clausula.custom_minimum_size = Vector2(240, Tema.ALTO_TACTIL)
	boton_negociacion_clausula.pressed.connect(_on_negociacion_clausula)
	fila_botones.add_child(boton_negociacion_clausula)

	var cerrar := Button.new()
	cerrar.text = "Cerrar"
	cerrar.custom_minimum_size = Vector2(140, Tema.ALTO_TACTIL)
	cerrar.pressed.connect(func(): dialogo_negociacion.hide())
	fila_botones.add_child(cerrar)

	label_negociacion_estado = RichTextLabel.new()
	label_negociacion_estado.bbcode_enabled = true
	label_negociacion_estado.fit_content = true
	label_negociacion_estado.custom_minimum_size = Vector2(0, 110)
	caja.add_child(label_negociacion_estado)


func _fila_spin(padre: Control, etiqueta: String, minimo: float, maximo: float, paso: float) -> SpinBox:
	var fila := HBoxContainer.new()
	padre.add_child(fila)
	fila.add_child(Componentes.celda(etiqueta, 250, Tema.SUAVE))
	var sb := SpinBox.new()
	sb.min_value = minimo
	sb.max_value = maximo
	sb.step = paso
	sb.custom_minimum_size = Vector2(240, Tema.ALTO_TACTIL)
	fila.add_child(sb)
	return sb


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
			"%d" % n, color, Tema.FONDO if (hecho or activo) else Tema.PANEL))
		caja_negociacion_pasos.add_child(Componentes.celda(nombre, 260, color))


func _caja_dato(etiqueta: String, valor: String, color: Color = Tema.TEXTO,
		acento: bool = false) -> Control:
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
		var clausula: float = vendedor.clausulas.get(jugador_id, 0.0)
		boton_negociacion_clausula.visible = clausula > 0.0
		boton_negociacion_clausula.text = "Pagar cláusula (%s)" % Economia.formato_dinero(clausula)
		boton_negociacion_clausula.disabled = GameState.equipo_jugador.caja["fichajes"] < clausula
	else:
		caja_negociacion_datos.add_child(_caja_dato("Vale", "?", Tema.SUAVE))
		caja_negociacion_datos.add_child(_caja_dato("Piden", "?", Tema.SUAVE))
		caja_negociacion_datos.add_child(_caja_dato("Hoy cobra", "?", Tema.SUAVE))
		caja_negociacion_datos.add_child(_caja_dato(
			"Tu presupuesto",
			Economia.formato_dinero(GameState.equipo_jugador.caja["fichajes"]), Tema.VERDE))
		spin_negociacion_monto.value = 0
		boton_negociacion_clausula.visible = false

	caja_negociacion_monto.visible = true
	caja_negociacion_contrato.visible = false
	boton_negociacion_rechazar.visible = false
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
	negociacion_oferta_id = oferta_id
	negociacion_jugador_id = int(o["jugador_id"])
	negociacion_vendedor = GameState._club_por_nombre(str(o["club"]))

	label_negociacion_titulo.text = str(o["jugador"])
	label_negociacion_sub.text = "%s %s  ·  sobre la mesa %s  ·  ronda %d  ·  %s" % [
		"Oferta de" if bool(o["entrante"]) else "Tu oferta a", str(o["club"]),
		Economia.formato_dinero(o["monto"]), int(o["ronda"]), _estado_legible(o)]

	var a_firmar: bool = str(o["estado"]) == Ofertas.ACUERDO_CLUB and not bool(o["entrante"])
	_dibujar_pasos(2 if a_firmar else 1)

	for hijo in caja_negociacion_datos.get_children():
		hijo.queue_free()

	var historia := ""
	for linea in o["log"]:
		historia += "[color=#93a79b]%s[/color]
" % str(linea)
	label_negociacion_estado.text = historia

	var me_toca: bool = str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS
	caja_negociacion_monto.visible = me_toca
	caja_negociacion_contrato.visible = a_firmar
	boton_negociacion_rechazar.visible = me_toca
	boton_negociacion_contra.visible = me_toca
	boton_negociacion_clausula.visible = false
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


func _precargar_contrato(o: Dictionary) -> void:
	var vendedor := GameState._club_por_nombre(str(o["club"]))
	var id := int(o["jugador_id"])
	if vendedor == null:
		return
	var donde := Mercado.ubicar(vendedor, id)
	if donde.is_empty():
		return
	var jugador: Dictionary = donde["jugador"]
	var pretende := Negociacion.sueldo_pretendido(
		jugador, float(vendedor.sueldos.get(id, 0.0)),
		GameState._division_de(vendedor), GameState.division_jugador)
	spin_negociacion_sueldo.value = ceil(pretende / spin_negociacion_sueldo.step) * spin_negociacion_sueldo.step
	var normal := ValorJugador.calcular(jugador, 50.0, 3) * Team.FACTOR_CLAUSULA
	spin_negociacion_clausula.value = ceil(normal / spin_negociacion_clausula.step) * spin_negociacion_clausula.step


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
		label_negociacion_estado.text = "[color=#d4a017]%s[/color]" % r["motivo"]
		return
	label_negociacion_estado.text = "[color=#27ae60]Oferta enviada. %s te contesta en unos dias — la seguis en Ofertas enviadas.[/color]" % negociacion_vendedor.nombre
	boton_negociacion_accion.disabled = true
	boton_negociacion_clausula.visible = false
	_on_buscar_mercado()


## Aceptar manda el monto EXACTO que hay sobre la mesa, no lo que quedo en
## el control: el paso del SpinBox es de $1.000 y redondeaba una oferta de
## $17.695 a $18.000, asi que "Aceptar" terminaba contraofertando sin que
## nadie lo pidiera.
func _responder(o: Dictionary, accion: String) -> void:
	var monto: float = float(o["monto"]) if accion == "aceptar" else float(spin_negociacion_monto.value)
	var r := GameState.responder_oferta(int(o["id"]), accion, monto)
	if not r["exito"]:
		label_negociacion_estado.text = "[color=#d4a017]%s[/color]" % r["motivo"]
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


func _firmar_contrato() -> void:
	var r := GameState.cerrar_fichaje(
		negociacion_oferta_id, float(spin_negociacion_sueldo.value),
		int(spin_negociacion_anios.value), float(spin_negociacion_clausula.value))
	if not r["exito"]:
		label_negociacion_estado.text = "[color=#d4a017]%s[/color]" % r["motivo"]
		return
	label_negociacion_estado.text = "[color=#27ae60]Cerrado. %s es tuyo.[/color]" % _nombre_jugador(r["jugador"])
	boton_negociacion_accion.disabled = true
	_mostrar_solapa_mercado(solapa_mercado_actual)


func _on_negociacion_clausula() -> void:
	var r := GameState.pagar_clausula(negociacion_vendedor, negociacion_jugador_id)
	if not r["exito"]:
		label_negociacion_estado.text = "[color=#d4a017]%s[/color]" % r["motivo"]
		return
	label_negociacion_estado.text = "[color=#27ae60]Clausula pagada: %s es tuyo por %s.[/color]" % [
		_nombre_jugador(r["jugador"]), Economia.formato_dinero(r["precio"])]
	boton_negociacion_accion.disabled = true
	boton_negociacion_clausula.disabled = true
	_on_buscar_mercado()


func _on_pagar_clausula(vendedor: Team, jugador_id: int) -> void:
	var resultado := GameState.pagar_clausula(vendedor, jugador_id)
	if resultado["exito"]:
		label_mercado_estado.text = "Clausula pagada: entra un %s, sale un %s, se pago %s." % [
			resultado["jugador_entra"]["posicion"], resultado["jugador_sale"]["posicion"], Economia.formato_dinero(resultado["clausula"])
		]
	else:
		label_mercado_estado.text = "No se pudo: %s" % resultado["motivo"]

	_refrescar_mercado()
	_refrescar_plantel()
	_refrescar_economia()


## Agentes libres: no se paga fee de transferencia, solo el sueldo. Es la
## unica forma de reforzarse sin plata en la caja de fichajes, asi que la
## pantalla lo dice arriba de todo.
func _construir_panel_libres(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["libres"] = panel

	var aviso := Label.new()
	aviso.text = "Sin fee de transferencia: solo pagas el sueldo. Fichar reemplaza a tu jugador MAS FLOJO de ese puesto, asi que nunca empeora el plantel."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(aviso)

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
func _fila_jugador_accion(j: Dictionary, detalle: String, texto_boton: String,
		ayuda_boton: String, al_apretar: Callable) -> Control:
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
	btn.pressed.connect(al_apretar)
	dentro.add_child(btn)
	return fila


func _refrescar_libres() -> void:
	for hijo in contenedor_libres_botones.get_children():
		hijo.queue_free()

	var pool: Array = GameState.liga_jugador().agentes_libres
	if pool.is_empty():
		contenedor_libres_botones.add_child(_tarjeta_vacia(
			"No hay agentes libres en tu division por ahora. Aparecen cuando a un club de la IA se le vence el contrato de alguien y no se lo renueva."))
		return

	for agente in pool:
		var id: int = int(agente["id"])
		contenedor_libres_botones.add_child(_fila_jugador_accion(
			agente,
			"%d años   ·   potencial %d" % [int(agente["edad"]), int(agente["potencial"])],
			"Fichar",
			"Reemplaza a tu jugador mas flojo de ese puesto, titular o suplente.",
			func(): _on_fichar_libre(id)))


## Reemplaza siempre a tu jugador mas debil en esa posicion (titular o
## banco, lo que sea mas bajo) — asi el fichaje de un libre nunca empeora
## el plantel.
func _on_fichar_libre(agente_id: int) -> void:
	var pool: Array = GameState.liga_jugador().agentes_libres
	var agente: Dictionary = {}
	for a in pool:
		if a["id"] == agente_id:
			agente = a
			break
	if agente.is_empty():
		return

	var equipo := GameState.equipo_jugador
	var posicion: String = agente["posicion"]
	var mejor_indice := -1
	var mejor_es_banco := false
	var peor_media := 999.0
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["posicion"] == posicion and equipo.jugadores[i]["media"] < peor_media:
			peor_media = equipo.jugadores[i]["media"]
			mejor_indice = i
			mejor_es_banco = false
	for i in range(equipo.banco.size()):
		if equipo.banco[i]["posicion"] == posicion and equipo.banco[i]["media"] < peor_media:
			peor_media = equipo.banco[i]["media"]
			mejor_indice = i
			mejor_es_banco = true

	if mejor_indice < 0:
		label_libres_estado.text = "No tenes ningun jugador en esa posicion para reemplazar."
		return

	var resultado := GameState.fichar_agente_libre(agente_id, mejor_indice, mejor_es_banco)
	if resultado["exito"]:
		label_libres_estado.text = "Fichado: entra un %s, sale un %s al pool." % [resultado["entra"]["posicion"], resultado["sale"]["posicion"]]
	else:
		label_libres_estado.text = "No se pudo: %s" % resultado["motivo"]

	_refrescar_libres()
	_refrescar_plantel()


## Prestamos (§9.3 extendido): cedes banco/cantera propios por una
## temporada, o pedis prestado a otro club de tu division — ver
## core/prestamos.gd.
## Ceder a prestamo. Pedir prestado NO vive aca: se hace desde Mercado,
## con la misma negociacion que una compra.
func _construir_panel_prestamos(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["prestamos"] = panel

	var aviso := Label.new()
	aviso.text = "Ceder a prestamo: una temporada, cobras un fee del 10% del valor y el club que lo recibe le paga el sueldo. Solo banco y cantera — a un titular no se lo puede ceder. Para PEDIR prestado, anda a Mercado."
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	aviso.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(aviso)

	label_prestamos_estado = Label.new()
	label_prestamos_estado.text = ""
	label_prestamos_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_prestamos_estado.add_theme_color_override("font_color", Tema.AMBAR)
	panel.add_child(label_prestamos_estado)

	var scroll_ceder := ScrollContainer.new()
	scroll_ceder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_ceder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_ceder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll_ceder)

	contenedor_prestamos_ceder_botones = VBoxContainer.new()
	contenedor_prestamos_ceder_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_ceder.add_child(contenedor_prestamos_ceder_botones)


func _refrescar_prestamos() -> void:
	for hijo in contenedor_prestamos_ceder_botones.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador
	var cedibles := []
	for j in equipo.banco:
		cedibles.append({"jugador": j, "desde_cantera": false})
	for j in equipo.cantera:
		cedibles.append({"jugador": j, "desde_cantera": true})

	if cedibles.is_empty():
		contenedor_prestamos_ceder_botones.add_child(_tarjeta_vacia(
			"No tenes a nadie para ceder: solo se puede prestar gente del banco o de la cantera."))
		return

	for entrada in cedibles:
		var j: Dictionary = entrada["jugador"]
		var id: int = int(j["id"])
		var origen := "cantera" if entrada["desde_cantera"] else "banco"
		contenedor_prestamos_ceder_botones.add_child(_fila_jugador_accion(
			j,
			"%s   ·   %d años   ·   potencial %d" % [
				origen, int(j["edad"]), int(j["potencial"])],
			"Ceder",
			"Se va una temporada a un club de tu division. Cobras el fee ahora.",
			func(): _on_ceder_prestamo(id)))


## Elige un rival al azar de tu division como destino del prestamo — no
## hay negociacion todavia (eso es contenido pendiente), cualquier club de
## tu misma division puede recibirlo.
func _on_ceder_prestamo(jugador_id: int) -> void:
	var rivales := []
	for rival in GameState.liga_jugador().equipos:
		if rival != GameState.equipo_jugador:
			rivales.append(rival)
	if rivales.is_empty():
		return
	var destino: Team = rivales[GameState.rng.randi() % rivales.size()]

	var resultado := GameState.ceder_a_prestamo(jugador_id, destino)
	if resultado["exito"]:
		label_prestamos_estado.text = "Prestamo concretado: %s se va a %s por esta temporada (fee cobrado %s)." % [
			resultado["jugador"]["posicion"], destino.nombre, Economia.formato_dinero(resultado["fee"])
		]
	else:
		label_prestamos_estado.text = "No se pudo: %s" % resultado["motivo"]

	_refrescar_prestamos()
	_refrescar_plantel()
	_refrescar_economia()


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
	"entrenamiento": "Mas cupos de foco individual (hasta 3) y todo el plantel crece un poco mas rapido.",
}

## Que pestaña de Instalaciones esta abierta. Las tres cosas que vivian
## aca —mejoras, investigadores y foco individual— no tienen nada que ver
## entre si salvo que se pagan con la misma caja, y apiladas en un solo
## scroll no se entendia donde empezaba una y terminaba la otra.
var solapa_instalaciones: String = "mejoras"
var contenedor_instalaciones_solapas: HBoxContainer
var dialogo_investigador: AcceptDialog
var contenedor_investigador_dialogo: VBoxContainer
var label_investigador_dialogo: Label


## Los efectos CONCRETOS de un nivel, para poder comparar el actual con el
## siguiente. Sin esto "subir a nivel 3 cuesta $72.000" no dice nada:
## no se sabe que se compra.
func _efecto_instalacion(categoria: String, nivel: int) -> String:
	match categoria:
		"estadio":
			if nivel <= 1:
				return "aforo base"
			return "aforo +%d%%" % ((nivel - 1) * 20)
		"medica":
			return "lesiones −%d%%, recuperacion +%d%%" % [
				(nivel - 1) * 10, (nivel - 1) * 15]
		"juveniles":
			# La calidad se SUMA al nivel del club: por debajo del 3 la
			# academia saca chicos peores de lo que da el club.
			return "camada de %d, calidad %+d" % [2 + nivel, (nivel - 3) * 3]
		"scouting":
			return "potencial de juveniles ±%d" % Scout.margen(
				mini(Scout.NIVEL_MAXIMO, nivel * 2 - 1))
		"entrenamiento":
			return "%d cupo%s de foco, crecimiento +%d%%" % [
				mini(nivel, Instalaciones.MAXIMO_FOCO_INDIVIDUAL),
				"" if mini(nivel, Instalaciones.MAXIMO_FOCO_INDIVIDUAL) == 1 else "s",
				nivel - 1]
	return ""


## Los niveles como puntos llenos y vacios: cuanto te queda por mejorar se
## ve sin leer "3/5".
func _puntos_de_nivel(nivel: int, maximo: int) -> Label:
	var l := Label.new()
	l.text = "●".repeat(nivel) + "○".repeat(maximo - nivel)
	l.add_theme_color_override("font_color", Tema.AMBAR)
	return l


func _construir_panel_instalaciones(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["instalaciones"] = panel

	contenedor_instalaciones_solapas = HBoxContainer.new()
	panel.add_child(contenedor_instalaciones_solapas)
	for par in [["mejoras", "Mejoras"], ["investigadores", "Investigadores"],
			["foco", "Foco individual"]]:
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
		elif str((btn as Button).text) == "Foco individual":
			clave = "foco"
		Tema.seleccionado(btn, clave == solapa_instalaciones)

	# La caja de Mejoras es la restriccion de las dos primeras solapas, asi
	# que va siempre a la vista: sin esto "Mejorar" aparece apagado y no se
	# entiende por que.
	if solapa_instalaciones != "foco":
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
		"foco":
			_refrescar_foco_individual(equipo)
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
	estilo.bg_color = Color("#1a231f")

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
	dialogo_investigador.ok_button_text = "Cerrar"
	dialogo_investigador.min_size = Vector2(720, 420)
	# Un tope duro: sin esto el dialogo crece con su contenido —diez filas
	# de opciones— y se pasa del alto de la pantalla, dejando el boton de
	# cerrar afuera. Que scrollee la lista, no la ventana.
	dialogo_investigador.max_size = Vector2(760, 560)
	add_child(dialogo_investigador)

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

	# Sin boton de cerrar propio: con el tope de alto de arriba, el que trae
	# AcceptDialog siempre queda dentro de la pantalla. Dos botones "Cerrar"
	# uno arriba del otro se leian como que hacian cosas distintas.


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


## §7.4 punto 3 / §5: hasta N jugadores (N = nivel de Entrenamiento con
## tope de 3) con foco en un atributo, que esta temporada crece más
## rápido — y la vía de entrada para aprender una habilidad de bronce (2
## temporadas seguidas en el mismo atributo, con ese atributo en 65+).
##
## Cuánto más rápido depende de si el atributo es propio del puesto (ver
## Progresion.multiplicador_foco), así que el multiplicador se muestra
## ANTES de asignar y no después: es la información con la que se decide.
func _refrescar_foco_individual(equipo: Team) -> void:
	var limite := Entrenamiento.limite(equipo)
	var usados := equipo.foco_individual.size()

	var explica := Label.new()
	explica.text = "El atributo elegido crece mucho mas rapido esta temporada. Cuanto mas depende del PUESTO: enfocar el remate de un 9 rinde mas que el mismo remate en un central. Dos temporadas seguidas en el mismo atributo, con ese atributo en 65 o mas, puede hacerle aprender una habilidad de bronce. Los cupos los da la instalacion de Entrenamiento, con tope de %d." % Instalaciones.MAXIMO_FOCO_INDIVIDUAL
	explica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explica.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	explica.add_theme_color_override("font_color", Tema.SUAVE)
	contenedor_instalaciones_botones.add_child(explica)

	contenedor_instalaciones_botones.add_child(Tema.etiqueta_seccion(
		"Cupos usados: %d de %d" % [usados, limite]))

	if equipo.foco_individual.is_empty():
		contenedor_instalaciones_botones.add_child(_tarjeta_vacia(
			"No tenes a nadie en foco. Es plata gratis que estas dejando pasar: los cupos no se acumulan de una temporada a la otra."))

	for jugador_id in equipo.foco_individual.keys():
		var jugador := _buscar_jugador_por_id(equipo, jugador_id)
		if jugador.is_empty():
			continue
		var atributo: String = equipo.foco_individual[jugador_id]
		var racha: int = jugador.get("foco_temporadas_consecutivas", 0)
		var mult := Progresion.multiplicador_foco(str(jugador["posicion"]), atributo)
		var valor: int = int(jugador["atributos"].get(atributo, 0))

		var tarjeta := Componentes.tarjeta(Tema.AMBAR)
		contenedor_instalaciones_botones.add_child(tarjeta)
		var fila := HBoxContainer.new()
		tarjeta.add_child(fila)

		var caja_pos := CenterContainer.new()
		caja_pos.custom_minimum_size = Vector2(56, 0)
		caja_pos.add_child(Componentes.chip(str(jugador["posicion"]), Color("#2f4a3c")))
		fila.add_child(caja_pos)

		var izq := VBoxContainer.new()
		izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		izq.add_theme_constant_override("separation", 2)
		fila.add_child(izq)
		var nombre := Label.new()
		nombre.text = _nombre_jugador(jugador)
		nombre.clip_text = true
		nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		izq.add_child(nombre)
		var sub := Label.new()
		# La racha y el valor del atributo juntos: son las dos condiciones
		# de la habilidad de bronce y por separado no dicen nada.
		var falta := ""
		if valor < 65:
			falta = "   ·   le faltan %d puntos para poder aprender la habilidad" % (65 - valor)
		elif racha >= 1:
			falta = "   ·   otra temporada mas y puede aprender la habilidad"
		sub.text = "%s %d   ·   racha de %d temporada%s%s" % [
			atributo.replace("_", " "), valor, racha, "" if racha == 1 else "s", falta]
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		sub.add_theme_color_override("font_color", Tema.SUAVE)
		izq.add_child(sub)

		var caja_mult := VBoxContainer.new()
		caja_mult.custom_minimum_size = Vector2(120, 0)
		caja_mult.add_theme_constant_override("separation", 0)
		fila.add_child(caja_mult)
		caja_mult.add_child(Tema.etiqueta_seccion("Crece"))
		var l_mult := Label.new()
		l_mult.text = "x%.2f" % mult
		Tema.numero(l_mult, 22, _color_de_multiplicador(mult))
		caja_mult.add_child(l_mult)

		var id_j := int(jugador_id)
		var btn := Button.new()
		btn.text = "Quitar"
		btn.custom_minimum_size = Vector2(130, Tema.ALTO_TACTIL)
		btn.pressed.connect(func():
			Entrenamiento.quitar(equipo, id_j)
			label_instalaciones_estado.text = "Foco liberado: quedo un cupo."
			_refrescar_instalaciones()
		)
		fila.add_child(btn)

	if usados >= limite:
		var tope := Label.new()
		tope.text = "No te quedan cupos. Quitale el foco a alguien, o subi la instalacion de Entrenamiento (hasta %d cupos)." % Instalaciones.MAXIMO_FOCO_INDIVIDUAL
		tope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tope.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		tope.add_theme_color_override("font_color", Tema.SUAVE)
		contenedor_instalaciones_botones.add_child(tope)
		return

	var elegibles: Array = equipo.jugadores + equipo.banco + equipo.cantera
	elegibles = elegibles.filter(func(j): return not equipo.foco_individual.has(j["id"]))
	if elegibles.is_empty():
		return

	contenedor_instalaciones_botones.add_child(Tema.etiqueta_seccion("Asignar un foco nuevo"))
	var tarjeta_nueva := Componentes.tarjeta()
	contenedor_instalaciones_botones.add_child(tarjeta_nueva)
	var caja := VBoxContainer.new()
	tarjeta_nueva.add_child(caja)
	var fila_nueva := HBoxContainer.new()
	caja.add_child(fila_nueva)

	var option_jugador := OptionButton.new()
	option_jugador.custom_minimum_size = Vector2(340, Tema.ALTO_TACTIL)
	for j in elegibles:
		option_jugador.add_item("%s  (%s, %d años)" % [
			_nombre_jugador(j), j["posicion"], int(j["edad"])])
	fila_nueva.add_child(option_jugador)

	var option_atributo := OptionButton.new()
	option_atributo.custom_minimum_size = Vector2(240, Tema.ALTO_TACTIL)
	for attr in PlayerGenerator.get_all_attributes():
		option_atributo.add_item(str(attr).replace("_", " "))
	fila_nueva.add_child(option_atributo)

	# La vista previa es el punto de la pantalla: el multiplicador depende
	# del puesto, asi que hay que poder verlo ANTES de gastar el cupo.
	var previa := Label.new()
	previa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	previa.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	caja.add_child(previa)

	var actualizar_previa := func():
		var j: Dictionary = elegibles[option_jugador.selected]
		var attr: String = str(PlayerGenerator.get_all_attributes()[option_atributo.selected])
		var m := Progresion.multiplicador_foco(str(j["posicion"]), attr)
		var v: int = int(j["atributos"].get(attr, 0))
		previa.text = "%s tiene %s en %d y de %s crece x%.2f con el foco puesto ahi." % [
			_nombre_jugador(j), attr.replace("_", " "), v, j["posicion"], m]
		previa.add_theme_color_override("font_color", _color_de_multiplicador(m))
	option_jugador.item_selected.connect(func(_i): actualizar_previa.call())
	option_atributo.item_selected.connect(func(_i): actualizar_previa.call())
	actualizar_previa.call()

	var btn_asignar := Button.new()
	btn_asignar.text = "Asignar foco"
	btn_asignar.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	Tema.primario(btn_asignar)
	btn_asignar.pressed.connect(func():
		var jugador_elegido: Dictionary = elegibles[option_jugador.selected]
		var atributo_elegido: String = str(
			PlayerGenerator.get_all_attributes()[option_atributo.selected])
		Entrenamiento.asignar(equipo, jugador_elegido["id"], atributo_elegido)
		label_instalaciones_estado.text = "%s entrena %s esta temporada." % [
			_nombre_jugador(jugador_elegido), atributo_elegido.replace("_", " ")]
		_refrescar_instalaciones()
	)
	fila_nueva.add_child(btn_asignar)


## Verde si el atributo es de los que rinden en ese puesto, rojo si el
## foco casi no sirve ahi. Es el unico dato que separa una buena decision
## de una mala en esta pantalla.
func _color_de_multiplicador(mult: float) -> Color:
	if mult >= 2.4:
		return Tema.VERDE
	if mult >= 1.8:
		return Tema.VERDE_TIBIO
	if mult >= 1.4:
		return Tema.AMBAR
	return Tema.ROJO


func _buscar_jugador_por_id(equipo: Team, jugador_id: int) -> Dictionary:
	for j in equipo.jugadores + equipo.banco + equipo.cantera:
		if j["id"] == jugador_id:
			return j
	return {}


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
	btn.tooltip_text = "Entra al banco y el peor suplente queda libre."
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


## Las noticias de la temporada, separadas por categoria y con los
## jugadores que se nombran clickeables.
##
## Antes era una sola lista de treinta tarjetas donde un fichaje, una
## lesion y un campeon se leian igual, y el jugador que se mencionaba era
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
	if t.contains("descen") or t.contains("descien") or t.contains("quiebra") \
			or t.contains("lesion"):
		return Tema.ROJO
	if t.contains("ascen") or t.contains("ascien") or t.contains("campe") \
			or t.contains("gana"):
		return Tema.VERDE
	if t.contains("fich") or t.contains("transfer") or t.contains("prestamo"):
		return Tema.CELESTE
	return Tema.BORDE


const VACIO_POR_SOLAPA := {
	"todas": "Todavia no hay noticias.",
	"rumores": "Todavia no se habla de nadie. Los rumores salen con el libro de pases abierto.",
	"fichajes": "Todavia no se movio nadie.",
	"lesiones": "Nadie se rompio todavia. Ojala siga asi.",
	"campeones": "Todavia no se corono nadie: los titulos se reparten al cerrar la temporada.",
}


func _refrescar_noticias() -> void:
	if contenedor_noticias == null:
		return
	for clave in botones_solapa_noticias:
		Tema.seleccionado(botones_solapa_noticias[clave], clave == noticias_solapa)
	for hijo in contenedor_noticias.get_children():
		hijo.queue_free()

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
	var caja := Componentes.tarjeta()
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


## Una linea de la lista: fecha, rival y resultado, con el color de si
## ganaste. El elegido queda marcado.
func _fila_de_historial(reg: Dictionary, indice: int) -> Control:
	var mio: String = GameState.equipo_jugador.nombre
	var propios: int = int(reg["gl"]) if str(reg["local"]) == mio else int(reg["gv"])
	var ajenos: int = int(reg["gv"]) if str(reg["local"]) == mio else int(reg["gl"])
	var rival: String = str(reg["visitante"]) if str(reg["local"]) == mio else str(reg["local"])
	var color := Tema.VERDE if propios > ajenos else (Tema.ROJO if propios < ajenos else Tema.SUAVE)

	var btn := Button.new()
	btn.text = "T%d F%d   %s %d-%d   %s" % [
		int(reg.get("temporada", 1)), int(reg.get("fecha", 0)),
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
	fecha.text = "Temporada %d  ·  fecha %d  ·  %s" % [
		int(r.get("temporada", 1)), int(r.get("fecha", 0)),
		Calendario.texto_medio(int(r.get("dia", 0)))]
	fecha.add_theme_font_size_override("font_size", Tema.TAM_ETIQUETA)
	fecha.add_theme_color_override("font_color", Tema.SUAVE)
	caja.add_child(fecha)

	var fila := HBoxContainer.new()
	caja.add_child(fila)
	var mio: String = GameState.equipo_jugador.nombre
	var l_local := Label.new()
	l_local.text = str(r["local"])
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
	l_visita.text = str(r["visitante"])
	l_visita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_visita.clip_text = true
	Tema.numero(l_visita, 22, Tema.AMBAR if str(r["visitante"]) == mio else Tema.TEXTO)
	fila.add_child(l_visita)
	return tarjeta


## Verde si ganaste, rojo si perdiste. El borde de la tarjeta dice el
## resultado antes de que leas los numeros.
func _color_del_resultado(r: Dictionary) -> Color:
	var mio: String = GameState.equipo_jugador.nombre
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
		var equipo := _equipo_de_la_liga(nombre)
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
	_refrescar_partida_guardado()
	_mostrar_seccion("club")


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
	if GameState.juego_terminado:
		_refrescar_objetivo()
		return
	if not GameState.hay_fecha_pendiente():
		return

	var temporada_antes := GameState.temporada_actual
	GameState.jugar_siguiente_fecha()

	_refrescar_historial_partidos()
	if GameState.temporada_actual != temporada_antes:
		dialogo_novedades.dialog_text = _texto_cierre_temporada()
		dialogo_novedades.popup_centered()

	_refrescar_tabla()
	_refrescar_plantel()
	_refrescar_objetivo()
	_refrescar_objetivo()
	_refrescar_barra_contexto()

	# El partido se VE. Antes se simulaba en silencio, te aparecia el
	# marcador ya hecho y recien despues podias pedir la repeticion, que es
	# como leer el diario antes de mirar el partido. Ahora se abre solo, y
	# adentro estan los controles para acelerar (x1 a x16) o saltar directo
	# al resultado.
	if not GameState.ultimos_fotogramas.is_empty():
		_mostrar_partido_animado()


func _on_simular_temporada() -> void:
	if GameState.juego_terminado:
		_refrescar_objetivo()
		return
	if not GameState.hay_fecha_pendiente():
		return

	# Simular una temporada entera bloquea el hilo unos segundos. Los dos
	# await dejan que Godot dibuje el aviso ANTES de empezar a laburar:
	# sin ellos la pantalla se congela sin explicacion.
	dialogo_novedades.dialog_text = "Simulando la temporada, esto tarda unos segundos..."
	dialogo_novedades.popup_centered()
	await get_tree().process_frame
	await get_tree().process_frame

	var temporada_antes := GameState.temporada_actual
	GameState.simular_temporada_completa()
	dialogo_novedades.hide()

	if GameState.temporada_actual != temporada_antes:
		dialogo_novedades.dialog_text = _texto_cierre_temporada()
		dialogo_novedades.popup_centered()

	# A diferencia de "jugar fecha", esto simula muchas fechas de una — no
	# tiene sentido mostrar el log/animado de sólo el último partido
	# jugado, como si fuera el único que pasó.
	GameState.ultimo_resultado = {}
	GameState.ultimo_log = []
	GameState.ultimos_eventos = []
	_refrescar_historial_partidos()

	_refrescar_tabla()
	_refrescar_plantel()
	_refrescar_objetivo()
	_refrescar_objetivo()


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
	_mostrar_seccion("club")


func _mostrar_partido() -> void:
	_ocultar_todos()
	paneles["partido"].visible = true
	var idx_actual := Estilos.LISTA.find(GameState.equipo_jugador.estilo)
	option_estilo.select(max(idx_actual, 0))
	var idx_cambios := OPCIONES_CAMBIOS.find(GameState.equipo_jugador.config_cambios)
	option_cambios.select(max(idx_cambios, 0))
	_refrescar_objetivo()
	_refrescar_objetivo()


## §10.5/§15: objetivo de la directiva para esta temporada, y el estado de
## game over si la directiva ya te destituyó (2 temporadas seguidas sin
## cumplir). Cuando termina el juego se deshabilitan los botones que
## avanzarían el calendario — la única salida es borrar la partida.
## El objetivo y el game over se muestran en la PORTADA, que es la
## pantalla desde la que se juega. Antes vivian en la pantalla "Partido",
## que ademas apagaba ahi mismo sus dos botones — y esos botones ya no
## existen: los de verdad estan en la portada y se apagan solos.
func _refrescar_objetivo() -> void:
	if paneles.has("portada") and paneles["portada"].visible:
		_refrescar_portada()


## Texto del objetivo de la directiva, con la advertencia si vas camino a
## que te echen.
func _texto_objetivo() -> String:
	if GameState.juego_terminado:
		return "GAME OVER: %s" % GameState.motivo_fin_partida
	var objetivo: Dictionary = GameState.equipo_jugador.objetivo_temporada
	if objetivo.is_empty():
		return ""
	var incumplidos: int = GameState.equipo_jugador.objetivos_incumplidos_seguidos
	var advertencia := ""
	if incumplidos > 0:
		advertencia = "  (⚠ %d/%d temporadas sin cumplir — te destituyen a la 2ª seguida)" % [
			incumplidos, Objetivos.MAX_INCUMPLIDOS_SEGUIDOS]
	return "Objetivo de la directiva: %s%s" % [objetivo["descripcion"], advertencia]


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
	var novedades: Array = GameState.avanzar_hasta_el_partido() if hasta_el_partido 		else GameState.avanzar_un_dia()
	_refrescar_portada()
	_refrescar_plantel()
	_refrescar_mercado()
	_refrescar_objetivo()
	_refrescar_objetivo()
	_refrescar_barra_contexto()
	if not novedades.is_empty():
		dialogo_novedades.dialog_text = "%s

%s" % [
			Calendario.texto_largo(GameState.dia_absoluto),
			"
".join(novedades.map(func(n): return "  ·  %s" % str(n)))]
		dialogo_novedades.popup_centered()


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
func _texto_informe_rival() -> String:
	var rival := _proximo_rival()
	if rival == null:
		return ""
	var mio: String = GameState.equipo_jugador.estilo
	var mod := Estilos.modificador(mio, rival.estilo)
	var pista := ""
	if mod > 0.0:
		pista = " (tu estilo lo complica)"
	elif mod < 0.0:
		pista = " (su estilo te complica a vos)"
	var dt_texto := ""
	if not rival.dt.is_empty():
		dt_texto = " — DT: %d/10 (%s)" % [rival.dt["nivel"], rival.dt["rasgo"]]
	var clasico_texto := ""
	if Rivalidad.es_clasico(GameState.equipo_jugador, rival):
		clasico_texto = " — ⚔ ¡ES TU CLÁSICO! (más tarjetas, más caos)"
	return "Rival: %s — estilo %s%s%s%s" % [rival.nombre, rival.estilo, pista, dt_texto, clasico_texto]


func _on_estilo_seleccionado(idx: int) -> void:
	GameState.equipo_jugador.estilo = Estilos.LISTA[idx]
	_refrescar_objetivo()


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
	# calidad de cancha del local. Se buscan en la liga del jugador, que es
	# donde se jugó el partido.
	var local: Team = _equipo_de_la_liga(str(r["local"]))
	var visitante: Team = _equipo_de_la_liga(str(r["visitante"]))
	if local == null or visitante == null:
		return
	var colores := ColoresClub.par_equipos(local, visitante)
	vista_partido.iniciar(
		GameState.ultimos_fotogramas, colores[0], colores[1],
		local.nombre, visitante.nombre,
		VistaPartido.construir_nombres(local, visitante),
		VistaCancha.estado_desde_calidad(local.calidad_cancha),
		local.color_short, visitante.color_short)


func _equipo_de_la_liga(nombre: String) -> Team:
	for e in GameState.liga_jugador().equipos:
		if e.nombre == nombre:
			return e
	return null


func _mostrar_economia() -> void:
	_ocultar_todos()
	paneles["economia"].visible = true
	_refrescar_economia()


func _mostrar_mercado() -> void:
	_ocultar_todos()
	paneles["mercado"].visible = true
	label_mercado_estado.text = ""
	_refrescar_mercado()


func _mostrar_libres() -> void:
	_ocultar_todos()
	paneles["libres"].visible = true
	label_libres_estado.text = ""
	_refrescar_libres()


func _mostrar_prestamos() -> void:
	_ocultar_todos()
	paneles["prestamos"].visible = true
	label_prestamos_estado.text = ""
	_refrescar_prestamos()


func _mostrar_instalaciones() -> void:
	_ocultar_todos()
	paneles["instalaciones"].visible = true
	label_instalaciones_estado.text = ""
	_refrescar_instalaciones()


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


## Cuanto hay que arrastrar antes de que un gesto cuente como scroll. Sin
## esto (el valor por defecto es 0) un arrastre que EMPIEZA sobre una
## etiqueta, un boton o un texto se lo come ese control y nunca llega al
## ScrollContainer: en el telefono las listas simplemente no se deslizan.
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


## §UI: el armazón. Trece pestañas sueltas pasan a CINCO secciones con
## subsolapas, y la navegación va al COSTADO.
##
## Al costado y no abajo porque el juego es apaisado: el alto son 648 px
## lógicos y es lo escaso, mientras que a lo ancho sobra. Una barra abajo
## se comería justo el espacio que necesitan las listas.
##
## Cada sección agrupa las pantallas que se usan juntas. Los paneles no se
## tocan: siguen siendo los mismos nodos en `paneles`, solo cambia por
## dónde se llega.
const SECCIONES := [
	{"clave": "club", "nombre": "Club", "paneles": []},
	{"clave": "equipo", "nombre": "Equipo", "paneles": [
		["plantel", "Plantel"], ["formacion", "Formacion"],
		["entrenamiento", "Entrenamiento"], ["economia", "Economia"],
		["cantera", "Cantera"], ["instalaciones", "Instalaciones"]]},
	{"clave": "partido", "nombre": "Liga", "paneles": [
		["tabla", "Tabla"], ["jugadores_liga", "Jugadores"],
		["historial", "Historial"]]},
	{"clave": "mercado", "nombre": "Mercado", "paneles": [
		["mercado", "Mercado"], ["libres", "Libres"], ["prestamos", "Prestamos"]]},
	{"clave": "mas", "nombre": "Mas", "paneles": [
		["noticias", "Noticias"],
		["seleccion", "Seleccion"], ["partida", "Partida"]]},
]

var seccion_actual: String = "club"
var panel_de_seccion_actual: String = ""
var botones_seccion: Dictionary = {}
var barra_subsolapas: HBoxContainer
var label_barra_club: Label
var label_barra_posicion: Label
var label_barra_plata: Label
var label_barra_fecha: Label
var label_barra_mercado: Label


func _construir_riel(padre: HBoxContainer) -> void:
	var riel := VBoxContainer.new()
	riel.custom_minimum_size = Vector2(132, 0)
	padre.add_child(riel)

	for seccion in SECCIONES:
		var btn := Button.new()
		btn.text = str(seccion["nombre"])
		btn.custom_minimum_size = Vector2(0, 62)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var clave := str(seccion["clave"])
		btn.pressed.connect(func(): _mostrar_seccion(clave))
		riel.add_child(btn)
		botones_seccion[clave] = btn

	riel.add_child(Control.new())
	riel.get_child(riel.get_child_count() - 1).size_flags_vertical = Control.SIZE_EXPAND_FILL


## La barra de contexto: quién sos, dónde estás y cuánta plata tenés. Antes
## nada de esto se veía sin entrar a tres pantallas distintas.
func _construir_barra_contexto(padre: VBoxContainer) -> void:
	var barra := HBoxContainer.new()
	padre.add_child(barra)

	label_barra_club = Label.new()
	Tema.numero(label_barra_club, Tema.TAM_BASE, Tema.TEXTO)
	barra.add_child(label_barra_club)

	label_barra_posicion = Label.new()
	label_barra_posicion.add_theme_color_override("font_color", Tema.SUAVE)
	barra.add_child(label_barra_posicion)

	# Solo aparece con el mercado abierto: fuera de la ventana no se puede
	# ofertar ni te ofertan, y eso hay que verlo sin entrar a Mercado.
	label_barra_mercado = Label.new()
	Tema.numero(label_barra_mercado, Tema.TAM_CHICO, Tema.VERDE)
	barra.add_child(label_barra_mercado)

	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(espacio)

	barra.add_child(Tema.etiqueta_seccion("Fichajes"))
	label_barra_plata = Label.new()
	Tema.numero(label_barra_plata, Tema.TAM_BASE, Tema.VERDE)
	barra.add_child(label_barra_plata)

	barra.add_child(Tema.etiqueta_seccion("Fecha"))
	label_barra_fecha = Label.new()
	Tema.numero(label_barra_fecha, Tema.TAM_BASE, Tema.TEXTO)
	barra.add_child(label_barra_fecha)

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
	label_barra_club.text = equipo.nombre
	var tabla := GameState.liga_jugador().tabla_ordenada()
	var puesto: int = tabla.find(equipo.nombre) + 1
	label_barra_posicion.text = "  Division %d  ·  %d° de %d" % [
		GameState.division_jugador + 1, puesto, tabla.size()]
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
	label_barra_fecha.text = Calendario.texto_corto(GameState.dia_absoluto)


func _mostrar_seccion(clave: String) -> void:
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

	if clave == "club":
		_mostrar_portada()
		return

	for entrada in subpaneles:
		var btn := Button.new()
		btn.text = str(entrada[1])
		var panel := str(entrada[0])
		btn.set_meta("panel", panel)
		btn.pressed.connect(func(): _mostrar_panel_de_seccion(panel))
		barra_subsolapas.add_child(btn)
	if not subpaneles.is_empty():
		_mostrar_panel_de_seccion(str(subpaneles[0][0]))


## Muestra un panel y marca su subsolapa. Reusa los `_mostrar_*` que ya
## existian para que cada panel siga refrescandose como siempre.
func _mostrar_panel_de_seccion(clave: String) -> void:
	var metodos := {
		"plantel": "_mostrar_plantel", "formacion": "_mostrar_formacion",
		"entrenamiento": "_mostrar_entrenamiento",
		"cantera": "_mostrar_cantera", "instalaciones": "_mostrar_instalaciones",
		"tabla": "_mostrar_tabla", "jugadores_liga": "_mostrar_jugadores_liga",
		"historial": "_mostrar_historial_partidos",
		"mercado": "_mostrar_mercado", "libres": "_mostrar_libres",
		"prestamos": "_mostrar_prestamos", "economia": "_mostrar_economia",
		"noticias": "_mostrar_noticias", "seleccion": "_mostrar_seleccion",
		"partida": "_mostrar_partida_panel",
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
		estilo.border_width_left = 4
		estilo.border_color = acento
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
	var hay_partido: bool = GameState.hay_partido_hoy()
	var caja_partido := _tarjeta(contenedor_portada, Tema.AMBAR if hay_partido else Tema.BORDE)
	caja_partido.add_child(Tema.etiqueta_seccion(Calendario.texto_largo(GameState.dia_absoluto)))
	var rival := _proximo_rival()
	var titulo := Label.new()
	if rival == null:
		titulo.text = "Temporada terminada."
	elif hay_partido:
		titulo.text = "%s  vs  %s   (%s)" % [
			equipo.nombre, rival.nombre, "de local" if _juega_de_local() else "de visitante"]
	else:
		titulo.text = "Sin partido hoy"
	Tema.numero(titulo, 24, Tema.TEXTO if hay_partido else Tema.SUAVE)
	caja_partido.add_child(titulo)

	# Lo que se sabe del rival: estilo, DT y si es clasico. Vivia en la
	# pantalla "Partido", pero es con lo que se elige el estilo propio, y
	# eso se decide antes de jugar.
	if rival != null:
		var informe := Label.new()
		informe.text = _texto_informe_rival()
		informe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		informe.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		informe.add_theme_color_override("font_color", Tema.SUAVE)
		caja_partido.add_child(informe)

	if rival != null and not hay_partido:
		var falta := GameState.dias_hasta_el_partido()
		var sub := Label.new()
		sub.text = "Fecha %d  ·  %s vs %s  ·  %s" % [
			GameState.fecha_actual + 1, equipo.nombre, rival.nombre,
			Calendario.en_cuantos_dias(falta)]
		sub.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
		sub.add_theme_color_override("font_color", Tema.SUAVE)
		caja_partido.add_child(sub)

	var fila_acciones := HBoxContainer.new()
	caja_partido.add_child(fila_acciones)
	if hay_partido:
		var btn_jugar := Button.new()
		btn_jugar.text = "Jugar el partido"
		btn_jugar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tema.primario(btn_jugar)
		btn_jugar.disabled = rival == null or GameState.juego_terminado
		btn_jugar.pressed.connect(func():
			_on_jugar_fecha()
			_refrescar_portada()
		)
		fila_acciones.add_child(btn_jugar)
	else:
		var btn_dia := Button.new()
		btn_dia.text = "Avanzar un dia"
		btn_dia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tema.primario(btn_dia)
		btn_dia.disabled = GameState.juego_terminado
		btn_dia.pressed.connect(func(): _avanzar_dias(false))
		fila_acciones.add_child(btn_dia)
		var btn_salto := Button.new()
		btn_salto.text = "Ir al proximo partido"
		btn_salto.custom_minimum_size = Vector2(230, Tema.ALTO_TACTIL)
		btn_salto.tooltip_text = "Pasa los dias de corrido, pero frena si pasa algo que necesita una decision."
		btn_salto.disabled = GameState.juego_terminado
		btn_salto.pressed.connect(func(): _avanzar_dias(true))
		fila_acciones.add_child(btn_salto)
	var btn_form := Button.new()
	btn_form.text = "Ver formacion"
	btn_form.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	btn_form.pressed.connect(func(): _mostrar_seccion("equipo"))
	fila_acciones.add_child(btn_form)

	# Simular tambien vive aca y no solo en Partido: la portada es desde
	# donde se juega, y mandar al jugador a otra seccion a buscar el boton
	# que salta la temporada es pedirle que adivine donde esta.
	var btn_simular := Button.new()
	btn_simular.text = TEXTO_SIMULAR_TEMPORADA
	btn_simular.custom_minimum_size = Vector2(280, Tema.ALTO_TACTIL)
	btn_simular.tooltip_text = "Juega de una todas las fechas que quedan, las tuyas incluidas: no vas a poder tocar nada hasta el final."
	btn_simular.disabled = rival == null or GameState.juego_terminado
	btn_simular.pressed.connect(func():
		_on_simular_temporada()
		_refrescar_portada()
	)
	fila_acciones.add_child(btn_simular)

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
		btn.pressed.connect(func(): _mostrar_seccion("mercado"))
		fila.add_child(btn)

	# --- Estado del club ---------------------------------------------------
	contenedor_portada.add_child(Tema.etiqueta_seccion("El club"))
	var estado := _tarjeta(contenedor_portada)
	# El objetivo con su advertencia de destitucion, que antes vivia en la
	# pantalla "Partido": es informacion para decidir, y se decide aca.
	var texto_objetivo := _texto_objetivo()
	if texto_objetivo != "":
		var l := Label.new()
		l.text = texto_objetivo
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if GameState.juego_terminado:
			l.add_theme_color_override("font_color", Tema.ROJO)
		estado.add_child(l)
	var linea := Label.new()
	linea.text = "Media del once %.1f   ·   disponibles %d de %d   ·   carga %s   ·   foco %s" % [
		equipo.media_equipo(), equipo.jugadores_sanos_count(),
		equipo.todos_los_jugadores().size(),
		CargaEntrenamiento.ETIQUETAS.get(equipo.carga_entrenamiento, "?"),
		FocoEquipo.ETIQUETAS.get(equipo.foco_equipo, "?")]
	linea.add_theme_color_override("font_color", Tema.SUAVE)
	estado.add_child(linea)


## Lo que esta esperando una decision tuya, ahora. Solo cosas accionables:
## una lista de "novedades" que no se pueden tocar no sirve de nada.
func _pendientes_de_portada() -> Array:
	var equipo := GameState.equipo_jugador
	var salida := []
	for o in equipo.ofertas:
		if str(o["estado"]) == Ofertas.PENDIENTE_NOSOTROS:
			salida.append({
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
				"color": Tema.AMBAR,
				"titulo": "Acordaste %s por %s" % [
					Economia.formato_dinero(o["monto"]), str(o["jugador"])],
				"detalle": "Falta firmar el contrato con el jugador.",
				"accion": "Firmar",
			})
	for id in equipo.conocimiento:
		if int(equipo.conocimiento[id]) > Investigadores.DIAS_VIGENCIA - 30:
			salida.append({
				"color": Tema.CELESTE,
				"titulo": "Informe nuevo listo",
				"detalle": "Ya podes ver su ficha completa en el mercado.",
				"accion": "Ver",
			})
			break
	return salida



# ---------------------------------------------------------------------------
# Entrenamiento
# ---------------------------------------------------------------------------

## Foco y carga viven ACA y no en Formacion. Estaban metidos en la fila de
## la formacion, al lado del desplegable tactico, como si fueran parte de
## armar el equipo: eran dos combos sin explicacion en una pantalla que
## habla de otra cosa. Son las dos decisiones que gobiernan como crece el
## plantel y merecen su propia seccion, con lo que hace cada opcion a la
## vista y no escondido en un tooltip.
var contenedor_entrenamiento: VBoxContainer
var option_carga_entr: OptionButton
var option_foco_entr: OptionButton
var label_reparto_foco: Label


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

	# --- Foco: que se entrena ------------------------------------------
	var caja_foco := _tarjeta(contenedor_entrenamiento, Tema.BORDE)
	caja_foco.add_child(Tema.etiqueta_seccion("Foco  ·  que se entrena"))
	var fila_foco := HBoxContainer.new()
	fila_foco.add_theme_constant_override("separation", 10)
	caja_foco.add_child(fila_foco)
	option_foco_entr = OptionButton.new()
	option_foco_entr.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	for area in FocoEquipo.AREAS:
		option_foco_entr.add_item(FocoEquipo.ETIQUETAS[area])
	var idx_foco := FocoEquipo.AREAS.find(equipo.foco_equipo)
	if idx_foco >= 0:
		option_foco_entr.selected = idx_foco
	option_foco_entr.item_selected.connect(func(i):
		_on_foco_equipo_elegido(i)
		_refrescar_entrenamiento())
	fila_foco.add_child(option_foco_entr)
	caja_foco.add_child(_texto_suave(
		"El presupuesto es FIJO: lo que ganan los atributos del area se lo sacas al resto. " \
		+ "Y se reparte entre los atributos del area, asi que un area chica da un empujon grande " \
		+ "a pocos y una grande da un empujon chico a muchos. Nadie retrocede: lo desatendido " \
		+ "crece mas despacio."))

	for area in FocoEquipo.AREAS:
		caja_foco.add_child(_fila_area_de_foco(area, equipo))

	# Cuanto pesa cada area en la temporada: cambiar a mitad de ano
	# reparte, no reinicia, y eso hay que poder verlo.
	var reparto := equipo.reparto_foco()
	if not reparto.is_empty():
		var partes := []
		for area in reparto:
			partes.append("%s %d%%" % [
				FocoEquipo.ETIQUETAS.get(area, area),
				int(round(float(reparto[area]) * 100.0))])
		caja_foco.add_child(_texto_suave(
			"Lo que va pesando esta temporada: %s." % ", ".join(partes)))


## Una fila por area, con sus atributos y cuanto multiplica cada cosa.
func _fila_area_de_foco(area: String, equipo: Team) -> Control:
	var actual: bool = area == equipo.foco_equipo
	var fila := Componentes.fila(FocoEquipo.AREAS.find(area) % 2 == 0)
	if actual:
		var e: StyleBoxFlat = fila.get_theme_stylebox("panel").duplicate()
		e.bg_color = Tema.PANEL_ALTO
		e.border_width_left = 3
		e.border_color = Tema.AMBAR
		fila.add_theme_stylebox_override("panel", e)
	var dentro := Componentes.contenido(fila)
	dentro.add_child(Componentes.celda(
		str(FocoEquipo.ETIQUETAS[area]), 130, Tema.AMBAR if actual else Tema.TEXTO))

	var atributos: Array = FocoEquipo.atributos_de(area)
	# Los multiplicadores reales, con la cuenta del propio sistema y no a
	# ojo: 19 atributos tiene un jugador de campo.
	var n_campo := 19
	var texto_mult := "todo parejo"
	if not atributos.is_empty():
		var n: int = atributos.size()
		texto_mult = "x%.2f   resto x%.2f" % [
			1.0 + FocoEquipo.PRESUPUESTO / float(n),
			maxf(FocoEquipo.MULTIPLICADOR_MINIMO,
				1.0 - FocoEquipo.PRESUPUESTO / float(n_campo - n))]
	# 250 y no 190: con menos, "el resto x0.79" se cortaba justo en el
	# numero, que es el dato por el que se elige.
	dentro.add_child(Componentes.celda_numero(texto_mult, 250, Tema.SUAVE))

	var detalle := Label.new()
	detalle.text = "%s %s" % [
		FocoEquipo.DESCRIPCIONES.get(area, ""),
		"" if atributos.is_empty() else "(%s)" % ", ".join(atributos)]
	detalle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalle.clip_text = true
	detalle.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	detalle.add_theme_color_override("font_color", Tema.SUAVE)
	dentro.add_child(detalle)
	return fila


func _texto_suave(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	l.add_theme_color_override("font_color", Tema.SUAVE)
	return l
