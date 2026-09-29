extends SceneTree
## Peinados del 3D (juego3d/peinados.py, Jugador3D.poner_peinado):
##
## 1. jugador.glb y golero.glb traen el pelo de los 10 peinados (el 1,
##    pelado, sin malla) y cada jugador dibuja solo el suyo.
## 2. Un plantel sale con peinados variados, el rival no los repite en el
##    mismo orden y cada jugador tiene siempre el mismo.

const SEED := 22

var fallos := 0


func _initialize() -> void:
	for ruta in ["res://assets/3d/jugador.glb", "res://assets/3d/golero.glb"]:
		_probar_glb(ruta)
	_probar_reparto()
	print("FALLOS=", fallos)
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, texto: String) -> void:
	if cond:
		print("OK: ", texto)
	else:
		fallos += 1
		print("FALLA: ", texto)


## Triángulos de pelo por peinado en la malla que dibuja el jugador.
static func _pelo_por_peinado(j: Jugador3D) -> Dictionary:
	var cuenta := {}
	for mi in j.find_children("*", "MeshInstance3D", true, false):
		var datos := (mi as MeshInstance3D).mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = datos[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var v := uv[indices[t]].y
			if v < -0.5:
				var k := -roundi(v) - 1
				cuenta[k] = int(cuenta.get(k, 0)) + 1
	return cuenta


func _probar_glb(ruta: String) -> void:
	var nombre := ruta.get_file()
	var j := Jugador3D.new(load(ruta) as PackedScene)
	var sin_pelo := 0
	var tamanos := {}
	for k in Jugador3D.CANTIDAD_PEINADOS:
		j.poner_peinado(k)
		var pelo := _pelo_por_peinado(j)
		var solo_el_suyo := pelo.keys().all(func(x): return x == k)
		_ok(solo_el_suyo, "%s peinado %d: dibuja solo su pelo %s" % [nombre, k, str(pelo)])
		var n := int(pelo.get(k, 0))
		if k == 1:
			_ok(n == 0, "%s: el pelado no tiene pelo" % nombre)
		else:
			_ok(n > 300, "%s peinado %d: %d triángulos de pelo" % [nombre, k, n])
			_ok(n < 12000, "%s peinado %d: no pasa de 12000 triángulos" % [nombre, k])
			tamanos[n] = true
		if n == 0:
			sin_pelo += 1
	_ok(sin_pelo == 1 and tamanos.size() == Jugador3D.CANTIDAD_PEINADOS - 1,
		"%s: 9 peinados con malla propia, todas distintas" % nombre)
	var otro := Jugador3D.new(load(ruta) as PackedScene)
	otro.poner_peinado(4)
	j.poner_peinado(4)
	var a := j.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var b := otro.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_ok(a.mesh == b.mesh, "%s: dos jugadores con el mismo peinado comparten la malla" % nombre)
	j.free()
	otro.free()


func _probar_reparto() -> void:
	var usos := {}
	for id in range(1, 2001):
		var p := Jugador3D.peinado_de(id)
		usos[p] = int(usos.get(p, 0)) + 1
	var menos := 2000
	var mas := 0
	for p in Jugador3D.CANTIDAD_PEINADOS:
		menos = mini(menos, int(usos.get(p, 0)))
		mas = maxi(mas, int(usos.get(p, 0)))
	_ok(menos >= 150 and mas <= 250, "2000 jugadores: cada peinado entre %d y %d veces" % [menos, mas])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipo := Team.generar("Peinados FC", rng)
	var distintos := {}
	for j in equipo.jugadores.slice(0, 11):
		distintos[Jugador3D.peinado_de(int(j["id"]))] = true
	_ok(distintos.size() >= 9, "los primeros 11 del plantel tienen %d peinados distintos" % distintos.size())
	var rival := Team.generar("Espejo FC", rng, 1000)
	var iguales := 0
	for i in mini(equipo.jugadores.size(), rival.jugadores.size()):
		if Jugador3D.peinado_de(int(equipo.jugadores[i]["id"])) == Jugador3D.peinado_de(int(rival.jugadores[i]["id"])):
			iguales += 1
	_ok(iguales <= 3, "el rival no repite los peinados en el mismo orden (%d de %d iguales)" % [iguales, rival.jugadores.size()])
	_ok(Jugador3D.peinado_de(12345) == Jugador3D.peinado_de(12345), "el mismo jugador tiene siempre el mismo peinado")
