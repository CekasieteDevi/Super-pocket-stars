extends SceneTree
## Busca cosas raras en un partido entero dibujado en 3D:
##   -- division=1 semilla=N [desde=T]
## Correr con --fixed-fps 30 (sin tiempo real). Imprime cada caso con su tick
## y minuto, y al final un resumen por tipo.
var _p: Prototipo3D
var _n := 0
var _prev_bola := Vector3.INF
var _casos := {}
var _ultimo := {}
var _desde := 0.0
var _suelta_desde := -1.0
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("desde="): _desde = float(a.trim_prefix("desde="))
	_p = (load("res://match/3d/prototipo_3d.tscn") as PackedScene).instantiate()
	root.add_child(_p)
	process_frame.connect(_ver)
func _caso(tipo: String, pos: float, det: String) -> void:
	# Un caso por tipo cada 4 ticks: si no, un problema de un segundo son 30.
	if _ultimo.has(tipo) and pos - float(_ultimo[tipo]) < 4.0 and pos >= float(_ultimo[tipo]):
		return
	_ultimo[tipo] = pos
	_casos[tipo] = int(_casos.get(tipo, 0)) + 1
	var rep := _p.reproductor
	var f: Dictionary = rep.fotogramas[mini(int(pos), rep.fotogramas.size() - 1)]
	print("CASO %s tick %.1f min %s | %s" % [tipo, pos, str(int(f.get("minuto", 0))), det])
func _ver() -> void:
	_n += 1
	var rep := _p.reproductor
	if rep == null or rep.vista == null: return
	if _n == 3 and _desde > 0.0:
		rep.posicion = _desde
	if _n < 4: return
	var v := rep.vista as VistaCancha3D
	var pos := rep.posicion
	if pos >= float(rep.fotogramas.size() - 2) or _n > 60000:
		print("RESUMEN ", _casos, " cuadros ", _n)
		quit(); return
	var idx := mini(int(pos), rep.fotogramas.size() - 1)
	var f: Dictionary = rep.fotogramas[idx]
	var parado := int(f.get("detenido", 0)) > 0
	var seg := v._segundos
	var bola := v._pelota.global_position
	# 1. La pelota salta: más de 45 m/s de partido entre dos cuadros.
	if _prev_bola != Vector3.INF and seg > 0.0 and v._pelota.visible:
		var vel := Vector2(bola.x - _prev_bola.x, bola.z - _prev_bola.z).length() / seg
		if vel > 45.0 and not VistaPartido._es_reubicacion(f):
			_caso("SALTO_PELOTA", pos, "%.0f m/s en (%.1f,%.1f)" % [vel, bola.x, bola.z])
	_prev_bola = bola
	if seg <= 0.0: return
	# 2. Pelota muy alta.
	if bola.y > 4.0:
		_caso("PELOTA_ALTA", pos, "y=%.1f" % bola.y)
	# 3. Dueño lejos de la pelota dibujada un buen rato (juego corriendo).
	var dueno := int(f["pelota"].get("poseedor_id", -1))
	var lejos := false
	if dueno != -1 and not parado:
		for i in mini(v._jugadores_cuadro.size(), v._posiciones.size()):
			if int(v._jugadores_cuadro[i]["id"]) == dueno:
				var d := (v._posiciones[i] as Vector2).distance_to(Vector2(bola.x, bola.z))
				if d > 2.0:
					lejos = true
					if _suelta_desde < 0.0: _suelta_desde = pos
					elif pos - _suelta_desde > 2.0:
						_caso("DUENO_LEJOS", pos, "id %d a %.1f m" % [dueno, d])
	if not lejos: _suelta_desde = -1.0
	# 4. Patina: se mueve rápido con una animación de quieto.
	for clave in v._personas:
		var p: Jugador3D = v._personas[clave]
		if not p.visible or not v._odometro.has(clave): continue
		var a := str(p._anim_actual)
		var rapidez := float(v._odometro[clave][2])
		if rapidez > 1.8 and a in ["Respirar", "Golero_Guardia", "Arquero_Sostiene", "Barrera", "Tarjeta", "Tarjeta_Completa", "Levantar_Brazo", "Bandera_Arriba", "Tablero", "Quieto"]:
			_caso("PATINA_" + ("OF" if clave.begins_with("of_") else "JUG"), pos, "%s %s a %.1f m/s" % [clave.substr(0, 14), a, rapidez])
		# 5. La pelota le atraviesa el cuerpo (no es el dueño ni la toca).
		if not clave.begins_with("of_") and bola.y < 1.1:
			var hd := Vector2(p.global_position.x - bola.x, p.global_position.z - bola.z).length()
			if hd < 0.18 and _prev_bola != Vector3.INF:
				pass
	# 6. Dos cuerpos encimados.
	for i in v._posiciones.size():
		for j in range(i + 1, v._posiciones.size()):
			if (v._posiciones[i] as Vector2).distance_to(v._posiciones[j]) < 0.4 and not parado:
				_caso("ENCIMADOS", pos, "%d y %d" % [int(v._jugadores_cuadro[i]["id"]), int(v._jugadores_cuadro[j]["id"])])
