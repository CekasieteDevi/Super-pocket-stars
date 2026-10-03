extends SceneTree

## Medición: cuánto tarda la pantalla del partido (VistaPartidoV2) en cada
## cuadro, sin pantalla. Mide el código de la vista (GDScript, esqueletos,
## animaciones), no el dibujo de la placa. Un cuadro lento se ve como un
## tirón. Imprime los cuadros más lentos con lo que pasaba (parada, acciones
## de los que hacen un gesto) y los cuadros que pasan de 4, 8 y 16 ms.
##
## Argumentos (después de `--`): `semilla=N`, `division=N`, `segundos=N`
## (segundos de partido que mira; 0 = entero), `saltar=pasos`.

const SEED := 20261201
const PREFIJO := "[cuadros_lentos]"
const DELTA := 1.0 / 60.0

var _vista: VistaPartidoV2
var _segundos := 0.0
var _peores: Array = []
var _por_umbral := [0, 0, 0]
var _cuadros := 0
var _total_us := 0
var _tope := 0
var _armado := false
## Desde cuántos ms se anota un cuadro (`umbral=N`).
var _umbral := 4.0
## Por cantidad de gestos a la vez: [cuadros, ms].
var _por_gestos := {}


## Se arma en la primera vuelta del árbol: en _initialize la raíz todavía no
## corre _ready de los hijos.
func _armar() -> void:
	var semilla := SEED
	var division := 4
	var saltar := 0
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"semilla": semilla = int(p[1])
			"division": division = int(p[1])
			"segundos": _segundos = float(p[1])
			"saltar": saltar = int(p[1])
			"umbral": _umbral = float(p[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local: Team = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var visitante: Team = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var r: Dictionary = MotorV2.simular(local, visitante, rng, true)
	_vista = VistaPartidoV2.new()
	_vista.size = Vector2(1280, 720)
	root.add_child(_vista)
	_vista.iniciar(r["receta_v2"], r["eventos"], local, visitante)
	_vista.set_process(false)
	if saltar > 0:
		_vista._partido.simular(saltar)
	_tope = int(_segundos * 60.0) if _segundos > 0.0 else 1 << 30


func _process(_delta: float) -> bool:
	if not _armado:
		_armado = true
		_armar()
		return false
	# Unos cuadros por vuelta: cada vuelta del árbol aplica lo pendiente.
	for k in 30:
		if _vista._terminado or _cuadros >= _tope:
			_informar()
			return true
		var t0 := Time.get_ticks_usec()
		_vista._process(DELTA)
		var us := Time.get_ticks_usec() - t0
		_cuadros += 1
		_total_us += us
		var ms := us / 1000.0
		for u in 3:
			if ms > [4.0, 8.0, 16.0][u]:
				_por_umbral[u] += 1
		var n_gestos := 0
		for i in _vista._partido.cantidad():
			if _vista._partido.get_accion(i) != "":
				n_gestos += 1
		var g: Array = _por_gestos.get(mini(n_gestos, 6), [0, 0.0, 0.0])
		g[0] += 1
		g[1] += ms
		g[2] = maxf(g[2], ms)
		_por_gestos[mini(n_gestos, 6)] = g
		if ms > _umbral and _cuadros > 30:
			var c: Object = _vista._partido
			var gestos := []
			for i in c.cantidad():
				var a: String = c.get_accion(i)
				if a != "":
					gestos.append(a)
			_peores.append({"ms": snappedf(ms, 0.01), "cuadro": _cuadros, "parada": str(c.get_estado()["parada"]),
				"gestos": gestos, "manos": c.get_en_manos(), "altura": snappedf(Vector3(c.get_pelota_pos()).y, 0.01)})
	return false


func _informar() -> void:
	_peores.sort_custom(func(a, b): return a["ms"] > b["ms"])
	print("%s %d cuadros, media %.2f ms" % [PREFIJO, _cuadros, float(_total_us) / maxi(_cuadros, 1) / 1000.0])
	for u in 3:
		print("%s cuadros de más de %.0f ms: %d" % [PREFIJO, [4.0, 8.0, 16.0][u], _por_umbral[u]])
	var claves := _por_gestos.keys()
	claves.sort()
	for k in claves:
		var g: Array = _por_gestos[k]
		print("%s con %d gestos a la vez: %d cuadros, %.2f ms de media, peor %.2f" % [PREFIJO, k, g[0], g[1] / g[0], g[2]])
	for i in mini(_peores.size(), 30):
		print("%s %s" % [PREFIJO, str(_peores[i])])
	print("FALLOS=0")
