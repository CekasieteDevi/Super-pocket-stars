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

var lista_plantel: RichTextLabel
var lista_ficha: RichTextLabel
var ficha_jugador_id := -1
var option_formacion: OptionButton
var option_carga: OptionButton
var option_foco: OptionButton
var label_foco_efecto: Label
var label_carga_efecto: Label
var contenedor_formacion: VBoxContainer
var label_formacion_estado: Label
## Jugador tocado primero en la pantalla de formacion, a la espera del
## segundo para intercambiarlos. -1 = nadie seleccionado.
var formacion_seleccion := -1
var contenedor_banco_botones: VBoxContainer
var lista_tabla: RichTextLabel
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
var contenedor_mercado_botones: VBoxContainer
var label_mercado_estado: Label
var posicion_mercado_actual: String = "DC"
var contenedor_libres_botones: VBoxContainer
var label_libres_estado: Label
var contenedor_prestamos_ceder_botones: VBoxContainer
var contenedor_prestamos_pedir_botones: VBoxContainer
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

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	var barra := HBoxContainer.new()
	raiz.add_child(barra)

	for entrada in [
		["Plantel", "_mostrar_plantel"], ["Formacion", "_mostrar_formacion"],
		["Tabla", "_mostrar_tabla"], ["Partido", "_mostrar_partido"],
		["Economia", "_mostrar_economia"], ["Mercado", "_mostrar_mercado"],
		["Libres", "_mostrar_libres"], ["Prestamos", "_mostrar_prestamos"],
		["Instalaciones", "_mostrar_instalaciones"], ["Seleccion", "_mostrar_seleccion"],
		["Cantera", "_mostrar_cantera"], ["Noticias", "_mostrar_noticias"], ["Partida", "_mostrar_partida_panel"],
	]:
		var btn := Button.new()
		btn.text = entrada[0]
		btn.pressed.connect(Callable(self, entrada[1]))
		barra.add_child(btn)

	var contenedor := Control.new()
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(contenedor)

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

	_mostrar_plantel()


## Fix 10: nombre y apellido del jugador, para las listas de la UI.
func _nombre_jugador(j: Dictionary) -> String:
	return "%s %s" % [j.get("nombre", "?"), j.get("apellido", "")]


## §5: si tiene una habilidad, la muestra con una estrella por nivel
## (bronce=★, plata=★★, oro=★★★) — atenuada entre parentesis si todavia
## no se manifesto (no llego a la media minima) para que se note que esta
## "dormida", no activa.
func _tag_habilidad(j: Dictionary) -> String:
	var h: Dictionary = j.get("habilidad", {})
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
func _construir_panel_plantel(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padre.add_child(panel)
	paneles["plantel"] = panel

	var titulo := Label.new()
	titulo.text = "Plantel / formacion — %s" % GameState.equipo_jugador.nombre
	panel.add_child(titulo)

	var titulo_titulares := Label.new()
	titulo_titulares.text = "Titulares (11) — toca el nombre para ver la ficha"
	panel.add_child(titulo_titulares)

	lista_plantel = RichTextLabel.new()
	lista_plantel.bbcode_enabled = true
	# Cada linea es un enlace al id del jugador: se toca el nombre y se
	# abre su ficha. Es el unico lugar donde se pueden ver los atributos.
	lista_plantel.meta_clicked.connect(func(meta): _mostrar_ficha(int(meta)))
	lista_plantel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_plantel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_plantel)

	var titulo_banco := Label.new()
	titulo_banco.text = "Banco (7)"
	panel.add_child(titulo_banco)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_banco_botones = VBoxContainer.new()
	contenedor_banco_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_banco_botones)

	_refrescar_plantel()


