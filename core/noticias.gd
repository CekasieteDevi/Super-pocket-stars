class_name Noticias
extends RefCounted

## El feed de noticias, con categoria y con los jugadores que menciona.
##
## Hasta ahora una noticia era un String suelto y el feed una sola lista de
## treinta lineas donde todos los hechos se leian igual.
## Con la categoria se puede separar en solapas, y con `jugadores` se puede
## hacer clickeable al que se nombra: de ahi se abre su ficha de mercado y
## se lo manda a investigar sin tener que ir a buscarlo a mano.
##
## Las noticias viejas de una partida guardada son Strings pelados. No se
## pierden: `normalizar` las envuelve y les adivina la categoria por el
## texto, que es lo mismo que hace `clasificar` con las que siguen
## llegando como String desde Liga (son veinte clubes generando fichajes y
## cantera, y no vale la pena estructurar cada una).

## Las solapas del panel, en orden. "todas" no es una categoria que se
## guarde: es la vista sin filtrar.
const SOLAPAS := [
	["todas", "Todas"],
	["fichajes", "Fichajes"],
	["campeones", "Campeones"],
	["club", "Club"],
]

const CATEGORIAS := ["fichajes", "campeones", "club"]


## `jugadores` es una lista de {id, nombre, club} — lo minimo para poder
## abrirle la ficha desde el feed. No se guarda el jugador entero porque
## para cuando se lea la noticia puede haber cambiado de club, de media o
## de todo: el id es lo unico que sigue valiendo.
static func crear(texto: String, categoria: String = "", jugadores: Array = []) -> Dictionary:
	var cat := categoria if CATEGORIAS.has(categoria) else clasificar(texto)
	return {"texto": texto, "cat": cat, "jugadores": jugadores}


## De que habla una noticia que llega como texto pelado. El orden importa:
## "se lesiona jugando el amistoso" habla de una lesion aunque tambien
## mencione la Seleccion, y una venta de urgencia por quiebra es un
## fichaje aunque el titular diga QUIEBRA.
static func clasificar(texto: String) -> String:
	var t := texto.to_lower()
	if t.contains("lesion") or t.contains("lesión"):
		return "lesiones"
	if t.contains("campeon") or t.contains("campeón"):
		return "campeones"
	if t.contains("rumor") or t.contains("sigue de cerca") or t.contains("quiere llevarse"):
		return "rumores"
	if t.contains("fichaj") or t.contains("ficha a") or t.contains("mercado") \
			or t.contains("clausula") or t.contains("cláusula") \
			or t.contains("prestamo") or t.contains("préstamo") \
			or t.contains("agente libre") or t.contains("agentes libres") \
			or t.contains("se lleva a"):
		return "fichajes"
	return "club"


## Una entrada del guardado, venga como String (partidas viejas) o como
## diccionario. Devuelve siempre el diccionario completo.
static func normalizar(entrada) -> Dictionary:
	if entrada is String:
		return crear(str(entrada))
	if entrada is Dictionary:
		var texto := str(entrada.get("texto", ""))
		var jugadores := []
		for j in entrada.get("jugadores", []):
			jugadores.append({
				"id": int(j.get("id", -1)),
				"nombre": str(j.get("nombre", "")),
				"club": str(j.get("club", "")),
			})
		return {
			"texto": texto,
			"cat": str(entrada.get("cat", clasificar(texto))),
			"jugadores": jugadores,
		}
	return crear(str(entrada))


## Como se referencia a un jugador dentro de una noticia.
static func mencion(jugador: Dictionary, club: String) -> Dictionary:
	return {
		"id": int(jugador.get("id", -1)),
		"nombre": "%s %s" % [jugador.get("nombre", ""), jugador.get("apellido", "")],
		"club": club,
	}


## Rumores y lesiones de guardados anteriores quedan fuera del panel.
static func es_visible(entrada: Dictionary) -> bool:
	return CATEGORIAS.has(str(entrada.get("cat", "")))


## Las de una categoria, en el orden en que ya vienen (mas nueva primero).
static func filtrar(lista: Array, categoria: String) -> Array:
	var salida := []
	for n in lista:
		if not es_visible(n):
			continue
		if categoria == "todas" or str(n.get("cat", "")) == categoria:
			salida.append(n)
	return salida
