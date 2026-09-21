class_name AgentesLibres
extends RefCounted

## Agentes libres (§9.3 extendido, plantel de 25 §14): pool de jugadores sin
## club, fichables SIN fee de transferencia (solo el sueldo negociado). Se
## alimenta de vencimientos de contrato de los clubes de la IA (Liga._avanzar_contratos)
## — al jugador humano no se le vencen contratos solo todavía (misma
## simplificación documentada que ya existía: sin una pantalla de "renovar
## contrato", forzar la salida de un titular sin que el jugador lo decida
## sería quitarle el control de su propio plantel). El pool es UNO SOLO
## para toda la piramide (Piramide.agentes_libres): el que queda sin club
## lo ve cualquier club de cualquier division.

const CONTRATO_LIBRE_ANIOS := 2

## A que edad se cuelga los botines el que esta sin club.
##
## El pool se vacia por donde se vacia en la realidad: los que nadie ficha
## envejecen temporada a temporada (Progresion.aplicar_temporada, que a
## esta edad ya es puro declive) y en algun momento se retiran. Desde
## EDAD_RETIRO_MINIMA la chance crece cada año y a EDAD_RETIRO_SEGURO se
## retiran todos.
##
## Sin esto la lista solo crece: entran los vencimientos de las diez
## divisiones y la partida guardada se llena de jugadores que nadie va a
## mirar. Los del pool son ademas los primeros candidatos a colgarlas —
## un veterano al que ningun club de la piramide le ofrecio contrato en
## toda una temporada no tiene mucho mas que esperar.
const EDAD_RETIRO_MINIMA := 33
const EDAD_RETIRO_SEGURO := 38

## Cuantas temporadas seguidas aguanta sin conseguir club antes de dejar
## el futbol, tenga la edad que tenga.
##
## La edad sola no alcanza para vaciar el pool. Medido con
## tests/_diag_pool_libres.gd, 16 temporadas de la piramide entera: la IA
## ficha mucho (450 de los 670 que quedan libres cada temporada), pero el
## resto —puesto que nadie necesitaba, sueldo que nadie podia pagar— se
## acumula, y con una edad media de 24 no lo limpia ningun retiro. Sin
## este corte el pool crece sin freno; con el se estaciona alrededor de
## 460, que es como el 10% de los jugadores que ya viajan en la partida
## guardada. El que no consiguio club en tres temporadas no lo iba a
## conseguir en la cuarta.
const TEMPORADAS_SIN_CLUB := 3

## Con cuantos años firma el juvenil que sube a tapar un puesto. El mismo
## contrato que cualquier promocion de cantera (ver Team.promover_juvenil):
## subir por un vencimiento ajeno no es un debut distinto de los otros.
const ANIOS_CANTERANO := 3


