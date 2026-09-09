class_name Copa
extends RefCounted

## Motor genérico de eliminación directa a partido único — Fase 7 (GDD §10:
## "copa interna de división + copa nacional entre todas las divisiones,
## partido único"). Sirve para cualquier cantidad de equipos: si no es
## potencia de 2, la cantidad sobrante juega una ronda previa y el resto
## pasa con bye, para que de ahí en adelante el cuadro quede parejo.
##
## Las dos copas domésticas ya NO llegan acá con una cantidad rara: entran
## 128 al Rey y 16 a la interna, así que el cuadro sale perfecto y ningún
## club pasa sin jugar (ver core/clasificacion_copas.gd). El mecanismo de
## bye queda igual porque sigue haciendo falta de red: una división a la
## que le falten clubes, o un guardado viejo, tienen que armar cuadro
## igual en vez de reventar.
##
## El CUADRO es fijo: se sortea una sola vez, al iniciar, y de ahí en
## adelante cada equipo se enfrenta al ganador del cruce de al lado hasta
## que quedan dos. Ver _intercalar.
##
## Empates: si 90' terminan igualados se juega el alargue (2x15') y si
## sigue empatado se define por penales — partido único a eliminación
## directa real (§8.7). El cruce del jugador lo resuelve entero
## MotorEspacial, con fotogramas; los de la IA, MatchEngine.simular_alargue
## y Penales.definir.

var nombre: String
var equipos_con_bye: Array = []  # Team, esperando a la ronda donde ya no hace falta bye
var partidos_pendientes: Array = []  # [[Team, Team], ...] listos para jugar_siguiente_ronda()
var historial: Array = []  # por ronda jugada: Array de {local, visitante, gl, gv, ganador}
var campeon: Team = null

## El partido del equipo seguido en la ronda que se acaba de jugar, con
## fotogramas para verlo. Es TRANSITORIO: no se guarda y se pisa en cada
## ronda. Queda vacio si el equipo seguido no jugo esa ronda (le toco bye,
## o ya lo eliminaron).
var seguido: Dictionary = {}


static func iniciar(nombre: String, equipos: Array, rng: RandomNumberGenerator) -> Copa:
	var c := Copa.new()
	c.nombre = nombre
	var n := equipos.size()
	var mezclados := _mezclar(equipos, rng)

	if n <= 1:
		c.campeon = mezclados[0] if n == 1 else null
		return c

	var potencia := 1
	while potencia * 2 <= n:
		potencia *= 2

	if potencia == n:
		c.partidos_pendientes = _armar_pares(mezclados)
	else:
		var con_bye: int = 2 * potencia - n
		c.equipos_con_bye = mezclados.slice(0, con_bye)
		c.partidos_pendientes = _armar_pares(mezclados.slice(con_bye, n))

	return c


## Juega la ronda pendiente entera y arma la siguiente.
##
## `equipo_seguido` es el club del jugador humano: su cruce sale con
## fotogramas para que lo pueda MIRAR, igual que su partido de liga (ver
## resolver_cruce). El partido seguido queda en `seguido`; la ronda entera
## vuelve como resultado.
func jugar_siguiente_ronda(rng: RandomNumberGenerator, equipo_seguido: Team = null) -> Array:
	seguido = {}
	if campeon != null or partidos_pendientes.is_empty():
		return []

	var resultados := []
	var ganadores := []
	for partido in partidos_pendientes:
		var home: Team = partido[0]
		var away: Team = partido[1]
		var es_el_del_jugador: bool = home == equipo_seguido or away == equipo_seguido
		var cruce := resolver_cruce(home, away, rng, es_el_del_jugador)
		resultados.append(fila_de_historial(cruce))
		if es_el_del_jugador:
			seguido = detalle_seguido(cruce)
		ganadores.append(cruce["ganador"])
	historial.append(resultados)

	var siguiente_pool: Array = _intercalar(ganadores, equipos_con_bye)
	equipos_con_bye = []

	if siguiente_pool.size() == 1:
		campeon = siguiente_pool[0]
		partidos_pendientes = []
	else:
		partidos_pendientes = _armar_pares(siguiente_pool)

	return resultados