func _refrescar_plantel() -> void:
	var equipo := GameState.equipo_jugador
	var texto := ""
	for j in equipo.jugadores:
		var capitan := "  (C)" if j["id"] == equipo.capitan_id else ""
		# [lb] es el corchete escapado: la lista ahora es BBCode y un
		# "[cantera]" suelto se comería como si fuera una etiqueta.
		var canterano := "  [lb]cantera]" if j.get("es_canterano", false) else ""
		# El nombre va como enlace y COLOREADO: un [url] sin estilo no se
		# distingue del texto común y nadie descubre que se puede tocar.
		texto += "%-4s  [url=%d][color=#8ecae6]%-22s[/color][/url]  media %5.1f   potencial %3d   genetica %s%s%s%s\n" % [
			j["posicion"], j["id"], _nombre_jugador(j), j["media"], j["potencial"],
			j["genetica_tier"], capitan, canterano, _tag_habilidad(j)
		]
	lista_plantel.text = texto

	for hijo in contenedor_banco_botones.get_children():
		hijo.queue_free()
	for j in equipo.banco:
		var fila := HBoxContainer.new()
		var canterano := "  [cantera]" if j.get("es_canterano", false) else ""
		var label := Label.new()
		label.text = "%-4s  %-22s  media %5.1f   potencial %3d%s%s" % [j["posicion"], _nombre_jugador(j), j["media"], j["potencial"], canterano, _tag_habilidad(j)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var jugador_id: int = j["id"]
		var btn_ficha := Button.new()
		btn_ficha.text = "Ficha"
		btn_ficha.pressed.connect(func(): _mostrar_ficha(jugador_id))
		fila.add_child(btn_ficha)

		var btn := Button.new()
		btn.text = "Subir a titular"
		btn.pressed.connect(func(): _on_promover_a_titular(jugador_id))
		fila.add_child(btn)

		contenedor_banco_botones.add_child(fila)


func _on_promover_a_titular(jugador_id: int) -> void:
	GameState.equipo_jugador.promover_a_titular(jugador_id)
	_refrescar_plantel()


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

	var btn_volver := Button.new()
	btn_volver.text = "< Volver al plantel"
	btn_volver.pressed.connect(_mostrar_plantel)
	panel.add_child(btn_volver)

	lista_ficha = RichTextLabel.new()
	lista_ficha.bbcode_enabled = true
	lista_ficha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_ficha)


func _mostrar_ficha(jugador_id: int) -> void:
	ficha_jugador_id = jugador_id
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
	var equipo := GameState.equipo_jugador
	var j := _buscar_jugador_por_id(equipo, ficha_jugador_id)
	if j.is_empty():
		lista_ficha.text = "Ese jugador ya no esta en el plantel."
		return

	var t := "[b]%s[/b]   %s, %d anos
" % [_nombre_jugador(j), j["posicion"], j["edad"]]
	t += "media %.1f   potencial %d   genetica %s
" % [j["media"], j["potencial"], j["genetica_tier"]]
	if j.get("mejor_posicion", j["posicion"]) != j["posicion"]:
		t += "[color=#d4a017]Rinde mejor de %s (media %.1f ahi)[/color]
" % [
			j["mejor_posicion"], j.get("media_mejor_posicion", j["media"])]
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
	var tag := _tag_habilidad(j)
	if tag != "":
		t += "habilidad:%s
" % tag

	# Estado: lo que cambia partido a partido.
	t += "
[b]Estado[/b]
"
	t += "  energia      %3d%%
" % int(round(equipo.resistencia_pct(j["id"]) * 100.0))
	t += "  animo        %3d
" % int(equipo.animo.get(j["id"], 50))
	if equipo.esta_lesionado(j["id"]):
		var les: Dictionary = equipo.lesiones[j["id"]]
		t += "  [color=#c0392b]lesionado: %s, %d dias[/color]
" % [les["tipo"], les["dias_restantes"]]
	var susp: int = int(equipo.suspendidos.get(j["id"], 0))
	if susp > 0:
		t += "  [color=#c0392b]suspendido %d fecha(s)[/color]
" % susp
	t += "  contrato     %d ano(s),  sueldo %s
" % [
		int(equipo.contratos.get(j["id"], 0)), Economia.formato_dinero(equipo.sueldos.get(j["id"], 0))]
	if equipo.clausulas.has(j["id"]):
		t += "  clausula     %s
