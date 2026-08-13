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
var contenedor_banco_botones: VBoxContainer
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	var barra := HBoxContainer.new()
	raiz.add_child(barra)

	for entrada in [
		["Plantel", "_mostrar_plantel"], ["Tabla", "_mostrar_tabla"], ["Partido", "_mostrar_partido"],
		["Economia", "_mostrar_economia"], ["Mercado", "_mostrar_mercado"],
		["Libres", "_mostrar_libres"], ["Prestamos", "_mostrar_prestamos"],
		["Instalaciones", "_mostrar_instalaciones"],
		["Cantera", "_mostrar_cantera"], ["Noticias", "_mostrar_noticias"],
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
	_construir_panel_cantera(contenedor)
	_construir_panel_noticias(contenedor)

	_mostrar_plantel()


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
	titulo_titulares.text = "Titulares (11)"
	panel.add_child(titulo_titulares)

	lista_plantel = RichTextLabel.new()
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
		var canterano := "  [cantera]" if j.get("es_canterano", false) else ""
		texto += "%-4s  media %5.1f   potencial %3d   genetica %s%s%s\n" % [
			j["posicion"], j["media"], j["potencial"], j["genetica_tier"], capitan, canterano
		]
	lista_plantel.text = texto

	for hijo in contenedor_banco_botones.get_children():
		hijo.queue_free()
	for j in equipo.banco:
		var fila := HBoxContainer.new()
		var canterano := "  [cantera]" if j.get("es_canterano", false) else ""
		var label := Label.new()
		label.text = "%-4s  media %5.1f   potencial %3d%s" % [j["posicion"], j["media"], j["potencial"], canterano]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Subir a titular"
		var jugador_id: int = j["id"]
		btn.pressed.connect(func(): _on_promover_a_titular(jugador_id))
		fila.add_child(btn)

		contenedor_banco_botones.add_child(fila)


func _on_promover_a_titular(jugador_id: int) -> void:
	GameState.equipo_jugador.promover_a_titular(jugador_id)
	_refrescar_plantel()


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

	var separador := HSeparator.new()
	panel.add_child(separador)

	var boton_simular_temporada := Button.new()
	boton_simular_temporada.text = "[debug] Simular resto de la temporada"
	boton_simular_temporada.pressed.connect(_on_simular_temporada)
	panel.add_child(boton_simular_temporada)


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


## Fase 9: mercado iniciado por el jugador (Mercado.ofertar_por_jugador).
## Solo lista rivales de tu propia división — sin plantel de 25 (§14) cada
## fichaje es un intercambio 1x1, así que mostrar toda la pirámide no
## tendría mucho sentido todavía.
const POSICIONES_MERCADO := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]


func _construir_panel_mercado(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["mercado"] = panel

	var titulo := Label.new()
	titulo.text = "Mercado — ofertar por un jugador de tu division"
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

	var candidatos := []  # [{equipo, jugador}]
	for rival in GameState.liga_jugador().equipos:
		if rival == equipo:
			continue
		for j in rival.jugadores:
			if j["posicion"] == posicion_mercado_actual:
				candidatos.append({"equipo": rival, "jugador": j})
	candidatos.sort_custom(func(a, b): return a["jugador"]["media"] > b["jugador"]["media"])

	var titulo_lista := Label.new()
	titulo_lista.text = "Tu titular mas debil en %s tiene media %.1f — mostrando los mejores de la division:" % [posicion_mercado_actual, mi_media_en_posicion]
	contenedor_mercado_botones.add_child(titulo_lista)

	for i in range(min(10, candidatos.size())):
		var candidato: Dictionary = candidatos[i]
		var rival: Team = candidato["equipo"]
		var jugador: Dictionary = candidato["jugador"]

		var fila := HBoxContainer.new()
		var valor := ValorJugador.calcular(jugador, rival.animo.get(jugador["id"], 50.0), rival.contratos.get(jugador["id"], 1))
		var label := Label.new()
		label.text = "%-14s  media %5.1f  potencial %3d  ~%s" % [rival.nombre, jugador["media"], jugador["potencial"], Economia.formato_dinero(valor)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(label)

		var btn := Button.new()
		btn.text = "Ofertar"
		btn.disabled = jugador["media"] <= mi_media_en_posicion
		var jugador_id: int = jugador["id"]
		btn.pressed.connect(func(): _on_ofertar(rival, jugador_id))
		fila.add_child(btn)

		contenedor_mercado_botones.add_child(fila)


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
		label.text = "%-4s  media %5.1f  potencial %3d  edad %d" % [agente["posicion"], agente["media"], agente["potencial"], agente["edad"]]
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
		label.text = "%-4s  media %5.1f  potencial %3d  (%s)" % [j["posicion"], j["media"], j["potencial"], origen_txt]
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
		label.text = "%-14s  %-4s  media %5.1f  potencial %3d  (%s)" % [rival.nombre, j["posicion"], j["media"], j["potencial"], origen_txt]
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


func _on_mejorar_instalacion(categoria: String) -> void:
	var resultado := GameState.mejorar_instalacion(categoria)
	if resultado["exito"]:
		label_instalaciones_estado.text = "%s ahora esta en nivel %d." % [NOMBRES_INSTALACIONES[categoria], resultado["nivel"]]
	else:
		label_instalaciones_estado.text = "No se pudo: %s" % resultado["motivo"]

	_refrescar_instalaciones()
	_refrescar_economia()


func _construir_panel_cantera(padre: Control) -> void:
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	padre.add_child(panel)
	paneles["cantera"] = panel

	var titulo := Label.new()
	titulo.text = "Cantera (§17) — juveniles sin debutar. Promover los manda al banco (para subirlos a titular, ver Plantel)."
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


## [debug] Simula todas las fechas que queden de la temporada de una,
## para no tener que clickear "jugar fecha" muchas veces al probar.
func _on_simular_temporada() -> void:
	if not GameState.hay_fecha_pendiente():
		label_resultado.text = "Temporada terminada."
		return

	var temporada_antes := GameState.temporada_actual
	GameState.simular_temporada_completa()

	label_resultado.text = "[debug] Temporada simulada entera. Ahora en temporada %d, division %d." % [
		GameState.temporada_actual, GameState.division_jugador + 1
	]
	if GameState.temporada_actual == temporada_antes:
		label_resultado.text = "[debug] Se jugaron las fechas que quedaban."

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


func _mostrar_cantera() -> void:
	_ocultar_todos()
	paneles["cantera"].visible = true
	_refrescar_cantera()


func _mostrar_noticias() -> void:
	_ocultar_todos()
	paneles["noticias"].visible = true
	_refrescar_noticias()
