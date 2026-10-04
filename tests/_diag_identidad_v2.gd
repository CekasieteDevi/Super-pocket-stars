extends SceneTree

## Etapa 7b del Motor V2 (docs/motor_v2.md): la identidad de cada estilo y
## cuánto depende de los atributos. Cada estilo de Estilos.LISTA juega con un
## plantel bueno y con uno malo contra el mismo rival, de local y de visitante.
## El estilo dice qué intenta el equipo; los atributos, qué tan bien le sale:
## la firma de cada estilo tiene que verse en las dos filas y salir mejor en la
## del plantel bueno. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_identidad_v2.gd -- semillas=20 semilla=97000
##
## `bueno`, `malo` y `rival`: el valor de todos los atributos de cada plantel.
## `solo=<grupo>`: el plantel bueno y el malo cambian solo en los jugadores de
## ese grupo (defensores, volantes o delanteros); los demás quedan en `rival`.
## `atributo=<nombre>`: cambia solo ese atributo y deja la media como está, para
## que no entre la rapidez que el motor le da al equipo de mejor media.
## `estilos=1,3`: solo esos estilos, por su lugar en Estilos.LISTA (0 = el primero).
## `rival_estilo=1`: el estilo del rival, por su lugar en Estilos.LISTA.
## `fisica=seccion.clave:valor,...` pisa data/fisica_v2.json en memoria.

const SEED := 97000
const MEDIO_LARGO_M := 52.5
## Cada cuántos pasos se mira la cancha (0,1 s).
const CADA_PASOS := 6
## DEC_* de motor_v2/cpp/src/cerebro/cerebro.h.
const TIPO_HUECO := 3
const TIPO_LARGO := 4
const TIPO_CENTRO := 5
const TIPO_DESPEJE := 7
## Golpe del remate de cabeza (GOLPES de tests/_diag_juego_v2.gd).
const GOLPE_CABEZA := 4
## Robo arriba: el remate sale hasta esto después de recuperar en campo rival.
const ROBO_SEG := 8.0
## Contra: el remate sale hasta esto después de recuperar en su campo.
const CONTRA_SEG := 12.0
## Remata solo: sin un rival a menos de esto.
const SOLO_M := 3.0
const GRUPOS := {"defensores": ["DFC", "LAT"], "volantes": ["MC", "MCO"], "delanteros": ["EXT", "DC"]}

var _bueno := 95.0
var _malo := 35.0
var _rival := 65.0
var _solo := ""
var _atributo := ""
var _rival_estilo := "Juego directo"


func _init() -> void:
	var semillas := 20
	var semilla := SEED
	var estilos := []
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"semillas": semillas = maxi(1, int(p[1]))
			"semilla": semilla = int(p[1])
			"bueno": _bueno = float(p[1])
			"malo": _malo = float(p[1])
			"rival": _rival = float(p[1])
			"solo": _solo = p[1]
			"atributo": _atributo = p[1]
			"rival_estilo": _rival_estilo = Estilos.LISTA[int(p[1])]
			"estilos":
				for indice in p[1].split(","):
					estilos.append(Estilos.LISTA[int(indice)])
			"fisica": _pisar(FisicaV2.datos(), p[1])
	print("[identidad] %d partidos por fila, semilla %d. Plantel bueno %d y malo %d%s contra un rival de %d con %s. Por partido, del equipo." % [
		semillas * 2, semilla, int(_bueno), int(_malo), (" (solo %s%s)" % [_solo if _solo != "" else "todos", (", " + _atributo) if _atributo != "" else ""]) if _solo + _atributo != "" else "",
		int(_rival), _rival_estilo])
	print("[identidad] %-14s %-6s %5s %6s %6s | %5s %5s %6s %6s %5s %5s | %6s %6s %6s %6s %5s | %6s %6s %6s %6s %6s | %7s %5s %7s" % ["estilo",
		"plant.", "favor", "contra", "poses.", "pases", "lleg.", "largo", "pelot.", "lleg.", "centr.", "bloque", "recup.",
		"altura", "riv. s", "off.", "remat.", "robo", "contra", "cabeza", "quites", "le esp.", "lleg.", "le solo"])
	for estilo in (Estilos.LISTA if estilos.is_empty() else estilos):
		for nivel in [_bueno, _malo]:
			_medir(estilo, nivel, semillas, semilla)
	print("[identidad] lleg.: pases y pelotazos que llegan a un compañero. largo: metros del pase. bloque: metros de su fondo a los que se para sin la pelota. recup. y altura: veces que recupera y a cuántos metros de su fondo. riv. s: segundos que tiene la pelota el rival antes de perderla. off.: offsides que le cobra al rival. robo: remates hasta %d s después de recuperar en campo rival. contra: remates hasta %d s después de recuperar en su campo. cabeza: remates de cabeza. le esp.: pelotazos y pases al hueco que le tira el rival, y cuántos llegan. le solo: remates del rival sin nadie a 3 m." % [
		int(ROBO_SEG), int(CONTRA_SEG)])
	quit()


