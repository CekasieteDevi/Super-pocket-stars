class_name Confederacion
extends RefCounted

## Sistema internacional — Fase 7 (GDD §10.1-§10.5). 12 países (Uruguay +
## 11 extranjeros), 110 clubes del exterior fijos, coeficiente que decide
## cuántas plazas pone cada país en cada copa, previa de julio, y las tres
## copas internacionales (Campeones/Guerreros/Emergentes) a fase de liga +
## eliminación directa.
##
## Uruguay usa la División 1 (Piramide.divisiones[0]) como su "ranking
## nacional", ordenada por la tabla de la temporada PASADA: la temporada
## internacional arranca junto con el campeonato (iniciar_temporada) y se
## juega repartida en el calendario, no de un saque al cerrar el año.
##
## Nombres de países reales, nunca clubes/escudos reales (aclarado en el
## GDD). Nombres de club y de jugador con pool creíble por país (§10.1,
## core/generador_nombres_internacional.gd + data/nombres_internacional.json)
## — Brasil/España/Inglaterra/Italia/Alemania/Francia/Países Bajos usan la
## plantilla que da el GDD; Argentina/Portugal/México/Colombia (sin
## plantilla explícita en el documento) se armaron con el mismo criterio.

## Orden de coeficiente inicial del GDD §10.1: los primeros 6 ponen 5
## plazas directas en Campeones ("alto"); del 7 al 12 ponen 2 y juegan la
## previa ("bajo"). Uruguay arranca 12°.
const PAISES_INICIALES := [
	"Brasil", "Espana", "Inglaterra", "Italia", "Alemania", "Francia",
	"Argentina", "Portugal", "Paises Bajos", "Mexico", "Colombia", "Uruguay",
]

const CLUBES_POR_PAIS := 10

## Banda de MEDIA de un club del exterior, en la escala de NivelDivision
## (86 = primera division de acá, 62 = cuarta).
##
## Los diez clubes de cada pais son su primera division, asi que ninguno
## puede salir de sexta: el peor pais de la confederacion tiene el nivel
## de una cuarta de acá, no el de una décima. Con la escala vieja
## —fuerza_equipo iba de 20 a 95 y se usaba como potencial, sin
## realizacion— convivian en la misma copa equipos de media 37 y de media
## 88 y salian resultados de 18-0, que es lo que estas constantes vienen a
## arreglar.
const MEDIA_MIN := 60.0
const MEDIA_MAX := 86.0
const LIMITE_TIER_ALTO := 6

var paises: Array = []  # [{"nombre", "coeficiente_score", "clubes":Array[ClubExterior], "es_uruguay":bool}]
var piramide: Piramide


static func generar(piramide: Piramide, rng: RandomNumberGenerator) -> Confederacion:
	var c := Confederacion.new()
	c.piramide = piramide
	var siguiente_id := 100000  # separado del rango 0-2199 de los 200 clubes uruguayos
	var nombres_usados := {}  # compartido entre países: formatos distintos hacen colisión rarísima, pero por las dudas
	for i in range(PAISES_INICIALES.size()):
		var nombre_pais: String = PAISES_INICIALES[i]
		var es_uruguay := nombre_pais == "Uruguay"
		var entry := {
			"nombre": nombre_pais,
			"coeficiente_score": 100.0 - i * 5.0,
			"clubes": [],
			"es_uruguay": es_uruguay,
		}
		if not es_uruguay:
			var fuerza_base: float = lerp(MEDIA_MAX, MEDIA_MIN + 6.0, float(i) / 11.0)
			for j in range(CLUBES_POR_PAIS):
				var fuerza: float = clamp(
					fuerza_base + rng.randf_range(-6.0, 6.0), MEDIA_MIN, MEDIA_MAX)
				var nombre_club := GeneradorNombresInternacional.nombre_club(nombre_pais, rng, nombres_usados)
				var club := ClubExterior.generar(nombre_club, nombre_pais, fuerza, siguiente_id)
				siguiente_id += Team.RANGO_IDS_RESERVADO
				entry["clubes"].append(club)
		c.paises.append(entry)
	return c


