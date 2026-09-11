extends SceneTree

## Etapa 7 del plan de realismo: el marcador cambia el COMPORTAMIENTO.
## El que gana sobre la hora baja el bloque, deja menos corridas y
## prefiere el apoyo seguro; el que pierde hace lo contrario. Los duelos
## se resuelven igual: aca no se toca ninguna probabilidad.

const SEED := 7710

var fallos := 0


func _armar_estado(rng: RandomNumberGenerator) -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 0)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	# El rasgo del DT se fija a mano en cada prueba que lo mire; por
	# defecto queda uno que no amplifica nada, para que la urgencia que se
	# mide sea la del marcador y no la del cuerpo tecnico.
	casa.dt = {"nivel": 5, "rasgo": "Cantera"}
	visita.dt = {"nivel": 5, "rasgo": "Cantera"}
	return MotorEspacial.crear_estado(casa, visita, rng)


## Una escena de ataque con la pelota en los pies de un MC.
func _escena(semilla: int, ataca_local: bool, pelota: Vector2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var estado := _armar_estado(rng)
	var portador := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == ataca_local and str(e["rol"]) == "MC":
			portador = int(id)
			break
	estado["jugadores"][portador]["pos"] = pelota
	estado["pelota"]["pos"] = pelota
	estado["pelota"]["poseedor_id"] = portador
	estado["pelota"]["ticks_con_pelota"] = 8
	estado["ultimo_equipo_con_pelota"] = ataca_local
	MotorEspacial._calcular_linea_offside(estado)
	return estado


## Pone el reloj y el marcador, y recalcula la urgencia: la cache es por
## tick y cambiar el minuto adentro del mismo tick no la invalida.
func _situacion(estado: Dictionary, minuto: float, goles_local: int, goles_visita: int,
		periodo: int = 1) -> void:
	estado["minuto"] = minuto
	estado["periodo"] = periodo
	estado["home"].goles = goles_local
	estado["away"].goles = goles_visita
	MotorEspacial._planificar_marcador(estado)


func _init() -> void:
	_test_la_urgencia_crece_con_el_minuto()
	_test_el_signo_sigue_al_marcador()
	_test_el_alargue_no_retrocede()
	_test_el_dt_amplifica_solo_lo_suyo()
	_test_el_bloque_sube_perdiendo_y_baja_ganando()
	_test_el_cupo_de_corridas_sigue_al_marcador()
	_test_perdiendo_se_arriesga_mas()
	_test_ganando_se_prefiere_el_apoyo_seguro()
	_test_el_ajuste_esta_acotado()
	_test_el_remate_no_se_toca()
	_test_ganando_no_sale_el_cierre()
	_test_la_urgencia_no_consume_azar()
	_test_las_opciones_arriesgadas_suben_perdiendo()
	_test_partidos_completos()
	print("\nFALLOS=%d" % fallos)
	quit()


func _falla(texto: String) -> void:
	fallos += 1
	print("FALLA: " + texto)


func _test_la_urgencia_crece_con_el_minuto() -> void:
	print("=== Al principio pesa poco, al final pesa ===")
	var estado := _escena(SEED, true, Vector2(0.0, 0.0))
	var medidas := []
	for minuto in [5.0, 45.0, 75.0, 89.0]:
		_situacion(estado, minuto, 0, 1)
		medidas.append(MotorEspacial.urgencia(estado, true))
	var crece := true
	for i in range(1, medidas.size()):
		if float(medidas[i]) <= float(medidas[i - 1]):
			crece = false
	if not crece:
		_falla("la urgencia no crece con el minuto: %s." % [medidas])
	elif float(medidas[0]) > 0.02:
		_falla("al minuto 5 la urgencia ya vale %.3f." % float(medidas[0]))
	else:
		print("OK: perdiendo 0-1, urgencia %.3f al 5', %.3f al 45', %.3f al 75', %.3f al 89'." % [
				medidas[0], medidas[1], medidas[2], medidas[3]])


func _test_el_signo_sigue_al_marcador() -> void:
	print("=== Ganando negativa, perdiendo positiva, empate chica ===")
	for lado in [true, false]:
		var estado := _escena(SEED, lado, Vector2(0.0, 0.0))
		_situacion(estado, 88.0, 2, 0)
		var ganando := MotorEspacial.urgencia(estado, lado)
		_situacion(estado, 88.0, 0, 2)
		var perdiendo := MotorEspacial.urgencia(estado, lado)
		_situacion(estado, 88.0, 1, 1)
		var empate := MotorEspacial.urgencia(estado, lado)
		if lado:
			pass
		else:
			# Para la visita el 2-0 es el marcador en contra: se invierte.
			var tmp := ganando
			ganando = perdiendo
			perdiendo = tmp
		if ganando >= 0.0 or perdiendo <= 0.0:
			_falla("%s: ganando %.3f y perdiendo %.3f." % [
					"local" if lado else "visita", ganando, perdiendo])
		elif empate <= 0.0 or empate >= perdiendo:
			_falla("%s: el empate dio %.3f, fuera de (0, %.3f)." % [
					"local" if lado else "visita", empate, perdiendo])
		else:
			print("OK: %s — ganando %.3f, empatando %.3f, perdiendo %.3f al 88'." % [
					"local" if lado else "visita", ganando, empate, perdiendo])


func _test_el_alargue_no_retrocede() -> void:
	print("=== El alargue entero vale como final ===")
	var estado := _escena(SEED, true, Vector2(0.0, 0.0))
	_situacion(estado, 90.0, 0, 1, 2)
	var noventa := MotorEspacial.urgencia(estado, true)
	_situacion(estado, 91.0, 0, 1, 3)
	var alargue := MotorEspacial.urgencia(estado, true)
	if alargue < noventa - 0.001:
		_falla("al 91' del alargue la urgencia bajo de %.3f a %.3f." % [noventa, alargue])
	else:
		print("OK: 90' %.3f, 91' del alargue %.3f." % [noventa, alargue])


func _test_el_dt_amplifica_solo_lo_suyo() -> void:
	print("=== Loco cuando pierde, Conservador cuando gana ===")
	var estado := _escena(SEED, true, Vector2(0.0, 0.0))
	var neutro_perdiendo := 0.0
	var neutro_ganando := 0.0
	_situacion(estado, 88.0, 0, 1)
	neutro_perdiendo = MotorEspacial.urgencia(estado, true)
	_situacion(estado, 88.0, 1, 0)
	neutro_ganando = MotorEspacial.urgencia(estado, true)

	estado["home"].dt = {"nivel": 5, "rasgo": "Loco"}
	_situacion(estado, 88.0, 0, 1)
	var loco_perdiendo := MotorEspacial.urgencia(estado, true)
	_situacion(estado, 88.0, 1, 0)
	var loco_ganando := MotorEspacial.urgencia(estado, true)

	estado["home"].dt = {"nivel": 5, "rasgo": "Conservador"}
	_situacion(estado, 88.0, 0, 1)
	var cons_perdiendo := MotorEspacial.urgencia(estado, true)
	_situacion(estado, 88.0, 1, 0)
	var cons_ganando := MotorEspacial.urgencia(estado, true)

	if loco_perdiendo <= neutro_perdiendo or not is_equal_approx(loco_ganando, neutro_ganando):
		_falla("el Loco dio %.3f perdiendo (neutro %.3f) y %.3f ganando (neutro %.3f)." % [
				loco_perdiendo, neutro_perdiendo, loco_ganando, neutro_ganando])
	elif cons_ganando >= neutro_ganando or not is_equal_approx(cons_perdiendo, neutro_perdiendo):
		_falla("el Conservador dio %.3f ganando (neutro %.3f) y %.3f perdiendo (neutro %.3f)." % [
				cons_ganando, neutro_ganando, cons_perdiendo, neutro_perdiendo])
	else:
		print("OK: perdiendo %.3f neutro contra %.3f el Loco; ganando %.3f contra %.3f el Conservador." % [
				neutro_perdiendo, loco_perdiendo, neutro_ganando, cons_ganando])


## Donde para su linea el equipo que defiende, midiendo el X medio de los
## que no tienen la pelota, en metros hacia el arco rival.
func _altura_del_bloque(estado: Dictionary, defiende_local: bool) -> float:
	var equipo: Team = estado["home"] if defiende_local else estado["away"]
	var suma := 0.0
	var cuantos := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) != defiende_local or str(e["rol"]) == "ARQ":
			continue
		var punto: Vector2 = MotorEspacial._ancla_de_rol(estado, e, equipo, false)["punto"]
		suma += punto.x * (1.0 if defiende_local else -1.0)
		cuantos += 1
	return suma / float(maxi(cuantos, 1))


