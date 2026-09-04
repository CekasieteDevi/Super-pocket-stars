extends SceneTree

## Vida y muerte de cada posesion (§50, pasos 1 y 2).
##
## §50 dejo medido QUE el juego no llega al ultimo cuarto, pero no por
## que. Esto separa las dos preguntas que quedaron abiertas:
##
## 1. De donde sale la perdida: en que banda de cancha muere cada
##    posesion y por que causa (intercepcion, quite, salida, remate,
##    falta). La tabla de §50 contaba ticks, no finales.
## 2. Si el problema es LLEGAR o SOSTENER: cuantas posesiones pisan el
##    ultimo cuarto y cuantos ticks duran una vez ahi. Pocas visitas
##    largas y muchas visitas cortas son dos problemas distintos.
##
## Misma semilla y misma cantidad de partidos que _diag_donde_se_falta,
## para que los porcentajes se puedan cruzar con la tabla de §50.

const SEED := 4400
const PARTIDOS := 25
## Distancia al arco que ATACA el equipo con la pelota. Mismos cortes
## que _diag_donde_se_falta.
const BANDAS := [0.0, 16.5, 22.0, 30.0, 40.0, 55.0, 200.0]
## Ultimo cuarto de cancha: 26,25 m del arco rival (105 / 4).
const ULTIMO_CUARTO := 26.25
## Ultimo tercio: 35 m del arco rival (105 / 3). El futbol real publica
## la posesion por tercios, no por cuartos, asi que este es el numero
## que se puede comparar contra afuera (paso 3 de §50).
const ULTIMO_TERCIO := 35.0

const CAUSAS := ["intercepcion", "rival_llego_antes", "quite", "gambeta",
	"centro", "segunda_pelota", "remate", "falta", "offside", "lateral",
	"corner", "saque_arco", "suelta"]


func _init() -> void:
	# Cierres de posesion: causa -> banda -> cuantos.
	var muertes := {}
	# Por banda: cuantas posesiones EMPEZARON ahi y cuantas de esas
	# llegaron al ultimo cuarto.
	var arranques := {}
	var total_posesiones := 0
	var total_ticks := 0
	# Visitas al ultimo cuarto: una por cada vez que una posesion entra.
	var visitas := 0
	var ticks_en_cuarto := 0
	var posesiones_que_llegan := 0
	# Cuanto avanza cada posesion: distancia al arco al empezar menos la
	# minima que alcanzo.
	var avance_total := 0.0
	# Cierres que le dan la pelota al rival, contra los que la dejan en
	# el mismo equipo (falta a favor, corner, lateral propio).
	var perdidas := 0
	var conserva := 0
	var ticks_en_tercio := 0
	var punta_total := {}
	var extra := {"goles": 0, "remates": 0, "faltas": 0, "offsides": 0, "pases": 0}
	for i in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var casa := Team.generar("A", rng, 0)
		var visita := Team.generar("B", rng, 400)
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := _correr(casa, visita, r2, muertes, arranques)
		perdidas += int(res["perdidas"])
		conserva += int(res["conserva"])
		total_posesiones += int(res["posesiones"])
		total_ticks += int(res["ticks"])
		visitas += int(res["visitas"])
		ticks_en_cuarto += int(res["ticks_cuarto"])
		posesiones_que_llegan += int(res["llegan"])
		avance_total += float(res["avance"])
		ticks_en_tercio += int(res["ticks_tercio"])
		for k in extra:
			extra[k] = int(extra[k]) + int(res[k])
		for b in res["punta"]:
			var f: Dictionary = punta_total.get(b, {"ticks": 0, "suma": 0.0, "pelota": 0.0, "linea": 0.0})
			f["ticks"] = int(f["ticks"]) + int(res["punta"][b]["ticks"])
			f["linea"] = float(f["linea"]) + float(res["punta"][b]["linea"])
			f["suma"] = float(f["suma"]) + float(res["punta"][b]["suma"])
			f["pelota"] = float(f["pelota"]) + float(res["punta"][b]["pelota"])
			punta_total[b] = f
	_imprimir(muertes, arranques, total_posesiones, total_ticks, visitas,
		ticks_en_cuarto, posesiones_que_llegan, avance_total, perdidas, conserva,
		ticks_en_tercio, punta_total)
	print("")
	print("5. EFECTOS DE BORDE (por partido, los dos equipos)")
	for k in ["goles", "remates", "pases", "faltas", "offsides"]:
		print("  %-10s %6.2f" % [k, float(extra[k]) / PARTIDOS])
	quit()