## Saca a "jugador" del plantel de equipo (venció contrato, no se lo
## renovó) y lo manda al pool. El puesto que deja vacante lo tapa alguien
## en el acto — ningún club puede quedar con un agujero en la formación de
## un día para el otro; la profundidad real que gana el juego es que ese
## jugador liberado ahora se puede fichar gratis desde el pool.
##
## Quién tapa el puesto lo decide `desde_cantera`: ver _reemplazo_para.
## Devuelve {jugador, de_cantera} con el que entró, o {} si el que se iba
## no estaba en el plantel.
static func liberar(equipo: Team, jugador: Dictionary, pool: Array,
		rng: RandomNumberGenerator, desde_cantera: bool = false) -> Dictionary:
	var id: int = jugador["id"]
	# Una RESERVA se va sin dejar hueco: no ocupaba ni slot del once ni
	# lugar del banco, asi que no hay nada que tapar.
	for i in range(equipo.reservas.size()):
		if equipo.reservas[i]["id"] == id:
			equipo.reservas.remove_at(i)
			equipo._limpiar_registro(id)
			jugador["club_libero"] = equipo.nombre
			pool.append(jugador)
			return {"jugador": {}, "de_cantera": false, "hueco": false, "sube": {}}

	var idx := -1
	var en_banco := false
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["id"] == id:
			idx = i
			break
	if idx == -1:
		en_banco = true
		for i in range(equipo.banco.size()):
			if equipo.banco[i]["id"] == id:
				idx = i
				break
	if idx == -1:
		return {}

	# El pool va ANTES de que se agregue el saliente (el append esta mas
	# abajo): un club no se puede tapar el hueco con el que acaba de dejar
	# ir, que es la misma regla que `veta_a` pero un renglon antes.
	var relevo := _reemplazo_para(equipo, jugador["posicion"], rng, desde_cantera, pool)
	if relevo.is_empty():
		relevo = _dejar_hueco(equipo, idx, en_banco, jugador["posicion"])
	else:
		var reemplazo: Dictionary = relevo["jugador"]
		if en_banco:
			equipo.banco[idx] = reemplazo
		else:
			equipo.jugadores[idx] = reemplazo
	equipo.recalcular_capitan()

	equipo._limpiar_registro(id)
	# Quien lo dejo ir. Ese club no lo puede volver a fichar libre (ver
	# `veta_a`): dejarlo ir y recuperarlo dos dias despues, gratis y sin
	# el sueldo viejo, convertia la decision de no renovar en un truco
	# para bajarle el sueldo a un titular.
	jugador["club_libero"] = equipo.nombre
	pool.append(jugador)
	return relevo


## ¿Este club tiene vedado fichar a este libre? Lo tiene el que lo dejo
## ir, y solo hasta que otro club lo fiche: ahi el que lo largo deja de
## ser su ultimo club (ver `fichar`).
static func veta_a(equipo: Team, agente: Dictionary) -> bool:
	return str(agente.get("club_libero", "")) == equipo.nombre


## Le pasa una temporada por encima a todo el pool: envejecen, declinan y
## los que ya estan para colgarlas se van. Devuelve los retirados.
##
## La llama Piramide.fin_de_temporada, antes de que lleguen los
## vencimientos nuevos: los que quedan libres en este cierre ya
## envejecieron con su club (Liga.procesar_economia_y_mercado_y_progresion)
## y no les toca dos veces.
static func envejecer_pool(pool: Array, rng: RandomNumberGenerator) -> Array:
	var retirados := []
	for i in range(pool.size() - 1, -1, -1):
		var jugador: Dictionary = pool[i]
		# Sin club no hay entrenador, ni mentor, ni foco: envejece pelado.
		Progresion.aplicar_temporada(jugador, rng)
		var temporadas: int = int(jugador.get("temporadas_libre", 0)) + 1
		jugador["temporadas_libre"] = temporadas
		if _se_retira(int(jugador["edad"]), rng) or temporadas >= TEMPORADAS_SIN_CLUB:
			pool.remove_at(i)
			retirados.append(jugador)
	retirados.reverse()
	return retirados


## De EDAD_RETIRO_MINIMA a EDAD_RETIRO_SEGURO la chance sube parejo: a los
## 33 se retira uno de cada seis y a los 37, cinco de cada seis.
static func _se_retira(edad: int, rng: RandomNumberGenerator) -> bool:
	if edad >= EDAD_RETIRO_SEGURO:
		return true
	if edad < EDAD_RETIRO_MINIMA:
		return false
	var tramo := float(EDAD_RETIRO_SEGURO - EDAD_RETIRO_MINIMA + 1)
	return rng.randf() < float(edad - EDAD_RETIRO_MINIMA + 1) / tramo