func _test_el_bloque_sube_perdiendo_y_baja_ganando() -> void:
	print("=== La misma escena, temprano y tarde, ganando y perdiendo ===")
	for lado in [true, false]:
		# Ataca el rival: el equipo que miramos defiende.
		var estado := _escena(SEED, not lado, Vector2(0.0, 6.0))
		_situacion(estado, 10.0, 0, 0)
		var temprano := _altura_del_bloque(estado, lado)
		_situacion(estado, 88.0, 2 if lado else 0, 0 if lado else 2)
		var ganando := _altura_del_bloque(estado, lado)
		_situacion(estado, 88.0, 0 if lado else 2, 2 if lado else 0)
		var perdiendo := _altura_del_bloque(estado, lado)
		if not (perdiendo > temprano and temprano > ganando):
			_falla("%s: temprano %.1f, ganando %.1f, perdiendo %.1f." % [
					"local" if lado else "visita", temprano, ganando, perdiendo])
		elif perdiendo - ganando > 2.0 * float(MotorEspacial.pesos_marcador()["altura_bloque"]) + 0.5:
			_falla("%s: entre ganar y perder hay %.1f m, mas que el tope." % [
					"local" if lado else "visita", perdiendo - ganando])
		else:
			print("OK: %s defiende a %.1f m temprano, %.1f m ganando y %.1f m perdiendo." % [
					"local" if lado else "visita", temprano, ganando, perdiendo])


