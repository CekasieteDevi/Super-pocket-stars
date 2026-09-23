extends SceneTree

## Solo lectura del guardado. Simula en memoria el mismo boton Jugar fecha.
## Busca pelota que llega sola al jugador o jugador que salta a la pelota:
## en el motor (fotogramas) y en lo que dibuja VistaPartido entre ticks.
const SEED := 0
const SUBPASOS := 8


func _init() -> void:
	call_deferred("_probar")


func _probar() -> void:
	var lista: Array = []
	var ruta := "res://scratch/diag_teletransporte_fotogramas.bin"
	if "reusar" in OS.get_cmdline_user_args() and FileAccess.file_exists(ruta):
		var leer := FileAccess.open(ruta, FileAccess.READ)
		lista = leer.get_var()
		leer.close()
	else:
		var gs := root.get_node("GameState")
		assert(gs.cargar_partida())
		gs.jugar_siguiente_fecha()
		lista = gs.ultimos_fotogramas
		var archivo := FileAccess.open(ruta, FileAccess.WRITE)
		archivo.store_var(lista)
		archivo.close()
	print("FOTOGRAMAS ", lista.size())
	_motor(lista)
	_vista(lista)
	quit()


static func _pos(d: Dictionary) -> Vector2:
	return Vector2(float(d["x"]), float(d["y"]))


static func _jugador(f: Dictionary, clave: int) -> Dictionary:
	for j in f["jugadores"]:
		if int(j["id"]) == clave:
			return j
	return {}


func _motor(lista: Array) -> void:
	var n_pose := 0
	var n_salto := 0
	var n_iman := 0
	var suelta := 0
	for i in range(1, lista.size()):
		var a: Dictionary = lista[i - 1]
		var b: Dictionary = lista[i]
		if bool(b.get("corte", false)) or int(a.get("periodo", 1)) != int(b.get("periodo", 1)):
			continue
		var pa := _pos(a["pelota"])
		var pb := _pos(b["pelota"])
		var dueno := int(b["pelota"].get("poseedor_id", -1))
		var dueno_ant := int(a["pelota"].get("poseedor_id", -1))
		var suelta_previa := suelta
		suelta = suelta + 1 if dueno == -1 else 0
		# Pelota suelta que dobla sin que nadie la toque: el iman hacia el dueño.
		if i >= 2 and dueno == -1 and dueno_ant == -1 and int(lista[i - 2]["pelota"].get("poseedor_id", -1)) == -1 				and a.get("acciones", []).is_empty() and b.get("acciones", []).is_empty():
			var v1 := pa - _pos(lista[i - 2]["pelota"])
			var v2 := pb - pa
			if v1.length() > 0.1 and v2.length() > 0.1 and absf(v1.angle_to(v2)) > deg_to_rad(20.0) and n_iman < 60:
				n_iman += 1
				print("MOTOR_IMAN i=%d min=%.2f giro=%.0f v1=%.2f v2=%.2f suelta=%d" % [
					i, float(b["minuto"]), rad_to_deg(absf(v1.angle_to(v2))), v1.length() * 4.0, v2.length() * 4.0, suelta])
				if suelta >= 12:
					_traza(lista, i)
		# Pelota que gana dueño estando lejos de él en el tick anterior.
		if dueno != -1 and dueno != dueno_ant:
			var ja := _jugador(a, dueno)
			var jb := _jugador(b, dueno)
			if not ja.is_empty():
				var d_ant := _pos(ja).distance_to(pa)
				var d_ahora := _pos(jb).distance_to(pb) if not jb.is_empty() else -1.0
				if d_ant > 0.8 and n_pose < 60:
					n_pose += 1
					print("MOTOR_POSESION suelta=%d i=%d min=%.2f clave=%d dist_ant=%.2f dist_ahora=%.2f salto_pelota=%.2f salto_jugador=%.2f det=%d acciones=%s" % [
						suelta_previa, i, float(b["minuto"]), dueno, d_ant, d_ahora, pa.distance_to(pb),
						_pos(ja).distance_to(_pos(jb)) if not jb.is_empty() else -1.0,
						int(b.get("detenido", 0)), b.get("acciones", [])])
		# Jugador que se mueve más de lo que puede correr en un tick.
		for jb in b["jugadores"]:
			var ja := _jugador(a, int(jb["id"]))
			if ja.is_empty():
				continue
			var d := _pos(ja).distance_to(_pos(jb))
			if d > 3.0 and n_salto < 60:
				n_salto += 1
				print("MOTOR_SALTO_JUGADOR i=%d min=%.2f clave=%d d=%.2f dueno=%d det=%d" % [
					i, float(b["minuto"]), int(jb["id"]), d, dueno, int(b.get("detenido", 0))])
	print("MOTOR_POSESION_LEJANA=%d MOTOR_SALTOS_JUGADOR=%d MOTOR_IMAN=%d" % [n_pose, n_salto, n_iman])