func _banda_de(dist: float) -> int:
	for b in range(BANDAS.size() - 1):
		if dist >= float(BANDAS[b]) and dist < float(BANDAS[b + 1]):
			return b
	return BANDAS.size() - 2


func _imprimir(muertes: Dictionary, arranques: Dictionary, posesiones: int,
		ticks: int, visitas: int, ticks_cuarto: int, llegan: int,
		avance: float, perdidas: int, conserva: int, ticks_tercio: int,
		punta: Dictionary) -> void:
	print("posesiones (%d partidos, los dos equipos)" % PARTIDOS)
	print("  posesiones: %d  (%.1f por partido)" % [posesiones, float(posesiones) / PARTIDOS])
	print("  duracion media: %.2f ticks (%.2f s)" % [
		float(ticks) / maxf(1.0, float(posesiones)),
		float(ticks) / maxf(1.0, float(posesiones)) * MotorEspacial.TICK_SEG])
	print("  avance medio por posesion: %.1f m hacia el arco rival" % [
		avance / maxf(1.0, float(posesiones))])
	print("  cierres que le dan la pelota al rival: %d de %d (%.1f%%)" % [
		perdidas, perdidas + conserva,
		100.0 * float(perdidas) / maxf(1.0, float(perdidas + conserva))])
	print("")
	print("1. DONDE Y COMO MUERE LA POSESION")
	var cab := "  causa              "
	for b in range(BANDAS.size() - 1):
		cab += "|%5.0f-%3.0f" % [BANDAS[b], minf(BANDAS[b + 1], 99.0)]
	print(cab + "|  total")
	var por_banda := {}
	for causa in CAUSAS:
		var fila: Dictionary = muertes.get(causa, {})
		var suma := 0
		for b in fila:
			if b is String:  # "perdida"/"conserva" van aparte
				continue
			suma += int(fila[b])
			por_banda[b] = int(por_banda.get(b, 0)) + int(fila[b])
		if suma == 0:
			continue
		var linea := "  %-18s " % causa
		for b in range(BANDAS.size() - 1):
			linea += "|%9d" % int(fila.get(b, 0))
		var perd: int = int(fila.get("perdida", 0))
		var cons: int = int(fila.get("conserva", 0))
		print(linea + "|%7d (%4.1f%%) | pierde la pelota %5.1f%%" % [
			suma, 100.0 * suma / maxf(1.0, float(posesiones)),
			100.0 * float(perd) / maxf(1.0, float(perd + cons))])
	var tot := "  %-18s " % "TOTAL"
	for b in range(BANDAS.size() - 1):
		tot += "|%9d" % int(por_banda.get(b, 0))
	print(tot + "|%7d" % posesiones)
	var pct := "  %-18s " % "% del total"
	for b in range(BANDAS.size() - 1):
		pct += "|%8.1f%%" % [100.0 * float(por_banda.get(b, 0)) / maxf(1.0, float(posesiones))]
	print(pct)
	print("")
	print("2. LLEGAR O SOSTENER (ultimo cuarto = a %.2f m del arco rival)" % ULTIMO_CUARTO)
	print("  posesiones que pisan el ultimo cuarto: %d de %d (%.1f%%)" % [
		llegan, posesiones, 100.0 * float(llegan) / maxf(1.0, float(posesiones))])
	print("  visitas al ultimo cuarto: %d  (%.2f por partido)" % [
		visitas, float(visitas) / PARTIDOS])
	print("  ticks ahi: %d  (%.1f%% del juego, %.2f ticks por visita = %.2f s)" % [
		ticks_cuarto, 100.0 * float(ticks_cuarto) / maxf(1.0, float(ticks)),
		float(ticks_cuarto) / maxf(1.0, float(visitas)),
		float(ticks_cuarto) / maxf(1.0, float(visitas)) * MotorEspacial.TICK_SEG])
	print("  ultimo TERCIO (a %.0f m): %.1f%% del juego con pelota" % [
		ULTIMO_TERCIO, 100.0 * float(ticks_tercio) / maxf(1.0, float(ticks))])
	print("")
	print("3. DESDE DONDE SE LLEGA (banda donde arranco la posesion)")
	print("  banda de arranque | posesiones | llegan al cuarto | %")
	for b in range(BANDAS.size() - 1):
		var fila: Dictionary = arranques.get(b, {})
		var n: int = int(fila.get("total", 0))
		if n == 0:
			continue
		var ll: int = int(fila.get("llegan", 0))
		print("  %5.0f - %5.0f m    | %10d | %16d | %5.1f%%" % [
			BANDAS[b], BANDAS[b + 1], n, ll, 100.0 * float(ll) / float(n)])
	print("")
	print("4. DONDE SE PARA LA PUNTA DEL ATAQUE, SEGUN DONDE ESTA LA PELOTA")
	print("  pelota a ... del arco | ticks | pelota | punta | linea rival | la punta esta")
	for b in range(BANDAS.size() - 1):
		var f: Dictionary = punta.get(b, {})
		var n: int = int(f.get("ticks", 0))
		if n == 0:
			continue
		var media: float = float(f["suma"]) / float(n)
		var media_pelota: float = float(f["pelota"]) / float(n)
		print("  %5.0f - %5.0f m       | %5d | %4.1f m | %4.1f m | %6.1f m    | %5.1f m adelante de la pelota" % [
			BANDAS[b], BANDAS[b + 1], n, media_pelota, media,
			float(f["linea"]) / float(n), media_pelota - media])


