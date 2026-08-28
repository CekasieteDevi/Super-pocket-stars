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

var lista_ficha: RichTextLabel
var ficha_jugador_id := -1
## De que club es el jugador de la ficha. null = uno propio. Si es ajeno,
## la ficha se dibuja en modo AJENO: sin lo que solo sabe un club de su
## propia gente y sin las habilidades dormidas (ver _refrescar_ficha).
var ficha_club: Team = null
var boton_volver_ficha: Button
var option_formacion: OptionButton
var option_carga: OptionButton
var option_foco: OptionButton
var label_foco_efecto: Label
var label_carga_efecto: Label
var contenedor_formacion: VBoxContainer
var cancha_formacion: CanchaFormacion
var label_formacion_estado: Label
## Jugador tocado primero en la pantalla de formacion, a la espera del
## segundo para intercambiarlos. -1 = nadie seleccionado.
var contenedor_tabla: VBoxContainer
var _fila_propia_tabla: Control = null
var label_tabla_leyenda: Label
var label_resultado: Label
var lista_log: RichTextLabel
var lista_estadisticas: RichTextLabel
var boton_jugar_fecha: Button
var boton_ver_animado: Button
var boton_simular_temporada: Button
## En un solo lugar: estaba escrito a mano al construirlo y al terminar de
## simular, y bastaba tocar uno para que el boton cambiara de nombre solo.
const TEXTO_SIMULAR_TEMPORADA := "Simular resto de la temporada"
var label_objetivo: Label
var option_estilo: OptionButton
var option_cambios: OptionButton
var label_informe_rival: Label

const OPCIONES_CAMBIOS := ["equilibrado", "descanso", "rendimiento"]
const ETIQUETAS_CAMBIOS := {"equilibrado": "Equilibrado", "descanso": "Priorizar descanso", "rendimiento": "Priorizar rendimiento"}
var vista_partido: VistaPartido
var contenedor_economia: VBoxContainer
var lista_cantera: RichTextLabel
var contenedor_cantera_botones: VBoxContainer
var contenedor_noticias: VBoxContainer
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
	_construir_panel_partido(contenedor)
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
	_construir_dialogo_negociacion()
	_construir_dialogo_prestamo()
	_construir_dialogo_investigador()

	# Al final, cuando ya esta todo construido: deja las listas
	# deslizables con el dedo (ver _ajustar_para_tactil).
	_ajustar_para_tactil(self)

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
	var panel := HBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padre.add_child(panel)
	paneles["plantel"] = panel

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
	for attr in _mejores_atributos(j, 5):
		caja.add_child(Componentes.barra_atributo(
			attr, int(j["atributos"][attr]), int(Progresion.techo_de(j, attr))))

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

	lista_ficha = RichTextLabel.new()
	lista_ficha.bbcode_enabled = true
	lista_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_ficha)


## club = null para uno propio; el Team dueño si es ajeno (viene del
## mercado, y solo se llega hasta aca con el informe terminado).
func _mostrar_ficha(jugador_id: int, club: Team = null) -> void:
	ficha_jugador_id = jugador_id
	ficha_club = club
	_ocultar_todos()
	paneles["ficha"].visible = true
	_refrescar_ficha()


## Barra de texto para un atributo. Se pinta con color segun el valor
## porque una grilla de 25 numeros sueltos no se lee: lo que se quiere ver
## de un vistazo es en que es bueno y en que no.
func _barra_atributo(nombre: String, valor: int, techo: int) -> String:
	var llenos: int = int(round(valor / 10.0))
	var color := "#c0392b"
	if valor >= 75:
		color = "#27ae60"
	elif valor >= 55:
		color = "#7fb069"
	elif valor >= 40:
		color = "#d4a017"
	# El techo de ESTE atributo (§7.2) es lo que dice si todavia le queda
	# margen ahi o si ya llego: dos jugadores con el mismo potencial global
	# pueden tener techos muy distintos atributo por atributo.
	var margen := ""
	if techo > valor + 1:
		margen = "  [color=#7f8c8d]-> %d[/color]" % techo
	else:
		margen = "  [color=#7f8c8d](al tope)[/color]"
	return "  %-14s [color=%s]%3d %s[/color]%s
" % [
		nombre.replace("_", " "), color, valor,
		"█".repeat(llenos) + "░".repeat(10 - llenos), margen]