## Con quien se tapa el puesto que dejo el que se fue.
##
## `desde_cantera` tira PRIMERO de los juveniles propios. Es para eso que
## la cantera genera juveniles todos los años, y lo usa solo el club del
## jugador humano: la IA no tiene quien le mire la cantera.
##
## Antes se generaba siempre un jugador nuevo del nivel del club, y ese
## fichaje cobraba sueldo de mercado contra el presupuesto de Contratos.
## Medido en una partida de division 10: se vencieron siete contratos y
## los siete reemplazos costaron $13.580 contra los $6.714 que cobraban
## los que se iban. Son $6.866 de un presupuesto de $8.025 —el 86%—
## gastados en jugadores que el club no eligio.
##
## Se busca primero un juvenil del mismo puesto y despues el mejor que
## haya: a un canterano fuera de puesto lo reacomoda Alineacion.arreglar,
## a un fichaje que nadie pidio no lo arregla nadie.
##
## Con la cantera vacia devuelve {} y NO inventa un jugador: en la vida
## real a un club no le aparece un futbolista de la nada porque se le
## venza un contrato. El puesto queda sin cubrir y lo resuelve el jugador
## como quiera —comprando, fichando un libre o subiendo un juvenil—, que
## es exactamente la decision que el fichaje automatico le sacaba. Quien
## se hace cargo del hueco es _dejar_hueco.
##
## La IA nunca deja el puesto vacio (desde_cantera == false): nadie le
## mira el plantel a los 200 clubes de la piramide, y un club de la IA con
## el once incompleto no lo arregla nunca mas. Pero antes de inventar un
## jugador sale a buscarlo al pool (ver `fichar_ia`): un club que necesita
## un DC y tiene un DC sin club a mano lo ficha, que es lo que haria
## cualquiera. Recien si el pool no tiene a nadie de ese puesto que pueda
## pagar, aparece uno nuevo.
static func _reemplazo_para(equipo: Team, posicion: String,
		rng: RandomNumberGenerator, desde_cantera: bool,
		pool: Array = []) -> Dictionary:
	# Antes que nada, las RESERVAS: ya son del club y ya cobran. Buscar
	# afuera —o hacer debutar a un juvenil— teniendo un suplente guardado
	# adentro seria pagar dos veces por el mismo puesto.
	var idx_reserva := equipo._mejor_reserva_para(posicion)
	if idx_reserva >= 0:
		var reserva: Dictionary = equipo.reservas[idx_reserva]
		equipo.reservas.remove_at(idx_reserva)
		return {"jugador": reserva, "de_cantera": false, "de_reservas": true}

	if desde_cantera:
		var mejor := -1
		for i in range(equipo.cantera.size()):
			if mejor == -1:
				mejor = i
				continue
			var en_puesto: bool = equipo.cantera[i]["posicion"] == posicion
			var mejor_en_puesto: bool = equipo.cantera[mejor]["posicion"] == posicion
			if en_puesto != mejor_en_puesto:
				if en_puesto:
					mejor = i
			elif equipo.cantera[i]["media"] > equipo.cantera[mejor]["media"]:
				mejor = i
		if mejor != -1:
			var juvenil: Dictionary = equipo.cantera[mejor]
			juvenil["es_canterano"] = true
			equipo.cantera.remove_at(mejor)
			equipo._registrar_fichaje(
				juvenil, ValorJugador.calcular(juvenil, 50.0, ANIOS_CANTERANO),
				ANIOS_CANTERANO)
			return {"jugador": juvenil, "de_cantera": true}

	if desde_cantera:
		return {}

	var del_pool := fichar_ia(equipo, pool, posicion)
	if not del_pool.is_empty():
		return {"jugador": del_pool, "de_cantera": false, "del_pool": true}

	# Del nivel del club: un club de decima no genera un refuerzo de
	# primera (ver Team.nivel_potencial).
	var nuevo := PlayerGenerator.generate(
		equipo.siguiente_id_cantera, rng, posicion, equipo.nivel_potencial())
	equipo.siguiente_id_cantera += 1
	equipo._registrar_fichaje(
		nuevo, ValorJugador.calcular(nuevo, 50.0, CONTRATO_LIBRE_ANIOS),
		CONTRATO_LIBRE_ANIOS)
	return {"jugador": nuevo, "de_cantera": false}


