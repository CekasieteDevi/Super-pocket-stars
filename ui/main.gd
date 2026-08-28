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
var label_objetivo: Label
var option_estilo: OptionButton
var option_cambios: OptionButton
var label_informe_rival: Label

const OPCIONES_CAMBIOS := ["equilibrado", "descanso", "rendimiento"]
const ETIQUETAS_CAMBIOS := {"equilibrado": "Equilibrado", "descanso": "Priorizar descanso", "rendimiento": "Priorizar rendimiento"}
var vista_partido: VistaPartido
var lista_economia: RichTextLabel
var lista_cantera: RichTextLabel
var contenedor_cantera_botones: VBoxContainer
var lista_noticias: RichTextLabel
var label_mercado_estado: Label
var contenedor_libres_botones: VBoxContainer
var label_libres_estado: Label
var contenedor_prestamos_ceder_botones: VBoxContainer
var label_prestamos_estado: Label
var contenedor_instalaciones_botones: VBoxContainer
var label_instalaciones_estado: Label
var lista_seleccion: RichTextLabel
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

	var contenedor := Control.new()
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columna.add_child(contenedor)

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
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_lista_plantel = VBoxContainer.new()
	contenedor_lista_plantel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_lista_plantel)

	var lateral := ScrollContainer.new()
	lateral.custom_minimum_size = Vector2(430, 0)
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
	caja_pos.custom_minimum_size = Vector2(64, 0)
	var color_pos := Color("#4a2a28") if equipo.esta_lesionado(id) else Color("#2f4a3c")
	caja_pos.add_child(Componentes.chip(str(j["posicion"]), color_pos))
	dentro.add_child(caja_pos)

	var btn := Button.new()
	btn.text = _nombre_jugador(j)
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	dentro.add_child(Componentes.celda_numero("%.1f" % float(j["media"]), 70))
	dentro.add_child(Componentes.celda("→%d" % int(j["potencial"]), 60, Tema.SUAVE))

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
	dentro.add_child(Componentes.celda(estado, 74, color))

	# Ficha y no "Subir": cambiar jugadores de lugar se hace arrastrando en
	# Formacion, que es donde se ve la cancha. Tener las dos formas en dos
	# pantallas distintas confundia mas de lo que ayudaba.
	var btn_ficha := Button.new()
	btn_ficha.text = "Ficha"
	btn_ficha.custom_minimum_size = Vector2(96, 0)
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

	label_carga_efecto = Label.new()
	label_carga_efecto.add_theme_color_override("font_color", Tema.SUAVE)
	label_carga_efecto.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	label_carga_efecto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sin recorte, su texto fija el ancho minimo de la fila y ese minimo
	# empuja el de la pantalla entera: el banco de la derecha se iba fuera
	# del viewport. Que se corte el texto, no la UI.
	label_carga_efecto.clip_text = true
	label_carga_efecto.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fila.add_child(label_carga_efecto)

	label_foco_efecto = Label.new()
	label_foco_efecto.visible = false
	panel.add_child(label_foco_efecto)

	label_formacion_estado = Label.new()
	label_formacion_estado.text = "Arrastrá un jugador sobre otro para cambiarlos de lugar."
	label_formacion_estado.add_theme_color_override("font_color", Tema.SUAVE)
	panel.add_child(label_formacion_estado)

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
	label_carga_efecto.tooltip_text = label_carga_efecto.text
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

	var fila_tactica := HBoxContainer.new()
	panel.add_child(fila_tactica)
	var label_tactica := Label.new()
	label_tactica.text = "Tu estilo de juego: "
	fila_tactica.add_child(label_tactica)
	option_estilo = OptionButton.new()
	for estilo in Estilos.LISTA:
		option_estilo.add_item(estilo)
	option_estilo.item_selected.connect(_on_estilo_seleccionado)
	fila_tactica.add_child(option_estilo)

	var fila_cambios := HBoxContainer.new()
	panel.add_child(fila_cambios)
	var label_cambios := Label.new()
	label_cambios.text = "Cambios automaticos: "
	fila_cambios.add_child(label_cambios)
	option_cambios = OptionButton.new()
	for opcion in OPCIONES_CAMBIOS:
		option_cambios.add_item(ETIQUETAS_CAMBIOS[opcion])
	option_cambios.item_selected.connect(_on_config_cambios_seleccionado)
	fila_cambios.add_child(option_cambios)

	label_objetivo = Label.new()
	panel.add_child(label_objetivo)

	label_informe_rival = Label.new()
	panel.add_child(label_informe_rival)

	boton_jugar_fecha = Button.new()
	boton_jugar_fecha.text = "Jugar siguiente fecha"
	# La accion principal de la pantalla de partido: la unica ambar de aca.
	Tema.primario(boton_jugar_fecha)
	boton_jugar_fecha.pressed.connect(_on_jugar_fecha)
	panel.add_child(boton_jugar_fecha)

	label_resultado = Label.new()
	label_resultado.text = "Todavia no jugaste ninguna fecha."
	label_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label_resultado)

	lista_estadisticas = RichTextLabel.new()
	lista_estadisticas.custom_minimum_size = Vector2(0, 130)
	panel.add_child(lista_estadisticas)

	lista_log = RichTextLabel.new()
	lista_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_log)

	boton_ver_animado = Button.new()
	boton_ver_animado.text = "Ver partido animado"
	boton_ver_animado.disabled = true
	boton_ver_animado.pressed.connect(_mostrar_partido_animado)
	panel.add_child(boton_ver_animado)

	var separador := HSeparator.new()
	panel.add_child(separador)

	boton_simular_temporada = Button.new()
	boton_simular_temporada.text = "[debug] Simular resto de la temporada"
	boton_simular_temporada.pressed.connect(_on_simular_temporada)
	panel.add_child(boton_simular_temporada)


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