## Guardado de partida — ver Team.guardar() / ClubExterior.guardar().
## piramide no viaja en el JSON: se le pasa la que ya se cargó por
## separado (GameState._cargar_partida la carga primero), porque
## Confederacion.piramide es la misma instancia que GameState.piramide, no
## una copia — guardarla dos veces sería redundante y desincronizable.
func guardar() -> Dictionary:
	var paises_datos := []
	for entry in paises:
		var clubes_datos := []
		for c in entry["clubes"]:
			clubes_datos.append(c.guardar())
		paises_datos.append({
			"nombre": entry["nombre"], "coeficiente_score": entry["coeficiente_score"],
			"es_uruguay": entry["es_uruguay"], "clubes": clubes_datos,
		})
	return {"paises": paises_datos}


static func cargar(datos: Dictionary, piramide_cargada: Piramide) -> Confederacion:
	var c := Confederacion.new()
	c.piramide = piramide_cargada
	for entry in datos["paises"]:
		var clubes := []
		for cd in entry["clubes"]:
			clubes.append(ClubExterior.cargar(cd))
		c.paises.append({
			"nombre": entry["nombre"], "coeficiente_score": entry["coeficiente_score"],
			"clubes": clubes, "es_uruguay": entry["es_uruguay"],
		})
	return c


func tier_de(indice: int) -> String:
	return "alto" if indice < LIMITE_TIER_ALTO else "bajo"


## Arranca la temporada internacional: reparte los cupos y deja las tres
## copas listas para jugarse ronda a ronda (ver TemporadaInternacional).
##
## Se llama al EMPEZAR la temporada, no al cerrarla: el club del jugador
## tiene que saber desde el primer día si juega una internacional, y sus
## cruces se juegan intercalados con el campeonato. Por eso el ranking
## nacional de Uruguay sale de la tabla de la temporada PASADA
## (`posiciones`, ver ClasificacionCopas.posiciones_finales) y no de la
## que todavía no se jugó. Con `posiciones` vacío —la primera temporada
## del mundo, o un test— ordena por reputación.
func iniciar_temporada(rng: RandomNumberGenerator, posiciones: Dictionary = {}) -> TemporadaInternacional:
	return TemporadaInternacional.iniciar(_asignar_cupos(rng, posiciones))


## Cierra la temporada internacional ya jugada: recalcula los coeficientes
## con lo que hizo cada país y hace derivar la fuerza de los clubes del
## exterior para el año que viene (§10.5).
func cerrar_temporada(temporada: TemporadaInternacional, rng: RandomNumberGenerator) -> Dictionary:
	var resultado := temporada.resultado()
	var por_copa := []
	for clave in TemporadaInternacional.CLAVES:
		if resultado.has(clave):
			por_copa.append(resultado[clave])
	_recalcular_coeficientes(por_copa)

	for pais in paises:
		for club in pais["clubes"]:
			club.derivar_fuerza(rng)
	return resultado


## La temporada internacional entera de un saque, sin nadie mirando. La
## usan los tests y el cierre de temporada cuando quedan rondas sin jugar.
func jugar_temporada_internacional(rng: RandomNumberGenerator,
		posiciones: Dictionary = {}) -> Dictionary:
	var temporada := iniciar_temporada(rng, posiciones)
	while temporada.hay_pendiente():
		temporada.jugar_siguiente_ronda(rng)
	return cerrar_temporada(temporada, rng)


## Nombre de club -> Team, con la pirámide y los clubes del exterior que
## ya tienen plantel materializado. Es lo que necesita el guardado para
## relocalizar los equipos de las copas internacionales, que están medio
## adentro y medio afuera de la pirámide (ver TemporadaInternacional.cargar).
func indice_de_equipos() -> Dictionary:
	var indice := {}
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			indice[equipo.nombre] = equipo
	for pais in paises:
		for club in pais["clubes"]:
			if club._equipo != null:
				indice[club.nombre] = club._equipo
	return indice