## Lo que cobra un agente libre de tabla, por ese contrato.
##
## Va con division -1 a proposito: SIN amortiguar contra la categoria del
## club que lo mira (ver ValorJugador.media_salarial). Un crack sin club
## pide lo que vale juegue donde juegue, y por eso los clubes chicos no se
## lo pueden llevar. Es el mismo numero del que parte la negociacion del
## jugador humano (Renovaciones.sueldo_pretendido, que para alguien de
## afuera del plantel tambien usa -1): la IA paga la tabla y no negocia.
static func sueldo_libre(agente: Dictionary, anios: int) -> float:
	return Economia.sueldo_de_ficha(agente, anios, -1)


## Un club de la IA busca en el pool un jugador de `posicion` y lo ficha.
## Devuelve el jugador que se lleva, o {} si no habia ninguno que le
## sirviera. NO lo mete en ninguna lista: de eso se encarga quien llama
## (_reemplazo_para, que lo pone en el puesto vacante).
##
## Se lleva al de mejor media de ese puesto que pueda pagar. El filtro
## real es el sueldo: la caja de Contratos del club es lo unico que separa
## a un club de decima de un crack libre.
static func fichar_ia(equipo: Team, pool: Array, posicion: String) -> Dictionary:
	var mejor := -1
	var mejor_sueldo := 0.0
	for i in range(pool.size()):
		var agente: Dictionary = pool[i]
		if str(agente["posicion"]) != posicion:
			continue
		if veta_a(equipo, agente):
			continue
		var sueldo := sueldo_libre(agente, CONTRATO_LIBRE_ANIOS)
		if not Economia.puede_pagar_contrato(equipo, sueldo):
			continue
		if mejor != -1 and float(agente["media"]) <= float(pool[mejor]["media"]):
			continue
		mejor = i
		mejor_sueldo = sueldo

	if mejor == -1:
		return {}

	var elegido: Dictionary = pool[mejor]
	pool.remove_at(mejor)
	elegido.erase("club_libero")
	elegido.erase("temporadas_libre")
	_incorporar(equipo, elegido, CONTRATO_LIBRE_ANIOS, mejor_sueldo)
	return elegido


## Da de alta al libre en el club con el sueldo ACORDADO y no con el de
## tabla. _registrar_fichaje escribe el de tabla y ya lo cobro de
## Contratos, asi que aca se devuelve ese y se cobra el otro. Lo comparten
## el fichaje del jugador humano (negociado) y el de la IA (de tabla).
static func _incorporar(equipo: Team, agente: Dictionary, anios: int,
		sueldo: float) -> void:
	var id: int = agente["id"]
	equipo._registrar_fichaje(
		agente, ValorJugador.calcular(agente, 50.0, anios), anios)
	if equipo.caja.has("contratos"):
		equipo.caja["contratos"] += float(equipo.sueldos.get(id, 0.0)) - sueldo
	equipo.sueldos[id] = sueldo
	equipo.renovaciones.erase(id)


