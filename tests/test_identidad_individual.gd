extends SceneTree

## Etapa 8 del plan de realismo: identidad individual.
##
## Cada jugador tiene cinco preferencias derivadas de sus atributos y de
## su rol. El perfil dice a QUE JUEGA, no cuan bueno es: mueve la utilidad
## de las opciones y el valor de los desmarques, y no toca ningun duelo.
## Lo que se comprueba aca es eso — que cambiar SOLO el perfil cambia las
## frecuencias de eleccion, que cada perfil conserva variedad y puede
## fallar, y que el resultado de la accion elegida sale igual que antes.

const SEED := 7710

var fallos := 0


func _ok(texto: String) -> void:
	print("OK: %s" % texto)


func _falla(texto: String) -> void:
	fallos += 1
	print("FALLA: %s" % texto)


func _armar_estado(rng: RandomNumberGenerator, division: int = 0) -> Dictionary:
	var casa := Team.generar("Casa", rng, division)
	var visita := Team.generar("Visita", rng, division)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	casa.dt = {"nivel": 5, "rasgo": "Cantera"}
	visita.dt = {"nivel": 5, "rasgo": "Cantera"}
	return MotorEspacial.crear_estado(casa, visita, rng)


## Una escena de ataque con la pelota en los pies del jugador de este rol.
func _escena(semilla: int, ataca_local: bool, pelota: Vector2, rol: String = "MC") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var estado := _armar_estado(rng)
	var portador := -1
	# No toda formacion tiene el rol pedido: si falta, la escena la juega
	# el suplente de rol que se indica. Sin esto la muestra se vaciaba
	# justo en las formaciones sin extremos.
	for candidato in [rol, "MCO", "DC", "MC"]:
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if e["equipo_local"] == ataca_local and str(e["rol"]) == candidato:
				portador = int(id)
				break
		if portador != -1:
			break
	if portador == -1:
		return {"estado": estado, "portador": -1}
	estado["jugadores"][portador]["pos"] = pelota
	estado["pelota"]["pos"] = pelota
	estado["pelota"]["poseedor_id"] = portador
	estado["pelota"]["ticks_con_pelota"] = 8
	estado["ultimo_equipo_con_pelota"] = ataca_local
	MotorEspacial._calcular_linea_offside(estado)
	return {"estado": estado, "portador": portador}


## Le pisa el perfil a un jugador. Es lo que pide la verificacion de la
## etapa: cambiar SOLO el perfil y dejar todo lo demas igual.
func _forzar_perfil(estado: Dictionary, clave: int, rasgo: String, valor: float) -> void:
	var e: Dictionary = estado["jugadores"][clave]
	var perfil := {}
	for r in MotorEspacial.RASGOS_PERFIL:
		perfil[r] = 0.25
	perfil[rasgo] = valor
	e["perfil"] = perfil
	e["perfil_rol"] = str(e["rol"])


func _dict_de(estado: Dictionary, clave: int) -> Dictionary:
	var e: Dictionary = estado["jugadores"][clave]
	var equipo: Team = estado["home"] if bool(e["equipo_local"]) else estado["away"]
	for j in equipo.convocados():
		if int(j["id"]) == int(e["jugador_id"]):
			return j
	return {}


func _init() -> void:
	_test_los_22_arrancan_con_perfil()
	_test_el_perfil_es_forma_y_no_nivel()
	_test_el_rol_mueve_el_perfil()
	_test_el_perfil_no_consume_azar()
	_test_se_recalcula_al_cambiar_de_rol()
	_test_el_suplente_entra_con_perfil()
	_test_el_ajuste_esta_acotado()
	_test_el_remate_no_se_toca()
	_test_el_contexto_apaga_la_preferencia()
	_test_la_descarga_la_pide_el_receptor()
	_test_el_encarador_encara_mas()
	_test_el_asociador_la_toca_mas()
	_test_cada_perfil_conserva_variedad()
	_test_preferir_no_es_saber()
	_test_el_perfil_inclina_el_desmarque()
	_test_partidos_completos()
	print("\nFALLOS=%d" % fallos)
	quit()