## Los clubes del exterior con plantel materializado. El calendario les
## tiene que pasar los días igual que a los de la pirámide: ahora las
## copas internacionales se juegan repartidas en la temporada, y sin
## recuperación de fatiga ni de lesiones los rivales del exterior se irían
## desgastando ronda a ronda hasta llegar rotos a la final.
func avanzar_dias(dias: int) -> void:
	for pais in paises:
		for club in pais["clubes"]:
			if club._equipo != null:
				club._equipo.avanzar_dias(dias)


## §10.2: cupos por copa según el tier de coeficiente de cada país.
## Tier alto (6 mejores): 1°-5° a Campeones directo, 6°-7° a Guerreros
## directo, 8°-9° a Emergentes directo, 10° no participa.
## Tier bajo (7°-12°, Uruguay arranca acá): 1°-2° a la previa de Campeones,
## 3° a Guerreros directo, 4°-5° a Emergentes directo, 6°-10° no participan.
##
## La previa NO se juega acá: se sortean los seis cruces y se los lleva
## TemporadaInternacional, que la juega como primera ronda de la
## temporada. Antes se resolvía en esta misma función, y eso dejaba
## afuera del calendario un cruce que el club del jugador puede jugar.
func _asignar_cupos(rng: RandomNumberGenerator, posiciones: Dictionary = {}) -> Dictionary:
	var directos_campeones := []
	var directos_guerreros := []
	var directos_emergentes := []
	var candidatos_previa := []

	for indice in range(paises.size()):
		var equipos_ordenados := _ranking_nacional(indice, rng, posiciones)
		if tier_de(indice) == "alto":
			for k in range(0, 5):
				directos_campeones.append(equipos_ordenados[k])
			for k in range(5, 7):
				directos_guerreros.append(equipos_ordenados[k])
			for k in range(7, 9):
				directos_emergentes.append(equipos_ordenados[k])
		else:
			candidatos_previa.append(equipos_ordenados[0])
			candidatos_previa.append(equipos_ordenados[1])
			directos_guerreros.append(equipos_ordenados[2])
			for k in range(3, 5):
				directos_emergentes.append(equipos_ordenados[k])

	# Previa (julio): 12 clubes de los países de tier bajo, 6 cruces a
	# partido único (el GDD pide ida y vuelta; simplificación como el
	# resto de las copas de esta fase — ver nota en Copa).
	var mezclados := _mezclar(candidatos_previa, rng)
	var cruces_previa := []
	for i in range(0, mezclados.size() - 1, 2):
		cruces_previa.append([mezclados[i], mezclados[i + 1]])

	return {
		"campeones": directos_campeones,
		"guerreros": directos_guerreros,
		"emergentes": directos_emergentes,
		"previa": cruces_previa,
	}


## Team ordenados por ranking nacional: para Uruguay, la División 1 por
## la tabla de la temporada PASADA (misma clave de mérito que las copas
## domésticas, ver ClasificacionCopas.ordenar_por_merito); para el resto,
## la mini-tabla abstracta del país.
func _ranking_nacional(indice_pais: int, rng: RandomNumberGenerator,
		posiciones: Dictionary = {}) -> Array:
	var pais: Dictionary = paises[indice_pais]
	if pais["es_uruguay"]:
		return ClasificacionCopas.ordenar_por_merito(piramide.divisiones[0].equipos, posiciones)

	var clubes_ordenados := _mini_tabla(pais["clubes"], rng)
	var out := []
	for club in clubes_ordenados:
		out.append(club.obtener_equipo(rng))
	return out