## Fichaje de un agente libre: sin fee de transferencia, el club solo
## empieza a pagarle el sueldo que ACORDARON en la negociacion (ver
## core/renovaciones.gd — un agente libre negocia igual que uno propio,
## solo que no cobra nada hoy y su sueldo no se amortigua contra tu
## division).
##
## No desplaza a nadie. Antes el fichaje era un trueque: entraba el libre,
## salia un jugador tuyo al pool y el plantel quedaba siempre en 18. Eso
## no es fichar un libre, es cambiar figuritas — y encima regalaba al que
## salia. Ahora el que llega ocupa un lugar VACANTE del plantel, asi que
## solo se puede fichar si te sobra lugar: se ficha para tapar un
## vencimiento, una venta o un prestamo.
##
## Entra al banco y no al once. El once reparte por SLOT (el slot `i` de
## la formacion lo ocupa jugadores[i], ver MotorEspacial) y el banco es
## una lista sin slots, asi que agregar ahi no le cambia el puesto a
## nadie. Si el once esta incompleto, quien sube al que llega es
## Alineacion.arreglar, igual que con cualquier otro suplente.
static func fichar(equipo: Team, pool: Array, jugador_id: int, anios: int,
		sueldo: float) -> Dictionary:
	var idx_pool := -1
	for i in range(pool.size()):
		if pool[i]["id"] == jugador_id:
			idx_pool = i
			break
	if idx_pool < 0:
		return {"exito": false, "motivo": "Ese agente libre ya no está disponible."}

	if veta_a(equipo, pool[idx_pool]):
		return {"exito": false,
			"motivo": "Lo dejaste ir vos al no renovarle: no podés volver a ficharlo libre. Otro club sí."}

	if equipo.todos_los_jugadores().size() >= Team.PLANTEL_MAXIMO:
		return {"exito": false,
			"motivo": "Tenés el plantel completo (%d). Para fichar un libre te tiene que quedar un lugar: vendé o cedé a alguien primero." % Team.PLANTEL_MAXIMO}

	var agente: Dictionary = pool[idx_pool]
	var anios_reales: int = clampi(anios, Renovaciones.ANIOS_MIN, Renovaciones.ANIOS_MAX)

	# El precio lo pone la negociacion, no una tabla: el mismo ida y
	# vuelta que una renovacion. Se vuelve a preguntar aca —y no se
	# confia en lo que la UI haya mostrado— porque entre la respuesta y
	# el click puede haber pasado una fecha entera.
	var veredicto := Renovaciones.ofrecer(equipo, agente, anios_reales, sueldo)
	if str(veredicto["respuesta"]) != "acepta":
		return {"exito": false, "motivo": "No acepta ese contrato.",
			"veredicto": veredicto}

	if not Economia.puede_pagar_contrato(equipo, sueldo):
		return Economia.motivo_contrato_corto(equipo, sueldo)

	pool.remove_at(idx_pool)
	# Ya tiene club nuevo: el veto del que lo largo y el reloj de las
	# temporadas sin club se terminan aca.
	agente.erase("club_libero")
	agente.erase("temporadas_libre")
	equipo.banco.append(agente)

	_incorporar(equipo, agente, anios_reales, sueldo)
	equipo.recalcular_capitan()

	return {"exito": true, "entra": agente, "anios": anios_reales, "sueldo": sueldo}


## Que hace el plantel con un puesto que no tapo nadie.
##
## El hueco NO se deja en el once. El motor reparte por SLOT —el slot `i`
## de la formacion lo ocupa jugadores[i], ver MotorEspacial— asi que sacar
## al del medio le correria el puesto a todos los que siguen y el equipo
## saldria parado en una formacion que nadie eligio. Entonces:
##
##   - Si el que se fue estaba en el banco, el banco se achica y listo: es
##     una lista sin slots.
##   - Si era titular, lo tapa alguien del banco (del mismo puesto si hay)
##     y el hueco baja al banco.
##   - Solo con el banco tambien vacio se achica el once, y ahi el ULTIMO
##     titular tapa el slot vacante para que el array se recorte por el
##     final y nadie mas cambie de puesto.
static func _dejar_hueco(equipo: Team, idx: int, en_banco: bool,
		posicion: String) -> Dictionary:
	if en_banco:
		equipo.banco.remove_at(idx)
		return {"jugador": {}, "de_cantera": false, "hueco": true, "sube": {}}

	var mejor := -1
	for i in range(equipo.banco.size()):
		var en_puesto: bool = str(equipo.banco[i]["posicion"]) == posicion
		if mejor == -1:
			mejor = i
			continue
		var mejor_en_puesto: bool = str(equipo.banco[mejor]["posicion"]) == posicion
		if en_puesto != mejor_en_puesto:
			if en_puesto:
				mejor = i
		elif float(equipo.banco[i]["media"]) > float(equipo.banco[mejor]["media"]):
			mejor = i

	if mejor != -1:
		var sube: Dictionary = equipo.banco[mejor]
		equipo.jugadores[idx] = sube
		equipo.banco.remove_at(mejor)
		return {"jugador": {}, "de_cantera": false, "hueco": true, "sube": sube}

	var ultimo: int = equipo.jugadores.size() - 1
	if ultimo > idx:
		equipo.jugadores[idx] = equipo.jugadores[ultimo]
	if ultimo >= 0:
		equipo.jugadores.remove_at(ultimo)
	return {"jugador": {}, "de_cantera": false, "hueco": true, "sube": {}}