## Un partido suelto de torneo. El del jugador lo juega el motor espacial
## con fotogramas, para que lo pueda MIRAR; los demas van con el motor
## abstracto, que es mucho mas rapido y alcanza.
##
## `es_eliminatoria` marca las dos cosas que separan un cruce a muerte
## subita de una fecha de fase de liga: prende el efecto copa (§8.4#28,
## ver Motivacion.es_david) y le pide al motor espacial que resuelva
## tambien el alargue y los penales. En una fase de liga el empate es un
## resultado y no hay David ni Goliat, asi que va en false.
##
## Lo usan los cruces de copa y las fechas de la fase de liga
## internacional (ver FaseLiga.jugar_fecha).
static func jugar_partido(home: Team, away: Team, rng: RandomNumberGenerator,
		es_el_del_jugador: bool, es_eliminatoria: bool) -> Dictionary:
	# El efecto copa se prende para el partido y se apaga al final, porque
	# el mismo objeto Team juega la liga.
	home.en_copa = es_eliminatoria
	away.en_copa = es_eliminatoria
	var r: Dictionary
	if es_el_del_jugador:
		# El motor espacial necesita el once COMPLETO: sin arreglar la
		# alineacion, un lesionado en el once deja un puesto vacio y el
		# motor revienta buscando al que no esta. Los partidos que no se
		# miran siguen sin arreglar, como siempre: el motor abstracto
		# se banca un equipo con huecos.
		Alineacion.arreglar(home)
		Alineacion.arreglar(away)
		r = MotorEspacial.simular(home, away, rng, true, es_eliminatoria)
	else:
		r = MatchEngine.simular(home, away, rng, false)
	home.en_copa = false
	away.en_copa = false
	return r


## Un cruce a eliminacion directa de punta a punta: 90', alargue y penales
## si hace falta (§8.7). Devuelve el partido entero —marcador, como se
## definio, ganador y el detalle para mirarlo— y no toca ningun cuadro,
## asi que sirve igual para una ronda de copa, para la previa
## internacional y para el playoff de octavos (ver TemporadaInternacional).
##
## El cruce del jugador se juega ENTERO con el motor espacial: si termina
## empatado, el alargue y la tanda tambien salen de ahi y tambien tienen
## fotogramas. Antes esos 30' y los penales los resolvian MatchEngine y
## Penales por atras, asi que el jugador miraba 90 minutos y se enteraba
## del resto por el resumen. Los cruces de la IA siguen igual: motor
## abstracto, alargue abstracto y tanda abstracta.
static func resolver_cruce(home: Team, away: Team, rng: RandomNumberGenerator,
		es_el_del_jugador: bool) -> Dictionary:
	var r := jugar_partido(home, away, rng, es_el_del_jugador, true)
	var gl: int = r["goles_local"]
	var gv: int = r["goles_visitante"]
	var definicion := str(r.get("definicion", "90 minutos"))
	var ganador: Team
	var penales_texto := ""
	var goles_log: Array = r.get("goles_log", []).duplicate()
	var eventos: Array = r.get("eventos", []).duplicate()

	var pen: Dictionary = r.get("penales", {})
	if not pen.is_empty():
		# El motor espacial ya jugo el alargue y pateo la tanda: el
		# ganador sale de ahi y el jugador vio los penales.
		ganador = pen["ganador"]
		penales_texto = " (%d-%d penales)" % [pen["goles_local"], pen["goles_visitante"]]
	elif gl != gv:
		ganador = home if gl > gv else away
	else:
		# Motor abstracto: el alargue y la tanda se juegan aparte.
		var r_alargue := MatchEngine.simular_alargue(home, away, rng, es_el_del_jugador)
		gl = r_alargue["goles_local"]
		gv = r_alargue["goles_visitante"]
		definicion = "alargue"
		goles_log.append_array(r_alargue.get("goles_log", []))
		eventos.append_array(r_alargue.get("eventos", []))
		if gl != gv:
			ganador = home if gl > gv else away
		else:
			var pen_abstracta := Penales.definir(home, away, rng)
			definicion = "penales"
			ganador = pen_abstracta["ganador"]
			penales_texto = " (%d-%d penales)" % [
				pen_abstracta["goles_local"], pen_abstracta["goles_visitante"]]

	return {
		"local": home.nombre, "visitante": away.nombre,
		"gl": gl, "gv": gv, "ganador": ganador,
		"definicion": definicion, "penales_texto": penales_texto,
		"goles_log": goles_log, "log": r.get("log", []), "eventos": eventos,
		"fotogramas": r.get("fotogramas", []),
	}