func _test_el_cupo_de_corridas_sigue_al_marcador() -> void:
	print("=== Cupo de corridas simultaneas ===")
	var estado := _escena(SEED, true, Vector2(10.0, 0.0))
	_situacion(estado, 10.0, 0, 0)
	var temprano := MotorEspacial._cupo_de_rupturas(estado, true)
	_situacion(estado, 89.0, 2, 0)
	var ganando := MotorEspacial._cupo_de_rupturas(estado, true)
	_situacion(estado, 89.0, 0, 2)
	var perdiendo := MotorEspacial._cupo_de_rupturas(estado, true)
	if temprano != MotorEspacial.MAX_RUPTURAS:
		_falla("temprano el cupo fue %d y no %d." % [temprano, MotorEspacial.MAX_RUPTURAS])
	elif ganando >= temprano or perdiendo <= temprano or ganando < 1:
		_falla("cupos: temprano %d, ganando %d, perdiendo %d." % [temprano, ganando, perdiendo])
	else:
		print("OK: cupo %d temprano, %d ganando sobre la hora, %d perdiendo." % [
				temprano, ganando, perdiendo])


## Utilidad ya ponderada de la primera opcion de este tipo, o null.
func _utilidad_de(estado: Dictionary, tipo: String):
	var poseedor: Dictionary = estado["jugadores"][int(estado["pelota"]["poseedor_id"])]
	var equipo: Team = estado["home"] if bool(poseedor["equipo_local"]) else estado["away"]
	var jugador := MotorEspacial._dict_jugador(estado, equipo, int(poseedor["jugador_id"]))
	var mejor = null
	for o in MotorEspacial.evaluar_opciones(estado, poseedor, jugador):
		if str(o["tipo"]) == tipo:
			if mejor == null or float(o["utilidad"]) > float(mejor):
				mejor = float(o["utilidad"])
	return mejor


