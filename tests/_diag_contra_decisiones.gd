extends SceneTree

## Medicion: que eligen los de arriba (EXT, DC, MCO) con la pelota en
## los primeros 6 s despues de recuperar, contra el resto del partido.
## No es un test: no falla nunca, mide.
##
## Viene de verlo jugar: en la contra el delantero queda libre y en vez
## de seguir corriendo busca un pase que arruina la jugada.
##
## Separa cada decision en:
##  - "libre": ningun rival en el cono de 15 m hacia el arco rival
##  - "tapado": el resto
## y los pases en "adelante" / "atras" segun adonde esta la pelota 1 s
## despues, medido contra la posicion del que la solto.
##
## Uso:
##   <godot> --path . --headless --script tests/_diag_contra_decisiones.gd -- partidos=5

const SEED := 77100
const REALISMO := preload("res://tests/_diag_realismo.gd")
const ROLES := ["EXT", "DC", "MCO"]
const TIPOS_PASE := ["pase", "pase_largo", "pase_hueco", "pared", "centro"]
# El mismo cono con el que el motor decide que va solo.
const CONO_M := MotorEspacial.CONO_SOLO_M
# La ventana de transicion del motor (SEGUNDOS_TRANSICION / TICK_SEG).
const VENTANA_TICKS := int(6.0 / 0.25)

var partidos_por_celda := 5


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var partes: PackedStringArray = arg.split("=")
		if partes.size() == 2 and partes[0] == "partidos":
			partidos_por_celda = maxi(1, int(partes[1]))
	var total := {}
	var partidos := 0
	for esc in REALISMO.ESCENARIOS:
		for par in REALISMO.ESTILOS:
			for i in range(partidos_por_celda):
				_medir(_simular(esc, par, SEED + i * 13)["fotogramas"], total)
				partidos += 1
	print("## Decisiones de los de arriba - semilla %d, %d partidos" % [SEED, partidos])
	for fase in ["contra", "resto"]:
		for espacio in ["libre", "tapado"]:
			var clave: String = fase + "/" + espacio
			var n := float(total.get(clave + "/n", 0.0))
			if n <= 0.0:
				continue
			print("")
			print("%s  (%d decisiones)" % [clave, int(n)])
			var tipos: Array = []
			for k in total:
				if str(k).begins_with(clave + "/t/"):
					tipos.append(k)
			tipos.sort()
			for k in tipos:
				print("  %-26s %6.1f%%" % [str(k).substr(clave.length() + 3), 100.0 * float(total[k]) / n])
			var adelante := float(total.get(clave + "/pase_adelante", 0.0))
			var atras := float(total.get(clave + "/pase_atras", 0.0))
			if adelante + atras > 0.0:
				print("  pases hacia atras          %6.1f%%  (de %d pases)" % [100.0 * atras / (adelante + atras), int(adelante + atras)])
			for dir in ["pase_adelante", "pase_atras"]:
				var m := float(total.get(clave + "/" + dir, 0.0))
				if m > 0.0:
					print("  %-18s la pierde en 5 s %5.1f%%, remata en 10 s %5.1f%%" % [dir,
						100.0 * float(total.get(clave + "/" + dir + "_perdida", 0.0)) / m,
						100.0 * float(total.get(clave + "/" + dir + "_tiro", 0.0)) / m])
	quit()


