extends SceneTree

## Medición: cuánto patina el pie apoyado en cada clip durante un partido
## de verdad, como lo dibuja la pantalla (VistaPartidoV2), sin pantalla. Usa
## el detector PATINA (DetectorPatinaV2) sobre los Jugador3D de la vista y
## suma, por clip, lo que avanza el cuerpo: un clip patina cuando el pie
## apoyado desliza una parte grande de lo que avanza el cuerpo.
##
## Argumentos (después de `--`): `semilla=N`, `division=N`, `segundos=N`
## (segundos de partido; 0 = entero), `saltar=pasos`.

const SEED := 20261201
const PREFIJO := "[patina_partido]"
const DELTA := 1.0 / 60.0
## Más que esto en un cuadro es un corte, no una carrera (18 m/s).
const SALTO_M := 0.3

var _vista: VistaPartidoV2
var _detector := DetectorPatinaV2.new()
var _armado := false
var _cuadros := 0
var _tope := 0
## clip -> [segundos, metros que avanzó el cuerpo]
var _cuerpo := {}
var _previas := {}
## Fundidos: jugador -> [clip de antes, clip nuevo]; "antes -> nuevo" ->
## [veces, metros que patina el pie más bajo mientras dura].
var _cambio := {}
var _ultimo_clip := {}
var _por_cambio := {}
## Clip de andar -> [segundos, suma del desvío entre adonde anda el clip y
## adonde va el cuerpo (rad), suma de rapidez del motor, suma de rapidez medida].
var _desvio := {}
const DIR_CLIP := {"Correr": 0.0, "Trotar": 0.0, "Caminar": 0.0, "Correr_Costado_Izq": PI * 0.5,
	"Correr_Costado_Der": -PI * 0.5, "Correr_Espaldas": PI}


func _armar() -> void:
	var semilla := SEED
	var division := 4
	var segundos := 0.0
	var saltar := 0
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"semilla": semilla = int(p[1])
			"division": division = int(p[1])
			"segundos": segundos = float(p[1])
			"saltar": saltar = int(p[1])
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
	_tope = int(segundos * 60.0) if segundos > 0.0 else 1 << 30


func _process(_delta: float) -> bool:
	if not _armado:
		_armado = true
		_armar()
		return false
	for k in 30:
		if _vista._terminado or _cuadros >= _tope:
			_informar()
			return true
		_vista._process(DELTA)
		_cuadros += 1
		var jugadores: Array = _vista.vista._jugadores
		# Los cortes al saque (tarjeta, gol) mueven a todos de golpe a
		# propósito: ese cuadro no cuenta.
		var saltaron := {}
		for p3: Jugador3D in jugadores:
			if _previas.has(p3) and (p3.position - (_previas[p3] as Vector3)).length() > SALTO_M:
				saltaron[p3] = true
				_detector._previos.erase(p3)
		# De a uno: lo que patina en un fundido se anota al cambio de clip de ese jugador.
		for p3: Jugador3D in jugadores:
			_medir_fundido(p3, false)
			var antes_f: float = (_detector.por_clip.get(DetectorPatinaV2.FUNDIDO, [0.0, 0.0]) as Array)[0]
			_detector.medir([p3], DELTA)
			var ahora_f: float = (_detector.por_clip.get(DetectorPatinaV2.FUNDIDO, [0.0, 0.0]) as Array)[0]
			if ahora_f > antes_f:
				var d: Array = _por_cambio.get(_cambio.get(p3, "?"), [0, 0.0])
				d[1] += ahora_f - antes_f
				_por_cambio[_cambio.get(p3, "?")] = d
		for p3: Jugador3D in jugadores:
			var clip := DetectorPatinaV2.FUNDIDO if p3._mezcla < 1.0 else p3._anim_actual
			if _previas.has(p3) and not saltaron.has(p3) and DIR_CLIP.has(clip):
				var mov := p3.position - (_previas[p3] as Vector3)
				if mov.length() > 1e-4:
					var dir_clip := p3.rotation.y + float(DIR_CLIP[clip])
					var dv := absf(wrapf(atan2(mov.x, mov.z) - dir_clip, -PI, PI))
					var dd: Array = _desvio.get(clip, [0.0, 0.0])
					dd[0] += DELTA
					dd[1] += dv * DELTA
					_desvio[clip] = dd
			if _previas.has(p3) and not saltaron.has(p3):
				var antes: Vector3 = _previas[p3]
				var d: Array = _cuerpo.get(clip, [0.0, 0.0])
				d[0] += DELTA
				d[1] += Vector2(p3.position.x - antes.x, p3.position.z - antes.z).length()
				_cuerpo[clip] = d
			_previas[p3] = p3.position
	return false


## Anota el cambio de clip de cada jugador y cuántas veces funde.
func _medir_fundido(p3: Jugador3D, salto: bool) -> void:
	var clip := p3._anim_actual
	var antes: String = _ultimo_clip.get(p3, clip)
	if clip != antes:
		_cambio[p3] = "%s -> %s" % [antes, clip]
		if p3._mezcla < 1.0:
			var d: Array = _por_cambio.get(_cambio[p3], [0, 0.0])
			d[0] += 1
			_por_cambio[_cambio[p3]] = d
	_ultimo_clip[p3] = clip


func _informar() -> void:
	var filas := []
	for clip in _detector.por_clip:
		var p: Array = _detector.por_clip[clip]
		var c: Array = _cuerpo.get(clip, [0.0, 0.0])
		var cuerpo_ms: float = c[1] / maxf(c[0], 1e-6)
		var pie_ms: float = p[0] / maxf(p[1], 1e-6)
		filas.append([clip, pie_ms, cuerpo_ms, c[0], p[0]])
	# Primero los que más metros patinan en total: los que más se ven.
	filas.sort_custom(func(a, b): return a[4] > b[4])
	print("%s %d cuadros" % [PREFIJO, _cuadros])
	for f in filas:
		print("%s %-26s pie %.2f m/s, cuerpo %.2f m/s (%3.0f%%), %6.1f s en el clip, %6.1f m patinados" % [PREFIJO, f[0], f[1],
			f[2], 100.0 * f[1] / maxf(f[2], 0.01), f[3], f[4]])
	for c in _desvio:
		print("%s desvío %-22s %.1f grados de media" % [PREFIJO, c, rad_to_deg(_desvio[c][1] / _desvio[c][0])])
	var cambios := _por_cambio.keys()
	cambios.sort_custom(func(a, b): return _por_cambio[a][1] > _por_cambio[b][1])
	for c in cambios.slice(0, 40):
		print("%s fundido %-40s %5d veces, %6.1f m patinados" % [PREFIJO, c, _por_cambio[c][0], _por_cambio[c][1]])
	print("FALLOS=0")