func _medir(estilo: String, nivel: float, semillas: int, semilla: int) -> void:
	var k := {"favor": 0.0, "contra": 0.0, "posesion": 0.0, "pases": 0.0, "llegan": 0.0, "largo": 0.0, "pelotazos": 0.0,
		"pelotazos_llegan": 0.0, "centros": 0.0, "bloque": 0.0, "muestras": 0.0, "recup": 0.0, "altura": 0.0,
		"rival_pasos": 0.0, "tramos": 0.0, "off": 0.0, "remates": 0.0, "robo": 0.0, "contras": 0.0, "cabeza": 0.0, "quites": 0.0,
		"le_espalda": 0.0, "le_espalda_llegan": 0.0, "le_solo": 0.0}
	var partidos := 0.0
	for n in semillas:
		for de_local in [true, false]:
			var generador := RandomNumberGenerator.new()
			generador.seed = semilla + n
			# Los dos planteles salen de la misma semilla en todas las filas: la
			# formación y los puestos no cambian con el estilo ni con el nivel.
			var equipo := _plantel("Equipo", generador, 0, estilo, nivel)
			var rival := _plantel("Rival", generador, 1000, _rival_estilo, _rival, false)
			var c: Object = CerebroV2.armar(equipo if de_local else rival, rival if de_local else equipo, semilla + n, true)
			var yo := 0 if de_local else 1
			# El lado 0 del motor ataca hacia +x.
			var s := 1.0 if yo == 0 else -1.0
			var previo := -1
			var perdida := 0
			# Recuperaciones: [paso, en campo rival].
			var recuperaciones := []
			var pasos := 0
			while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
				c.simular(CADA_PASOS)
				pasos += CADA_PASOS
				var estado: Dictionary = c.get_estado()
				if str(estado["parada"]) != "nada":
					previo = -1
					perdida = 0
					continue
				var con := int(c.get_equipo_con_pelota())
				if con == 1 - yo:
					var pos: PackedVector2Array = c.get_pos()
					var equipos: PackedInt32Array = c.get_equipos()
					var arqueros: PackedInt32Array = c.get_arqueros()
					var suma := 0.0
					var cuantos := 0
					for i in pos.size():
						if int(equipos[i]) == yo and int(arqueros[i]) == 0:
							suma += pos[i].x * s
							cuantos += 1
					if cuantos > 0:
						k["bloque"] += suma / cuantos + MEDIO_LARGO_M
						k["muestras"] += 1.0
				if previo == yo and con == 1 - yo:
					perdida = pasos
				elif previo == 1 - yo and con == yo:
					var x: float = c.get_pelota_pos().x * s + MEDIO_LARGO_M
					k["recup"] += 1.0
					k["altura"] += x
					recuperaciones.append([int(estado["paso"]), x > MEDIO_LARGO_M])
					if perdida > 0:
						k["rival_pasos"] += pasos - perdida
						k["tramos"] += 1.0
				if con >= 0:
					previo = con
			partidos += 1.0
			var cuenta: Dictionary = c.contadores()
			k["favor"] += float(cuenta["goles_%d" % yo])
			k["contra"] += float(cuenta["goles_%d" % (1 - yo)])
			k["posesion"] += 100.0 * float(cuenta["posesion_%d" % yo]) / maxf(float(cuenta["posesion_0"]) + float(cuenta["posesion_1"]), 1.0)
			k["off"] += float(cuenta["offsides_cobrados_%d" % (1 - yo)])
			for r in c.registro_pases():
				if int(r["equipo"]) != yo and (int(r["tipo"]) == TIPO_LARGO or int(r["tipo"]) == TIPO_HUECO):
					# Pelotazos y pases al hueco del rival.
					k["le_espalda"] += 1.0
					if int(r["resultado"]) <= 1:
						k["le_espalda_llegan"] += 1.0
				if int(r["equipo"]) != yo or int(r["tipo"]) == TIPO_DESPEJE:
					continue
				var llega := 1.0 if int(r["resultado"]) <= 1 else 0.0
				k["pases"] += 1.0
				k["llegan"] += llega
				k["largo"] += (r["desde"] as Vector2).distance_to(r["meta"])
				if int(r["tipo"]) == TIPO_LARGO or int(r["tipo"]) == TIPO_HUECO:
					k["pelotazos"] += 1.0
					k["pelotazos_llegan"] += llega
				elif int(r["tipo"]) == TIPO_CENTRO:
					k["centros"] += 1.0
			for r in c.registro_remates():
				if int(r["equipo"]) != yo:
					# El que le remata sin nadie a 3 m: quedó solo.
					if float(r["presion_m"]) > SOLO_M:
						k["le_solo"] += 1.0
					continue
				k["remates"] += 1.0
				if int(r["golpe"]) == GOLPE_CABEZA:
					k["cabeza"] += 1.0
				# La última recuperación antes del remate.
				var paso := int(r["paso"])
				for i in range(recuperaciones.size() - 1, -1, -1):
					var rec: Array = recuperaciones[i]
					if int(rec[0]) > paso:
						continue
					var seg := (paso - int(rec[0])) / 60.0
					if rec[1] and seg <= ROBO_SEG:
						k["robo"] += 1.0
					elif not rec[1] and seg <= CONTRA_SEG:
						k["contras"] += 1.0
					break
			for e in c.eventos():
				if str(e["tipo"]) == "quite" and int(e["equipo"]) == yo:
					k["quites"] += 1.0
	var pases := maxf(k["pases"], 1.0)
	print("[identidad] %-14s %-6s %5.2f %6.2f %5.1f%% | %5.1f %4.0f%% %6.1f %6.2f %4.0f%% %5.2f | %6.1f %6.1f %6.1f %6.2f %5.2f | %6.2f %6.2f %6.2f %6.2f %6.2f | %7.2f %4.0f%% %7.2f" % [
		estilo, "bueno" if nivel == _bueno else "malo", k["favor"] / partidos, k["contra"] / partidos, k["posesion"] / partidos,
		k["pases"] / partidos, 100.0 * k["llegan"] / pases, k["largo"] / pases, k["pelotazos"] / partidos,
		100.0 * k["pelotazos_llegan"] / maxf(k["pelotazos"], 1.0), k["centros"] / partidos,
		k["bloque"] / maxf(k["muestras"], 1.0), k["recup"] / partidos, k["altura"] / maxf(k["recup"], 1.0),
		k["rival_pasos"] / maxf(k["tramos"], 1.0) / 60.0, k["off"] / partidos, k["remates"] / partidos, k["robo"] / partidos,
		k["contras"] / partidos, k["cabeza"] / partidos, k["quites"] / partidos, k["le_espalda"] / partidos,
		100.0 * k["le_espalda_llegan"] / maxf(k["le_espalda"], 1.0), k["le_solo"] / partidos])


