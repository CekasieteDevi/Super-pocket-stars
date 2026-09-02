class_name Confederacion
extends RefCounted

## Sistema internacional — Fase 7 (GDD §10.1-§10.5). 12 países (Uruguay +
## 11 extranjeros), 110 clubes del exterior fijos, coeficiente que decide
## cuántas plazas pone cada país en cada copa, previa de julio, y las tres
## copas internacionales (Campeones/Guerreros/Emergentes) a fase de liga +
## eliminación directa.
##
## Uruguay usa la tabla de División 1 (Piramide.divisiones[0]) como su
## "ranking nacional" — llamar a jugar_temporada_internacional() DESPUÉS de
## Piramide.jugar_temporada() pero ANTES de Piramide.fin_de_temporada()
## (que resetea esa tabla para la temporada siguiente).
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


## Corre la temporada internacional completa: arma los cupos (mini-tablas +
## previa), juega las tres copas, y recalcula los coeficientes con el
## resultado. Devuelve el detalle de cada copa.
func jugar_temporada_internacional(rng: RandomNumberGenerator) -> Dictionary:
	var cupos := _asignar_cupos(rng)

	var fase_campeones := FaseLiga.iniciar("Copa de Campeones", cupos["campeones"], 8)
	var fase_guerreros := FaseLiga.iniciar("Copa de Guerreros", cupos["guerreros"], 6)
	var fase_emergentes := FaseLiga.iniciar("Copa de Emergentes", cupos["emergentes"], 6)

	var resultado_campeones := _jugar_copa_con_fase_liga(fase_campeones, rng)
	var resultado_guerreros := _jugar_copa_con_fase_liga(fase_guerreros, rng)
	var resultado_emergentes := _jugar_copa_con_fase_liga(fase_emergentes, rng)

	_recalcular_coeficientes([resultado_campeones, resultado_guerreros, resultado_emergentes])

	for pais in paises:
		for club in pais["clubes"]:
			club.derivar_fuerza(rng)

	return {
		"campeones": resultado_campeones, "guerreros": resultado_guerreros, "emergentes": resultado_emergentes,
		"previa": cupos["previa_resultados"],
	}


## §10.2: cupos por copa según el tier de coeficiente de cada país.
## Tier alto (6 mejores): 1°-5° a Campeones directo, 6°-7° a Guerreros
## directo, 8°-9° a Emergentes directo, 10° no participa.
## Tier bajo (7°-12°, Uruguay arranca acá): 1°-2° a la previa de Campeones,
## 3° a Guerreros directo, 4°-5° a Emergentes directo, 6°-10° no participan.
func _asignar_cupos(rng: RandomNumberGenerator) -> Dictionary:
	var directos_campeones := []
	var directos_guerreros := []
	var directos_emergentes := []
	var candidatos_previa := []

	for indice in range(paises.size()):
		var equipos_ordenados := _ranking_nacional(indice, rng)
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
	var ganadores_previa := []
	var perdedores_previa := []
	var resultados_previa := []
	for i in range(0, mezclados.size(), 2):
		var a: Team = mezclados[i]
		var b: Team = mezclados[i + 1]
		var r := MatchEngine.simular(a, b, rng, false)
		var ganador: Team = a if r["goles_local"] >= r["goles_visitante"] else b
		var perdedor: Team = b if ganador == a else a
		ganadores_previa.append(ganador)
		perdedores_previa.append(perdedor)
		resultados_previa.append({"local": a.nombre, "visitante": b.nombre, "gl": r["goles_local"], "gv": r["goles_visitante"], "ganador": ganador.nombre})

	return {
		"campeones": directos_campeones + ganadores_previa,
		"guerreros": directos_guerreros + perdedores_previa,
		"emergentes": directos_emergentes,
		"previa_resultados": resultados_previa,
	}


## Team ordenados por ranking nacional: la tabla de División 1 para
## Uruguay, la mini-tabla abstracta del país para el resto.
func _ranking_nacional(indice_pais: int, rng: RandomNumberGenerator) -> Array:
	var pais: Dictionary = paises[indice_pais]
	if pais["es_uruguay"]:
		var division1: Liga = piramide.divisiones[0]
		var mapa := {}
		for equipo in division1.equipos:
			mapa[equipo.nombre] = equipo
		var out := []
		for nombre in division1.tabla_ordenada():
			out.append(mapa[nombre])
		return out

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


## §10.3: fase de liga completa, top 8 directo a octavos, el resto (hasta
## 16 más) juega un playoff a partido único por los últimos 8 lugares de
## octavos, y de ahí en más eliminación directa hasta la final.
## Simplificación documentada: el GDD marca ida y vuelta desde octavos y
## bombos por coeficiente para armar la fase de liga — acá todo el
## knockout es a partido único (reutiliza Copa) y el fixture de la fase de
## liga no arma bombos, ver notas en Copa y FaseLiga.
func _jugar_copa_con_fase_liga(fase: FaseLiga, rng: RandomNumberGenerator) -> Dictionary:
	fase.jugar_temporada(rng)
	var ordenados := fase.equipos_ordenados()
	var n := ordenados.size()

	var directos: Array = ordenados.slice(0, 8)
	var resto: Array = ordenados.slice(8, n)
	var tamano_pool: int = min(16, resto.size())
	var pool_playoff: Array = resto.slice(0, tamano_pool)
	var eliminados: Array = resto.slice(tamano_pool, resto.size())

	var ganadores_playoff := []
	var partidos_playoff := []
	for i in range(tamano_pool / 2):
		var a: Team = pool_playoff[i]
		var b: Team = pool_playoff[tamano_pool - 1 - i]
		var r := MatchEngine.simular(a, b, rng, false)
		var ganador: Team = a if r["goles_local"] >= r["goles_visitante"] else b
		ganadores_playoff.append(ganador)
		partidos_playoff.append({"local": a.nombre, "visitante": b.nombre, "gl": r["goles_local"], "gv": r["goles_visitante"], "ganador": ganador.nombre})

	var equipos_octavos: Array = directos + ganadores_playoff
	var knockout := Copa.iniciar("%s - Eliminacion" % fase.nombre, equipos_octavos, rng)
	while knockout.campeon == null:
		knockout.jugar_siguiente_ronda(rng)

	return {
		"fase_liga": fase, "eliminados_pre_playoff": eliminados,
		"partidos_playoff": partidos_playoff, "knockout": knockout, "campeon": knockout.campeon,
	}


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
