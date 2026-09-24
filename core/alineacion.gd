class_name Alineacion
extends RefCounted

## Que el once que sale a la cancha pueda jugar.
##
## Hasta ahora no lo miraba nadie. reset_partido() mandaba a la cancha a
## los once titulares sin preguntar, asi que un lesionado o un suspendido
## salia igual y recien lo sacaban en la primera ventana de cambios. En el
## fútbol eso no pasa: al suspendido no lo deja el reglamento y al
## lesionado no lo deja el sentido comun.
##
## Hoy reset_partido() deja afuera al que no puede jugar, pero solo eso:
## el equipo sale con diez y el puesto queda vacio. Alineacion es la que
## BUSCA el reemplazo y tapa el hueco. Las dos hacen falta.
##
## Lo usan dos caminos distintos. Al club del jugador se le avisa antes de
## darle a Jugar, para que elija el reemplazo (ver el modal de alineacion
## en ui/main.gd). A los doscientos clubes de la IA se les arregla solo
## (ver Liga.jugar_fecha): nadie va a revisar el once de cada uno, y si no
## se les arreglara serian los unicos que juegan con lesionados.

const LESIONADO := "lesionado"
const SUSPENDIDO := "suspendido"
const EXPULSADO := "expulsado"


## Por que no puede jugar, o "" si puede.
static func motivo(equipo: Team, jugador_id: int) -> String:
	if equipo.esta_lesionado(jugador_id):
		return LESIONADO
	if int(equipo.suspendidos.get(jugador_id, 0)) > 0:
		return SUSPENDIDO
	if equipo.expulsados_partido.has(jugador_id):
		return EXPULSADO
	return ""


static func texto_motivo(equipo: Team, jugador_id: int) -> String:
	match motivo(equipo, jugador_id):
		LESIONADO:
			var les: Dictionary = equipo.lesiones.get(jugador_id, {})
			return "lesionado: %s, %d días" % [
				str(les.get("tipo", "")), int(les.get("dias_restantes", 0))]
		SUSPENDIDO:
			var fechas := int(equipo.suspendidos.get(jugador_id, 0))
			return "suspendido: %d fecha%s" % [fechas, "" if fechas == 1 else "s"]
		EXPULSADO:
			return "expulsado"
	return ""


## Lo mismo, pero corto: para donde no entra la frase entera. El cubo de
## la pantalla de Formacion mide 104 px de ancho y ahi no entra
## "suspendido: 2 fechas".
static func texto_motivo_corto(equipo: Team, jugador_id: int) -> String:
	match motivo(equipo, jugador_id):
		LESIONADO:
			var les: Dictionary = equipo.lesiones.get(jugador_id, {})
			return "Lesión %d d" % int(les.get("dias_restantes", 0))
		SUSPENDIDO:
			return "Susp. %d f" % int(equipo.suspendidos.get(jugador_id, 0))
		EXPULSADO:
			return "Expulsado"
	return ""


## Los TITULARES que no pueden jugar. Solo los titulares: el suplente
## lesionado no molesta a nadie, no va a entrar.
static func indisponibles(equipo: Team) -> Array:
	var out := []
	for j in equipo.jugadores:
		if not equipo.puede_jugar(int(j["id"])):
			out.append(j)
	return out


static func hay_problema(equipo: Team) -> bool:
	return not indisponibles(equipo).is_empty()


## El mejor reemplazo del banco para este titular: del puesto de SU SLOT
## si hay, y si no el que mejor rinde en ese slot. Un 4-3-3 sin extremos
## suplentes tiene que poder jugar igual, aunque sea con un volante de
## extremo.
##
## El respaldo antes elegia la mejor media sin mirar el puesto. La media
## de un arquero es la de arquero, asi que un arquero suplente de media
## alta tapaba al 9 lesionado. Medido con tests/_diag_once_fuera_de_puesto.gd:
## despues de una temporada, 197 de los 200 clubes tenian el once
## desordenado.
static func reemplazo_para(equipo: Team, jugador: Dictionary, tomados: Array) -> Dictionary:
	var rol := rol_del_slot(equipo, int(jugador["id"]), str(jugador["posicion"]))
	var misma := {}
	var cualquiera := {}
	var media_cualquiera := -1.0
	for s in equipo.banco:
		var id := int(s["id"])
		if tomados.has(id) or not equipo.puede_jugar(id):
			continue
		if str(s["posicion"]) == rol:
			if misma.is_empty() or float(s["media"]) > float(misma["media"]):
				misma = s
			continue
		var media_en_rol := rinde_en(s, rol)
		if media_en_rol > media_cualquiera:
			cualquiera = s
			media_cualquiera = media_en_rol
	return misma if not misma.is_empty() else cualquiera