func _test_perdiendo_se_arriesga_mas() -> void:
	print("=== Perdiendo sobre la hora: la opcion que gana metros vale mas ===")
	var w := MotorEspacial.pesos_marcador()
	var hueco_perdiendo := MotorEspacial._ajuste_de_marcador(0.9, "pase_hueco", 15.0, 20.0, 0.8)
	var atras_perdiendo := MotorEspacial._ajuste_de_marcador(0.9, "pase", -10.0, 12.0, 0.9)
	var hueco_tranquilo := MotorEspacial._ajuste_de_marcador(0.0, "pase_hueco", 15.0, 20.0, 0.8)
	if hueco_perdiendo <= hueco_tranquilo or atras_perdiendo >= 0.0:
		_falla("hueco %.3f (tranquilo %.3f) y pase atras %.3f." % [
				hueco_perdiendo, hueco_tranquilo, atras_perdiendo])
	else:
		print("OK: con urgencia 0.9 el hueco suma %+.3f y el pase atras %+.3f." % [
				hueco_perdiendo, atras_perdiendo])
	# Y en una escena real la utilidad se mueve en la misma direccion.
	var estado := _escena(SEED, true, Vector2(6.0, 3.0))
	_situacion(estado, 10.0, 0, 0)
	var antes = _utilidad_de(estado, "pase_hueco")
	_situacion(estado, 89.0, 0, 2)
	var despues = _utilidad_de(estado, "pase_hueco")
	if antes == null or despues == null:
		print("OK: la escena no ofrecio pase al hueco; alcanza con el ajuste medido arriba.")
	elif float(despues) <= float(antes):
		_falla("en la escena el hueco paso de %.3f a %.3f perdiendo 0-2 al 89'." % [antes, despues])
	else:
		print("OK: en la escena el pase al hueco sube de %.3f a %.3f perdiendo 0-2 al 89'." % [
				antes, despues])
	if absf(hueco_perdiendo) > float(w["tope"]) + 0.001:
		_falla("el ajuste paso el tope.")


func _test_ganando_se_prefiere_el_apoyo_seguro() -> void:
	print("=== Ganando sobre la hora: apoyo seguro arriba, riesgo abajo ===")
	var apoyo := MotorEspacial._ajuste_de_marcador(-0.9, "pase", 4.0, 14.0, 0.9)
	var largo := MotorEspacial._ajuste_de_marcador(-0.9, "pase_largo", 20.0, 38.0, 0.6)
	var hueco := MotorEspacial._ajuste_de_marcador(-0.9, "pase_hueco", 15.0, 20.0, 0.8)
	var atras := MotorEspacial._ajuste_de_marcador(-0.9, "pase", -10.0, 12.0, 0.9)
	if apoyo <= 0.0 or atras <= 0.0 or largo >= 0.0 or hueco >= 0.0:
		_falla("apoyo %.3f, atras %.3f, largo %.3f, hueco %.3f." % [apoyo, atras, largo, hueco])
	else:
		print("OK: con urgencia -0.9 el apoyo corto suma %+.3f y el pase atras %+.3f; el largo %+.3f y el hueco %+.3f." % [
				apoyo, atras, largo, hueco])


func _test_el_ajuste_esta_acotado() -> void:
	print("=== El ajuste nunca pasa el tope ===")
	var tope: float = float(MotorEspacial.pesos_marcador()["tope"])
	var peor := 0.0
	var combinaciones := 0
	for urg in [-1.0, -0.7, -0.3, 0.0, 0.3, 0.7, 1.0]:
		for tipo in ["pase", "pase_largo", "pase_hueco", "gambeta", "centro", "conducir", "tiro"]:
			for adelante in [-20.0, -3.0, 0.0, 8.0, 30.0]:
				for dist in [4.0, 18.0, 40.0]:
					for libertad in [0.0, 0.5, 1.0]:
						var a: float = MotorEspacial._ajuste_de_marcador(urg, tipo, adelante, dist, libertad)
						peor = maxf(peor, absf(a))
						combinaciones += 1
	if peor > tope + 0.001:
		_falla("el peor ajuste fue %.3f con tope %.3f." % [peor, tope])
	else:
		print("OK: el peor ajuste de %d combinaciones es %.3f, con tope %.3f." % [
				combinaciones, peor, tope])