## El mercado de libres corre TODOS LOS DIAS, con el libro de pases
## abierto o cerrado.
##
## Un jugador sin club no es una transferencia: no hay club vendedor ni
## fee, asi que no hay nada que la ventana tenga que regular. Antes el
## pool solo se movia en el cierre de temporada, cuando un vencimiento
## dejaba un hueco del mismo puesto (ver _reemplazo_para). Resultado
## medido en la partida del usuario, temporada 4: 440 libres parados, 8
## de ellos con media 90 o mas, que ningun club iba a mirar nunca.
##
## Aca los clubes salen a buscar por iniciativa propia, todos los dias.

## Cuantos clubes de la piramide miran el pool por dia. Son 200 clubes:
## con este numero cada club mira el pool cada 33 dias.
const CLUBES_QUE_MIRAN_POR_DIA := 6

## Cuanta media le tiene que sacar el libre al peor de su puesto para que
## el club haga el cambio. Sin margen, los clubes rotarian el plantel
## entero por diferencias de una decima.
const MEJORA_MINIMA := 3.0


## Con que animo el suplente ya no quiere seguir en el club.
##
## Es lo que mantiene viva la lista entre un cierre de temporada y el
## otro. Al amargado el club lo deja ir SIN exigir que el que llega sea
## mejor (ver _mirar_el_pool): se quiere ir igual. Asi entran al pool
## suplentes de primera —los que a vos te sirven— y no solo el descarte
## del cierre. Medido con tests/_diag_rotacion_libres.gd: sin esto el
## mejor libre caia a media 68 a los dos meses y se quedaba ahi.
const ANIMO_DE_RUPTURA := 25.0

## Cuantos clubes por dia sueltan a un suplente amargado sin esperar a
## fichar el reemplazo. Con 200 clubes es uno cada cien dias.
const CLUBES_QUE_LIMPIAN_POR_DIA := 2

## Cuantos libres aguanta la lista. Pasado el tope, los de menor media
## cuelgan los botines: nadie los iba a fichar y la partida guardada no
## puede engordar sin freno. Medido con tests/_diag_rotacion_libres.gd:
## sin tope el pool pasaba de 440 a 1232 en tres temporadas.
const TOPE_POOL := 520


## Un dia de mercado de libres en toda la piramide. Devuelve los fichajes
## hechos, para que quien llama arme las noticias que quiera.
##
## `protegido` es el club del jugador humano: sus fichajes los decide el,
## nadie le toca el plantel.
static func ronda_diaria(piramide, rng: RandomNumberGenerator, dias: int,
		protegido: Team = null) -> Array:
	var hechos := []
	var pool: Array = piramide.agentes_libres
	if pool.is_empty():
		return hechos
	for _dia in range(maxi(dias, 0)):
		for _i in range(CLUBES_QUE_LIMPIAN_POR_DIA):
			var club_limpia := _club_al_azar(piramide, rng, protegido)
			if club_limpia != null:
				_soltar_amargado(club_limpia, pool, rng)
		for _i in range(CLUBES_QUE_MIRAN_POR_DIA):
			var club := _club_al_azar(piramide, rng, protegido)
			if club == null:
				continue
			var ficha := _mirar_el_pool(club, pool)
			if not ficha.is_empty():
				hechos.append(ficha)
		_retirar_sobrantes(pool)
	return hechos