## El puesto que pide la formacion en el slot de este titular. El slot `i`
## lo ocupa jugadores[i] (ver data/formaciones.json).
static func rol_del_slot(equipo: Team, jugador_id: int, por_defecto: String) -> String:
	var roles: Array = Formaciones.roles_compartidos(equipo.formacion)
	for i in range(mini(roles.size(), equipo.jugadores.size())):
		if int(equipo.jugadores[i]["id"]) == jugador_id:
			return str(roles[i])
	return por_defecto


## Reacomoda el once y el banco de un club de la IA segun su formacion:
## cada slot con alguien de ese puesto que pueda jugar. Devuelve true si
## cambio algo.
##
## Sin esto el once de la IA se desarmaba solo. Cada reemplazo que tapa un
## hueco con alguien de otro puesto queda para siempre, porque nadie
## vuelve a mirar el once de los 200 clubes. En una partida de temporada
## 14, en 145 clubes atajaba un jugador de campo.
##
## Mira tambien las reservas. Medido con tests/_diag_once_fuera_de_puesto.gd:
## a mitad de la segunda temporada los planteles tenian gente de todos
## los puestos, pero 600 titulares jugaban fuera de puesto porque el del
## puesto estaba en reservas y el banco lleno de otros puestos.
##
## Es conservador a proposito: el titular que ya esta en un slot de su
## puesto no se mueve. Solo se tocan los slots mal cubiertos, asi que un
## once sano queda igual y la rotacion por uso no cambia.
##
## No se usa con el club del jugador: su once lo arma el.
static func acomodar(equipo: Team) -> bool:
	var roles: Array = Formaciones.roles_compartidos(equipo.formacion)
	var candidatos: Array = equipo.jugadores + equipo.banco + equipo.reservas
	var n_titulares: int = equipo.jugadores.size()
	var n_banco: int = equipo.banco.size()
	var desde_reservas: int = n_titulares + n_banco
	var ocupante := []
	ocupante.resize(roles.size())
	ocupante.fill(-1)
	var usados := {}

	# 1. El titular sano que ya esta en un slot de su puesto se queda.
	for i in range(mini(roles.size(), n_titulares)):
		var j: Dictionary = candidatos[i]
		if str(j["posicion"]) == str(roles[i]) and equipo.puede_jugar(int(j["id"])):
			ocupante[i] = i
			usados[i] = true

	# 2. Los slots mal cubiertos, el arco primero: un arquero de campo es
	# el peor error posible. Gana el del puesto; entre dos del puesto, el
	# que ya iba al partido antes que la reserva; y despues la media.
	var orden := []
	for i in range(roles.size()):
		if ocupante[i] == -1:
			if str(roles[i]) == "ARQ":
				orden.push_front(i)
			else:
				orden.append(i)
	for i in orden:
		var elegido := _mejor_para(equipo, candidatos, usados, str(roles[i]), desde_reservas, true)
		if elegido != -1:
			ocupante[i] = elegido
			usados[elegido] = true

	# 3. Sin nadie sano, el slot lo ocupa alguien que no puede jugar:
	# reset_partido lo deja afuera y el club sale con diez, igual que
	# antes (ver Liga._resolver_forfeit).
	for i in range(roles.size()):
		if ocupante[i] != -1:
			continue
		for c in range(candidatos.size()):
			if not usados.has(c):
				ocupante[i] = c
				usados[c] = true
				break

	var once := []
	for i in range(roles.size()):
		if ocupante[i] != -1:
			once.append(candidatos[ocupante[i]])

	# 4. El banco, del mismo tamaño que tenia: primero un jugador sano por
	# cada puesto que pide Formaciones.banco_para, despues el resto en
	# orden (banco, titulares que bajan, reservas).
	var banco := []
	for rol in Formaciones.banco_para(equipo.formacion):
		if banco.size() >= n_banco:
			break
		var c := _mejor_para(equipo, candidatos, usados, str(rol), desde_reservas, false)
		if c != -1:
			banco.append(candidatos[c])
			usados[c] = true
	for c in range(candidatos.size()):
		if banco.size() >= n_banco:
			break
		if not usados.has(c):
			banco.append(candidatos[c])
			usados[c] = true
	var reservas := []
	for c in range(desde_reservas, candidatos.size()):
		if not usados.has(c):
			reservas.append(candidatos[c])
	for c in range(desde_reservas):
		if not usados.has(c):
			reservas.append(candidatos[c])

	if _mismos_ids(once, equipo.jugadores) and _mismos_ids(banco, equipo.banco):
		return false
	equipo.jugadores = once
	equipo.banco = banco
	equipo.reservas = reservas
	equipo.recalcular_capitan()
	return true