## §10.1: "cada temporada se corre una mini-tabla abstracta entre los 10
## clubes de cada país (una tirada por cruce)". Todos contra todos a una
## vuelta, resultado abstracto por probabilidad (no un partido simulado
## entero) — barato, como pide el GDD.
func _mini_tabla(clubes: Array, rng: RandomNumberGenerator) -> Array:
	var puntos := {}
	for club in clubes:
		puntos[club] = 0
	for i in range(clubes.size()):
		for j in range(i + 1, clubes.size()):
			var resultado := _resultado_abstracto(clubes[i].fuerza_equipo, clubes[j].fuerza_equipo, rng)
			if resultado == 1:
				puntos[clubes[i]] += 3
			elif resultado == -1:
				puntos[clubes[j]] += 3
			else:
				puntos[clubes[i]] += 1
				puntos[clubes[j]] += 1

	var ordenado: Array = clubes.duplicate()
	ordenado.sort_custom(func(a, b):
		if puntos[a] != puntos[b]:
			return puntos[a] > puntos[b]
		return a.fuerza_equipo > b.fuerza_equipo
	)
	return ordenado


static func _resultado_abstracto(fuerza_a: float, fuerza_b: float, rng: RandomNumberGenerator) -> int:
	var p_gana_a: float = Duel.p_base(fuerza_a, fuerza_b) / 100.0
	var p_empate := 0.24
	var roll := rng.randf()
	if roll < p_empate:
		return 0
	if roll < p_empate + p_gana_a * (1.0 - p_empate):
		return 1
	return -1


## Puntos de fase de liga + un bonus creciente por ronda alcanzada en el
## knockout, sumados por país y aplicados con una deriva lenta (70% del
## coeficiente viejo + lo nuevo) para que no sea 100% volátil temporada a
## temporada. Después reordena países por el coeficiente resultante.
func _recalcular_coeficientes(resultados: Array) -> void:
	var puntos_por_equipo := {}

	for resultado in resultados:
		var fase: FaseLiga = resultado["fase_liga"]
		for nombre in fase.tabla:
			puntos_por_equipo[nombre] = puntos_por_equipo.get(nombre, 0.0) + fase.tabla[nombre]["pts"]

		var knockout: Copa = resultado["knockout"]
		var pesos := [5.0, 8.0, 12.0, 18.0]
		for ronda_idx in range(knockout.historial.size()):
			var peso: float = pesos[ronda_idx] if ronda_idx < pesos.size() else 20.0
			for partido in knockout.historial[ronda_idx]:
				for nombre in [partido["local"], partido["visitante"]]:
					puntos_por_equipo[nombre] = puntos_por_equipo.get(nombre, 0.0) + peso
		if knockout.campeon != null:
			puntos_por_equipo[knockout.campeon.nombre] = puntos_por_equipo.get(knockout.campeon.nombre, 0.0) + 15.0

	var puntos_por_pais := {}
	for i in range(paises.size()):
		puntos_por_pais[i] = 0.0
	for nombre_equipo in puntos_por_equipo:
		var indice := _pais_de_equipo(nombre_equipo)
		if indice >= 0:
			puntos_por_pais[indice] += puntos_por_equipo[nombre_equipo]

	for i in range(paises.size()):
		paises[i]["coeficiente_score"] = paises[i]["coeficiente_score"] * 0.7 + puntos_por_pais[i]

	paises.sort_custom(func(a, b): return a["coeficiente_score"] > b["coeficiente_score"])


func _pais_de_equipo(nombre_equipo: String) -> int:
	for i in range(paises.size()):
		var pais: Dictionary = paises[i]
		if pais["es_uruguay"]:
			for equipo in piramide.divisiones[0].equipos:
				if equipo.nombre == nombre_equipo:
					return i
		else:
			for club in pais["clubes"]:
				if club.nombre == nombre_equipo:
					return i
	return -1


static func _mezclar(equipos: Array, rng: RandomNumberGenerator) -> Array:
	var copia := equipos.duplicate()
	for i in range(copia.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = copia[i]
		copia[i] = copia[j]
		copia[j] = tmp
	return copia