func _construir_panel_economia(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["economia"] = panel

	var titulo := Label.new()
	titulo.text = "Economia del club"
	panel.add_child(titulo)

	lista_economia = RichTextLabel.new()
	lista_economia.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_economia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_economia)


func _refrescar_economia() -> void:
	var equipo := GameState.equipo_jugador
	var texto := "Reputacion: %.1f / 100%s\n" % [equipo.reputacion, "  (EN QUIEBRA)" if equipo.quebrado else ""]
	texto += "Hinchas: %.1f / 100 (racha sin ganar: %d)  — suman ganando, se pierden con una racha larga sin ganar, y ascender/descender pesa fuerte.\n\n" % [equipo.fans, equipo.racha_sin_ganar]

	var sueldos_totales := 0.0
	for id in equipo.sueldos:
		sueldos_totales += equipo.sueldos[id]

	var informe: Dictionary = GameState.ultimo_informe_economico
	if informe.is_empty():
		texto += "Ultimo balance: todavia no cerraste una temporada.\n"
		texto += "La plata entra recien cuando termina la fecha 38 (entradas + sponsor + premio segun tabla).\n\n"
	else:
		texto += "Ultimo balance de temporada:\n"
		texto += "  Ingresos            %s\n" % Economia.formato_dinero(informe["ingresos"])
		texto += "  Egresos             %s\n" % Economia.formato_dinero(informe["egresos"])
		texto += "    de los cuales sueldos:      %s\n" % Economia.formato_dinero(informe["sueldos"])
		texto += "    de los cuales mantenimiento: %s\n" % Economia.formato_dinero(informe["mantenimiento"])
		texto += "  Neto                %s%s\n\n" % [Economia.formato_dinero(informe["neto"]), "  (en rojo)" if informe["neto"] < 0 else ""]

	# "Restante" es lo que tenes disponible AHORA para gastar de cada
	# categoria — la plata que no gastaste una temporada se ACUMULA para la
	# siguiente en vez de perderse, asi que puede ser mayor que lo que se
	# asigno esta temporada si venis ahorrando. No se puede gastar plata de
	# Fichajes en Contratos ni viceversa, por eso no hay un "Total" (sumarlos
	# no te dice cuanto podes gastar en nada concreto). "Usado" sale de
	# comparar contra la foto de la caja justo despues del ultimo reparto,
	# antes de que el mercado gastara nada.
	texto += "Presupuestos (Restante = lo que podes gastar AHORA; puede ser mayor a lo Asignado esta temporada si venis ahorrando de antes):\n"
	texto += "  %-14s %14s %14s %14s\n" % ["Categoria", "Asignado", "Usado", "Restante"]
	for categoria in equipo.caja:
		var presupuesto: float = equipo.presupuesto_temporada.get(categoria, 0.0)
		var restante: float = equipo.caja[categoria]
		var usado: float = equipo.caja_al_cierre.get(categoria, 0.0) - restante
		texto += "  %-14s %14s %14s %14s\n" % [categoria.capitalize(), Economia.formato_dinero(presupuesto), Economia.formato_dinero(usado), Economia.formato_dinero(restante)]
	texto += "\n"

	texto += "Masa salarial actual del plantel: %s (puede diferir del ultimo balance si hubo fichajes despues)\n" % Economia.formato_dinero(sueldos_totales)

	var valor_plantel := 0.0
	for j in equipo.jugadores:
		valor_plantel += ValorJugador.calcular(j, equipo.animo.get(j["id"], 50.0), equipo.contratos.get(j["id"], 1))
	texto += "Valor de mercado del plantel: %s\n" % Economia.formato_dinero(valor_plantel)

	lista_economia.text = texto


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