## Corre un partido y acumula. Devuelve los totales de ese partido.
func _correr(home: Team, away: Team, rng: RandomNumberGenerator,
		muertes: Dictionary, arranques: Dictionary) -> Dictionary:
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false
	home.forma_partido = 0.0
	away.forma_partido = 0.0
	home.clima_partido = Clima.generar(rng)
	away.clima_partido = home.clima_partido
	home.arbitro_partido = Arbitro.generar(rng)
	away.arbitro_partido = home.arbitro_partido
	var estado := MotorEspacial.crear_estado(home, away, rng)
	var res := {"posesiones": 0, "ticks": 0, "visitas": 0, "ticks_cuarto": 0,
		"llegan": 0, "avance": 0.0, "perdidas": 0, "conserva": 0,
		"ticks_tercio": 0}
	home.goles = 0
	away.goles = 0
	# Por banda de la pelota: cuantos ticks, y suma de la distancia al
	# arco rival del atacante MAS ADELANTADO. Mide la sospecha 1 de §50:
	# si los de arriba quedan clavados contra la linea de offside, esta
	# distancia no baja aunque la pelota este lejos.
	var punta := {}
	for mitad in range(2):
		MotorEspacial._reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MotorEspacial.MINUTOS_MOSTRADOS_POR_MITAD * mitad
		# Posesion en curso: de quien es, cuantos ticks lleva, donde
		# arranco, la banda del ultimo tick y lo mas cerca que estuvo.
		var duenio := 2  # 2 = no hay posesion abierta
		var t_pos := 0
		var banda_ini := -1
		var dist_ini := 0.0
		var dist_min := 999.0
		var ultima_banda := -1
		var en_cuarto := false
		var llego := false
		# Posesion cerrada a la espera de saber quien sigue con la
		# pelota. Una falta a 45 m no es una perdida: el juego se detiene
		# y la saca el mismo equipo. Sin este diferido, "falta" figuraba
		# como causa de muerte de 205 posesiones que en realidad seguian.
		var pendiente := {}
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			var antes := _foto(estado)
			MotorEspacial._tick(estado, false)
			var quien := _quien_controla(estado)
			# Juego detenido o pelota de nadie: la posesion se cierra y
			# el reinicio abre una nueva. Un corner a favor tambien corta
			# la jugada, y lo que se mide es la jugada.
			var corte: bool = quien == 2 or (duenio != 2 and quien != duenio)
			if corte and duenio != 2:
				pendiente = {"causa": _causa(estado, antes), "banda": ultima_banda,
					"banda_ini": banda_ini, "duenio": duenio, "ticks": t_pos,
					"llego": llego, "avance": maxf(0.0, dist_ini - dist_min)}
				duenio = 2
				en_cuarto = false
				llego = false
			if quien == 2:
				continue
			if not pendiente.is_empty():
				_cerrar(pendiente, quien, muertes, arranques, res)
				pendiente = {}
			var dist := _dist_al_arco(estado, quien == 0)
			if duenio == 2:
				duenio = quien
				t_pos = 0
				dist_ini = dist
				dist_min = dist
				banda_ini = _banda_de(dist)
			t_pos += 1
			dist_min = minf(dist_min, dist)
			ultima_banda = _banda_de(dist)
			# Una visita se cuenta al ENTRAR, no por tick: entrar diez
			# veces un tick y entrar una vez diez ticks son dos futboles
			# distintos y la tabla de §50 no los separaba.
			if dist <= ULTIMO_TERCIO:
				res["ticks_tercio"] = int(res["ticks_tercio"]) + 1
			var b_pelota := _banda_de(dist)
			var f: Dictionary = punta.get(b_pelota, {"ticks": 0, "suma": 0.0, "pelota": 0.0})
			f["ticks"] = int(f["ticks"]) + 1
			f["suma"] = float(f["suma"]) + _punta_del_ataque(estado, quien == 0)
			f["pelota"] = float(f["pelota"]) + dist
			f["linea"] = float(f.get("linea", 0.0)) + _linea_rival(estado, quien == 0)
			punta[b_pelota] = f
			if dist <= ULTIMO_CUARTO:
				if not en_cuarto:
					en_cuarto = true
					res["visitas"] = int(res["visitas"]) + 1
					llego = true
				res["ticks_cuarto"] = int(res["ticks_cuarto"]) + 1
			else:
				en_cuarto = false
		# Se acabo la mitad con una posesion sin resolver: entra a la
		# tabla, pero no cuenta como perdida ni como conservada.
		if not pendiente.is_empty():
			_cerrar(pendiente, -1, muertes, arranques, res)
	res["punta"] = punta
	# Efectos de borde: un cambio que sube la punta tiene que mejorar
	# estos numeros, no solo la tabla de posesion.
	res["goles"] = home.goles + away.goles
	res["remates"] = int(estado["tiros"]["home"]) + int(estado["tiros"]["away"])
	res["faltas"] = int(estado.get("faltas", 0))
	res["offsides"] = int(estado.get("offsides", 0))
	res["pases"] = int(estado["pases"]["home"]) + int(estado["pases"]["away"])
	return res