## La fila que va al historial de una copa: solo nombres y numeros, nada
## de referencias a Team, que es lo que la deja guardar tal cual.
static func fila_de_historial(cruce: Dictionary) -> Dictionary:
	return {
		"local": cruce["local"], "visitante": cruce["visitante"],
		"gl": cruce["gl"], "gv": cruce["gv"],
		"ganador": cruce["ganador"].nombre if cruce["ganador"] != null else "",
		"definicion": cruce["definicion"], "penales_texto": cruce["penales_texto"],
	}


## El partido del jugador listo para que lo mire la pantalla animada:
## la fila del historial mas el log, los eventos y los fotogramas.
static func detalle_seguido(cruce: Dictionary) -> Dictionary:
	var d := fila_de_historial(cruce)
	d["goles_log"] = cruce["goles_log"]
	d["log"] = cruce["log"]
	d["eventos"] = cruce["eventos"]
	d["fotogramas"] = cruce["fotogramas"]
	return d


## Si el club está EN el cuadro: le queda un cruce, pasó sin jugar, ya
## jugó alguna ronda (aunque lo hayan eliminado) o salió campeón. Desde
## que la copa se juega por clasificación, "no aparece" ya no significa
## "lo eliminaron": significa que no clasificó, y hay dos cosas que
## dependen de saberlo — el objetivo de directiva de copa (imposible de
## cumplir sin cupo, ver Objetivos.generar) y el aviso al jugador.
func participa(equipo: Team) -> bool:
	if equipo == null:
		return false
	if campeon == equipo:
		return true
	for p in partidos_pendientes:
		if p[0] == equipo or p[1] == equipo:
			return true
	if equipos_con_bye.has(equipo):
		return true
	for ronda in historial:
		for partido in ronda:
			if partido["local"] == equipo.nombre or partido["visitante"] == equipo.nombre:
				return true
	return false


## El cruce que le toca a un equipo en la ronda que viene: [local,
## visitante]. Vacio si ya lo eliminaron, si le toco bye o si la copa
## termino. Con esto la UI sabe si el jugador tiene partido de copa hoy.
func cruce_de(equipo: Team) -> Array:
	for p in partidos_pendientes:
		if p[0] == equipo or p[1] == equipo:
			return p
	return []


## Como se llama la ronda que viene, por cuantos equipos quedan vivos —
## los que juegan mas los que pasan con bye. Con 200 equipos las primeras
## rondas no tienen nombre propio, y ahi dice cuantos quedan.
func ronda_actual() -> String:
	if partidos_pendientes.is_empty():
		return ""
	var vivos: int = partidos_pendientes.size() * 2 + equipos_con_bye.size()
	match vivos:
		2: return "Final"
		4: return "Semifinal"
		8: return "Cuartos de final"
		16: return "Octavos de final"
	return "Ronda de %d" % vivos


## El que perdio la final, por nombre. "" si la copa todavia no termino.
## Lo necesita el premio al finalista: llegar a la final tambien paga.
func finalista() -> String:
	if campeon == null or historial.is_empty():
		return ""
	var final_: Array = historial[historial.size() - 1]
	if final_.is_empty():
		return ""
	var partido: Dictionary = final_[0]
	if str(partido["ganador"]) == str(partido["local"]):
		return str(partido["visitante"])
	return str(partido["local"])


## §10.5/§15 (Objetivos de directiva, ver core/objetivos.gd): cuántas
## rondas ganó este equipo en total en esta copa — 0 si perdió su primer
## partido, historial.size() si salió campeón. Un bye (ronda en la que no
## aparece en ningún partido porque le tocó pasar directo) no suma ni
## resta, simplemente no cuenta esa ronda.
func rondas_ganadas(equipo: Team) -> int:
	var rondas := 0
	for ronda in historial:
		for partido in ronda:
			if partido["local"] == equipo.nombre or partido["visitante"] == equipo.nombre:
				if partido["ganador"] == equipo.nombre:
					rondas += 1
				break
	return rondas