func _construir_solapa_jugadores(padre: Control) -> Control:
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padre.add_child(caja)

	var filtros := HBoxContainer.new()
	caja.add_child(filtros)

	filtros.add_child(_etiqueta("Puesto:"))
	option_pos_mercado = OptionButton.new()
	option_pos_mercado.add_item("Cualquiera")
	for pos in BusquedaMercado.POSICIONES:
		option_pos_mercado.add_item(pos)
	filtros.add_child(option_pos_mercado)

	filtros.add_child(_etiqueta("Division:"))
	option_div_mercado = OptionButton.new()
	option_div_mercado.add_item("Cualquiera")
	for d in range(10):
		option_div_mercado.add_item("D%d" % (d + 1))
	filtros.add_child(option_div_mercado)

	filtros.add_child(_etiqueta("Edad:"))
	spin_edad_min = _spin(0, 45, 0)
	filtros.add_child(spin_edad_min)
	filtros.add_child(_etiqueta("a"))
	spin_edad_max = _spin(0, 45, 0)
	filtros.add_child(spin_edad_max)

	filtros.add_child(_etiqueta("Contrato hasta:"))
	spin_contrato = _spin(0, 6, 0)
	filtros.add_child(spin_contrato)

	var btn_buscar := Button.new()
	btn_buscar.text = "Buscar"
	btn_buscar.custom_minimum_size = Vector2(130, Tema.ALTO_TACTIL)
	Tema.primario(btn_buscar)
	btn_buscar.pressed.connect(_on_buscar_mercado)
	filtros.add_child(btn_buscar)

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
		btn.add_theme_color_override("font_color",
			Tema.AMBAR if orden_mercado == clave else Tema.SUAVE)
		btn.pressed.connect(func(): _on_ordenar_mercado(clave))
		dentro.add_child(btn)
	dentro.add_child(Componentes.celda("Club", Componentes.COL_CLUB, Tema.SUAVE))
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
	dentro.add_child(Componentes.celda_numero(str(f["edad"]), Componentes.COL_EDAD))

	var caja_pos := CenterContainer.new()
	caja_pos.custom_minimum_size = Vector2(Componentes.COL_POS, 0)
	caja_pos.add_child(Componentes.chip(str(f["posicion"]), Color("#2f4a3c")))
	dentro.add_child(caja_pos)

	if conocido:
		dentro.add_child(Componentes.celda_numero("%.1f" % float(f["media"]), Componentes.COL_MEDIA))
		dentro.add_child(Componentes.celda_numero(
			Economia.formato_dinero(f["valor"]), Componentes.COL_VALOR))
		dentro.add_child(Componentes.celda_numero(
			Economia.formato_dinero(f["salario"]), Componentes.COL_SALARIO))
		dentro.add_child(Componentes.celda_numero(
			"%d años" % int(f["contrato"]), Componentes.COL_CONTRATO))
		dentro.add_child(Componentes.celda_numero(str(int(f["animo"])), Componentes.COL_ANIMO,
			Componentes.color_de_valor(int(f["animo"]))))
	elif float(f["progreso"]) >= 0.0:
		var inv := Investigadores.progreso(equipo, jugador_id)
		var faltan := _dias_que_faltan(equipo, jugador_id)
		dentro.add_child(Componentes.bloque_investigando(
			Componentes.COL_TAPADAS, inv, faltan))
	else:
		dentro.add_child(Componentes.bloque_tapado(Componentes.COL_TAPADAS))

	dentro.add_child(Componentes.celda(
		"%s D%d" % [str(f["club"]), int(f["division"])], Componentes.COL_CLUB, Tema.SUAVE))

	# --- Acciones ----------------------------------------------------------
	var btn_inv := Button.new()
	btn_inv.custom_minimum_size = Vector2(Componentes.COL_ACCION, 0)
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
		btn_inv.add_theme_color_override("font_color", Tema.AMBAR)
		btn_inv.pressed.connect(func(): _on_investigar(vendedor, jugador_id))
	dentro.add_child(btn_inv)

	var btn_comprar := Button.new()
	btn_comprar.custom_minimum_size = Vector2(Componentes.COL_ACCION, 0)
	var negociando := false
	for o in equipo.ofertas:
		if int(o["jugador_id"]) == jugador_id and Ofertas.abierta(o):
			negociando = true
	if Negociacion.bloqueado(vendedor, jugador_id, GameState.temporada_actual):
		btn_comprar.text = "Vetado"
		btn_comprar.disabled = true
		btn_comprar.tooltip_text = "Te ofendieron con la ultima oferta. Vuelven a escucharte la temporada que viene."
	elif negociando:
		btn_comprar.text = "En curso"
		btn_comprar.disabled = true
		btn_comprar.tooltip_text = "Ya tenes una negociacion abierta por el. Miralo en Ofertas enviadas."
	else:
		btn_comprar.text = "Comprar"
		btn_comprar.pressed.connect(func(): _abrir_negociacion(vendedor, jugador_id))
	dentro.add_child(btn_comprar)

	var btn_prestamo := Button.new()
	btn_prestamo.text = "Préstamo"
	btn_prestamo.custom_minimum_size = Vector2(Componentes.COL_ACCION, 0)
	btn_prestamo.pressed.connect(func(): _abrir_prestamo(vendedor, jugador_id))
	dentro.add_child(btn_prestamo)
	return fila


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
func _refrescar_investigaciones() -> void:
	for hijo in contenedor_investigaciones.get_children():
		hijo.queue_free()
	var equipo := GameState.equipo_jugador
	var indice := _indice_de_jugadores()

	var titulo := Label.new()
	titulo.text = "En curso"
	contenedor_investigaciones.add_child(titulo)

	var en_curso := 0
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == -1:
			continue
		en_curso += 1
		var pct: float = float(inv["dias"]) / Investigadores.dias_de_informe(int(inv["estrellas"]))
		var faltan: int = int(ceil(
			Investigadores.dias_de_informe(int(inv["estrellas"])) - float(inv["dias"])))
		var quien := str(inv["nombre_objetivo"])
		if quien == "":
			quien = "un jugador"
		var fila := HBoxContainer.new()
		var l := _etiqueta("%-26s %-24s  %3d%%  (faltan %d dias, investigador de %d★)" % [
			quien, str(inv["club_objetivo"]), int(round(pct * 100.0)), faltan, int(inv["estrellas"])])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var id_inv := int(inv["id"])
		var btn := Button.new()
		btn.text = "Cancelar"
		btn.pressed.connect(func():
			Investigadores.cancelar(equipo, id_inv)
			_refrescar_investigaciones()
		)
		fila.add_child(btn)
		contenedor_investigaciones.add_child(fila)
	if en_curso == 0:
		contenedor_investigaciones.add_child(_etiqueta(
			"Nadie. Los investigadores libres estan esperando: mandalos desde la solapa Jugadores."))

	var titulo2 := Label.new()
	titulo2.text = "