func _refrescar_ficha() -> void:
	var ajeno: bool = ficha_club != null
	var equipo: Team = ficha_club if ajeno else GameState.equipo_jugador
	boton_volver_ficha.text = "< Volver al mercado" if ajeno else "< Volver al plantel"

	# De un ajeno solo se llega hasta aca con el informe terminado, pero se
	# vuelve a chequear igual: la ficha se puede quedar abierta mientras
	# pasa el tiempo y el jugador puede haber cambiado de club.
	if ajeno and not Investigadores.conoce(GameState.equipo_jugador, ficha_jugador_id):
		lista_ficha.text = "Todavia no lo investigaste."
		return

	# _buscar_jugador_por_id ya mira titulares, banco y cantera.
	var j := _buscar_jugador_por_id(equipo, ficha_jugador_id)
	if j.is_empty():
		lista_ficha.text = "Ese jugador ya no esta en %s." % (equipo.nombre if ajeno else "el plantel")
		return

	var t := "[b]%s[/b]   %s, %d anos
" % [_nombre_jugador(j), j["posicion"], j["edad"]]
	if ajeno:
		t += "[color=#8ecae6]%s[/color]
" % equipo.nombre
	t += "media %.1f   potencial %d   genetica %s
" % [j["media"], j["potencial"], j["genetica_tier"]]
	t += "pie %s
" % ("izquierdo" if Personalidad.pie_preferido(j) < 0 else "derecho")

	var p: Dictionary = j.get("personalidades", {})
	if p.is_empty():
		t += "sin rasgos de personalidad
"
	else:
		t += "[color=#27ae60]%s[/color]  /  [color=#c0392b]%s[/color]
" % [
			p.get("positiva", "-"), p.get("negativa", "-")]
	var tag := _tag_habilidad(j, ajeno)
	if tag != "":
		t += "habilidad:%s
" % tag

	t += "
[b]Estado[/b]
"
	if not ajeno:
		# La energia es del partido en curso: de un jugador ajeno no se
		# sabe, y ademas no significa nada fuera de su propio calendario.
		t += "  energia      %3d%%
" % int(round(equipo.resistencia_pct(j["id"]) * 100.0))
	t += "  animo        %3d
" % int(equipo.animo.get(j["id"], 50))
	if equipo.esta_lesionado(j["id"]):
		var les: Dictionary = equipo.lesiones[j["id"]]
		t += "  [color=#c0392b]lesionado: %s, %d dias[/color]
" % [les["tipo"], les["dias_restantes"]]
	if not ajeno:
		var susp: int = int(equipo.suspendidos.get(j["id"], 0))
		if susp > 0:
			t += "  [color=#c0392b]suspendido %d fecha(s)[/color]
" % susp
	t += "  contrato     %d año(s),  sueldo %s
" % [
		int(equipo.contratos.get(j["id"], 0)), Economia.formato_dinero(equipo.sueldos.get(j["id"], 0))]
	if equipo.clausulas.has(j["id"]):
		t += "  clausula     %s
" % Economia.formato_dinero(equipo.clausulas[j["id"]])
	if ajeno:
		t += "  valor        %s
" % Economia.formato_dinero(
			ValorJugador.calcular(j, equipo.animo.get(j["id"], 50.0), equipo.contratos.get(j["id"], 3)))

	# Atributos por grupo. El de arquero solo si es arquero: a un delantero
	# no le sirve saber su `estirada`.
	var grupos: Dictionary = PlayerGenerator.get_attribute_groups()
	var attrs: Dictionary = j["atributos"]
	for grupo in grupos:
		if grupo == "arquero" and j["posicion"] != "ARQ":
			continue
		t += "