## El mejor candidato sano y libre para `rol`, o -1. Con
## `aceptar_otro_puesto` en false no acepta a nadie de otro puesto (lo usa
## el banco, que se completa despues en orden).
static func _mejor_para(equipo: Team, candidatos: Array, usados: Dictionary,
		rol: String, desde_reservas: int, aceptar_otro_puesto: bool) -> int:
	var elegido := -1
	var clave_elegido := []
	for c in range(candidatos.size()):
		if usados.has(c) or not equipo.puede_jugar(int(candidatos[c]["id"])):
			continue
		var del_puesto: bool = str(candidatos[c]["posicion"]) == rol
		if not del_puesto and not aceptar_otro_puesto:
			continue
		var valor: float = float(candidatos[c]["media"]) if del_puesto 			else rinde_en(candidatos[c], rol)
		var clave := [1 if del_puesto else 0, 1 if c < desde_reservas else 0, valor]
		if elegido == -1 or clave > clave_elegido:
			elegido = c
			clave_elegido = clave
	return elegido


## Lo que rinde un jugador en un puesto que no es el suyo: su media con
## los pesos de ese puesto, menos el castigo de jugar fuera de posicion
## que le aplica el partido (Puestos.modificador_de, en puntos
## porcentuales). Sin el castigo, un arquero con buenos pases le ganaba el
## puesto de volante a un extremo, porque los atributos no dependen del
## puesto (ver PlayerGenerator.techos_por_atributo).
static func rinde_en(jugador: Dictionary, rol: String) -> float:
	return PlayerGenerator.compute_media(jugador["atributos"], rol) 		* (1.0 + Puestos.modificador_de(jugador, rol) / 100.0)


static func _mismos_ids(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]["id"]) != int(b[i]["id"]):
			return false
	return true


## Lo que haria el arreglo automatico, SIN tocar nada. Sirve para
## mostrarselo al jugador antes de que decida.
##
## Devuelve [{"sale": Dictionary, "entra": Dictionary, "motivo": String}].
## Si a alguno no se le encuentra reemplazo, "entra" viene vacio: el club
## se quedo sin suplentes sanos y ese puesto no se puede cubrir.
static func plan(equipo: Team) -> Array:
	var pasos := []
	var tomados := []
	for j in indisponibles(equipo):
		var entra := reemplazo_para(equipo, j, tomados)
		if not entra.is_empty():
			tomados.append(int(entra["id"]))
		pasos.append({
			"sale": j, "entra": entra,
			"motivo": texto_motivo(equipo, int(j["id"])),
		})
	return pasos


## Aplica el plan. Devuelve los pasos que efectivamente se hicieron.
##
## Los que no tienen reemplazo se quedan donde estan: no hay a quien
## poner, y sacarlo por sacarlo dejaria al equipo con diez. Si eso deja al
## club sin gente para jugar, de eso ya se ocupa Liga._resolver_forfeit.
static func arreglar(equipo: Team) -> Array:
	var hechos := []
	for paso in plan(equipo):
		if paso["entra"].is_empty():
			continue
		if equipo.intercambiar(int(paso["sale"]["id"]), int(paso["entra"]["id"])):
			hechos.append(paso)
	if not hechos.is_empty():
		equipo.recalcular_capitan()
	return hechos


## Cuantos titulares quedarian sin cubrir.
static func sin_cubrir(equipo: Team) -> int:
	var n := 0
	for paso in plan(equipo):
		if paso["entra"].is_empty():
			n += 1
	return n


