class_name Seleccion
extends RefCounted

## Selección nacional de Uruguay — sistema todavía sin fase en el roadmap
## original, agregado como extensión natural una vez que existe una
## pirámide completa de jugadores reales para convocar. Junta a los
## mejores jugadores DE TODA LA PIRÁMIDE (cualquier división: parte de la
## gracia es que tu crack de la División 10 pueda llegar a la selección)
## y los hace jugar amistosos contra selecciones rivales generadas para
## la ocasión. Los llamados vuelven a su club después del partido; si se
## lesionan jugando para la selección, la lesión SÍ le pega a su club real
## (ver GameState._jugar_amistoso_seleccion) — ese es el riesgo real de
## una convocatoria, no es gratis.

const ID_BASE_RIVAL := 900000
const ID_BASE_SELECCION := 950000


var nombre: String = "Selección Uruguay"
var convocatorias: Dictionary = {}  # jugador_id -> cantidad histórica de veces convocado


## Guardado de partida.
func guardar() -> Dictionary:
	var convocatorias_datos := {}
	for id in convocatorias:
		convocatorias_datos[str(id)] = convocatorias[id]
	return {"nombre": nombre, "convocatorias": convocatorias_datos}


static func cargar(datos: Dictionary) -> Seleccion:
	var s := Seleccion.new()
	s.nombre = datos.get("nombre", "Selección Uruguay")
	for id_str in datos.get("convocatorias", {}):
		s.convocatorias[int(id_str)] = datos["convocatorias"][id_str]
	return s


## Arma la convocatoria SIN registrarla en el historial (convocatorias) —
## para previsualizar "quién entraría hoy" (UI) tantas veces como haga
## falta sin inflar el contador de veces convocado de nadie.
func previsualizar(piramide: Piramide) -> Dictionary:
	var candidatos_por_posicion := {}
	for pos in Team.FORMACION + Team.BANCO_FORMACION:
		candidatos_por_posicion[pos] = []

	var clubes_por_jugador := {}
	for liga in piramide.divisiones:
		for club in liga.equipos:
			for j in club.todos_los_jugadores():
				if not club.puede_jugar(j["id"]):
					continue
				candidatos_por_posicion[j["posicion"]].append(j)
				clubes_por_jugador[j["id"]] = club

	for pos in candidatos_por_posicion:
		candidatos_por_posicion[pos].sort_custom(func(a, b): return a["media"] > b["media"])

	var seleccion := Team.new()
	seleccion.nombre = nombre
	seleccion.reputacion = 80.0
	seleccion.scouts = [{"nivel": 4}]
	seleccion.instalaciones = Instalaciones.nivel_inicial()
	for categoria in Economia.CATEGORIAS_CAJA:
		seleccion.caja[categoria] = 0.0
		seleccion.presupuesto_temporada[categoria] = 0.0
		seleccion.caja_al_cierre[categoria] = 0.0

	var usados := {}
	for pos in Team.FORMACION:
		var elegido := _mejor_disponible(candidatos_por_posicion, pos, usados)
		seleccion.jugadores.append(elegido)
		usados[elegido["id"]] = true
		seleccion._registrar_fichaje(elegido, ValorJugador.calcular(elegido, 50.0, 1), 1)
	for pos in Team.BANCO_FORMACION:
		var elegido := _mejor_disponible(candidatos_por_posicion, pos, usados)
		seleccion.banco.append(elegido)
		usados[elegido["id"]] = true
		seleccion._registrar_fichaje(elegido, ValorJugador.calcular(elegido, 50.0, 1), 1)

	seleccion.recalcular_capitan()
	return {"equipo": seleccion, "clubes_por_jugador": clubes_por_jugador}


## La convocatoria real, para jugar el amistoso — misma lógica que
## previsualizar() pero además queda en el historial (convocatorias).
func convocar(piramide: Piramide) -> Dictionary:
	var resultado := previsualizar(piramide)
	var uruguay: Team = resultado["equipo"]
	for j in uruguay.todos_los_jugadores():
		convocatorias[j["id"]] = convocatorias.get(j["id"], 0) + 1
	return resultado


## El mejor disponible en su posición natural; si ya no queda nadie (plantel
## muy chico, no debería pasar con 200 clubes), cae al mejor disponible de
## cualquier posición como último recurso, para no dejar un puesto vacío.
func _mejor_disponible(candidatos_por_posicion: Dictionary, posicion: String, usados: Dictionary) -> Dictionary:
	for j in candidatos_por_posicion[posicion]:
		if not usados.has(j["id"]):
			return j
	for pos in candidatos_por_posicion:
		for j in candidatos_por_posicion[pos]:
			if not usados.has(j["id"]):
				return j
	return {}


## Rival de un amistoso: una selección extranjera generada con la misma
## lógica que los clubes del exterior (fuerza objetivo, sin plantel
## persistente — se tira de nuevo cada vez, no hace falta guardarla).
## Simplificación conocida: Uruguay sale de elegir a los mejores de TODA
## la pirámide (miles de jugadores), mientras el rival es una sola tirada
## random alrededor de "fuerza" — por diseño Uruguay suele ser más fuerte
## que un rival "parejo" en teoría, así que estos amistosos pueden salir
## lopsided más seguido que un partido de selecciones real. No afecta nada
## competitivo (ni tabla ni ascensos), es color — golear 17-0 en un
## amistoso no rompe la partida.
static func generar_rival(nombre_pais: String, fuerza: float, rng: RandomNumberGenerator) -> Team:
	return Team.generar("Selección %s" % nombre_pais, rng, ID_BASE_RIVAL, int(round(fuerza)))