[b]%s[/b]
" % grupo.capitalize()
		for a in grupos[grupo]:
			if attrs.has(a):
				t += _barra_atributo(a, int(attrs[a]), Progresion.techo_de(j, a))
	lista_ficha.text = t


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

	fila.add_child(Tema.etiqueta_seccion("Carga"))
	option_carga = OptionButton.new()
	for nivel in CargaEntrenamiento.NIVELES:
		option_carga.add_item(CargaEntrenamiento.ETIQUETAS[nivel])
	option_carga.item_selected.connect(_on_carga_elegida)
	fila.add_child(option_carga)

	fila.add_child(Tema.etiqueta_seccion("Foco"))
	option_foco = OptionButton.new()
	for area in FocoEquipo.AREAS:
		option_foco.add_item(FocoEquipo.ETIQUETAS[area])
	option_foco.item_selected.connect(_on_foco_equipo_elegido)
	fila.add_child(option_foco)

	label_foco_efecto = Label.new()
	label_foco_efecto.visible = false
	panel.add_child(label_foco_efecto)

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
	var idx_carga := CargaEntrenamiento.NIVELES.find(equipo.carga_entrenamiento)
	if idx_carga >= 0:
		option_carga.selected = idx_carga
	label_carga_efecto.text = _texto_carga(equipo)
	option_carga.tooltip_text = CargaEntrenamiento.resumen(equipo.carga_entrenamiento)
	var idx_foco := FocoEquipo.AREAS.find(equipo.foco_equipo)
	if idx_foco >= 0:
		option_foco.selected = idx_foco
	option_foco.tooltip_text = "%s%s" % [
		FocoEquipo.resumen(equipo.foco_equipo), _reparto_foco_texto(equipo)]

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


