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


## El mejor reemplazo del banco para este titular: de su misma posicion
## si hay, y si no el mejor disponible. Un 4-3-3 sin extremos suplentes
## tiene que poder jugar igual, aunque sea con un volante de extremo.
static func reemplazo_para(equipo: Team, jugador: Dictionary, tomados: Array) -> Dictionary:
	var misma := {}
	var cualquiera := {}
	for s in equipo.banco:
		var id := int(s["id"])
		if tomados.has(id) or not equipo.puede_jugar(id):
			continue
		if str(s["posicion"]) == str(jugador["posicion"]):
			if misma.is_empty() or float(s["media"]) > float(misma["media"]):
				misma = s
		elif cualquiera.is_empty() or float(s["media"]) > float(cualquiera["media"]):
			cualquiera = s
	return misma if not misma.is_empty() else cualquiera


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