func _test_el_remate_no_se_toca() -> void:
	print("=== El marcador no premia el remate ===")
	var peor := 0.0
	for urg in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for dist in [8.0, 20.0, 32.0]:
			peor = maxf(peor, absf(MotorEspacial._ajuste_de_marcador(urg, "tiro", 10.0, dist, 0.5)))
			peor = maxf(peor, absf(MotorEspacial._ajuste_de_marcador(urg, "conducir", 10.0, dist, 0.5)))
	if peor > 0.0:
		_falla("el remate o la conduccion recibieron %.3f de ajuste." % peor)
	else:
		print("OK: el remate no recibe ajuste de marcador en ningun estado del partido.")


func _test_ganando_no_sale_el_cierre() -> void:
	print("=== Ganando sobre la hora no sale un tercero a cerrar ===")
	for lado in [true, false]:
		# Ataca `lado`; defiende el otro, con Presion alta para que el
		# cierre salga siempre que se le permita.
		var estado := _escena(SEED, lado, Vector2(0.0, 4.0))
		var defiende_local: bool = not lado
		var equipo_def: Team = estado["home"] if defiende_local else estado["away"]
		equipo_def.estilo = "Presión alta"
		_situacion(estado, 10.0, 0, 0)
		var plan_temprano := MotorEspacial._planificar_defensa(estado, lado)
		var cierre_temprano: int = int(plan_temprano.get("cierre", -1))
		estado["defensa"] = {}
		_situacion(estado, 89.0, 0 if defiende_local else 2, 2 if defiende_local else 0)
		# El que defiende va perdiendo 0-2: tiene que seguir cerrando.
		var plan_perdiendo := MotorEspacial._planificar_defensa(estado, lado)
		var cierre_perdiendo: int = int(plan_perdiendo.get("cierre", -1))
		estado["defensa"] = {}
		_situacion(estado, 89.0, 2 if defiende_local else 0, 0 if defiende_local else 2)
		var plan_ganando := MotorEspacial._planificar_defensa(estado, lado)
		var cierre_ganando: int = int(plan_ganando.get("cierre", -1))
		if cierre_ganando != -1:
			_falla("%s ganando 2-0 al 89' mando un tercero a cerrar." % [
					"el local" if defiende_local else "la visita"])
		elif cierre_temprano == -1 or cierre_perdiendo == -1:
			_falla("%s no cerro ni temprano (%d) ni perdiendo (%d)." % [
					"el local" if defiende_local else "la visita", cierre_temprano, cierre_perdiendo])
		else:
			print("OK: %s cierra temprano y perdiendo, y con el partido ganado no." % [
					"el local" if defiende_local else "la visita"])


func _test_la_urgencia_no_consume_azar() -> void:
	print("=== La urgencia no toca el RNG ni cambia entre corridas ===")
	var estado := _escena(SEED, true, Vector2(4.0, 2.0))
	_situacion(estado, 80.0, 1, 2)
	var rng: RandomNumberGenerator = estado["rng"]
	var antes: int = rng.state
	var u1 := MotorEspacial.urgencia(estado, true)
	MotorEspacial._planificar_marcador(estado)
	var u2 := MotorEspacial.urgencia(estado, true)
	if rng.state != antes:
		_falla("calcular la urgencia movio el estado del RNG.")
	elif not is_equal_approx(u1, u2):
		_falla("la misma situacion dio %.4f y despues %.4f." % [u1, u2])
	else:
		print("OK: la misma situacion da %.4f dos veces y el RNG no se mueve." % u1)