## Los peores de la lista se retiran cuando el pool pasa el tope.
static func _retirar_sobrantes(pool: Array) -> void:
	while pool.size() > TOPE_POOL:
		var peor := 0
		for i in range(pool.size()):
			if float(pool[i]["media"]) < float(pool[peor]["media"]):
				peor = i
		pool.remove_at(peor)


## Un club cualquiera de la piramide, nunca el del jugador humano.
static func _club_al_azar(piramide, rng: RandomNumberGenerator, protegido: Team) -> Team:
	var liga = piramide.divisiones[rng.randi() % piramide.divisiones.size()]
	if liga.equipos.is_empty():
		return null
	var club: Team = liga.equipos[rng.randi() % liga.equipos.size()]
	return null if club == protegido else club


## El suplente que no juega y se amargo se va libre, sin esperar a que el
## club le consiga reemplazo.
##
## Es lo que mantiene viva la lista entre un cierre de temporada y el
## otro: el que sale de un club de primera es un suplente de media alta,
## o sea la ganga que se puede encontrar cualquier dia. Del banco y de las
## RESERVAS: a un titular no lo suelta nadie por estar de mal humor, pero
## el que ni al banco llega es el primero que se harta.
static func _soltar_amargado(equipo: Team, pool: Array, rng: RandomNumberGenerator) -> void:
	var candidatos := []
	for i in range(equipo.banco.size()):
		var id := int(equipo.banco[i]["id"])
		if float(equipo.animo.get(id, 50.0)) <= ANIMO_DE_RUPTURA:
			candidatos.append({"lista": equipo.banco, "idx": i})
	for i in range(equipo.reservas.size()):
		var id_r := int(equipo.reservas[i]["id"])
		if float(equipo.animo.get(id_r, 50.0)) <= ANIMO_DE_RUPTURA:
			candidatos.append({"lista": equipo.reservas, "idx": i})
	if candidatos.is_empty():
		return
	var elegido: Dictionary = candidatos[rng.randi() % candidatos.size()]
	var lista: Array = elegido["lista"]
	var idx: int = int(elegido["idx"])
	var jugador: Dictionary = lista[idx]
	lista.remove_at(idx)
	equipo._limpiar_registro(int(jugador["id"]))
	# Se fue peleado: este club no lo puede volver a fichar (misma regla
	# que `liberar`).
	jugador["club_libero"] = equipo.nombre
	pool.append(jugador)
	equipo.recalcular_capitan()