func _simular(esc: Dictionary, estilos: Array, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var a := Team.generar("A", rng, 0, NivelDivision.potencial(esc["a"]),
		"Uruguay", NivelDivision.realizacion(esc["a"]))
	var b := Team.generar("B", rng, 400, NivelDivision.potencial(esc["b"]),
		"Uruguay", NivelDivision.realizacion(esc["b"]))
	a.estilo = estilos[0]
	b.estilo = estilos[1]
	var rng_partido := RandomNumberGenerator.new()
	rng_partido.seed = semilla
	return MotorEspacial.simular(a, b, rng_partido, true)


func _medir(fotogramas: Array, total: Dictionary) -> void:
	var n := fotogramas.size()
	var ultimo_local = null
	var tick_recupero := -1000
	var previa = null
	for t in range(1, n):
		var f: Dictionary = fotogramas[t]
		if int(f.get("detenido", 0)) > 0:
			# La pelota parada cierra la ventana, igual que en el motor.
			tick_recupero = -1000
		var pid: int = int(f["pelota"]["poseedor_id"])
		var poseedor := _jugador(f, pid)
		if not poseedor.is_empty() and int(f.get("detenido", 0)) == 0:
			var local_p: bool = bool(poseedor["equipo_local"])
			if ultimo_local != null and bool(ultimo_local) != local_p:
				tick_recupero = t
			ultimo_local = local_p
		var d = f.get("decision", null)
		if d == null or is_same(d, previa):
			continue
		previa = d
		var anterior: Dictionary = fotogramas[t - 1]
		var quien := _jugador(anterior, int(anterior["pelota"]["poseedor_id"]))
		if quien.is_empty():
			quien = poseedor
		if quien.is_empty() or not ROLES.has(str(quien["rol"])):
			continue
		var local: bool = bool(quien["equipo_local"])
		var fase := "contra" if t - tick_recupero <= VENTANA_TICKS else "resto"
		var espacio := "libre" if _camino_libre(anterior, quien) else "tapado"
		var clave := fase + "/" + espacio
		var tipo := str(d["tipo"])
		total[clave + "/n"] = float(total.get(clave + "/n", 0.0)) + 1.0
		total[clave + "/t/" + tipo] = float(total.get(clave + "/t/" + tipo, 0.0)) + 1.0
		if TIPOS_PASE.has(tipo) and t + 4 < n:
			var signo := 1.0 if local else -1.0
			var avance: float = (float(fotogramas[t + 4]["pelota"]["x"]) - float(quien["x"])) * signo
			var dir := "pase_adelante" if avance > 0.0 else "pase_atras"
			total[clave + "/" + dir] = float(total.get(clave + "/" + dir, 0.0)) + 1.0
			# Que pasa despues: la pierde en 5 s, o el equipo remata en 10 s.
			if _pierde(fotogramas, t, local, 20):
				total[clave + "/" + dir + "_perdida"] = float(total.get(clave + "/" + dir + "_perdida", 0.0)) + 1.0
			if _remata(fotogramas, t, local, 40):
				total[clave + "/" + dir + "_tiro"] = float(total.get(clave + "/" + dir + "_tiro", 0.0)) + 1.0


## El rival tiene la pelota en algun fotograma de los proximos `ticks`.
func _pierde(fotogramas: Array, t: int, local: bool, ticks: int) -> bool:
	for k in range(t, mini(fotogramas.size(), t + ticks)):
		var f: Dictionary = fotogramas[k]
		var j := _jugador(f, int(f["pelota"]["poseedor_id"]))
		if not j.is_empty() and bool(j["equipo_local"]) != local and int(f.get("detenido", 0)) == 0:
			return true
	return false


## El equipo remata en los proximos `ticks`. El que remata figura como
## poseedor en el fotograma anterior al de la decision "tiro".
func _remata(fotogramas: Array, t: int, local: bool, ticks: int) -> bool:
	var previa = fotogramas[t].get("decision", null)
	for k in range(t + 1, mini(fotogramas.size(), t + ticks)):
		var d = fotogramas[k].get("decision", null)
		if d == null or is_same(d, previa):
			continue
		previa = d
		if str(d["tipo"]) != "tiro":
			continue
		var anterior: Dictionary = fotogramas[k - 1]
		var j := _jugador(anterior, int(anterior["pelota"]["poseedor_id"]))
		if not j.is_empty() and bool(j["equipo_local"]) == local:
			return true
	return false


## Ningun rival de campo en el cono de CONO_M metros hacia el arco rival.
## Copia la geometria de MotorEspacial._solo_frente_al_arco sin la presion.
func _camino_libre(f: Dictionary, quien: Dictionary) -> bool:
	var signo := 1.0 if bool(quien["equipo_local"]) else -1.0
	for j in f["jugadores"]:
		if bool(j["equipo_local"]) == bool(quien["equipo_local"]) or str(j["rol"]) == "ARQ":
			continue
		var dx: float = (float(j["x"]) - float(quien["x"])) * signo
		var dy: float = absf(float(j["y"]) - float(quien["y"]))
		if dx > 0.0 and dx < CONO_M and dy < 3.0 + dx * 0.5:
			return false
	return true


func _jugador(f: Dictionary, clave: int) -> Dictionary:
	if clave == -1:
		return {}
	for j in f["jugadores"]:
		if int(j["id"]) == clave:
			return j
	return {}
