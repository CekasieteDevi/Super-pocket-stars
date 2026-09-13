extends SceneTree

## Donde se para el arquero y donde termina el remate que ataja.
##
## Viene de verlo jugando: "a veces el golero esta tan adelantado que la
## pelota lo pasa de largo y luego aparece en sus manos".
##
## Eran dos cosas encadenadas:
##  - El desplazamiento por estilo (16 m) se le aplicaba tambien al
##    arquero. Con Presion alta lo paraba en el borde del area: 7,32 m de
##    su linea de media y 32% del partido a mas de 10 m.
##  - La atajada terminaba en la LINEA del arco. El arquero adelantado
##    tenia que volver corriendo mientras la pelota volaba a 26 m/s, no
##    llegaba, y el motor le daba la pelota igual. En el 69% de las
##    atajadas con Presion alta la pelota ya lo habia pasado.
##
## Medido con tests/_diag_arquero_posicion.gd.

const SEED := 4242
const PARTIDOS := 6
## Presion alta era el peor caso y Defensivo el mejor: si el estilo ya no
## lo mueve, los dos tienen que dar lo mismo.
const ESTILOS := ["Presión alta", "Defensivo"]

## Su corral son los 16,5 m entre la linea y el borde del area, pero solo
## se va lejos cuando el juego esta en la otra mitad. Medido: 2,9 a 3,1 m
## de media segun el estilo. Con el estilo encima daba 7,32.
const DISTANCIA_MEDIA_MAX := 4.5
## Y a mas de 10 m de la linea casi nunca. Medido: 1-2%. Antes, 32%.
const FRACCION_LEJOS_MAX := 0.05


func _init() -> void:
	var fallos := 0
	var medidas := {}
	for estilo in ESTILOS:
		medidas[estilo] = _medir(estilo)
	fallos += _test_el_estilo_no_lo_saca_del_arco(medidas)
	fallos += _test_la_pelota_no_lo_pasa_de_largo(medidas)
	for arquero_local in [true, false]:
		fallos += _test_achica_sobre_la_bisectriz(arquero_local)
		fallos += _test_no_achica_con_un_defensor_en_el_camino(arquero_local)
		fallos += _test_el_centro_se_descuelga_llegando(arquero_local)
		fallos += _test_rechaza_hacia_donde_no_hay_nadie(arquero_local)
	print("FALLOS=%d" % fallos)
	quit()


## Simula `PARTIDOS` con los dos equipos en `estilo` y devuelve:
##  - dist: distancia del arquero a su linea, fotograma por fotograma
##  - lejos: cuantas de esas muestras pasan los 10 m
##  - atajadas / pasadas: atajadas totales y en cuantas la pelota ya
##    habia pasado al arquero cuando el motor se la dio
func _medir(estilo: String) -> Dictionary:
	var suma := 0.0
	var muestras := 0
	var lejos := 0
	var atajadas := 0
	var pasadas := 0

	for p in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + p * 977
		var casa := Team.generar("Casa", rng, p * 100)
		var visita := Team.generar("Visita", rng, 500 + p * 100)
		casa.estilo = estilo
		visita.estilo = estilo
		var res := MotorEspacial.simular(casa, visita, rng, true)
		var fs: Array = res["fotogramas"]
		for i in range(2, fs.size()):
			var f: Dictionary = fs[i]
			for j in f["jugadores"]:
				if str(j["rol"]) != "ARQ":
					continue
				var linea: float = -MotorEspacial.MEDIO_LARGO if bool(j["equipo_local"]) else MotorEspacial.MEDIO_LARGO
				var d: float = absf(float(j["x"]) - linea)
				suma += d
				muestras += 1
				if d > 10.0:
					lejos += 1

			# La atajada: el arquero pasa a tener la pelota que venia
			# volando. Se mira el fotograma ANTERIOR, que es el ultimo de
			# vuelo, contra donde esta el arquero al tomarla.
			var pos_id: int = int(f["pelota"]["poseedor_id"])
			if pos_id == -1 or int(fs[i - 1]["pelota"]["poseedor_id"]) != -1:
				continue
			var ev = f["evento"]
			if ev == null or str(ev.get("resultado", "")) != "atajada":
				continue
			var arq := Vector2.ZERO
			for j in f["jugadores"]:
				if int(j["id"]) == pos_id:
					arq = Vector2(float(j["x"]), float(j["y"]))
			var b1 := Vector2(float(fs[i - 2]["pelota"]["x"]), float(fs[i - 2]["pelota"]["y"]))
			var b2 := Vector2(float(fs[i - 1]["pelota"]["x"]), float(fs[i - 1]["pelota"]["y"]))
			if b1.distance_to(b2) < 0.5:
				continue   # no venia viajando: no hay nada que mirar
			atajadas += 1
			var linea_arq: float = -MotorEspacial.MEDIO_LARGO if arq.x < 0.0 else MotorEspacial.MEDIO_LARGO
			if absf(b2.x - linea_arq) < absf(arq.x - linea_arq):
				pasadas += 1

	return {
		"media": suma / maxf(muestras, 1),
		"fraccion_lejos": float(lejos) / maxf(muestras, 1),
		"atajadas": atajadas,
		"pasadas": pasadas,
	}


