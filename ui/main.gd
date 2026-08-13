extends Control

## Fase 4 del roadmap (GDD §13): UI mínima — plantel/formación, tabla,
## resultado de partido. Sin pixel art todavía (eso es fase 9); acá solo
## tiene que andar y mostrar datos reales del motor.
##
## Los nodos se arman por código en vez de a mano en el editor: así el
## layout queda versionado y reproducible sin depender de una sesión
## interactiva del editor.

var panel_plantel: VBoxContainer
var panel_tabla: VBoxContainer
var panel_partido: VBoxContainer

var lista_plantel: RichTextLabel
var lista_tabla: RichTextLabel
var label_resultado: Label
var lista_log: RichTextLabel
var boton_jugar_fecha: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	var barra := HBoxContainer.new()
	raiz.add_child(barra)

	var btn_plantel := Button.new()
	btn_plantel.text = "Plantel"
	btn_plantel.pressed.connect(_mostrar_plantel)
	barra.add_child(btn_plantel)

	var btn_tabla := Button.new()
	btn_tabla.text = "Tabla"
	btn_tabla.pressed.connect(_mostrar_tabla)
	barra.add_child(btn_tabla)

	var btn_partido := Button.new()
	btn_partido.text = "Partido"
	btn_partido.pressed.connect(_mostrar_partido)
	barra.add_child(btn_partido)

	var contenedor := Control.new()
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(contenedor)

	_construir_panel_plantel(contenedor)
	_construir_panel_tabla(contenedor)
	_construir_panel_partido(contenedor)

	_mostrar_plantel()


func _construir_panel_plantel(padre: Control) -> void:
	panel_plantel = VBoxContainer.new()
	panel_plantel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padre.add_child(panel_plantel)

	var titulo := Label.new()
	titulo.text = "Plantel / formacion — %s" % GameState.equipo_jugador.nombre
	panel_plantel.add_child(titulo)

	lista_plantel = RichTextLabel.new()
	lista_plantel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_plantel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_plantel.add_child(lista_plantel)
	_refrescar_plantel()


func _refrescar_plantel() -> void:
	var texto := ""
	for j in GameState.equipo_jugador.jugadores:
		var capitan := "  (C)" if j["id"] == GameState.equipo_jugador.capitan_id else ""
		texto += "%-4s  media %5.1f   potencial %3d   genetica %s%s\n" % [
			j["posicion"], j["media"], j["potencial"], j["genetica_tier"], capitan
		]
	lista_plantel.text = texto


func _construir_panel_tabla(padre: Control) -> void:
	panel_tabla = VBoxContainer.new()
	panel_tabla.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_tabla.visible = false
	padre.add_child(panel_tabla)

	var titulo := Label.new()
	titulo.text = "Tabla de posiciones"
	panel_tabla.add_child(titulo)

	lista_tabla = RichTextLabel.new()
	lista_tabla.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_tabla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_tabla.add_child(lista_tabla)
	_refrescar_tabla()


func _refrescar_tabla() -> void:
	var texto := "%-10s %3s %3s %3s %3s %4s %4s %4s %4s\n" % ["Equipo", "PJ", "PG", "PE", "PP", "GF", "GC", "DG", "Pts"]
	var pos := 1
	for nombre in GameState.liga.tabla_ordenada():
		var f: Dictionary = GameState.liga.tabla[nombre]
		var marca := " <- vos" if nombre == GameState.equipo_jugador.nombre else ""
		texto += "%2d. %-10s %3d %3d %3d %3d %4d %4d %4d %4d%s\n" % [
			pos, nombre, f["pj"], f["pg"], f["pe"], f["pp"], f["gf"], f["gc"], f["dg"], f["pts"], marca
		]
		pos += 1
	lista_tabla.text = texto


func _construir_panel_partido(padre: Control) -> void:
	panel_partido = VBoxContainer.new()
	panel_partido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_partido.visible = false
	padre.add_child(panel_partido)

	boton_jugar_fecha = Button.new()
	boton_jugar_fecha.text = "Jugar siguiente fecha"
	boton_jugar_fecha.pressed.connect(_on_jugar_fecha)
	panel_partido.add_child(boton_jugar_fecha)

	label_resultado = Label.new()
	label_resultado.text = "Todavia no jugaste ninguna fecha."
	panel_partido.add_child(label_resultado)

	lista_log = RichTextLabel.new()
	lista_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_partido.add_child(lista_log)


func _on_jugar_fecha() -> void:
	if not GameState.hay_fecha_pendiente():
		label_resultado.text = "Temporada terminada."
		boton_jugar_fecha.disabled = true
		return

	GameState.jugar_siguiente_fecha()

	var r: Dictionary = GameState.ultimo_resultado
	if r.size() > 0:
		label_resultado.text = "Fecha %d/%d:  %s  %d - %d  %s" % [
			GameState.fecha_actual, GameState.liga.fixture.size(),
			r["local"], r["gl"], r["gv"], r["visitante"]
		]

	var texto_log := ""
	for entry in GameState.ultimo_log:
		if entry.find("GOL") != -1:
			texto_log += entry + "\n"
	lista_log.text = texto_log

	_refrescar_tabla()
	_refrescar_plantel()


func _mostrar_plantel() -> void:
	panel_plantel.visible = true
	panel_tabla.visible = false
	panel_partido.visible = false


func _mostrar_tabla() -> void:
	panel_plantel.visible = false
	panel_tabla.visible = true
	panel_partido.visible = false
	_refrescar_tabla()


func _mostrar_partido() -> void:
	panel_plantel.visible = false
	panel_tabla.visible = false
	panel_partido.visible = true