## Que tipos cuentan como "arriesgar": las que buscan romper la linea o
## terminar la jugada. El remate queda afuera porque el marcador no lo
## toca (ver _ajuste_de_marcador).
const OPCIONES_ARRIESGADAS := ["pase_hueco", "pase_largo", "gambeta", "centro"]


func _test_las_opciones_arriesgadas_suben_perdiendo() -> void:
	print("=== La misma escena al 89', ganando y perdiendo ===")
	# Se mide la VENTAJA de arriesgar: la mejor opcion arriesgada menos la
	# mejor segura, en la misma escena. Contar cual gana no sirve — en la
	# mayoria de las escenas manda la conduccion o el apoyo corto y el
	# ganador no cambia aunque la balanza se mueva entera.
	var escenas := 40
	var suma_ganando := 0.0
	var suma_perdiendo := 0.0
	var medidas := 0
	for i in range(escenas):
		var pelota := Vector2(-8.0 + float(i % 8) * 4.0, -12.0 + float(i % 5) * 6.0)
		var estado := _escena(SEED + i * 7, true, pelota)
		_situacion(estado, 89.0, 2, 0)
		var ganando = _ventaja_de_arriesgar(estado)
		_situacion(estado, 89.0, 0, 2)
		var perdiendo = _ventaja_de_arriesgar(estado)
		if ganando == null or perdiendo == null:
			continue
		medidas += 1
		suma_ganando += float(ganando)
		suma_perdiendo += float(perdiendo)
	if medidas == 0:
		_falla("ninguna escena ofrecio las dos familias de opciones.")
	elif suma_perdiendo <= suma_ganando:
		_falla("la ventaja de arriesgar dio %.3f ganando y %.3f perdiendo." % [
				suma_ganando / float(medidas), suma_perdiendo / float(medidas)])
	else:
		print("OK: en %d escenas arriesgar vale %+.3f ganando 2-0 y %+.3f perdiendo 0-2 (%.3f de diferencia)." % [
				medidas, suma_ganando / float(medidas), suma_perdiendo / float(medidas),
				(suma_perdiendo - suma_ganando) / float(medidas)])


## Mejor utilidad arriesgada menos mejor utilidad segura, o null si la
## escena no ofrece las dos familias.
func _ventaja_de_arriesgar(estado: Dictionary):
	var poseedor: Dictionary = estado["jugadores"][int(estado["pelota"]["poseedor_id"])]
	var equipo: Team = estado["home"] if bool(poseedor["equipo_local"]) else estado["away"]
	var jugador := MotorEspacial._dict_jugador(estado, equipo, int(poseedor["jugador_id"]))
	var arriesgada := -INF
	var segura := -INF
	for o in MotorEspacial.evaluar_opciones(estado, poseedor, jugador):
		var u: float = float(o["utilidad"])
		if OPCIONES_ARRIESGADAS.has(str(o["tipo"])):
			arriesgada = maxf(arriesgada, u)
		elif str(o["tipo"]) == "pase" or str(o["tipo"]) == "conducir":
			segura = maxf(segura, u)
	if arriesgada == -INF or segura == -INF:
		return null
	return arriesgada - segura


func _test_partidos_completos() -> void:
	print("=== Partidos completos: el motor sigue cerrando ===")
	var partidos := 8
	var goles := 0
	var urgencias := []
	for i in range(partidos):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i * 13
		var casa := Team.generar("Casa %d" % i, rng, 0)
		var visita := Team.generar("Visita %d" % i, rng, 0)
		var res := MotorEspacial.simular(casa, visita, rng)
		goles += int(res["goles_local"]) + int(res["goles_visitante"])
		urgencias.append(absi(int(res["goles_local"]) - int(res["goles_visitante"])))
	print("OK: %d partidos, %.2f goles por partido, %.2f de diferencia media." % [
			partidos, float(goles) / float(partidos),
			_media(urgencias)])


func _media(valores: Array) -> float:
	if valores.is_empty():
		return 0.0
	var suma := 0.0
	for v in valores:
		suma += float(v)
	return suma / float(valores.size())
