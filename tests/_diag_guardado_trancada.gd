extends SceneTree

## Solo lectura del guardado. Juega la proxima fecha del usuario varias
## veces, con otra semilla cada vez, y reproduce su partido en
## VistaPartido. Busca la pelota colgada en el aire y la cancha quieta.
## No llama a guardar_partida().
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_guardado_trancada.gd -- partidos=10 desde=0

const SEED := 88100
const DELTA := 0.05
## Segundos reales con la pelota dibujada en el mismo lugar.
const SEG_QUIETA := 2.5

var partidos := 10
var desde := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos = maxi(1, int(partes[1]))
		if partes.size() == 2 and partes[0] == "desde":
			desde = int(partes[1])
	call_deferred("_probar")


func _probar() -> void:
	var gs := root.get_node("GameState")
	for k in range(desde, desde + partidos):
		assert(gs.cargar_partida())
		gs.rng.seed = SEED + k * 7
		gs.jugar_siguiente_fecha()
		var lista: Array = gs.ultimos_fotogramas
		if lista.is_empty():
			print("SIN FOTOGRAMAS k=%d" % k)
			continue
		_reproducir(lista, k)
	quit()


func _reproducir(lista: Array, k: int) -> void:
	var vista := VistaPartido.new()
	vista.size = Vector2(1152, 648)
	root.add_child(vista)
	vista.iniciar(lista, Color.RED, Color.BLUE, "A", "B")
	var pasos := 0
	var quieta := 0.0
	var ultima := Vector3(INF, INF, INF)
	var informado := false
	while not vista._terminado and pasos < 100000:
		vista._process(DELTA)
		pasos += 1
		var pel := {}
		for e in vista.vista.entidades:
			if e["tipo"] == "pelota":
				pel = e
		if pel.is_empty():
			quieta = 0.0
			continue
		var actual := Vector3(pel["pos"].x, pel["pos"].y, float(pel["z"]))
		if actual.distance_to(ultima) < 0.01:
			quieta += DELTA
		else:
			quieta = 0.0
			informado = false
		ultima = actual
		var idx := int(vista.posicion)
		if quieta >= SEG_QUIETA and not informado and (float(pel["z"]) > 0.3 or int(lista[mini(idx, lista.size() - 1)]["detenido"]) == 0):
			informado = true
			var f: Dictionary = lista[mini(idx, lista.size() - 1)]
			print("QUIETA k=%d idx=%d congelado=%d min=%.1f det=%d pelota_vista=%s motor=(%.1f,%.1f,%.2f) pos=%s anclada=%s" % [
				k, idx, vista._idx_congelado, f["minuto"], f["detenido"], str(actual),
				f["pelota"]["x"], f["pelota"]["y"], f["pelota"]["z"], str(f["pelota"]["poseedor_id"]), str(pel.get("anclada", false))])
			for j in range(maxi(0, idx - 8), mini(lista.size(), idx + 3)):
				var g: Dictionary = lista[j]
				var q: Dictionary = g["pelota"]
				print("   idx=%d det=%d pel=(%.1f,%.1f,%.2f) pos=%s pase=%s rem=%s acc=%s ev=%s" % [j, g["detenido"], q["x"], q["y"], q["z"], str(q["poseedor_id"]), str(q["es_pase"]), str(q["es_remate"]), str(g["acciones"]), str(g["eventos"]).left(300)])
	print("partido k=%d fotogramas=%d pasos=%d terminado=%s" % [k, lista.size(), pasos, str(vista._terminado)])
	vista.free()