## Donde esta la linea de offside rival, medida en distancia al arco que
## defiende. Es el techo duro del ataque: _objetivo_sin_pelota clampea a
## todos contra ella. Si la punta coincide con este numero, el que manda
## es el clamp y no el apoyo.
func _linea_rival(estado: Dictionary, ataca_local: bool) -> float:
	var linea: Dictionary = estado["linea_offside"]
	var x: float = float(linea["local"] if ataca_local else linea["away"])
	return absf(MotorEspacial.arco_rival(ataca_local).x - x)


## Distancia al arco rival del jugador de campo mas adelantado del
## equipo que ataca. El arquero no cuenta: nunca sube.
func _punta_del_ataque(estado: Dictionary, ataca_local: bool) -> float:
	var mejor := 999.0
	var arco := MotorEspacial.arco_rival(ataca_local)
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) != ataca_local or str(e["rol"]) == "ARQ":
			continue
		mejor = minf(mejor, e["pos"].distance_to(arco))
	return mejor


## Anota una posesion ya cerrada, ahora que se sabe quien sigue con la
## pelota. `sigue` es -1 cuando se acabo el tiempo y nunca se supo.
func _cerrar(p: Dictionary, sigue: int, muertes: Dictionary,
		arranques: Dictionary, res: Dictionary) -> void:
	var causa: String = p["causa"]
	var banda: int = int(p["banda"])
	var fila: Dictionary = muertes.get(causa, {})
	fila[banda] = int(fila.get(banda, 0)) + 1
	if sigue != -1:
		var quedo := "conserva" if sigue == int(p["duenio"]) else "perdida"
		fila[quedo] = int(fila.get(quedo, 0)) + 1
		res["perdidas" if quedo == "perdida" else "conserva"] = \
			int(res["perdidas" if quedo == "perdida" else "conserva"]) + 1
	muertes[causa] = fila
	var ar: Dictionary = arranques.get(int(p["banda_ini"]), {})
	ar["total"] = int(ar.get("total", 0)) + 1
	if bool(p["llego"]):
		ar["llegan"] = int(ar.get("llegan", 0)) + 1
		res["llegan"] = int(res["llegan"]) + 1
	arranques[int(p["banda_ini"])] = ar
	res["posesiones"] = int(res["posesiones"]) + 1
	res["ticks"] = int(res["ticks"]) + int(p["ticks"])
	res["avance"] = float(res["avance"]) + float(p["avance"])


