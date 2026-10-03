extends SceneTree

## Medición: cuánto tarda armar la pantalla del primer partido
## (VistaPartidoV2.iniciar) y cuánto de eso es armar las mallas de la cara y
## de cada peinado que aparece (Jugador3D._con_peinado). La malla de cada
## peinado se arma la primera vez que un jugador la usa; el segundo partido
## ya las tiene.
##
## En la PC y sin pantalla. En el teléfono lo mide el banco
## (motor_v2/banco_etapa8.gd, la línea "armar la pantalla del partido").
##
##   <godot> --path . --headless --script tests/_diag_mallas_3d.gd -- semilla=20261201 division=4

const SEED := 20261201
const PREFIJO := "[mallas_3d]"

var _armado := false


func _process(_delta: float) -> bool:
	if _armado:
		return true
	_armado = true
	var semilla := SEED
	var division := 4
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() == 2 and p[0] == "semilla":
			semilla = int(p[1])
		elif p.size() == 2 and p[0] == "division":
			division = int(p[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local: Team = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var visitante: Team = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var r: Dictionary = MotorV2.simular(local, visitante, rng, true)
	for partido in 2:
		var desde := Time.get_ticks_usec()
		var mallas_antes := Jugador3D.usec_mallas
		var vista := VistaPartidoV2.new()
		vista.size = Vector2(1280, 720)
		root.add_child(vista)
		vista.iniciar(r["receta_v2"], r["eventos"], local, visitante)
		var peinados := {}
		for p3: Jugador3D in vista.vista._jugadores:
			peinados[p3.peinado] = true
		print("%s partido %d: armar la pantalla %.0f ms, de eso las mallas %.0f ms (%d peinados distintos)" % [PREFIJO,
			partido + 1, float(Time.get_ticks_usec() - desde) / 1000.0,
			float(Jugador3D.usec_mallas - mallas_antes) / 1000.0, peinados.size()])
		vista.free()
	print("FALLOS=0")
	return true