## Rotación antes del partido, según la prioridad del partido y la energía
## con la que cada titular llega (Cansancio.motivo_rotacion). Cambia el
## once en el lugar y devuelve los pasos hechos, que después se deshacen
## con `deshacer_rotacion`: el once del club no cambia, solo el de hoy.
## Así el suplente que jugó la copa del miércoles vuelve al banco para la
## liga del domingo, y el titular que descansó vuelve a su puesto.
##
## Devuelve [{"sale": id, "entra": id, "motivo": String}].
static func rotar(equipo: Team, prioridad: int, rival: Team) -> Array:
	var hechos := []
	var rival_inferior := rival != null \
		and rival.media_equipo() <= equipo.media_equipo() - Cansancio.DIFERENCIA_RIVAL_INFERIOR
	var tomados := []
	for titular in equipo.jugadores.duplicate():
		var id := int(titular["id"])
		if not equipo.puede_jugar(id):
			continue
		var energia := equipo.energia_proximo_partido(id)
		var motivo_rot := Cansancio.motivo_rotacion(energia, prioridad, rival_inferior)
		if motivo_rot.is_empty():
			continue
		# El titular fresco de una copa menor solo descansa si el que entra
		# no desarma al equipo. Contra un rival muy inferior, entra igual.
		var margen := INF
		if Cansancio.franja(energia) == 0 and not rival_inferior:
			margen = Cansancio.MARGEN_ROTACION_BAJA
		var entra := _reemplazo_descansado(equipo, titular, energia, margen, tomados)
		if entra.is_empty():
			continue
		if equipo.intercambiar(id, int(entra["id"])):
			tomados.append(int(entra["id"]))
			tomados.append(id)
			hechos.append({"sale": id, "entra": int(entra["id"]), "motivo": motivo_rot})
	if not hechos.is_empty():
		equipo.recalcular_capitan()
	return hechos


## Rota a los dos clubes que tienen la rotación en automático y deja
## anotada la prioridad del partido. Devuelve lo que hay que deshacer.
static func rotar_partido(home: Team, away: Team, prioridad: int) -> Dictionary:
	var rotados := {}
	for club in [home, away]:
		club.prioridad_partido = prioridad
		if club.rotacion_automatica:
			rotados[club] = rotar(club, prioridad, away if club == home else home)
	return rotados


static func deshacer_partido(rotados: Dictionary) -> void:
	for club in rotados:
		deshacer_rotacion(club, rotados[club])


static func deshacer_rotacion(equipo: Team, hechos: Array) -> void:
	if hechos.is_empty():
		return
	for i in range(hechos.size() - 1, -1, -1):
		equipo.intercambiar(int(hechos[i]["entra"]), int(hechos[i]["sale"]))
	equipo.recalcular_capitan()


## El mejor reemplazo que llega más descansado que el titular: primero el
## del puesto del slot, del banco o de las reservas; si no hay, el que
## mejor rinde en ese puesto. Al arco solo va un arquero. `margen` es
## cuánto menos puede rendir que el titular.
static func _reemplazo_descansado(equipo: Team, titular: Dictionary, energia: float,
		margen: float, tomados: Array) -> Dictionary:
	var rol := rol_del_slot(equipo, int(titular["id"]), str(titular["posicion"]))
	var piso: float = float(titular["media"]) - margen
	var mejor := {}
	var clave_mejor := []
	for lista in [equipo.banco, equipo.reservas]:
		for s in lista:
			var id := int(s["id"])
			if tomados.has(id) or not equipo.puede_jugar(id):
				continue
			# Descansar a alguien para poner a uno más cansado no sirve. Al
			# titular fresco solo lo reemplaza otro fresco.
			var energia_s := equipo.energia_proximo_partido(id)
			var franja_s := Cansancio.franja(energia_s)
			if Cansancio.franja(energia) == 0:
				if franja_s != 0:
					continue
			elif franja_s >= Cansancio.franja(energia) and energia_s <= energia:
				continue
			var del_puesto: bool = str(s["posicion"]) == rol
			if rol == "ARQ" and not del_puesto:
				continue
			var valor: float = float(s["media"]) if del_puesto else rinde_en(s, rol)
			if valor < piso:
				continue
			var clave := [1 if del_puesto else 0, valor]
			if mejor.is_empty() or clave > clave_mejor:
				mejor = s
				clave_mejor = clave
	return mejor