" % Economia.formato_dinero(equipo.clausulas[j["id"]])

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

	var fila := HBoxContainer.new()
	panel.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = "Formacion:"
	fila.add_child(etiqueta)

	option_formacion = OptionButton.new()
	for nombre in Formaciones.lista():
		option_formacion.add_item(nombre)
	option_formacion.item_selected.connect(_on_formacion_elegida)
	fila.add_child(option_formacion)

	var fila_carga := HBoxContainer.new()
	panel.add_child(fila_carga)
	var et_carga := Label.new()
	et_carga.text = "Carga de entrenamiento:"
	fila_carga.add_child(et_carga)

	option_carga = OptionButton.new()
	for nivel in CargaEntrenamiento.NIVELES:
		option_carga.add_item(CargaEntrenamiento.ETIQUETAS[nivel])
	option_carga.item_selected.connect(_on_carga_elegida)
	fila_carga.add_child(option_carga)

	label_carga_efecto = Label.new()
	label_carga_efecto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label_carga_efecto)

	# §7.4.2: la carga dice CUANTO se entrena, el foco dice QUE.
	var fila_foco := HBoxContainer.new()
	panel.add_child(fila_foco)
	var et_foco := Label.new()
	et_foco.text = "Foco del equipo:"
	fila_foco.add_child(et_foco)

	option_foco = OptionButton.new()
	for area in FocoEquipo.AREAS:
		option_foco.add_item(FocoEquipo.ETIQUETAS[area])
	option_foco.item_selected.connect(_on_foco_equipo_elegido)
	fila_foco.add_child(option_foco)

	label_foco_efecto = Label.new()
	label_foco_efecto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label_foco_efecto)

	label_formacion_estado = Label.new()
	label_formacion_estado.text = "Toca un jugador y despues otro para cambiarlos de lugar."
	panel.add_child(label_formacion_estado)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_formacion = VBoxContainer.new()
	contenedor_formacion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_formacion)


func _mostrar_formacion() -> void:
	_ocultar_todos()
	paneles["formacion"].visible = true
	formacion_seleccion = -1
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
	formacion_seleccion = -1
	_refrescar_formacion()


## Un toque elige, el segundo intercambia. Si se vuelve a tocar al mismo,
## se cancela.
func _on_tocar_jugador_formacion(jugador_id: int) -> void:
	if formacion_seleccion == -1:
		formacion_seleccion = jugador_id
	elif formacion_seleccion == jugador_id:
		formacion_seleccion = -1
	else:
		GameState.equipo_jugador.intercambiar(formacion_seleccion, jugador_id)
		formacion_seleccion = -1
	_refrescar_formacion()
	_refrescar_plantel()


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


func _refrescar_formacion() -> void:
	var equipo := GameState.equipo_jugador
	var idx := Formaciones.lista().find(equipo.formacion)
	if idx >= 0:
		option_formacion.selected = idx
	var idx_carga := CargaEntrenamiento.NIVELES.find(equipo.carga_entrenamiento)
	if idx_carga >= 0:
		option_carga.selected = idx_carga
	label_carga_efecto.text = "%s   —   promedio de la temporada hasta ahora: x%.2f de crecimiento" % [
		CargaEntrenamiento.resumen(equipo.carga_entrenamiento), equipo.factor_carga_temporada()]
	var idx_foco := FocoEquipo.AREAS.find(equipo.foco_equipo)
	if idx_foco >= 0:
		option_foco.selected = idx_foco
	label_foco_efecto.text = "%s%s" % [FocoEquipo.resumen(equipo.foco_equipo), _reparto_foco_texto(equipo)]
	label_formacion_estado.text = "Toca un jugador y despues otro para cambiarlos de lugar." 		if formacion_seleccion == -1 else "Elegido. Toca a otro para cambiarlos, o al mismo para cancelar."

	for hijo in contenedor_formacion.get_children():
		hijo.queue_free()

	var roles := Formaciones.roles(equipo.formacion)
	_agregar_titulo_formacion("Titulares")
	for i in range(equipo.jugadores.size()):
		var j: Dictionary = equipo.jugadores[i]
		var rol: String = str(roles[i]) if i < roles.size() else str(j["posicion"])
		_agregar_fila_formacion(_texto_slot(rol, j), j["id"])
	_agregar_titulo_formacion("Banco")
	for j in equipo.banco:
		_agregar_fila_formacion("      %-22s  media %5.1f   (%s)%s" % [
			_nombre_jugador(j), j["media"], j["posicion"], _tag_habilidad(j)], j["id"])


func _agregar_titulo_formacion(texto: String) -> void:
	var t := Label.new()
	t.text = texto
	contenedor_formacion.add_child(t)


func _agregar_fila_formacion(texto: String, jugador_id: int) -> void:
	var fila := HBoxContainer.new()
	var btn := Button.new()
	btn.text = ("> " if formacion_seleccion == jugador_id else "  ") + texto
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): _on_tocar_jugador_formacion(jugador_id))
	fila.add_child(btn)

	var btn_ficha := Button.new()
	btn_ficha.text = "Ficha"
	btn_ficha.pressed.connect(func(): _mostrar_ficha(jugador_id))
	fila.add_child(btn_ficha)
	contenedor_formacion.add_child(fila)


func _construir_panel_tabla(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["tabla"] = panel

	var titulo := Label.new()
	titulo.name = "titulo"
	panel.add_child(titulo)

	lista_tabla = RichTextLabel.new()
	lista_tabla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_tabla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_tabla)
	_refrescar_tabla()