## Sigue al que se queda la pelota desde unos ticks antes del giro.
func _traza(lista: Array, i: int) -> void:
	var fin := i
	while fin < lista.size() - 1 and int(lista[fin]["pelota"].get("poseedor_id", -1)) == -1 and fin - i < 40:
		fin += 1
	var clave := int(lista[fin]["pelota"].get("poseedor_id", -1))
	for k in range(maxi(1, i - 4), fin + 1):
		var f: Dictionary = lista[k]
		var j := _jugador(f, clave)
		var ja := _jugador(lista[k - 1], clave)
		var pel := _pos(f["pelota"])
		print("   k=%d pelota=%s vel=%.2f dueno=%d | clave=%d pos=%s dist=%.2f vel_j=%.2f acciones=%s" % [
			k, pel, pel.distance_to(_pos(lista[k - 1]["pelota"])) * 4.0, int(f["pelota"].get("poseedor_id", -1)),
			clave, _pos(j) if not j.is_empty() else Vector2.ZERO,
			_pos(j).distance_to(pel) if not j.is_empty() else -1.0,
			_pos(j).distance_to(_pos(ja)) * 4.0 if not j.is_empty() and not ja.is_empty() else -1.0,
			f.get("acciones", [])])


func _vista(lista: Array) -> void:
	var vista := VistaPartido.new()
	root.add_child(vista)
	vista.iniciar(lista, Color.RED, Color.BLUE)
	vista.set_process(false)
	var anterior := Vector2.INF
	var n_rapida := 0
	var n_lejos := 0
	for i in range(lista.size() - 1):
		var corte := bool(lista[i + 1].get("corte", false))
		for s in range(SUBPASOS):
			var t := float(s) / float(SUBPASOS)
			vista._mostrar(i, t)
			var bola := {}
			for ent in vista.vista.entidades:
				if ent["tipo"] == "pelota":
					bola = ent
			if bola.is_empty():
				anterior = Vector2.INF
				continue
			var pos: Vector2 = bola["pos"]
			# Pelota que dibujada queda lejos de donde el motor la tiene.
			var real := _pos(lista[i]["pelota"]).lerp(_pos(lista[i + 1]["pelota"]), t)
			var desvio := pos.distance_to(real)
			if desvio > 2.0 and n_lejos < 80 and not corte:
				n_lejos += 1
				var ent_desc := _quien(vista.vista.entidades, pos)
				print("VISTA_DESVIO i=%d t=%.3f min=%.2f desvio=%.2f dibujada=%s motor=%s dueno=%d->%d acciones=%s cerca=%s" % [
					i, t, float(lista[i]["minuto"]), desvio, pos, real,
					int(lista[i]["pelota"].get("poseedor_id", -1)),
					int(lista[i + 1]["pelota"].get("poseedor_id", -1)),
					lista[i].get("acciones", []) + lista[i + 1].get("acciones", []), ent_desc])
			if anterior != Vector2.INF and not corte:
				var v := pos.distance_to(anterior) * float(SUBPASOS) * 4.0
				if v > 45.0 and n_rapida < 80:
					n_rapida += 1
					print("VISTA_SALTO_PELOTA i=%d t=%.3f min=%.2f vel=%.1f m/s de=%s a=%s dueno=%d->%d" % [
						i, t, float(lista[i]["minuto"]), v, anterior, pos,
						int(lista[i]["pelota"].get("poseedor_id", -1)),
						int(lista[i + 1]["pelota"].get("poseedor_id", -1))])
			anterior = pos
		if corte:
			anterior = Vector2.INF
	print("VISTA_DESVIOS=%d VISTA_SALTOS_PELOTA=%d" % [n_lejos, n_rapida])
	vista.free()


static func _quien(ents: Array, pos: Vector2) -> String:
	var mejor := INF
	var desc := ""
	for e in ents:
		if e["tipo"] != "jugador":
			continue
		var d := pos.distance_to(e["pos"])
		if d < mejor:
			mejor = d
			desc = "%s/%s d=%.2f" % [e.get("accion", ""), e.get("pose", ""), d]
	return desc