Conocidos (%d) — un informe dura %d dias y despues el jugador vuelve a quedar tapado" % [
		equipo.conocimiento.size(), Investigadores.DIAS_VIGENCIA]
	contenedor_investigaciones.add_child(titulo2)

	if equipo.conocimiento.is_empty():
		contenedor_investigaciones.add_child(_etiqueta("Todavia no terminaste ningun informe."))
		return

	var conocidos := []
	for id in equipo.conocimiento:
		conocidos.append({"id": int(id), "dias": float(equipo.conocimiento[id])})
	conocidos.sort_custom(func(a, b): return float(a["dias"]) < float(b["dias"]))

	for c in conocidos:
		var id: int = int(c["id"])
		var dato: Dictionary = indice.get(id, {})
		var nombre := "(ya no esta en la piramide)"
		var club := ""
		var extra := ""
		if not dato.is_empty():
			var j: Dictionary = dato["jugador"]
			nombre = _nombre_jugador(j)
			club = "%s D%d" % [dato["club"].nombre, int(dato["division"])]
			extra = "%-4s  media %5.1f  %2d años" % [j["posicion"], j["media"], int(j["edad"])]
		var dias: int = int(ceil(float(c["dias"])))
		var aviso := "vence en %d dias" % dias
		if dias < 120:
			aviso = "VENCE PRONTO (%d dias)" % dias
		contenedor_investigaciones.add_child(_etiqueta(
			"%-26s %-24s %-28s  %s" % [nombre, club, extra, aviso]))


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