## Quien controla la pelota: 0 local, 1 visitante, 2 nadie. Con la pelota
## en vuelo no hay poseedor, pero el equipo que la jugo sigue siendo el
## dueno de la jugada: es el mismo criterio que usa _tick para elegir
## quien persigue.
func _quien_controla(estado: Dictionary) -> int:
	if int(estado.get("detenido", 0)) > 0:
		return 2
	var pelota: Dictionary = estado["pelota"]
	var id: int = int(pelota.get("poseedor_id", -1))
	if id != -1 and estado["jugadores"].has(id):
		return 0 if bool(estado["jugadores"][id]["equipo_local"]) else 1
	if bool(pelota.get("en_vuelo", false)):
		return 0 if bool(pelota.get("pasador_local", true)) else 1
	return 2


func _dist_al_arco(estado: Dictionary, es_local: bool) -> float:
	return estado["pelota"]["pos"].distance_to(MotorEspacial.arco_rival(es_local))


## Contadores del estado antes del tick, para saber que paso adentro.
func _foto(estado: Dictionary) -> Dictionary:
	var pd: Dictionary = estado["pase_detalle"]
	return {
		"intercepcion": int(pd["interceptado_vuelo"]),
		"rival_llego_antes": int(pd["rival_llego_antes"]),
		"quite": int(estado["robos"]["ganados"]),
		"remate": int(estado["tiros"]["home"]) + int(estado["tiros"]["away"]),
		"falta": int(estado.get("faltas", 0)),
		"offside": int(estado.get("offsides", 0)),
		"eventos": int(estado["eventos"].size()),
	}


## Por que se corto la jugada. El orden importa: si un pase se intercepto
## y ademas hubo falta en el mismo tick, la falta es la que paro el juego.
func _causa(estado: Dictionary, antes: Dictionary) -> String:
	if int(estado.get("faltas", 0)) > int(antes["falta"]):
		return "falta"
	if int(estado.get("offsides", 0)) > int(antes["offside"]):
		return "offside"
	var tipos := {}
	for i in range(int(antes["eventos"]), estado["eventos"].size()):
		tipos[str(estado["eventos"][i].get("tipo", ""))] = true
	for tipo in ["corner", "lateral", "saque_arco"]:
		if tipos.has(tipo):
			return tipo
	# El remate NO corta la posesion cuando sale: la pelota vuela y el
	# equipo que remato sigue siendo dueño de la jugada. Corta cuando la
	# agarra el arquero, y ahi el contador `tiros` ya subio hace ticks.
	# Por eso la causa se lee del evento del tick que corta, no del
	# contador: con el contador solo se detectaban 9 de 113 remates.
	for tipo in ["tiro_puerta", "penal", "tiro"]:
		if tipos.has(tipo):
			return "remate"
	var pd: Dictionary = estado["pase_detalle"]
	if int(pd["interceptado_vuelo"]) > int(antes["intercepcion"]):
		return "intercepcion"
	if int(pd["rival_llego_antes"]) > int(antes["rival_llego_antes"]):
		return "rival_llego_antes"
	if int(estado["robos"]["ganados"]) > int(antes["quite"]):
		return "quite"
	if tipos.has("gambeta"):
		return "gambeta"
	if tipos.has("centro"):
		return "centro"
	# Un pase que no era `es_pase` —despeje, pelotazo— no toca
	# `pase_detalle`, pero igual cambia de dueño: es una segunda pelota.
	if tipos.has("pase"):
		return "segunda_pelota"
	return "suelta"