func _test_el_estilo_no_lo_saca_del_arco(medidas: Dictionary) -> int:
	print("=== El estilo del equipo no mueve al arquero ===")
	var fallos := 0
	for estilo in ESTILOS:
		var m: Dictionary = medidas[estilo]
		if float(m["media"]) > DISTANCIA_MEDIA_MAX:
			print("FALLA: con %s el arquero se para a %.2f m de su linea, mas de los %.1f tolerados." % [
				estilo, m["media"], DISTANCIA_MEDIA_MAX])
			fallos += 1
		if float(m["fraccion_lejos"]) > FRACCION_LEJOS_MAX:
			print("FALLA: con %s pasa el %.0f%% del partido a mas de 10 m de su linea (tope %.0f%%)." % [
				estilo, 100.0 * float(m["fraccion_lejos"]), 100.0 * FRACCION_LEJOS_MAX])
			fallos += 1
	if fallos == 0:
		print("OK: %s a %.2f m de su linea y %s a %.2f m; ninguno vive afuera del arco." % [
			ESTILOS[0], medidas[ESTILOS[0]]["media"],
			ESTILOS[1], medidas[ESTILOS[1]]["media"]])
	return fallos


func _test_la_pelota_no_lo_pasa_de_largo(medidas: Dictionary) -> int:
	print("
=== La atajada termina en el arquero, no en la linea ===")
	var fallos := 0
	var total := 0
	for estilo in ESTILOS:
		var m: Dictionary = medidas[estilo]
		total += int(m["atajadas"])
		if int(m["pasadas"]) > 0:
			print("FALLA: con %s, %d de %d atajadas le llegan con la pelota ya pasada." % [
				estilo, m["pasadas"], m["atajadas"]])
			fallos += 1
	if total == 0:
		print("FALLA: no se midio ninguna atajada; el test no esta mirando nada.")
		return 1
	if fallos == 0:
		print("OK: las %d atajadas medidas terminan delante del arquero." % total)
	return fallos


# ---------------------------------------------------------------------------
# Etapa 6: achique, centros y rechazos
# ---------------------------------------------------------------------------

## Punto a `metros` de la linea del arco que defiende el arquero, hacia el
## campo. La misma escena sirve para los dos lados.
func _punto(arquero_local: bool, metros: float, y: float) -> Vector2:
	var arco := MotorEspacial.arco_propio(arquero_local)
	return Vector2(arco.x - signf(arco.x) * metros, y)


## Juego abierto: el arquero en su lugar y todos los demas lejos del area.
## Cada caso acerca a quien necesita.
func _escena(arquero_local: bool, semilla: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	for equipo in [casa, visita]:
		equipo.reset_partido()
		equipo.clima_partido = "despejado"
	casa.local = true
	visita.local = false
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	estado["detenido"] = 0
	estado["quietos"] = 0
	estado["balon_parado"] = {}
	var arquero := -1
	var atacantes := []
	var companeros := []
	var claves: Array = estado["jugadores"].keys()
	claves.sort()
	for id in claves:
		var e: Dictionary = estado["jugadores"][id]
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		if bool(e["equipo_local"]) == arquero_local:
			if str(e["rol"]) == "ARQ":
				arquero = id
				e["pos"] = _punto(arquero_local, 2.8, 0.0)
				# El mismo arquero de los dos lados: los planteles se sortean
				# distinto y uno de 4,5 m/s no llega a lo que llega uno de 7.
				e["vel_max"] = 7.0
				e["aceleracion"] = 4.0
			else:
				e["pos"] = _punto(arquero_local, 60.0, -25.0 + companeros.size() * 5.0)
				companeros.append(id)
		else:
			e["pos"] = _punto(arquero_local, 45.0, -25.0 + atacantes.size() * 5.0)
			if str(e["rol"]) != "ARQ":
				atacantes.append(id)
	var equipo_arq: Team = casa if arquero_local else visita
	return {"estado": estado, "arquero": arquero, "atacantes": atacantes,
		"companeros": companeros, "ficha_arquero": equipo_arq.arquero()}


## Rival solo con la pelota a 18 m, abierto a 7 m del centro.
func _escena_mano_a_mano(arquero_local: bool, achique: int) -> Dictionary:
	var d := _escena(arquero_local, SEED + 50)
	var estado: Dictionary = d["estado"]
	d["ficha_arquero"]["atributos"]["achique"] = achique
	var rival: int = d["atacantes"][0]
	estado["jugadores"][rival]["pos"] = _punto(arquero_local, 18.0, 7.0)
	estado["pelota"]["en_vuelo"] = false
	estado["pelota"]["poseedor_id"] = rival
	estado["pelota"]["pos"] = estado["jugadores"][rival]["pos"]
	estado["pelota"]["ticks_con_pelota"] = 1
	d["rival"] = rival
	return d


func _test_achica_sobre_la_bisectriz(arquero_local: bool) -> int:
	print("\n=== Uno contra uno: achica sobre la bisectriz (arquero local=%s) ===" % arquero_local)
	var bueno := _escena_mano_a_mano(arquero_local, 90)
	var malo := _escena_mano_a_mano(arquero_local, 10)
	MotorEspacial._planificar_arqueros(bueno["estado"], not arquero_local)
	MotorEspacial._planificar_arqueros(malo["estado"], not arquero_local)
	var plan: Dictionary = bueno["estado"]["arqueros"][bueno["arquero"]]
	var plan_malo: Dictionary = malo["estado"]["arqueros"][malo["arquero"]]
	if str(plan["tipo"]) != "achicar" or str(plan_malo["tipo"]) != "achicar":
		print("FALLA: con el rival solo a 18 m las intenciones fueron '%s' y '%s'." % [plan["tipo"], plan_malo["tipo"]])
		return 1
	var arco := MotorEspacial.arco_propio(arquero_local)
	var pelota: Vector2 = bueno["estado"]["pelota"]["pos"]
	var destino: Vector2 = plan["destino"]
	var hacia := destino - pelota
	var a := absf(hacia.angle_to(arco + Vector2(0.0, MotorEspacial.ARCO_MEDIO_ANCHO) - pelota))
	var b := absf(hacia.angle_to(arco - Vector2(0.0, MotorEspacial.ARCO_MEDIO_ANCHO) - pelota))
	if absf(a - b) > 0.01:
		print("FALLA: el punto de achique abre %.3f rad hacia un palo y %.3f hacia el otro." % [a, b])
		return 1
	if destino.distance_to(pelota) < 4.0 - 0.01:
		print("FALLA: achica hasta %.2f m de la pelota; el margen es 4." % destino.distance_to(pelota))
		return 1
	var prof_bueno: float = absf(destino.x - arco.x)
	var prof_malo: float = absf((plan_malo["destino"] as Vector2).x - arco.x)
	if prof_bueno <= prof_malo:
		print("FALLA: con achique 90 sale a %.2f m y con 10 a %.2f m." % [prof_bueno, prof_malo])
		return 1
	var estado: Dictionary = bueno["estado"]
	var e: Dictionary = estado["jugadores"][bueno["arquero"]]
	var cob_linea := MotorEspacial.cobertura_arquero(estado, pelota, not arquero_local)
	var desde_linea: Vector2 = e["pos"]
	e["pos"] = destino
	var cob_achique := MotorEspacial.cobertura_arquero(estado, pelota, not arquero_local)
	e["pos"] = desde_linea
	if cob_achique <= cob_linea:
		print("FALLA: achicando tapa %.2f del arco y en la linea %.2f." % [cob_achique, cob_linea])
		return 1
	# Y va caminando: un tick despues esta mas cerca, con un paso fisico.
	var tope: float = float(e["vel_max"]) * MotorEspacial.TICK_SEG + 0.01
	MotorEspacial._tick(estado, false)
	var paso: float = desde_linea.distance_to(e["pos"])
	if paso > tope or (e["pos"] as Vector2).distance_to(destino) >= desde_linea.distance_to(destino):
		print("FALLA: el primer tick lo movio %.2f m (tope %.2f) sin acercarlo al punto." % [paso, tope])
		return 1
	print("OK: achica a %.2f m de la linea con achique 90 y a %.2f con 10, igual angulo a cada palo; tapa %.2f contra %.2f en la linea." % [
		prof_bueno, prof_malo, cob_achique, cob_linea])
	return 0


func _test_no_achica_con_un_defensor_en_el_camino(arquero_local: bool) -> int:
	print("\n=== Con un defensor en el camino no sale (arquero local=%s) ===" % arquero_local)
	var d := _escena_mano_a_mano(arquero_local, 90)
	var estado: Dictionary = d["estado"]
	estado["jugadores"][d["companeros"][0]]["pos"] = _punto(arquero_local, 10.0, 3.9)
	MotorEspacial._planificar_arqueros(estado, not arquero_local)
	var plan: Dictionary = estado["arqueros"][d["arquero"]]
	if str(plan["tipo"]) == "achicar":
		print("FALLA: achico con un companero parado en el camino del rival al arco.")
		return 1
	print("OK: con un central en el camino se queda en '%s'." % plan["tipo"])
	return 0


## Un centro que cae en `punto`, con un atacante y un defensor al lado.
func _escena_centro(arquero_local: bool, punto: Vector2, semilla: int) -> Dictionary:
	var d := _escena(arquero_local, semilla)
	var estado: Dictionary = d["estado"]
	d["ficha_arquero"]["atributos"]["achique"] = 80
	estado["jugadores"][d["atacantes"][0]]["pos"] = punto + Vector2(0.0, 1.0)
	estado["jugadores"][d["companeros"][0]]["pos"] = punto - Vector2(0.0, 1.0)
	return d


func _descuelgues(arquero_local: bool, punto: Vector2, pos_arquero: Vector2) -> int:
	var cuenta := 0
	for i in range(120):
		var d := _escena_centro(arquero_local, punto, SEED + 60)
		var estado: Dictionary = d["estado"]
		estado["jugadores"][d["arquero"]]["pos"] = pos_arquero
		estado["rng"].seed = SEED + 6000 + i
		MotorEspacial._resolver_centro(estado, punto, not arquero_local, 30)
		for ev in estado["eventos"]:
			if str(ev.get("tipo", "")) == "centro" and str(ev.get("resultado", "")) == "descuelga":
				cuenta += 1
	return cuenta


func _test_el_centro_se_descuelga_llegando(arquero_local: bool) -> int:
	print("\n=== El centro se descuelga llegando, no desde un radio (arquero local=%s) ===" % arquero_local)
	var punto := _punto(arquero_local, 8.5, 3.0)
	# A 6 m, adentro del radio de 7 m que antes le daba la pelota.
	var lejos := _descuelgues(arquero_local, punto, _punto(arquero_local, 2.8, 0.0))
	var encima := _descuelgues(arquero_local, punto, punto + Vector2(0.0, -0.8))
	if lejos != 0 or encima == 0:
		print("FALLA: 120 centros dan %d descuelgues parado a 6 m y %d debajo de la pelota." % [lejos, encima])
		return 1
	# Y sale a buscar el que le cae cerca mientras vuela, no el que cae lejos.
	var cerca := _intencion_en_centro(arquero_local, _punto(arquero_local, 6.0, 2.0))
	var lejano := _intencion_en_centro(arquero_local, _punto(arquero_local, 14.0, -4.0))
	if str(cerca["primera"]) != "interceptar" or str(lejano["primera"]) == "interceptar":
		print("FALLA: al centro que cae a 6 m la intencion fue '%s' y al que cae a 14 m '%s'." % [
			cerca["primera"], lejano["primera"]])
		return 1
	var alcance: float = MotorEspacial.ALCANCE_ESTIRADA + float(MotorEspacial.pesos_arquero()["alcance_descuelgue"])
	if float(cerca["dist_al_caer"]) > alcance:
		print("FALLA: salio al centro y cuando cayo estaba a %.2f m; su alcance es %.2f." % [cerca["dist_al_caer"], alcance])
		return 1
	print("OK: 120 centros: 0 descuelgues parado a 6 m y %d debajo de la pelota; sale al que cae a 6 m y llega a %.2f m." % [
		encima, cerca["dist_al_caer"]])
	return 0


## Lanza un centro desde la banda al `punto` y corre hasta que cae.
func _intencion_en_centro(arquero_local: bool, punto: Vector2) -> Dictionary:
	var d := _escena_centro(arquero_local, punto, SEED + 70)
	var estado: Dictionary = d["estado"]
	var clave: int = d["arquero"]
	var receptor: int = d["atacantes"][0]
	var desde := _punto(arquero_local, 14.0, 28.0)
	var p: Dictionary = estado["pelota"]
	p["poseedor_id"] = -1
	p["en_vuelo"] = true
	p["pos"] = desde
	p["origen_pos"] = desde
	p["destino_pos"] = punto
	p["vel"] = (punto - desde).normalized() * 18.0
	p["destino_id"] = receptor
	p["es_pase"] = true
	p["es_centro"] = true
	p["centro_de"] = not arquero_local
	p["es_remate"] = false
	p["altura_max"] = 6.0
	p["pasador_local"] = not arquero_local
	p["pasador_id"] = int(estado["jugadores"][d["atacantes"][1]]["jugador_id"])
	p["attr_pasador"] = "pases"
	p["pases_pasador"] = 50.0
	var primera := ""
	var dist_al_caer := INF
	for t in range(12):
		var antes: Vector2 = estado["jugadores"][clave]["pos"]
		MotorEspacial._tick(estado, false)
		if t == 0:
			primera = str(estado["arqueros"][clave]["tipo"])
		# Termina el centro: cae y se disputa, o alguien lo corta en la
		# bajada antes de caer. En los dos casos importa donde estaba el
		# arquero cuando la pelota llego a esa altura.
		if not bool(p.get("es_centro", false)) or p.has("dirigida_a") or int(p["poseedor_id"]) != -1:
			dist_al_caer = antes.distance_to(p["pos"])
			break
	return {"primera": primera, "dist_al_caer": dist_al_caer}


func _test_rechaza_hacia_donde_no_hay_nadie(arquero_local: bool) -> int:
	print("\n=== El rechazo va al corner o adonde no hay nadie (arquero local=%s) ===" % arquero_local)
	var bueno := _rechazos(arquero_local, 95)
	var malo := _rechazos(arquero_local, 10)
	print("  estirada 95: %s" % bueno)
	print("  estirada 10: %s" % malo)
	var fallos := 0
	if int(bueno["adentro_del_arco"]) + int(malo["adentro_del_arco"]) > 0:
		print("FALLA: un rechazo salio por adentro del arco propio.")
		fallos += 1
	if int(bueno["corner"]) == 0 or int(malo["en_juego"]) == 0:
		print("FALLA: los rechazos no reparten entre corner y juego.")
		fallos += 1
	if int(bueno["lado_ocupado"]) >= int(bueno["lado_libre"]):
		print("FALLA: el buen arquero la dejo %d veces del lado de los atacantes y %d del libre." % [
			bueno["lado_ocupado"], bueno["lado_libre"]])
		fallos += 1
	if int(malo["en_juego"]) <= int(bueno["en_juego"]):
		print("FALLA: el de estirada 10 la deja en juego %d veces y el de 95 %d." % [malo["en_juego"], bueno["en_juego"]])
		fallos += 1
	if fallos == 0:
		print("OK: de 300, el de 95 la saca por el fondo %d veces y la deja en juego %d; el de 10, %d y %d." % [
			bueno["corner"], bueno["en_juego"], malo["corner"], malo["en_juego"]])
	return fallos


## 300 rechazos del mismo remate con dos atacantes esperando del lado
## positivo. Cuenta a donde fue cada uno.
func _rechazos(arquero_local: bool, estirada: int) -> Dictionary:
	var d := _escena(arquero_local, SEED + 80)
	var plantilla: Dictionary = d["estado"]
	d["ficha_arquero"]["atributos"]["estirada"] = estirada
	var arq_pos: Vector2 = plantilla["jugadores"][d["arquero"]]["pos"]
	plantilla["jugadores"][d["atacantes"][0]]["pos"] = _punto(arquero_local, 6.0, 9.0)
	plantilla["jugadores"][d["atacantes"][1]]["pos"] = _punto(arquero_local, 9.0, 11.0)
	var hacia_campo := Vector2(-signf(MotorEspacial.arco_propio(arquero_local).x), 0.0)
	var cuenta := {"corner": 0, "lateral": 0, "en_juego": 0, "lado_ocupado": 0, "lado_libre": 0, "al_medio": 0, "adentro_del_arco": 0}
	for i in range(300):
		var estado: Dictionary = plantilla.duplicate(true)
		estado["pelota"]["pos"] = arq_pos
		estado["pelota"]["en_vuelo"] = false
		estado["pelota"]["poseedor_id"] = -1
		estado["rng"].seed = SEED + 8000 + i
		MotorEspacial._rechazar_remate(estado, {"es_local": not arquero_local, "dist": 12.0})
		var p: Dictionary = estado["pelota"]
		if p.has("saliendo"):
			var punto: Vector2 = p["saliendo"]["punto"]
			if absf(punto.x) >= MotorEspacial.MEDIO_LARGO - 0.01:
				cuenta["corner"] += 1
				if absf(punto.y) <= MotorEspacial.ARCO_MEDIO_ANCHO:
					cuenta["adentro_del_arco"] += 1
			else:
				cuenta["lateral"] += 1
			continue
		cuenta["en_juego"] += 1
		var dir: Vector2 = ((p["destino_pos"] as Vector2) - arq_pos).normalized()
		if absf(dir.angle_to(hacia_campo)) < deg_to_rad(30.0):
			cuenta["al_medio"] += 1
		elif dir.y > 0.0:
			cuenta["lado_ocupado"] += 1
		else:
			cuenta["lado_libre"] += 1
	return cuenta