func _refrescar_tabla() -> void:
	var panel: VBoxContainer = paneles["tabla"]
	var titulo: Label = panel.get_node("titulo")
	titulo.text = "Tabla de posiciones — Division %d" % (GameState.division_jugador + 1)

	var liga := GameState.liga_jugador()
	var texto := "%-14s %3s %3s %3s %3s %4s %4s %4s %4s\n" % ["Equipo", "PJ", "PG", "PE", "PP", "GF", "GC", "DG", "Pts"]
	var pos := 1
	for nombre in liga.tabla_ordenada():
		var f: Dictionary = liga.tabla[nombre]
		var marca := " <- vos" if nombre == GameState.equipo_jugador.nombre else ""
		texto += "%2d. %-14s %3d %3d %3d %3d %4d %4d %4d %4d%s\n" % [
			pos, nombre, f["pj"], f["pg"], f["pe"], f["pp"], f["gf"], f["gc"], f["dg"], f["pts"], marca
		]
		pos += 1
	lista_tabla.text = texto


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
## jugador (Mercado.ofertar_por_jugador / Mercado.pagar_clausula). Busca
## en tu división y las dos vecinas (una arriba, una abajo) — mostrar toda
## la pirámide sería demasiado ruido, pero limitarse a exactamente tu
## división también se sentía corto.
const POSICIONES_MERCADO := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]


## Divisiones vecinas + la propia (acotado a 0..9), como equipos de esa
## división: [{"equipo":Team, "division":int}, ...] — division es
## 1-indexada para mostrar en la UI.
func _candidatos_mercado_por_division() -> Array:
	var equipo := GameState.equipo_jugador
	var candidatos := []
	for offset in [-1, 0, 1]:
		var d: int = GameState.division_jugador + offset
		if d < 0 or d >= GameState.piramide.divisiones.size():
			continue
		for rival in GameState.piramide.divisiones[d].equipos:
			if rival == equipo:
				continue
			candidatos.append({"equipo": rival, "division": d + 1})
	return candidatos