func _construir_panel_partido(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["partido"] = panel

	# Los controles y los tres botones ARRIBA, y todo lo que cambia de alto
	# —resultado, estadisticas, relato— abajo y adentro de un scroll.
	#
	# Antes iba todo en un VBox suelto y el panel no scrollea: con el
	# relato de un partido largo el contenido pasaba el alto de la pantalla
	# y los botones del final —"Ver partido animado" y "Simular resto de la
	# temporada"— quedaban abajo del borde, sin forma de llegar. Parecian
	# borrados.
	var barra := HFlowContainer.new()
	barra.add_theme_constant_override("h_separation", 12)
	barra.add_theme_constant_override("v_separation", 8)
	panel.add_child(barra)

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

	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	barra.add_child(_grupo_filtro(" ", acciones))

	boton_jugar_fecha = Button.new()
	boton_jugar_fecha.text = "Jugar siguiente fecha"
	boton_jugar_fecha.custom_minimum_size = Vector2(230, Tema.ALTO_TACTIL)
	# La accion principal de la pantalla de partido: la unica ambar de aca.
	Tema.primario(boton_jugar_fecha)
	boton_jugar_fecha.pressed.connect(_on_jugar_fecha)
	acciones.add_child(boton_jugar_fecha)

	boton_ver_animado = Button.new()
	# Mismo texto que le pone _on_jugar_fecha al habilitarlo: con dos
	# distintos el boton se renombraba solo al terminar un partido.
	boton_ver_animado.text = "Ver partido animado"
	boton_ver_animado.custom_minimum_size = Vector2(200, Tema.ALTO_TACTIL)
	boton_ver_animado.tooltip_text = "Reproduce tu ultimo partido con la vista de cancha."
	boton_ver_animado.disabled = true
	boton_ver_animado.pressed.connect(_mostrar_partido_animado)
	acciones.add_child(boton_ver_animado)

	boton_simular_temporada = Button.new()
	boton_simular_temporada.text = TEXTO_SIMULAR_TEMPORADA
	boton_simular_temporada.custom_minimum_size = Vector2(280, Tema.ALTO_TACTIL)
	boton_simular_temporada.tooltip_text = "Juega de una todas las fechas que quedan, las tuyas incluidas: no vas a poder tocar nada hasta el final."
	boton_simular_temporada.pressed.connect(_on_simular_temporada)
	acciones.add_child(boton_simular_temporada)

	label_objetivo = Label.new()
	label_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_objetivo.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_objetivo.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(label_objetivo)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var dentro := VBoxContainer.new()
	dentro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(dentro)

	label_informe_rival = Label.new()
	label_informe_rival.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dentro.add_child(label_informe_rival)

	label_resultado = Label.new()
	label_resultado.text = "Todavia no jugaste ninguna fecha."
	label_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dentro.add_child(label_resultado)

	lista_estadisticas = RichTextLabel.new()
	lista_estadisticas.fit_content = true
	lista_estadisticas.custom_minimum_size = Vector2(0, 120)
	dentro.add_child(lista_estadisticas)

	lista_log = RichTextLabel.new()
	lista_log.fit_content = true
	lista_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dentro.add_child(lista_log)


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
	vista_partido.hud.menu_pedido.connect(_mostrar_partido)


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
	var donde := Mercado.ubicar(vendedor, jugador_id)
	var nombre := _nombre_jugador(donde["jugador"]) if not donde.is_empty() else ""
	var r := Investigadores.investigar(GameState.equipo_jugador, jugador_id, vendedor.nombre, nombre)
	if r["exito"]:
		label_mercado_estado.text = "Investigador de %d estrellas asignado: el informe tarda %d dias." % [
			int(r["investigador"]["estrellas"]), int(round(float(r["dias_totales"])))]
	else:
		label_mercado_estado.text = "No se pudo: %s" % r["motivo"]
	_on_buscar_mercado()


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


## Las noticias de la temporada. Van en tarjetas y de la mas NUEVA a la
## mas vieja: en un parrafo corrido de treinta lineas lo ultimo que paso
## quedaba al fondo, que es justo lo que se viene a leer.
func _construir_panel_noticias(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["noticias"] = panel

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
	if t.contains("descen") or t.contains("descien") or t.contains("quiebra") 			or t.contains("lesion"):
		return Tema.ROJO
	if t.contains("ascen") or t.contains("ascien") or t.contains("campe") 			or t.contains("gana"):
		return Tema.VERDE
	if t.contains("fich") or t.contains("transfer") or t.contains("prestamo"):
		return Tema.CELESTE
	return Tema.BORDE


func _refrescar_noticias() -> void:
	if contenedor_noticias == null:
		return
	for hijo in contenedor_noticias.get_children():
		hijo.queue_free()

	if GameState.noticias.is_empty():
		var vacio := Componentes.tarjeta()
		var l := Label.new()
		l.text = "Todavia no hay noticias: se generan al cerrar cada temporada."
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Tema.SUAVE)
		vacio.add_child(l)
		contenedor_noticias.add_child(vacio)
		return

	var total := GameState.noticias.size()
	for i in range(total - 1, -1, -1):
		var texto := str(GameState.noticias[i])
		var tarjeta := Componentes.tarjeta(_acento_de_noticia(texto))
		var l := Label.new()
		l.text = texto
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tarjeta.add_child(l)
		contenedor_noticias.add_child(tarjeta)


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
	advertencia.text = "Guardar pisa lo que hubiera. Cargar reemplaza TODO lo que este pasando ahora por lo del archivo. Borrar elimina el archivo y no toca la partida en curso."
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

	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(hueco)

	# Borrar lejos de las otras dos y en rojo: es la unica que no se puede
	# deshacer.
	boton_borrar_partida = Button.new()
	boton_borrar_partida.text = "Borrar guardado"
	boton_borrar_partida.custom_minimum_size = Vector2(180, Tema.ALTO_TACTIL)
	boton_borrar_partida.add_theme_color_override("font_color", Tema.ROJO)
	boton_borrar_partida.pressed.connect(_on_borrar_partida)
	barra.add_child(boton_borrar_partida)


func _refrescar_partida_guardado() -> void:
	var hay_guardado := GameState.hay_partida_guardada()
	boton_cargar_partida.disabled = not hay_guardado
	boton_borrar_partida.disabled = not hay_guardado
	if label_partida_estado.text == "":
		label_partida_estado.text = "Hay una partida guardada." if hay_guardado \
			else "No hay ninguna partida guardada todavia."


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
		_refrescar_ultimo_partido()
		_mostrar_plantel()
	else:
		label_partida_estado.text = "No se pudo cargar la partida (archivo corrupto o inexistente)."
	_refrescar_partida_guardado()


## Repinta la pantalla de Partido con el último partido jugado. Hace
## falta al CARGAR: el resultado viaja en el guardado, pero la pantalla se
## había armado con el texto inicial y se quedaba diciendo "todavía no
## jugaste ninguna fecha" con una temporada entera encima.
func _refrescar_ultimo_partido() -> void:
	var r: Dictionary = GameState.ultimo_resultado
	if r.is_empty():
		label_resultado.text = "Todavia no jugaste ninguna fecha."
		lista_log.text = ""
		lista_estadisticas.text = ""
		_refrescar_boton_animado()
		return
	label_resultado.text = "Ultimo partido:  %s  %d - %d  %s" % [
		r["local"], r["gl"], r["gv"], r["visitante"]
	]
	var texto_log := ""
	for entry in GameState.ultimo_log:
		if entry.find("GOL") != -1 or entry.find("TARJETA") != -1 or entry.find("CAMBIO") != -1:
			texto_log += entry + "
"
	lista_log.text = texto_log
	lista_estadisticas.text = _texto_estadisticas(r)
	_refrescar_boton_animado()


## La repeticion necesita los FOTOGRAMAS, que no se guardan por tamano, no
## los eventos. Al cargar una partida hay resultado pero no repeticion, y
## el boton tiene que decir por que en vez de quedar gris y mudo.
func _refrescar_boton_animado() -> void:
	var hay: bool = not GameState.ultimos_fotogramas.is_empty()
	boton_ver_animado.disabled = not hay
	boton_ver_animado.text = "Ver partido animado" if hay 		else "Ver partido animado (la repeticion no se guarda)"


func _on_borrar_partida() -> void:
	GameState.borrar_partida()
	label_partida_estado.text = "Partida guardada borrada."
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
		label_resultado.text = "Temporada terminada."
		return

	var temporada_antes := GameState.temporada_actual
	GameState.jugar_siguiente_fecha()

	var r: Dictionary = GameState.ultimo_resultado
	if r.size() > 0:
		label_resultado.text = "Fecha %d/%d:  %s  %d - %d  %s" % [
			GameState.fecha_actual, GameState.liga_jugador().fixture.size(),
			r["local"], r["gl"], r["gv"], r["visitante"]
		]
		# GameState.ultimo_log vacio = fue un forfeit (Liga._resolver_forfeit
		# no llama a MatchEngine.simular()), asi que equipo_jugador.clima_
		# partido/arbitro_partido quedarian con lo que haya seteado el
		# ULTIMO partido real jugado — mostrarlo seria mostrar informacion
		# vieja de otra fecha.
		if not GameState.ultimo_log.is_empty():
			var clima: String = GameState.equipo_jugador.clima_partido
			var clima_texto := "  (Clima: %s, árbitro %s)" % [clima, GameState.equipo_jugador.arbitro_partido] if clima != "" else "  (árbitro %s)" % GameState.equipo_jugador.arbitro_partido
			label_resultado.text += clima_texto
	if GameState.temporada_actual != temporada_antes:
		label_resultado.text += _texto_cierre_temporada()

	var texto_log := ""
	for entry in GameState.ultimo_log:
		if entry.find("GOL") != -1 or entry.find("TARJETA") != -1 or entry.find("CAMBIO") != -1:
			texto_log += entry + "\n"
	lista_log.text = texto_log
	_refrescar_boton_animado()
	lista_estadisticas.text = _texto_estadisticas(r) if r.size() > 0 else ""

	_refrescar_tabla()
	_refrescar_plantel()
	_refrescar_informe_rival()
	_refrescar_objetivo()


## Resumen de estadisticas post-partido (posesion/tiros/pases) — pensado
## para que efectos como el choque de estilos (§8.6.3) o el rasgo del DT
## (§8.6.4) se puedan VER, ya que hoy solo cambian el % de exito de cada
## duelo y eso queda invisible si lo unico que se muestra es el marcador.
func _texto_estadisticas(r: Dictionary) -> String:
	var stats := EstadisticasPartido.calcular(GameState.ultimos_eventos, r["local"], r["visitante"])
	var loc: Dictionary = stats[r["local"]]
	var vis: Dictionary = stats[r["visitante"]]
	var texto := "%-24s %10s %10s\n" % ["", r["local"], r["visitante"]]
	texto += "%-24s %9.0f%% %9.0f%%\n" % ["Posesion", loc["posesion_pct"], vis["posesion_pct"]]
	texto += "%-24s %10d %10d\n" % ["Tiros", loc["tiros"], vis["tiros"]]
	texto += "%-24s %10d %10d\n" % ["Tiros al arco", loc["tiros_al_arco"], vis["tiros_al_arco"]]
	texto += "%-24s %10s %10s\n" % [
		"Pases (completados)",
		"%d/%d" % [loc["pases_completados"], loc["pases_intentados"]],
		"%d/%d" % [vis["pases_completados"], vis["pases_intentados"]],
	]
	return texto


## [debug] Simula todas las fechas que queden de la temporada de una,
## para no tener que clickear "jugar fecha" muchas veces al probar.
func _on_simular_temporada() -> void:
	if GameState.juego_terminado:
		_refrescar_objetivo()
		return
	if not GameState.hay_fecha_pendiente():
		label_resultado.text = "Temporada terminada."
		return

	# Simular una temporada entera bloquea el hilo unos segundos. Sin
	# esto el boton se quedaba igual y parecia que el toque no habia
	# entrado. Los dos await dejan que Godot dibuje el cambio ANTES de
	# empezar a laburar: sin ellos el texto nuevo no llega a pintarse.
	boton_simular_temporada.text = "Simulando..."
	boton_simular_temporada.disabled = true
	label_resultado.text = "Simulando la temporada, esto tarda unos segundos..."
	await get_tree().process_frame
	await get_tree().process_frame

	var temporada_antes := GameState.temporada_actual
	GameState.simular_temporada_completa()

	boton_simular_temporada.text = TEXTO_SIMULAR_TEMPORADA
	boton_simular_temporada.disabled = false

	if GameState.temporada_actual != temporada_antes:
		label_resultado.text = "[debug] Temporada simulada entera." + _texto_cierre_temporada()
	else:
		label_resultado.text = "[debug] Se jugaron las fechas que quedaban."

	# A diferencia de "jugar fecha", esto simula muchas fechas de una — no
	# tiene sentido mostrar el log/animado de sólo el último partido
	# jugado, como si fuera el único que pasó.
	GameState.ultimo_resultado = {}
	GameState.ultimo_log = []
	GameState.ultimos_eventos = []
	lista_log.text = ""
	lista_estadisticas.text = ""
	_refrescar_boton_animado()

	_refrescar_tabla()
	_refrescar_plantel()
	_refrescar_informe_rival()
	_refrescar_objetivo()


func _mostrar_plantel() -> void:
	_ocultar_todos()
	paneles["plantel"].visible = true
	_refrescar_plantel()


func _mostrar_tabla() -> void:
	_ocultar_todos()
	paneles["tabla"].visible = true
	_refrescar_tabla()


func _mostrar_partido() -> void:
	_ocultar_todos()
	paneles["partido"].visible = true
	var idx_actual := Estilos.LISTA.find(GameState.equipo_jugador.estilo)
	option_estilo.select(max(idx_actual, 0))
	var idx_cambios := OPCIONES_CAMBIOS.find(GameState.equipo_jugador.config_cambios)
	option_cambios.select(max(idx_cambios, 0))
	_refrescar_informe_rival()
	_refrescar_objetivo()


## §10.5/§15: objetivo de la directiva para esta temporada, y el estado de
## game over si la directiva ya te destituyó (2 temporadas seguidas sin
## cumplir). Cuando termina el juego se deshabilitan los botones que
## avanzarían el calendario — la única salida es borrar la partida.
func _refrescar_objetivo() -> void:
	if GameState.juego_terminado:
		label_objetivo.text = "GAME OVER: %s" % GameState.motivo_fin_partida
		boton_jugar_fecha.disabled = true
		boton_simular_temporada.disabled = true
		return

	boton_jugar_fecha.disabled = false
	boton_simular_temporada.disabled = false
	var objetivo: Dictionary = GameState.equipo_jugador.objetivo_temporada
	if objetivo.is_empty():
		label_objetivo.text = ""
		return
	var incumplidos: int = GameState.equipo_jugador.objetivos_incumplidos_seguidos
	var advertencia := ""
	if incumplidos > 0:
		advertencia = "  (⚠ %d/%d temporadas sin cumplir — te destituyen a la 2ª seguida)" % [incumplidos, Objetivos.MAX_INCUMPLIDOS_SEGUIDOS]
	label_objetivo.text = "Objetivo de la directiva: %s%s" % [objetivo["descripcion"], advertencia]


## §8.6.3/§8.6.5: le muestra al jugador con qué rival juega la próxima
## fecha y cómo pega el choque de estilos, para que elija táctica con
## información en vez de a ciegas.
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


func _refrescar_informe_rival() -> void:
	var rival := _proximo_rival()
	if rival == null:
		label_informe_rival.text = ""
		return
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
	label_informe_rival.text = "Próximo rival: %s — estilo %s%s%s%s" % [rival.nombre, rival.estilo, pista, dt_texto, clasico_texto]


func _on_estilo_seleccionado(idx: int) -> void:
	GameState.equipo_jugador.estilo = Estilos.LISTA[idx]
	_refrescar_informe_rival()


func _on_config_cambios_seleccionado(idx: int) -> void:
	GameState.equipo_jugador.config_cambios = OPCIONES_CAMBIOS[idx]


func _mostrar_partido_animado() -> void:
	_ocultar_todos()
	paneles["partido_animado"].visible = true
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
	var colores := ColoresClub.par(local.nombre, visitante.nombre)
	vista_partido.iniciar(
		GameState.ultimos_fotogramas, colores[0], colores[1],
		local.nombre, visitante.nombre,
		VistaPartido.construir_nombres(local, visitante),
		VistaCancha.estado_desde_calidad(local.calidad_cancha))


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
		["cantera", "Cantera"], ["instalaciones", "Instalaciones"]]},
	{"clave": "partido", "nombre": "Partido", "paneles": [
		["partido", "Partido"], ["tabla", "Tabla"]]},
	{"clave": "mercado", "nombre": "Mercado", "paneles": [
		["mercado", "Mercado"], ["libres", "Libres"], ["prestamos", "Prestamos"]]},
	{"clave": "mas", "nombre": "Mas", "paneles": [
		["economia", "Economia"], ["noticias", "Noticias"],
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


func _refrescar_barra_contexto() -> void:
	if label_barra_club == null:
		return
	var equipo := GameState.equipo_jugador
	label_barra_club.text = equipo.nombre
	var tabla := GameState.liga_jugador().tabla_ordenada()
	var puesto: int = tabla.find(equipo.nombre) + 1
	label_barra_posicion.text = "  Division %d  ·  %d° de %d" % [
		GameState.division_jugador + 1, puesto, tabla.size()]
	label_barra_plata.text = Economia.formato_dinero(equipo.caja["fichajes"])
	label_barra_fecha.text = "%d / %d" % [
		GameState.fecha_actual + 1, GameState.liga_jugador().fixture.size()]


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
		"cantera": "_mostrar_cantera", "instalaciones": "_mostrar_instalaciones",
		"partido": "_mostrar_partido", "tabla": "_mostrar_tabla",
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

	# --- Proximo partido, con su boton -------------------------------------
	var caja_partido := _tarjeta(contenedor_portada, Tema.AMBAR)
	caja_partido.add_child(Tema.etiqueta_seccion(
		"Proximo partido  ·  fecha %d" % (GameState.fecha_actual + 1)))
	var rival := _proximo_rival()
	var titulo := Label.new()
	if rival == null:
		titulo.text = "Temporada terminada."
	else:
		var de_local := false
		var liga := GameState.liga_jugador()
		for partido in liga.fixture[GameState.fecha_actual]:
			if liga.equipos[partido[0]] == equipo:
				de_local = true
		titulo.text = "%s  vs  %s   (%s)" % [
			equipo.nombre, rival.nombre, "de local" if de_local else "de visitante"]
	Tema.numero(titulo, 24, Tema.TEXTO)
	caja_partido.add_child(titulo)

	var fila_acciones := HBoxContainer.new()
	caja_partido.add_child(fila_acciones)
	var btn_jugar := Button.new()
	btn_jugar.text = "Jugar la fecha"
	btn_jugar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tema.primario(btn_jugar)
	btn_jugar.disabled = rival == null or GameState.juego_terminado
	btn_jugar.pressed.connect(func():
		_on_jugar_fecha()
		_refrescar_portada()
	)
	fila_acciones.add_child(btn_jugar)
	var btn_form := Button.new()
	btn_form.text = "Ver formacion"
	btn_form.custom_minimum_size = Vector2(220, Tema.ALTO_TACTIL)
	btn_form.pressed.connect(func(): _mostrar_seccion("equipo"))
	fila_acciones.add_child(btn_form)

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
	var objetivo: Dictionary = equipo.objetivo_temporada
	if not objetivo.is_empty():
		var l := Label.new()
		l.text = "Objetivo: %s" % objetivo["descripcion"]
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