## El pool de la ronda que viene, en el ORDEN DEL CUADRO.
##
## El sorteo se hace UNA sola vez, en iniciar(): de ahi en adelante el
## ganador de cada cruce ya sabe con quien se juega la ronda siguiente —el
## ganador del cruce de al lado— como en cualquier cuadro de copa. Antes
## se volvia a sortear despues de cada ronda, asi que el cuadro no existia
## como tal: cada ronda era un sorteo nuevo entre los que quedaban.
##
## Los que pasaron sin jugar se intercalan con los ganadores en vez de ir
## todos juntos al final: asi al que le toco bye le toca despues un equipo
## que SI jugo, que es como se arma una ronda previa de verdad. Cuando hay
## mas byes que ganadores, los que sobran se cruzan entre ellos.
static func _intercalar(ganadores: Array, con_bye: Array) -> Array:
	if con_bye.is_empty():
		return ganadores
	var salida := []
	var i := 0
	var j := 0
	while i < con_bye.size() and j < ganadores.size():
		salida.append(con_bye[i])
		salida.append(ganadores[j])
		i += 1
		j += 1
	while i < con_bye.size():
		salida.append(con_bye[i])
		i += 1
	while j < ganadores.size():
		salida.append(ganadores[j])
		j += 1
	return salida


static func _armar_pares(equipos: Array) -> Array:
	var pares := []
	for i in range(0, equipos.size(), 2):
		pares.append([equipos[i], equipos[i + 1]])
	return pares


static func _mezclar(equipos: Array, rng: RandomNumberGenerator) -> Array:
	var copia := equipos.duplicate()
	for i in range(copia.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = copia[i]
		copia[i] = copia[j]
		copia[j] = tmp
	return copia


## Guardado. `historial` ya usa NOMBRES (se arma así en
## jugar_siguiente_ronda), así que lo único que hay que traducir son las
## tres cosas que sí guardan referencias a Team: el bye, los partidos
## pendientes y el campeón. Los equipos se relocalizan al cargar buscando
## por nombre en un índice, igual que hace Confederacion.
func guardar() -> Dictionary:
	var pares := []
	for p in partidos_pendientes:
		pares.append([p[0].nombre, p[1].nombre])
	var bye := []
	for e in equipos_con_bye:
		bye.append(e.nombre)
	return {
		"nombre": nombre,
		"equipos_con_bye": bye,
		"partidos_pendientes": pares,
		"historial": historial,
		"campeon": campeon.nombre if campeon != null else "",
	}


static func cargar(datos: Dictionary, piramide) -> Copa:
	var indice := {}
	for liga in piramide.divisiones:
		for e in liga.equipos:
			indice[e.nombre] = e
	return cargar_desde_indice(datos, indice)


## El mismo cargar, pero con un índice ya armado de nombre -> Team. Lo
## necesitan las copas internacionales: la mitad de sus equipos son clubes
## del exterior y no están en la pirámide (ver Confederacion.indice_de_equipos).
static func cargar_desde_indice(datos: Dictionary, indice: Dictionary) -> Copa:
	var c := Copa.new()
	c.nombre = str(datos.get("nombre", "Copa"))
	c.historial = datos.get("historial", [])
	for n in datos.get("equipos_con_bye", []):
		if indice.has(str(n)):
			c.equipos_con_bye.append(indice[str(n)])
	for p in datos.get("partidos_pendientes", []):
		# Si un equipo del cuadro ya no existe (no debería pasar dentro de
		# una temporada), se descarta el cruce entero en vez de dejar un
		# partido a medias que reventaría al jugarlo.
		if indice.has(str(p[0])) and indice.has(str(p[1])):
			c.partidos_pendientes.append([indice[str(p[0])], indice[str(p[1])]])
	var campeon_nombre := str(datos.get("campeon", ""))
	if campeon_nombre != "" and indice.has(campeon_nombre):
		c.campeon = indice[campeon_nombre]
	return c
