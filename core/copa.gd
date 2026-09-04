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
## Empates: si 90' terminan igualados se juega el alargue (2x15',
## MatchEngine.simular_alargue) y si sigue empatado se define por penales
## (Penales.definir) — partido único a eliminación directa real (§8.7).

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


## `equipo_seguido` es el club del jugador humano: su cruce se juega con
## el motor espacial y con fotogramas, para que lo pueda MIRAR, igual que
## su partido de liga (ver Liga.jugar_fecha). Los otros 99 cruces siguen
## con el motor abstracto, que es mucho mas rapido y alcanza. El partido
## seguido queda en `seguido`; la ronda entera vuelve como resultado.
##
## El alargue y los penales del cruce seguido los resuelve MatchEngine
## igual que en cualquier otro cruce: el motor espacial no tiene alargue,
## asi que esos 30' no se ven, se cuentan en el resumen.
func jugar_siguiente_ronda(rng: RandomNumberGenerator, equipo_seguido: Team = null) -> Array:
	seguido = {}
	if campeon != null or partidos_pendientes.is_empty():
		return []

	var resultados := []
	var ganadores := []
	for partido in partidos_pendientes:
		var home: Team = partido[0]
		var away: Team = partido[1]
		# §8.4#28: el efecto copa vale en la copa. Se prende para el cruce
		# y se apaga al final, porque el mismo objeto Team juega la liga.
		home.en_copa = true
		away.en_copa = true
		var es_el_del_jugador: bool = home == equipo_seguido or away == equipo_seguido
		var r: Dictionary
		if es_el_del_jugador:
			# El motor espacial necesita el once COMPLETO: sin arreglar la
			# alineacion, un lesionado en el once deja un puesto vacio y el
			# motor revienta buscando al que no esta. Los cruces que no se
			# miran siguen sin arreglar, como siempre: el motor abstracto
			# se banca un equipo con huecos.
			Alineacion.arreglar(home)
			Alineacion.arreglar(away)
			r = MotorEspacial.simular(home, away, rng, true)
		else:
			r = MatchEngine.simular(home, away, rng, false)
		var gl: int = r["goles_local"]
		var gv: int = r["goles_visitante"]
		var definicion := "90 minutos"
		var ganador: Team
		var penales_texto := ""
		var goles_log: Array = r.get("goles_log", []).duplicate()
		var eventos: Array = r.get("eventos", []).duplicate()

		if gl != gv:
			ganador = home if gl > gv else away
		else:
			var r_alargue := MatchEngine.simular_alargue(home, away, rng, es_el_del_jugador)
			gl = r_alargue["goles_local"]
			gv = r_alargue["goles_visitante"]
			definicion = "alargue"
			goles_log.append_array(r_alargue.get("goles_log", []))
			eventos.append_array(r_alargue.get("eventos", []))
			if gl != gv:
				ganador = home if gl > gv else away
			else:
				var pen := Penales.definir(home, away, rng)
				definicion = "penales"
				ganador = pen["ganador"]
				penales_texto = " (%d-%d penales)" % [pen["goles_local"], pen["goles_visitante"]]

		resultados.append({
			"local": home.nombre, "visitante": away.nombre,
			"gl": gl, "gv": gv, "ganador": ganador.nombre,
			"definicion": definicion, "penales_texto": penales_texto,
		})
		if es_el_del_jugador:
			seguido = {
				"local": home.nombre, "visitante": away.nombre,
				"gl": gl, "gv": gv, "goles_log": goles_log,
				"log": r.get("log", []), "eventos": eventos,
				"fotogramas": r.get("fotogramas", []),
				"ganador": ganador.nombre,
				"definicion": definicion, "penales_texto": penales_texto,
			}
		ganadores.append(ganador)
		home.en_copa = false
		away.en_copa = false
	historial.append(resultados)

	var siguiente_pool: Array = _intercalar(ganadores, equipos_con_bye)
	equipos_con_bye = []

	if siguiente_pool.size() == 1:
		campeon = siguiente_pool[0]
		partidos_pendientes = []
	else:
		partidos_pendientes = _armar_pares(siguiente_pool)

	return resultados


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
## por nombre en la pirámide, igual que hace Confederacion.
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