## Un plantel con todos los atributos en `valor`. Con `solo`, ese valor va
## nada más que a los jugadores del grupo y los demás quedan en el del rival.
func _plantel(nombre: String, generador: RandomNumberGenerator, id_inicial: int, estilo: String, valor: float,
		filtra := true) -> Team:
	var equipo := Team.generar(nombre, generador, id_inicial)
	equipo.estilo = estilo
	# Cambiar el estilo a mano estrena una táctica, y eso resta en todos los
	# duelos (Familiaridad): acá se mide el estilo, no el estreno.
	equipo.familiaridad = Familiaridad.inicial(equipo.formacion, equipo.estilo)
	var roles: Array = GRUPOS.get(_solo, [])
	var slots := Formaciones.slots(equipo.formacion)
	for lista in [equipo.jugadores, equipo.banco]:
		for i in lista.size():
			var jugador: Dictionary = lista[i]
			var rol := str(slots[i]["rol"]) if lista == equipo.jugadores and i < slots.size() else ""
			var v := valor
			if filtra and not roles.is_empty() and not roles.has(rol):
				v = _rival
			if _atributo != "":
				# Todo el plantel al nivel del rival, y el atributo aparte.
				for clave in jugador["atributos"]:
					jugador["atributos"][clave] = _rival
				jugador["atributos"][_atributo] = v
				jugador["media"] = _rival
				continue
			for clave in jugador["atributos"]:
				jugador["atributos"][clave] = v
			jugador["media"] = v
	return equipo


func _pisar(datos: Dictionary, texto: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("FISICA %s = %s" % [kv[0], kv[1]])