func _construir_panel_libres(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["libres"] = panel

	var titulo := Label.new()
	titulo.text = "Agentes libres — sin fee de transferencia, solo pagas el sueldo"
	panel.add_child(titulo)

	label_libres_estado = Label.new()
	label_libres_estado.text = ""
	panel.add_child(label_libres_estado)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_libres_botones = VBoxContainer.new()
	contenedor_libres_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_libres_botones)


func _refrescar_libres() -> void:
	for hijo in contenedor_libres_botones.get_children():
		hijo.queue_free()

	var pool: Array = GameState.liga_jugador().agentes_libres
	if pool.is_empty():
		var label := Label.new()
		label.text = "No hay agentes libres en tu division por ahora — aparecen cuando a un club de la IA se le vence el contrato de alguien."
		contenedor_libres_botones.add_child(label)
		return

	for agente in pool:
		var fila := HBoxContainer.new()
		var label := Label.new()
		label.text = "%-4s  %-22s  media %5.1f  potencial %3d  edad %d" % [agente["posicion"], _nombre_jugador(agente), agente["media"], agente["potencial"], agente["edad"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Fichar"
		var agente_id: int = agente["id"]
		btn.pressed.connect(func(): _on_fichar_libre(agente_id))
		fila.add_child(btn)

		contenedor_libres_botones.add_child(fila)


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
func _construir_panel_prestamos(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["prestamos"] = panel

	var titulo := Label.new()
	titulo.text = "Prestamos — 1 temporada, fee unico del 10%% del valor + sueldo mientras dure"
	panel.add_child(titulo)

	label_prestamos_estado = Label.new()
	label_prestamos_estado.text = ""
	panel.add_child(label_prestamos_estado)

	var titulo_ceder := Label.new()
	titulo_ceder.text = "Ceder a prestamo (tu banco y cantera)"
	panel.add_child(titulo_ceder)

	var scroll_ceder := ScrollContainer.new()
	scroll_ceder.custom_minimum_size = Vector2(0, 160)
	scroll_ceder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll_ceder)

	contenedor_prestamos_ceder_botones = VBoxContainer.new()
	contenedor_prestamos_ceder_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_ceder.add_child(contenedor_prestamos_ceder_botones)

	# Pedir prestado ya no vive aca: se hace desde Mercado, con el mismo
	# buscador y las mismas condiciones que una compra (duracion, reparto
	# del sueldo y opcion de compra). Esta pestaña quedo solo para CEDER,
	# que es la operacion inversa.


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
		var label := Label.new()
		label.text = "No tenes banco ni cantera disponible para ceder."
		contenedor_prestamos_ceder_botones.add_child(label)
	for entrada in cedibles:
		var j: Dictionary = entrada["jugador"]
		var fila := HBoxContainer.new()
		var origen_txt := "cantera" if entrada["desde_cantera"] else "banco"
		var label := Label.new()
		label.text = "%-4s  %-22s  media %5.1f  potencial %3d  (%s)" % [j["posicion"], _nombre_jugador(j), j["media"], j["potencial"], origen_txt]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Ceder"
		var jugador_id: int = j["id"]
		btn.pressed.connect(func(): _on_ceder_prestamo(jugador_id))
		fila.add_child(btn)

		contenedor_prestamos_ceder_botones.add_child(fila)

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
	"estadio": "Estadio (mas aforo, mas entradas)",
	"medica": "Medica (menos lesiones, recupera mas rapido)",
	"juveniles": "Juveniles (camada de cantera mas grande)",
	"scouting": "Scouting (reportes de potencial mas precisos)",
	"entrenamiento": "Entrenamiento (mas cupos de foco individual hasta 3, crecimiento mas rapido)",
}


func _construir_panel_instalaciones(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["instalaciones"] = panel

	var titulo := Label.new()
	titulo.text = "Instalaciones — mejoras permanentes, se pagan con el presupuesto de Mejoras"
	panel.add_child(titulo)

	label_instalaciones_estado = Label.new()
	label_instalaciones_estado.text = ""
	panel.add_child(label_instalaciones_estado)

	var scroll := ScrollContainer.new()
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
	var label_presupuesto := Label.new()
	label_presupuesto.text = "Presupuesto de Mejoras disponible: %s" % Economia.formato_dinero(equipo.caja["mejoras"])
	contenedor_instalaciones_botones.add_child(label_presupuesto)

	for categoria in Instalaciones.CATEGORIAS:
		var nivel: int = equipo.instalaciones.get(categoria, 1)
		var fila := HBoxContainer.new()
		var label := Label.new()
		if nivel >= Instalaciones.NIVEL_MAXIMO:
			label.text = "%-45s  nivel %d/%d (maximo)" % [NOMBRES_INSTALACIONES[categoria], nivel, Instalaciones.NIVEL_MAXIMO]
		else:
			var costo := Instalaciones.costo_siguiente_nivel(nivel)
			label.text = "%-45s  nivel %d/%d — subir a %d cuesta %s" % [
				NOMBRES_INSTALACIONES[categoria], nivel, Instalaciones.NIVEL_MAXIMO, nivel + 1, Economia.formato_dinero(costo)
			]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Mejorar"
		btn.disabled = nivel >= Instalaciones.NIVEL_MAXIMO
		btn.pressed.connect(func(): _on_mejorar_instalacion(categoria))
		fila.add_child(btn)

		contenedor_instalaciones_botones.add_child(fila)

	_refrescar_investigadores_instalaciones(equipo)
	_refrescar_foco_individual(equipo)


## §9.4: la red de investigadores vive en Instalaciones porque es lo que
## es — una inversion permanente del club, pagada con Mejoras, que compite
## con el estadio y la cantera por la misma plata. A quien estas mirando
## con ella se ve en Mercado > Investigaciones.
##
## No se MEJORAN como el resto de las instalaciones: se contratan y se
## despiden. Despedir sirve para liberar un slot y poner a uno mejor.
func _refrescar_investigadores_instalaciones(equipo: Team) -> void:
	var titulo := Label.new()
	titulo.text = "\nInvestigadores (%d de %d slots) — las estrellas son VELOCIDAD, no calidad: el informe siempre termina completo" % [
		equipo.investigadores.size(), Investigadores.SLOTS]
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contenedor_instalaciones_botones.add_child(titulo)

	for inv in equipo.investigadores:
		var fila := HBoxContainer.new()
		var estado := "libre"
		if int(inv["objetivo"]) != -1:
			var quien := str(inv["nombre_objetivo"])
			estado = "ocupado con %s" % (quien if quien != "" else str(inv["club_objetivo"]))
		var l := _etiqueta("%-14s  informe en %3d dias  —  %s" % [
			"★".repeat(int(inv["estrellas"])),
			int(Investigadores.dias_de_informe(int(inv["estrellas"]))), estado])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var id_inv := int(inv["id"])
		var btn := Button.new()
		btn.text = "Despedir"
		btn.pressed.connect(func():
			Investigadores.despedir(equipo, id_inv)
			label_instalaciones_estado.text = "Investigador despedido: se libero un slot."
			_refrescar_instalaciones()
		)
		fila.add_child(btn)
		contenedor_instalaciones_botones.add_child(fila)

	var hay_slot: bool = equipo.investigadores.size() < Investigadores.SLOTS
	for estrellas in range(Investigadores.ESTRELLAS_MIN, Investigadores.ESTRELLAS_MAX + 1):
		var costo := Investigadores.costo(estrellas)
		var fila := HBoxContainer.new()
		var l := _etiqueta("%-14s  informe en %3d dias  —  contratar por %s" % [
			"★".repeat(estrellas), int(Investigadores.dias_de_informe(estrellas)),
			Economia.formato_dinero(costo)])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(l)
		var btn := Button.new()
		btn.text = "Contratar"
		btn.disabled = not hay_slot or equipo.caja["mejoras"] < costo
		var e := estrellas
		btn.pressed.connect(func(): _on_contratar_investigador(e))
		fila.add_child(btn)
		contenedor_instalaciones_botones.add_child(fila)


func _on_contratar_investigador(estrellas: int) -> void:
	var r := Investigadores.contratar(GameState.equipo_jugador, estrellas)
	if r["exito"]:
		label_instalaciones_estado.text = "Contratado un investigador de %d estrella(s) por %s." % [
			estrellas, Economia.formato_dinero(r["costo"])]
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
## por jugador: es la información con la que se decide a quién enfocar.
func _refrescar_foco_individual(equipo: Team) -> void:
	var titulo_foco := Label.new()
	titulo_foco.text = "\nFoco individual (%d/%d cupos usados) — el atributo elegido crece x2 esta temporada. 2 temporadas seguidas en el mismo atributo (con ese atributo en 65+) puede hacerle aprender una habilidad de bronce." % [
		equipo.foco_individual.size(), Entrenamiento.limite(equipo)
	]
	contenedor_instalaciones_botones.add_child(titulo_foco)

	for jugador_id in equipo.foco_individual.keys():
		var jugador := _buscar_jugador_por_id(equipo, jugador_id)
		if jugador.is_empty():
			continue
		var atributo: String = equipo.foco_individual[jugador_id]
		var racha: int = jugador.get("foco_temporadas_consecutivas", 0)
		var fila := HBoxContainer.new()
		var label := Label.new()
		label.text = "%-22s %-5s foco: %-10s x%.2f (racha: %d temporada%s)" % [
			_nombre_jugador(jugador), jugador["posicion"], atributo,
			Progresion.multiplicador_foco(jugador["posicion"], atributo),
			racha, "" if racha == 1 else "s"
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)
		var btn_quitar := Button.new()
		btn_quitar.text = "Quitar"
		btn_quitar.pressed.connect(func():
			Entrenamiento.quitar(equipo, jugador_id)
			_refrescar_instalaciones()
		)
		fila.add_child(btn_quitar)
		contenedor_instalaciones_botones.add_child(fila)

	if equipo.foco_individual.size() >= Entrenamiento.limite(equipo):
		return

	var elegibles: Array = equipo.jugadores + equipo.banco + equipo.cantera
	elegibles = elegibles.filter(func(j): return not equipo.foco_individual.has(j["id"]))
	if elegibles.is_empty():
		return

	var fila_nueva := HBoxContainer.new()
	var option_jugador := OptionButton.new()
	for j in elegibles:
		option_jugador.add_item("%s (%s, %d años)" % [_nombre_jugador(j), j["posicion"], j["edad"]])
	fila_nueva.add_child(option_jugador)

	var option_atributo := OptionButton.new()
	for attr in PlayerGenerator.get_all_attributes():
		option_atributo.add_item(attr)
	fila_nueva.add_child(option_atributo)

	var btn_asignar := Button.new()
	btn_asignar.text = "Asignar foco"
	btn_asignar.pressed.connect(func():
		var jugador_elegido: Dictionary = elegibles[option_jugador.selected]
		var atributo_elegido := option_atributo.get_item_text(option_atributo.selected)
		Entrenamiento.asignar(equipo, jugador_elegido["id"], atributo_elegido)
		_refrescar_instalaciones()
	)
	fila_nueva.add_child(btn_asignar)
	contenedor_instalaciones_botones.add_child(fila_nueva)


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
func _construir_panel_seleccion(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["seleccion"] = panel

	var titulo := Label.new()
	titulo.text = "Selección Uruguay — convocatoria actual (los mejores de TODA la piramide). Juega un amistoso al cerrar cada temporada."
	panel.add_child(titulo)

	lista_seleccion = RichTextLabel.new()
	lista_seleccion.bbcode_enabled = true
	lista_seleccion.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_seleccion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_seleccion)


func _refrescar_seleccion() -> void:
	var convocatoria := GameState.seleccion.previsualizar(GameState.piramide)
	var uruguay: Team = convocatoria["equipo"]
	var clubes_por_jugador: Dictionary = convocatoria["clubes_por_jugador"]

	var texto := "[b]Titulares (11)[/b]\n"
	for j in uruguay.jugadores:
		texto += _linea_convocado(j, clubes_por_jugador)
	texto += "\n[b]Banco (7)[/b]\n"
	for j in uruguay.banco:
		texto += _linea_convocado(j, clubes_por_jugador)

	lista_seleccion.text = texto


func _linea_convocado(j: Dictionary, clubes_por_jugador: Dictionary) -> String:
	var club: Team = clubes_por_jugador.get(j["id"])
	var club_nombre: String = club.nombre if club != null else "?"
	var veces: int = GameState.seleccion.convocatorias.get(j["id"], 0)
	var linea := "%-4s  %-22s  %-20s  media %5.1f  (%d convocatoria%s)" % [
		j["posicion"], _nombre_jugador(j), club_nombre, j["media"], veces, "s" if veces != 1 else ""
	]
	if club == GameState.equipo_jugador:
		return "[color=yellow]%s  <- tu equipo[/color]\n" % linea
	return linea + "\n"


func _construir_panel_cantera(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["cantera"] = panel

	var titulo := Label.new()
	titulo.text = "Cantera (§17) — juveniles sin debutar. Promover los manda al banco (para subirlos a titular, ver Plantel)."
	panel.add_child(titulo)

	label_cantera_mentor = Label.new()
	panel.add_child(label_cantera_mentor)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_cantera_botones = VBoxContainer.new()
	contenedor_cantera_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_cantera_botones)


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
		label_cantera_mentor.text = "Sin mentor en el plantel: nadie de 28+ con Lider nato / Profesional / Metodico."
	else:
		var rasgo := "?"
		for candidato in Mentores.BONUS_POR_RASGO:
			if Personalidad.tiene(mentor, candidato):
				rasgo = candidato
				break
		label_cantera_mentor.text = "Mentor: %s (%s, %d años) — los jugadores de 21 o menos crecen mas rapido." % [_nombre_jugador(mentor), rasgo, mentor["edad"]]

	if equipo.cantera.is_empty():
		var label := Label.new()
		label.text = "No hay juveniles en la cantera esta temporada."
		contenedor_cantera_botones.add_child(label)
		return

	var nivel_scout: int = equipo.scouts[0]["nivel"] if not equipo.scouts.is_empty() else 1
	for juvenil in equipo.cantera:
		var fila := HBoxContainer.new()
		var margen := Scout.margen(nivel_scout)
		var potencial_min: int = clamp(juvenil["potencial"] - margen, 0, 99)
		var potencial_max: int = clamp(juvenil["potencial"] + margen, 0, 99)
		var label := Label.new()
		label.text = "%-4s  %-22s  edad %d  media %.1f  potencial %d-%d (scout nivel %d)%s" % [
			juvenil["posicion"], _nombre_jugador(juvenil), juvenil["edad"], juvenil["media"], potencial_min, potencial_max, nivel_scout, _tag_habilidad(juvenil)
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Promover al banco"
		var id: int = juvenil["id"]
		btn.pressed.connect(func(): _on_promover_juvenil(id))
		fila.add_child(btn)

		contenedor_cantera_botones.add_child(fila)


func _on_promover_juvenil(id: int) -> void:
	GameState.equipo_jugador.promover_juvenil(id)
	_refrescar_cantera()
	_refrescar_plantel()


func _construir_panel_noticias(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["noticias"] = panel

	var titulo := Label.new()
	titulo.text = "Noticias"
	panel.add_child(titulo)

	lista_noticias = RichTextLabel.new()
	lista_noticias.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_noticias.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_noticias)


func _refrescar_noticias() -> void:
	if GameState.noticias.is_empty():
		lista_noticias.text = "Todavia no hay noticias — se generan al cerrar cada temporada."
		return
	lista_noticias.text = "\n".join(GameState.noticias)


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

	var titulo := Label.new()
	titulo.text = "Partida — guardado local (1 solo espacio)"
	panel.add_child(titulo)

	label_partida_estado = Label.new()
	label_partida_estado.text = ""
	panel.add_child(label_partida_estado)

	var barra := HBoxContainer.new()
	panel.add_child(barra)

	var boton_guardar := Button.new()
	boton_guardar.text = "Guardar partida"
	boton_guardar.pressed.connect(_on_guardar_partida)
	barra.add_child(boton_guardar)

	boton_cargar_partida = Button.new()
	boton_cargar_partida.text = "Cargar partida"
	boton_cargar_partida.pressed.connect(_on_cargar_partida)
	barra.add_child(boton_cargar_partida)

	boton_borrar_partida = Button.new()
	boton_borrar_partida.text = "Borrar partida guardada"
	boton_borrar_partida.pressed.connect(_on_borrar_partida)
	barra.add_child(boton_borrar_partida)


func _refrescar_partida_guardado() -> void:
	var hay_guardado := GameState.hay_partida_guardada()
	boton_cargar_partida.disabled = not hay_guardado
	boton_borrar_partida.disabled = not hay_guardado
	if label_partida_estado.text == "":
		label_partida_estado.text = "Hay una partida guardada." if hay_guardado else "No hay ninguna partida guardada todavia."


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

	boton_simular_temporada.text = "[debug] Simular resto de la temporada"
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