func _construir_panel_mercado(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["mercado"] = panel

	var titulo := Label.new()
	titulo.text = "Mercado — ofertar por un jugador de tu division y las vecinas"
	panel.add_child(titulo)

	var barra_posiciones := HBoxContainer.new()
	panel.add_child(barra_posiciones)
	for pos in POSICIONES_MERCADO:
		var btn := Button.new()
		btn.text = pos
		btn.pressed.connect(func():
			posicion_mercado_actual = pos
			_refrescar_mercado()
		)
		barra_posiciones.add_child(btn)

	label_mercado_estado = Label.new()
	label_mercado_estado.text = ""
	panel.add_child(label_mercado_estado)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	contenedor_mercado_botones = VBoxContainer.new()
	contenedor_mercado_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(contenedor_mercado_botones)


func _refrescar_mercado() -> void:
	for hijo in contenedor_mercado_botones.get_children():
		hijo.queue_free()

	var equipo := GameState.equipo_jugador
	var mi_media_en_posicion := -1.0
	for j in equipo.jugadores:
		if j["posicion"] == posicion_mercado_actual and (mi_media_en_posicion < 0.0 or j["media"] < mi_media_en_posicion):
			mi_media_en_posicion = j["media"]

	var candidatos := []  # [{equipo, jugador, division}]
	for entrada in _candidatos_mercado_por_division():
		var rival: Team = entrada["equipo"]
		for j in rival.jugadores:
			if j["posicion"] == posicion_mercado_actual:
				candidatos.append({"equipo": rival, "jugador": j, "division": entrada["division"]})
	candidatos.sort_custom(func(a, b): return a["jugador"]["media"] > b["jugador"]["media"])

	var titulo_lista := Label.new()
	titulo_lista.text = "Tu titular mas debil en %s tiene media %.1f — mostrando los mejores de tu division y las vecinas:" % [posicion_mercado_actual, mi_media_en_posicion]
	contenedor_mercado_botones.add_child(titulo_lista)

	for i in range(min(15, candidatos.size())):
		var candidato: Dictionary = candidatos[i]
		var rival: Team = candidato["equipo"]
		var jugador: Dictionary = candidato["jugador"]

		var fila := HBoxContainer.new()
		var valor := ValorJugador.calcular(jugador, rival.animo.get(jugador["id"], 50.0), rival.contratos.get(jugador["id"], 1))
		var clausula: float = rival.clausulas.get(jugador["id"], valor * Team.FACTOR_CLAUSULA)
		var label := Label.new()
		label.text = "%-22s  %-14s D%d  media %5.1f  pot %3d  ~%s  (clausula %s)" % [
			_nombre_jugador(jugador), rival.nombre, candidato["division"], jugador["media"], jugador["potencial"],
			Economia.formato_dinero(valor), Economia.formato_dinero(clausula)
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var jugador_id: int = jugador["id"]

		var btn := Button.new()
		btn.text = "Ofertar"
		btn.disabled = jugador["media"] <= mi_media_en_posicion
		btn.pressed.connect(func(): _on_ofertar(rival, jugador_id))
		fila.add_child(btn)

		var btn_clausula := Button.new()
		btn_clausula.text = "Pagar clausula"
		btn_clausula.disabled = equipo.caja["fichajes"] < clausula
		btn_clausula.pressed.connect(func(): _on_pagar_clausula(rival, jugador_id))
		fila.add_child(btn_clausula)

		contenedor_mercado_botones.add_child(fila)


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


func _on_ofertar(vendedor: Team, jugador_id: int) -> void:
	var resultado := GameState.ofertar_por_jugador(vendedor, jugador_id)
	if resultado["exito"]:
		label_mercado_estado.text = "Fichaje concretado: entra un %s, sale un %s, diferencia pagada %s." % [
			resultado["jugador_entra"]["posicion"], resultado["jugador_sale"]["posicion"], Economia.formato_dinero(resultado["diferencia"])
		]
	else:
		label_mercado_estado.text = "No se pudo: %s" % resultado["motivo"]

	_refrescar_mercado()
	_refrescar_plantel()
	_refrescar_economia()


## Agentes libres (§9.3 extendido): pool de tu división, sin fee de
## transferencia, ver core/agentes_libres.gd.
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

	var titulo_pedir := Label.new()
	titulo_pedir.text = "Pedir prestado (banco y cantera de tu division)"
	panel.add_child(titulo_pedir)

	var scroll_pedir := ScrollContainer.new()
	scroll_pedir.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_pedir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll_pedir)

	contenedor_prestamos_pedir_botones = VBoxContainer.new()
	contenedor_prestamos_pedir_botones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_pedir.add_child(contenedor_prestamos_pedir_botones)


func _refrescar_prestamos() -> void:
	for hijo in contenedor_prestamos_ceder_botones.get_children():
		hijo.queue_free()
	for hijo in contenedor_prestamos_pedir_botones.get_children():
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

	var candidatos := []  # [{equipo, jugador, desde_cantera}]
	for rival in GameState.liga_jugador().equipos:
		if rival == equipo:
			continue
		for j in rival.banco:
			candidatos.append({"equipo": rival, "jugador": j, "desde_cantera": false})
		for j in rival.cantera:
			candidatos.append({"equipo": rival, "jugador": j, "desde_cantera": true})

	if candidatos.is_empty():
		var label2 := Label.new()
		label2.text = "No hay candidatos para pedir prestado en tu division."
		contenedor_prestamos_pedir_botones.add_child(label2)
	for candidato in candidatos:
		var rival: Team = candidato["equipo"]
		var j: Dictionary = candidato["jugador"]
		var fila := HBoxContainer.new()
		var origen_txt := "cantera" if candidato["desde_cantera"] else "banco"
		var label := Label.new()
		label.text = "%-14s  %-4s  %-22s  media %5.1f  potencial %3d  (%s)" % [rival.nombre, j["posicion"], _nombre_jugador(j), j["media"], j["potencial"], origen_txt]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Pedir prestado"
		var jugador_id: int = j["id"]
		btn.pressed.connect(func(): _on_pedir_prestamo(rival, jugador_id))
		fila.add_child(btn)

		contenedor_prestamos_pedir_botones.add_child(fila)


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


func _on_pedir_prestamo(club_origen: Team, jugador_id: int) -> void:
	var resultado := GameState.pedir_prestamo(club_origen, jugador_id)
	if resultado["exito"]:
		label_prestamos_estado.text = "Prestamo recibido: llega un %s de %s (fee pagado %s)." % [
			resultado["jugador"]["posicion"], club_origen.nombre, Economia.formato_dinero(resultado["fee"])
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

	_refrescar_foco_individual(equipo)


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

	var temporada_antes := GameState.temporada_actual
	GameState.simular_temporada_completa()

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
