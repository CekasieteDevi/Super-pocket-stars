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
var lista_tabla: RichTextLabel
var label_resultado: Label
var lista_log: RichTextLabel
var boton_jugar_fecha: Button
var boton_ver_animado: Button
var partido_visual: PartidoVisual
var lista_economia: RichTextLabel
var lista_cantera: RichTextLabel
var contenedor_cantera_botones: VBoxContainer
var lista_noticias: RichTextLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	var barra := HBoxContainer.new()
	raiz.add_child(barra)

	for entrada in [
		["Plantel", "_mostrar_plantel"], ["Tabla", "_mostrar_tabla"], ["Partido", "_mostrar_partido"],
		["Economia", "_mostrar_economia"], ["Cantera", "_mostrar_cantera"], ["Noticias", "_mostrar_noticias"],
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
	_construir_panel_cantera(contenedor)
	_construir_panel_noticias(contenedor)

	_mostrar_plantel()


func _ocultar_todos() -> void:
	for panel in paneles.values():
		panel.visible = false


func _construir_panel_plantel(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padre.add_child(panel)
	paneles["plantel"] = panel

	var titulo := Label.new()
	titulo.text = "Plantel / formacion — %s" % GameState.equipo_jugador.nombre
	panel.add_child(titulo)

	lista_plantel = RichTextLabel.new()
	lista_plantel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_plantel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_plantel)
	_refrescar_plantel()


func _refrescar_plantel() -> void:
	var texto := ""
	for j in GameState.equipo_jugador.jugadores:
		var capitan := "  (C)" if j["id"] == GameState.equipo_jugador.capitan_id else ""
		var canterano := "  [cantera]" if j.get("es_canterano", false) else ""
		texto += "%-4s  media %5.1f   potencial %3d   genetica %s%s%s\n" % [
			j["posicion"], j["media"], j["potencial"], j["genetica_tier"], capitan, canterano
		]
	lista_plantel.text = texto


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

	boton_jugar_fecha = Button.new()
	boton_jugar_fecha.text = "Jugar siguiente fecha"
	boton_jugar_fecha.pressed.connect(_on_jugar_fecha)
	panel.add_child(boton_jugar_fecha)

	label_resultado = Label.new()
	label_resultado.text = "Todavia no jugaste ninguna fecha."
	panel.add_child(label_resultado)

	lista_log = RichTextLabel.new()
	lista_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(lista_log)

	boton_ver_animado = Button.new()
	boton_ver_animado.text = "Ver partido animado"
	boton_ver_animado.disabled = true
	boton_ver_animado.pressed.connect(_mostrar_partido_animado)
	panel.add_child(boton_ver_animado)


## Fase 8: reproduce los eventos del ultimo partido jugado con una pelota
## placeholder (sin pixel art ni posiciones por jugador todavia).
func _construir_panel_partido_animado(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["partido_animado"] = panel

	var btn_volver := Button.new()
	btn_volver.text = "< Volver"
	btn_volver.pressed.connect(_mostrar_partido)
	panel.add_child(btn_volver)

	var escena: PackedScene = load("res://ui/partido_visual.tscn")
	partido_visual = escena.instantiate()
	partido_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(partido_visual)


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
	var texto := "Reputacion: %.1f / 100%s\n\n" % [equipo.reputacion, "  (EN QUIEBRA)" if equipo.quebrado else ""]

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

	# "Restante" es lo que tenes disponible AHORA en cada presupuesto — no
	# se puede gastar plata de Fichajes en Contratos ni viceversa, por eso
	# no hay un "Total" (sumarlos no te dice cuanto podes gastar en nada
	# concreto). "Usado" sale de comparar contra la foto de la caja justo
	# despues del ultimo reparto, antes de que el mercado gastara nada.
	texto += "Presupuestos (lo que se puede gastar de cada uno es independiente):\n"
	texto += "  %-14s %14s %14s %14s\n" % ["Categoria", "Presupuesto", "Usado", "Restante"]
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


func _construir_panel_cantera(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["cantera"] = panel

	var titulo := Label.new()
	titulo.text = "Cantera (§17) — juveniles sin debutar"
	panel.add_child(titulo)

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
		label.text = "%-4s  edad %d  media %.1f  potencial %d-%d (scout nivel %d)" % [
			juvenil["posicion"], juvenil["edad"], juvenil["media"], potencial_min, potencial_max, nivel_scout
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Promover"
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


func _on_jugar_fecha() -> void:
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
	if GameState.temporada_actual != temporada_antes:
		label_resultado.text += "\n¡Termino la temporada! Division actual: %d." % (GameState.division_jugador + 1)

	var texto_log := ""
	for entry in GameState.ultimo_log:
		if entry.find("GOL") != -1:
			texto_log += entry + "\n"
	lista_log.text = texto_log
	boton_ver_animado.disabled = GameState.ultimos_eventos.is_empty()

	_refrescar_tabla()
	_refrescar_plantel()


func _mostrar_plantel() -> void:
	_ocultar_todos()
	paneles["plantel"].visible = true


func _mostrar_tabla() -> void:
	_ocultar_todos()
	paneles["tabla"].visible = true
	_refrescar_tabla()


func _mostrar_partido() -> void:
	_ocultar_todos()
	paneles["partido"].visible = true


func _mostrar_partido_animado() -> void:
	_ocultar_todos()
	paneles["partido_animado"].visible = true
	var r: Dictionary = GameState.ultimo_resultado
	partido_visual.iniciar(r["local"], r["visitante"], GameState.ultimos_eventos)


func _mostrar_economia() -> void:
	_ocultar_todos()
	paneles["economia"].visible = true
	_refrescar_economia()


func _mostrar_cantera() -> void:
	_ocultar_todos()
	paneles["cantera"].visible = true
	_refrescar_cantera()


func _mostrar_noticias() -> void:
	_ocultar_todos()
	paneles["noticias"].visible = true
	_refrescar_noticias()