# ---------------------------------------------------------------------------
# El perfil en si
# ---------------------------------------------------------------------------

func _test_los_22_arrancan_con_perfil() -> void:
	print("\n=== Los 22 arrancan con perfil y el arquero queda neutro ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var estado := _armar_estado(rng)
	var sin_perfil := 0
	var arqueros := 0
	var arqueros_neutros := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if not e.has("perfil"):
			sin_perfil += 1
			continue
		if str(e["rol"]) != "ARQ":
			continue
		arqueros += 1
		var neutro := true
		for r in MotorEspacial.RASGOS_PERFIL:
			if absf(float(e["perfil"][r]) - 0.5) > 0.001:
				neutro = false
		if neutro:
			arqueros_neutros += 1
	if sin_perfil == 0:
		_ok("los %d de la cancha arrancan con perfil armado." % estado["jugadores"].size())
	else:
		_falla("%d jugadores sin perfil al empezar." % sin_perfil)
	if arqueros == 2 and arqueros_neutros == 2:
		_ok("los dos arqueros quedan en 0,5 parejo: su rama es la etapa 6.")
	else:
		_falla("arqueros neutros: %d de %d." % [arqueros_neutros, arqueros])


func _test_el_perfil_es_forma_y_no_nivel() -> void:
	print("\n=== El perfil es la forma del jugador, no su nivel ===")
	# Dos planteles de divisiones opuestas: si el perfil midiera nivel, el
	# de primera tendria las cinco preferencias arriba y el de decima las
	# cinco abajo. Tiene que dar lo mismo en las dos.
	var peor_media := 0.5
	var peor_division := 0
	for division in [0, 9]:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + division
		var estado := _armar_estado(rng, division)
		var suma := 0.0
		var cuantos := 0
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if str(e["rol"]) == "ARQ":
				continue
			for r in MotorEspacial.RASGOS_PERFIL:
				suma += float(e["perfil"][r])
			cuantos += MotorEspacial.RASGOS_PERFIL.size()
		var media: float = suma / float(cuantos)
		if absf(media - 0.5) > absf(peor_media - 0.5):
			peor_media = media
			peor_division = division
	if absf(peor_media - 0.5) <= 0.06:
		_ok("la media de las cinco preferencias queda en %.3f (la peor, division %d)." % [peor_media, peor_division + 1])
	else:
		_falla("la media se fue a %.3f en division %d: el perfil esta midiendo nivel." % [peor_media, peor_division + 1])

	# Y adentro de un mismo jugador tiene que haber relieve: si las cinco
	# preferencias fueran iguales no habria identidad ninguna.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = SEED
	var e2 := _armar_estado(rng2)
	var con_relieve := 0
	var de_campo := 0
	for id in e2["jugadores"]:
		var e: Dictionary = e2["jugadores"][id]
		if str(e["rol"]) == "ARQ":
			continue
		de_campo += 1
		var alto := -INF
		var bajo := INF
		for r in MotorEspacial.RASGOS_PERFIL:
			alto = maxf(alto, float(e["perfil"][r]))
			bajo = minf(bajo, float(e["perfil"][r]))
		if alto - bajo >= 0.15:
			con_relieve += 1
	if con_relieve == de_campo:
		_ok("los %d jugadores de campo separan su preferencia fuerte de la debil al menos 0,15." % de_campo)
	else:
		_falla("%d de %d jugadores quedaron chatos." % [de_campo - con_relieve, de_campo])


func _test_el_rol_mueve_el_perfil() -> void:
	print("\n=== El mismo jugador cambia de perfil si le cambia el rol ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var estado := _armar_estado(rng)
	var clave := -1
	for id in estado["jugadores"]:
		if str(estado["jugadores"][id]["rol"]) == "MC":
			clave = int(id)
			break
	var jugador := _dict_de(estado, clave)
	var como_ext := MotorEspacial._construir_perfil(jugador, "EXT")
	var como_dfc := MotorEspacial._construir_perfil(jugador, "DFC")
	if float(como_ext["regate"]) > float(como_dfc["regate"]) + 0.10:
		_ok("de extremo prefiere el regate %.2f y de central %.2f." % [como_ext["regate"], como_dfc["regate"]])
	else:
		_falla("el rol no movio el regate: EXT %.2f, DFC %.2f." % [como_ext["regate"], como_dfc["regate"]])
	if float(como_dfc["llegada"]) < float(como_ext["llegada"]) 			or float(como_dfc["ruptura"]) < float(como_ext["ruptura"]):
		_ok("de central baja la corrida (llegada %.2f, ruptura %.2f)." % [como_dfc["llegada"], como_dfc["ruptura"]])
	else:
		_falla("el central conserva la corrida del extremo.")


func _test_el_perfil_no_consume_azar() -> void:
	print("\n=== Armar el perfil no toca el RNG y da lo mismo dos veces ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var estado := _armar_estado(rng)
	var clave := -1
	for candidato in ["MCO", "MC", "DC"]:
		for id in estado["jugadores"]:
			if str(estado["jugadores"][id]["rol"]) == candidato:
				clave = int(id)
				break
		if clave != -1:
			break
	var jugador := _dict_de(estado, clave)
	var antes: int = estado["rng"].state
	var a := MotorEspacial._construir_perfil(jugador, "MCO")
	var b := MotorEspacial._construir_perfil(jugador, "MCO")
	var despues: int = estado["rng"].state
	var iguales := true
	for r in MotorEspacial.RASGOS_PERFIL:
		if absf(float(a[r]) - float(b[r])) > 0.0001:
			iguales = false
	if iguales and antes == despues:
		_ok("dos construcciones dan el mismo perfil y el RNG no se mueve.")
	else:
		_falla("el perfil no es determinista o consumio azar.")


func _test_se_recalcula_al_cambiar_de_rol() -> void:
	print("\n=== Si le cambia el rol, el perfil se rehace ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var estado := _armar_estado(rng)
	var clave := -1
	for id in estado["jugadores"]:
		if str(estado["jugadores"][id]["rol"]) == "DFC":
			clave = int(id)
			break
	var como_dfc: Dictionary = MotorEspacial.perfil_de(estado, clave).duplicate()
	estado["jugadores"][clave]["rol"] = "DC"
	var como_dc: Dictionary = MotorEspacial.perfil_de(estado, clave)
	if float(como_dc["descarga"]) > float(como_dfc["descarga"]) + 0.05:
		_ok("pasado a nueve prefiere la descarga %.2f, contra %.2f de central." % [como_dc["descarga"], como_dfc["descarga"]])
	else:
		_falla("el perfil no se rehizo al cambiarle el rol.")


func _test_el_suplente_entra_con_perfil() -> void:
	print("\n=== El suplente que entra trae su propio perfil ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var estado := _armar_estado(rng)
	var casa: Team = estado["home"]
	# Se simula la entrada como la hace _sincronizar_cambios: el suplente
	# hereda el slot del que sale y llega SIN perfil en su dict.
	var sale := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) and str(e["rol"]) == "MC":
			sale = int(id)
			break
	var suplente: Dictionary = {}
	for j in casa.banco:
		var esta := false
		for id in estado["jugadores"]:
			if int(estado["jugadores"][id]["jugador_id"]) == int(j["id"]):
				esta = true
		if not esta and str(j["posicion"]) != "ARQ":
			suplente = j
			break
	if suplente.is_empty():
		_falla("no habia suplente de campo para probar.")
		return
	var viejo: Dictionary = estado["jugadores"][sale]
	var clave_nueva := MotorEspacial.clave_de(int(suplente["id"]), true)
	estado["jugadores"].erase(sale)
	estado["jugadores"][clave_nueva] = {
		"clave": clave_nueva, "jugador_id": suplente["id"], "equipo_local": true,
		"rol": viejo["rol"], "base": viejo["base"], "pos": viejo["pos"],
		"vel": Vector2.ZERO, "objetivo": viejo["base"], "vel_max": 7.0,
		"aceleracion": 3.0, "rapidez": 0.0,
	}
	var perfil: Dictionary = MotorEspacial.perfil_de(estado, clave_nueva)
	var suma := 0.0
	for r in MotorEspacial.RASGOS_PERFIL:
		suma += float(perfil[r])
	if estado["jugadores"][clave_nueva].has("perfil") and suma > 0.0:
		_ok("el suplente entro y se le armo el perfil (media %.2f)." % (suma / 5.0))
	else:
		_falla("el suplente entro sin perfil.")


# ---------------------------------------------------------------------------
# El ajuste de utilidad
# ---------------------------------------------------------------------------

func _test_el_ajuste_esta_acotado() -> void:
	print("\n=== El ajuste nunca pasa el tope ===")
	var tope: float = float(MotorEspacial.pesos_perfil()["tope"])
	var tipos := ["conducir", "gambeta", "pared", "pase", "pase_hueco", "pase_largo",
		"centro", "tiro", "despeje"]
	var peor := 0.0
	var cuantas := 0
	var perfil := {}
	var receptor := {}
	for g in [0.0, 0.5, 1.0]:
		for r in MotorEspacial.RASGOS_PERFIL:
			perfil[r] = g
			receptor[r] = g
		for tipo in tipos:
			for adelante in [-20.0, 0.0, 8.0, 40.0]:
				for dist in [3.0, 15.0, 45.0]:
					for libertad in [0.0, 0.5, 1.0]:
						for presion in [0.0, 1.0]:
							for camino in [0.0, 1.0]:
								var a: float = MotorEspacial._ajuste_de_perfil(
									perfil, receptor, tipo, adelante, dist, libertad, presion, camino)
								peor = maxf(peor, absf(a))
								cuantas += 1
	if peor <= tope + 0.0001:
		_ok("el peor ajuste de %d combinaciones es %.3f, con tope %.3f." % [cuantas, peor, tope])
	else:
		_falla("el ajuste llego a %.3f y el tope es %.3f." % [peor, tope])


func _test_el_remate_no_se_toca() -> void:
	print("\n=== El perfil no premia el remate ===")
	var perfil := {}
	var peor := 0.0
	for g in [0.0, 0.25, 0.5, 0.75, 1.0]:
		for r in MotorEspacial.RASGOS_PERFIL:
			perfil[r] = g
		for adelante in [-10.0, 0.0, 25.0]:
			for libertad in [0.0, 1.0]:
				peor = maxf(peor, absf(MotorEspacial._ajuste_de_perfil(
					perfil, perfil, "tiro", adelante, 20.0, libertad, 0.3, 0.7)))
	if peor == 0.0:
		_ok("el remate recibe cero en todo el rango, como el marcador.")
	else:
		_falla("el remate recibio %.3f de ajuste de perfil." % peor)


func _test_el_contexto_apaga_la_preferencia() -> void:
	print("\n=== Un mal contexto apaga la preferencia ===")
	var encarador := {}
	for r in MotorEspacial.RASGOS_PERFIL:
		encarador[r] = 0.25
	encarador["regate"] = 1.0
	var con_espacio: float = MotorEspacial._ajuste_de_perfil(
		encarador, {}, "gambeta", 0.0, 0.0, 0.0, 0.05, 1.0)
	var encerrado: float = MotorEspacial._ajuste_de_perfil(
		encarador, {}, "gambeta", 0.0, 0.0, 0.0, 0.95, 1.0)
	if con_espacio > 0.10 and encerrado < con_espacio * 0.25:
		_ok("el encarador cobra %.3f con espacio y %.3f encerrado." % [con_espacio, encerrado])
	else:
		_falla("el contexto no apago la gambeta: %.3f contra %.3f." % [con_espacio, encerrado])

	var asociador := {}
	for r in MotorEspacial.RASGOS_PERFIL:
		asociador[r] = 0.25
	asociador["asociacion"] = 1.0
	var corto_y_libre: float = MotorEspacial._ajuste_de_perfil(
		asociador, {}, "pase", 5.0, 8.0, 1.0, 0.3, 0.5)
	var largo_y_tapado: float = MotorEspacial._ajuste_de_perfil(
		asociador, {}, "pase", 5.0, 40.0, 0.05, 0.3, 0.5)
	if corto_y_libre > 0.10 and largo_y_tapado < corto_y_libre * 0.25:
		_ok("el asociador cobra %.3f por el pase corto y libre y %.3f por el largo y tapado." % [corto_y_libre, largo_y_tapado])
	else:
		_falla("el pase no distinguio el contexto: %.3f contra %.3f." % [corto_y_libre, largo_y_tapado])


func _test_la_descarga_la_pide_el_receptor() -> void:
	print("\n=== La descarga la pide el que recibe, no el que pasa ===")
	var neutro := {}
	for r in MotorEspacial.RASGOS_PERFIL:
		neutro[r] = 0.5
	var nueve := neutro.duplicate()
	nueve["descarga"] = 1.0
	var a_nueve: float = MotorEspacial._ajuste_de_perfil(neutro, nueve, "pase", 12.0, 14.0, 0.15, 0.4, 0.5)
	var a_cualquiera: float = MotorEspacial._ajuste_de_perfil(neutro, neutro, "pase", 12.0, 14.0, 0.15, 0.4, 0.5)
	if a_nueve > a_cualquiera + 0.05:
		_ok("pasarle al nueve de apoyo marcado suma %.3f contra %.3f." % [a_nueve, a_cualquiera])
	else:
		_falla("el perfil del receptor no cambio nada: %.3f contra %.3f." % [a_nueve, a_cualquiera])
	# Y solo si esta adelantado: descargar hacia atras no es descargar.
	var hacia_atras: float = MotorEspacial._ajuste_de_perfil(neutro, nueve, "pase", -8.0, 14.0, 0.15, 0.4, 0.5)
	if hacia_atras < a_nueve:
		_ok("hacia atras no cobra la descarga (%.3f)." % hacia_atras)
	else:
		_falla("la descarga cobro tambien hacia atras.")


# ---------------------------------------------------------------------------
# Frecuencias de eleccion
# ---------------------------------------------------------------------------

## Reparto de decisiones sobre muchas semillas, con el perfil del
## poseedor pisado. Devuelve {tipo: veces} y el total.
func _reparto(rasgo: String, valor: float, escenas: int, rol: String, pelota: Vector2) -> Dictionary:
	var cuenta := {}
	var total := 0
	for i in range(escenas):
		var d := _escena(SEED + i * 17, i % 2 == 0, pelota if i % 2 == 0 else Vector2(-pelota.x, pelota.y), rol)
		var estado: Dictionary = d["estado"]
		var clave: int = d["portador"]
		if clave == -1:
			continue
		_forzar_perfil(estado, clave, rasgo, valor)
		var poseedor: Dictionary = estado["jugadores"][clave]
		var jugador := _dict_de(estado, clave)
		if jugador.is_empty():
			continue
		var opciones := MotorEspacial.evaluar_opciones(estado, poseedor, jugador)
		if opciones.is_empty():
			continue
		var presion := MotorEspacial.presion_normalizada(estado, poseedor["pos"], bool(poseedor["equipo_local"]))
		var temp := MotorEspacial.temperatura(jugador, presion)
		# El azar de la eleccion sale de un RNG propio y con semilla fija:
		# asi la unica diferencia entre las dos corridas es el perfil.
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var elegida := MotorEspacial.elegir_softmax(opciones, temp, rng)
		cuenta[elegida["tipo"]] = int(cuenta.get(elegida["tipo"], 0)) + 1
		total += 1
	return {"cuenta": cuenta, "total": total}


func _test_el_encarador_encara_mas() -> void:
	print("\n=== Subirle el regate al poseedor: encara mas seguido ===")
	var alto := _reparto("regate", 1.0, 120, "EXT", Vector2(18.0, 24.0))
	var bajo := _reparto("regate", 0.0, 120, "EXT", Vector2(18.0, 24.0))
	var con_alto: int = int(alto["cuenta"].get("gambeta", 0)) + int(alto["cuenta"].get("conducir", 0))
	var con_bajo: int = int(bajo["cuenta"].get("gambeta", 0)) + int(bajo["cuenta"].get("conducir", 0))
	if con_alto > con_bajo:
		_ok("gambeta+conduccion: %d de %d con regate alto, %d de %d con regate bajo." % [
			con_alto, alto["total"], con_bajo, bajo["total"]])
	else:
		_falla("el regate no movio la frecuencia: %d contra %d." % [con_alto, con_bajo])


func _test_el_asociador_la_toca_mas() -> void:
	print("\n=== Subirle la asociacion: la toca corto mas seguido ===")
	var alto := _reparto("asociacion", 1.0, 120, "MC", Vector2(5.0, 8.0))
	var bajo := _reparto("asociacion", 0.0, 120, "MC", Vector2(5.0, 8.0))
	var con_alto: int = int(alto["cuenta"].get("pase", 0)) + int(alto["cuenta"].get("pared", 0))
	var con_bajo: int = int(bajo["cuenta"].get("pase", 0)) + int(bajo["cuenta"].get("pared", 0))
	if con_alto > con_bajo:
		_ok("pase+pared: %d de %d con asociacion alta, %d de %d con asociacion baja." % [
			con_alto, alto["total"], con_bajo, bajo["total"]])
	else:
		_falla("la asociacion no movio la frecuencia: %d contra %d." % [con_alto, con_bajo])


func _test_cada_perfil_conserva_variedad() -> void:
	print("\n=== Ningun perfil elige siempre lo mismo ===")
	# La referencia es el perfil del MONTON en la misma escena, no un
	# numero suelto: cuanta variedad hay en un ataque por la banda o en una
	# salida desde el fondo ya lo decide la escena, y lo que se mide aca es
	# si el perfil la achica.
	var problemas := 0
	for caso in [["regate", "EXT", Vector2(18.0, 24.0)], ["asociacion", "MC", Vector2(5.0, 8.0)]]:
		var extremo := _reparto(str(caso[0]), 1.0, 120, str(caso[1]), caso[2] as Vector2)
		var monton := _reparto(str(caso[0]), 0.25, 120, str(caso[1]), caso[2] as Vector2)
		var share_e := _dominante(extremo)
		var share_m := _dominante(monton)
		var tipos: int = extremo["cuenta"].size()
		if tipos >= 3 and share_e <= share_m + 0.15:
			_ok("%s al maximo: %d tipos distintos, el mas elegido %.0f%% contra %.0f%% del monton." % [
				str(caso[0]), tipos, 100.0 * share_e, 100.0 * share_m])
		else:
			problemas += 1
			_falla("%s al maximo colapso a %d tipos, el mas elegido %.0f%% contra %.0f%% del monton." % [
				str(caso[0]), tipos, 100.0 * share_e, 100.0 * share_m])
	if problemas == 0:
		_ok("los dos perfiles extremos conservan la variedad de la escena.")


## Que fraccion se lleva el tipo mas elegido de un reparto.
func _dominante(r: Dictionary) -> float:
	var mayor := 0
	for tipo in r["cuenta"]:
		mayor = maxi(mayor, int(r["cuenta"][tipo]))
	return float(mayor) / float(maxi(int(r["total"]), 1))


func _test_preferir_no_es_saber() -> void:
	print("\n=== Preferir el regate no hace que la gambeta salga ===")
	var ganadas := []
	for valor in [0.0, 1.0]:
		var total_intentos := 0
		var total_ganadas := 0
		for i in range(40):
			var d := _escena(SEED + i * 17, true, Vector2(18.0, 10.0), "EXT")
			var estado: Dictionary = d["estado"]
			var clave: int = d["portador"]
			if clave == -1:
				continue
			_forzar_perfil(estado, clave, "regate", valor)
			var poseedor: Dictionary = estado["jugadores"][clave]
			var jugador := _dict_de(estado, clave)
			# Se le planta un rival adelante: sin alguien a quien encarar
			# la prueba no mide nada, porque la gambeta ni existe.
			for id in estado["jugadores"]:
				var r: Dictionary = estado["jugadores"][id]
				if not bool(r["equipo_local"]) and str(r["rol"]) != "ARQ":
					r["pos"] = poseedor["pos"] + Vector2(4.0, 0.0)
					break
			var rival := MotorEspacial._rival_a_encarar(estado, poseedor["pos"], true)
			if rival == -1 or jugador.is_empty():
				continue
			# El RNG del partido se repone a mano: la unica diferencia
			# entre las dos vueltas tiene que ser el perfil.
			estado["rng"].seed = SEED + i
			MotorEspacial._resolver_gambeta(estado, poseedor, jugador, rival)
			total_intentos += int(estado["gambetas"]["home"]["intentos"])
			total_ganadas += int(estado["gambetas"]["home"]["ganadas"])
		ganadas.append([total_intentos, total_ganadas])
	if ganadas[0] == ganadas[1]:
		_ok("con regate 0 y con regate 1: %d intentos y %d ganadas en los dos." % [ganadas[0][0], ganadas[0][1]])
	else:
		_falla("el perfil cambio el resultado del duelo: %s contra %s." % [str(ganadas[0]), str(ganadas[1])])


# ---------------------------------------------------------------------------
# Movimiento sin pelota
# ---------------------------------------------------------------------------

func _test_el_perfil_inclina_el_desmarque() -> void:
	print("\n=== El perfil inclina el tipo de desmarque ===")
	var w := MotorEspacial.pesos_perfil()
	var perfil := {}
	for r in MotorEspacial.RASGOS_PERFIL:
		perfil[r] = 0.5
	var neutro: float = MotorEspacial._sesgo_perfil_desmarque(perfil, "ruptura")
	perfil["ruptura"] = 1.0
	var rompedor: float = MotorEspacial._sesgo_perfil_desmarque(perfil, "ruptura")
	if absf(neutro) < 0.0001 and absf(rompedor - float(w["desmarque"])) < 0.0001:
		_ok("el del monton suma 0,000 y el rompedor %.3f al valor de su ruptura." % rompedor)
	else:
		_falla("el sesgo de desmarque no dio lo esperado: %.3f y %.3f." % [neutro, rompedor])

	# Y sobre el reparto real: subirle la ruptura a los de arriba tiene
	# que darle mas corridas al equipo, sin romper el cupo de la etapa 1.
	var corridas := []
	for valor in [0.0, 1.0]:
		var cuantas := 0
		for i in range(40):
			var d := _escena(SEED + i * 17, true, Vector2(0.0, 6.0), "MC")
			var estado: Dictionary = d["estado"]
			if int(d["portador"]) == -1:
				continue
			for id in estado["jugadores"]:
				var e: Dictionary = estado["jugadores"][id]
				if bool(e["equipo_local"]) and MotorEspacial.ROLES_QUE_ROMPEN.has(str(e["rol"])):
					_forzar_perfil(estado, int(id), "ruptura", valor)
			MotorEspacial._planificar_desmarques(estado, true)
			for clave in estado.get("desmarques", {}):
				if str(estado["desmarques"][clave]["tipo"]) == "ruptura":
					cuantas += 1
		corridas.append(cuantas)
	if corridas[1] > corridas[0]:
		_ok("en 40 escenas: %d rupturas con la preferencia al maximo contra %d al minimo." % [corridas[1], corridas[0]])
	else:
		_falla("la preferencia no movio el reparto: %d contra %d." % [corridas[1], corridas[0]])


func _test_partidos_completos() -> void:
	print("\n=== Partidos completos: el motor sigue cerrando ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var goles := 0
	var partidos := 8
	for i in range(partidos):
		var casa := Team.generar("Casa %d" % i, rng, 0)
		var visita := Team.generar("Visita %d" % i, rng, 0)
		var r := MotorEspacial.simular(casa, visita, rng, false)
		goles += int(r["goles_local"]) + int(r["goles_visitante"])
	_ok("%d partidos, %.2f goles por partido." % [partidos, float(goles) / float(partidos)])