## Un club mira el pool y se lleva al mejor que le sirva. Devuelve
## {club, entra, sale} —`sale` vacio si entro en un lugar vacante— o {} si
## no habia nadie que le sirviera.
##
## Que el club este completo NO lo deja afuera: si el libre es bastante
## mejor que el peor de ese puesto, lo cambia y al otro lo larga. Un
## plantel de 18 sin esta regla es un candado — los clubes nacen completos
## y solo abren un lugar cuando se les vence un contrato.
static func _mirar_el_pool(equipo: Team, pool: Array) -> Dictionary:
	# Contra el plantel de la IA y no contra el tope legal de 40: un club
	# de la IA no acumula suplentes, mantiene su once y su banco.
	var hay_lugar: bool = equipo.todos_los_jugadores().size() < Team.plantel_de_la_ia()
	# El peor de cada puesto, para saber a quien podria reemplazar.
	var peores := {}
	if not hay_lugar:
		peores = _peor_por_puesto(equipo)

	var elegido := -1
	var sueldo_elegido := 0.0
	var sale := {}
	for i in range(pool.size()):
		var agente: Dictionary = pool[i]
		if veta_a(equipo, agente):
			continue
		if elegido != -1 and float(agente["media"]) <= float(pool[elegido]["media"]):
			continue
		var candidato_sale := {}
		if not hay_lugar:
			var peor: Dictionary = peores.get(str(agente["posicion"]), {})
			if peor.is_empty():
				continue
			# Al amargado lo deja ir sin pedirle nada al que llega: el que
			# se quiere ir ya se queria ir. Al que esta bien solo lo saca
			# alguien bastante mejor.
			var margen: float = 0.0 if bool(peor["amargado"]) else MEJORA_MINIMA
			if float(agente["media"]) < float(peor["jugador"]["media"]) + margen:
				continue
			candidato_sale = peor
		var sueldo := sueldo_libre(agente, CONTRATO_LIBRE_ANIOS)
		# El sueldo del que se va se libera con el cambio, asi que cuenta
		# como presupuesto disponible: sin esto un club completo no podria
		# reemplazar a nadie por alguien que cobre un peso mas.
		var disponible: float = equipo.caja.get("contratos", 0.0)
		if not candidato_sale.is_empty():
			disponible += float(equipo.sueldos.get(int(candidato_sale["jugador"]["id"]), 0.0))
		if sueldo > disponible:
			continue
		elegido = i
		sueldo_elegido = sueldo
		sale = candidato_sale

	if elegido == -1:
		return {}

	var entra: Dictionary = pool[elegido]
	pool.remove_at(elegido)
	entra.erase("club_libero")
	entra.erase("temporadas_libre")

	var saliente := {}
	if sale.is_empty():
		# mover_a_banco y no banco.append: con el banco lleno el que llega
		# va a reservas en vez de sentarse de octavo suplente.
		equipo.mover_a_banco(entra)
	else:
		saliente = sale["jugador"]
		equipo._limpiar_registro(int(saliente["id"]))
		# Ocupa el MISMO lugar que el que sale: mismo puesto y mismo slot
		# de la formacion (el slot `i` lo ocupa jugadores[i], ver
		# MotorEspacial). Cambiarlo de lugar le correria el puesto a todos
		# los que siguen.
		if bool(sale["en_banco"]):
			equipo.banco[int(sale["indice"])] = entra
		else:
			equipo.jugadores[int(sale["indice"])] = entra
		# Quien lo largo no lo puede recuperar gratis, igual que en
		# `liberar`: si no, el cambio seria reversible y no costaria nada.
		saliente["club_libero"] = equipo.nombre
		pool.append(saliente)

	_incorporar(equipo, entra, CONTRATO_LIBRE_ANIOS, sueldo_elegido)
	equipo.recalcular_capitan()
	return {"club": equipo, "entra": entra, "sale": saliente}


## posicion -> {jugador, indice, en_banco, amargado} del que sale de ese
## puesto si el club ficha a alguien.
##
## El orden es: primero el suplente amargado (ANIMO_DE_RUPTURA), despues
## el de menor media. El banco antes que el once: entre dos iguales sale
## el suplente y no el titular.
static func _peor_por_puesto(equipo: Team) -> Dictionary:
	var peores := {}
	for lista in [[equipo.jugadores, false], [equipo.banco, true]]:
		var jugadores: Array = lista[0]
		var en_banco: bool = lista[1]
		for i in range(jugadores.size()):
			var j: Dictionary = jugadores[i]
			var pos := str(j["posicion"])
			var amargado: bool = en_banco and float(
				equipo.animo.get(int(j["id"]), 50.0)) <= ANIMO_DE_RUPTURA
			var candidato := {"jugador": j, "indice": i, "en_banco": en_banco,
				"amargado": amargado}
			var actual: Dictionary = peores.get(pos, {})
			if actual.is_empty():
				peores[pos] = candidato
				continue
			if bool(actual["amargado"]) != amargado:
				if amargado:
					peores[pos] = candidato
				continue
			if float(j["media"]) <= float(actual["jugador"]["media"]):
				peores[pos] = candidato
	return peores
