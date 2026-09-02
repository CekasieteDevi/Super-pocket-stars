class_name ClubExterior
extends RefCounted

## Club del exterior — Fase 7 (GDD §10.5). Identidad horneada y fija
## (nombre, país, fuerza_equipo con deriva lenta); los jugadores NO existen
## hasta que el club se cruza con uno tuyo — generación perezosa, y una vez
## generados quedan guardados (no se vuelven a tirar cada vez).
##
## Nombre del club (Confederacion.generar) y de sus jugadores (acá, al
## materializar el plantel) salen del pool creíble por país del §10.1 —
## ver core/generador_nombres_internacional.gd.

var nombre: String
var pais: String
## La MEDIA que tiene que dar su plantel, en la misma escala que las
## divisiones de la piramide (ver NivelDivision): 86 es una primera
## division como la de acá, 62 es una cuarta. Deriva despacio de una
## temporada a la otra.
##
## Antes era un numero suelto de 0 a 100 que se pasaba como POTENCIAL a
## Team.generar, con la realizacion por defecto. Eso lo dejaba muy por
## debajo de lo que el numero decia: un club "de 75" terminaba con media
## ~56, contra los 86 de la primera division uruguaya, y los cruces
## internacionales daban 18-0. NivelDivision llego despues que esto y
## nunca se conecto — ver MEDIA_MIN/MEDIA_MAX en Confederacion.
var fuerza_equipo: float
var id_base: int  # rango de ids reservado para cuando se materialice

var _equipo: Team = null  # cache: null hasta el primer cruce

## Version de la escala de fuerza_equipo. 1 = la vieja (0-100 usado como
## potencial), 2 = media de NivelDivision. Ver cargar().
const ESCALA := 2


static func generar(nombre: String, pais: String, fuerza_equipo: float, id_base: int) -> ClubExterior:
	var c := ClubExterior.new()
	c.nombre = nombre
	c.pais = pais
	c.fuerza_equipo = fuerza_equipo
	c.id_base = id_base
	return c


## Guardado de partida — si el club nunca se cruzó con el jugador (§10.5,
## "generación perezosa"), _equipo sigue null y no hay plantel que guardar;
## se recupera igual de perezoso la próxima vez que se cruce.
func guardar() -> Dictionary:
	# `escala` marca que fuerza_equipo esta en la escala de medias de
	# NivelDivision. Sin la marca, cargar() sabe que viene de la vieja.
	var datos := {"nombre": nombre, "pais": pais, "fuerza_equipo": fuerza_equipo,
		"id_base": id_base, "escala": ESCALA}
	if _equipo != null:
		datos["equipo"] = _equipo.guardar()
	return datos


static func cargar(datos: Dictionary) -> ClubExterior:
	var c := ClubExterior.new()
	c.nombre = datos["nombre"]
	c.pais = datos["pais"]
	c.id_base = datos["id_base"]
	var vieja: bool = int(datos.get("escala", 1)) < ESCALA
	c.fuerza_equipo = float(datos["fuerza_equipo"])
	if vieja:
		# Partida guardada con la escala vieja (0-100 usado como
		# potencial): se lleva a la banda nueva de medias. El plantel que
		# hubiera quedado cacheado se tira — se genero con el nivel viejo
		# y nunca mas se iba a corregir solo. Se puede tirar sin miedo:
		# ningun club del exterior es tuyo ni te debe nada, y las copas
		# internacionales se juegan enteras de un saque al cerrar la
		# temporada, asi que nunca hay una a medias.
		c.fuerza_equipo = clamp(
			remap(c.fuerza_equipo, 20.0, 95.0, Confederacion.MEDIA_MIN, Confederacion.MEDIA_MAX),
			Confederacion.MEDIA_MIN, Confederacion.MEDIA_MAX)
	elif datos.has("equipo"):
		c._equipo = Team.cargar(datos["equipo"])
	return c


## Devuelve el Team materializado, generándolo la primera vez que se pide.
func obtener_equipo(rng: RandomNumberGenerator) -> Team:
	if _equipo == null:
		# Se genera con el MISMO molde que un club de la piramide: el nivel
		# de division que da esa media, con su potencial y su realizacion.
		# Sin la realizacion el plantel sale crudo y la media queda muy por
		# debajo del numero que pide fuerza_equipo.
		var nivel := NivelDivision.division_para_media(fuerza_equipo)
		_equipo = Team.generar(nombre, rng, id_base, NivelDivision.potencial(nivel),
			pais, NivelDivision.realizacion(nivel))
	return _equipo


## §10.5: la fuerza del club deriva despacio de temporada en temporada
## (un grande puede decaer en 20 años, un chico puede crecer). Si el club
## ya tiene un plantel generado, lo hace medio consistente con la nueva
## fuerza dejando que la progresión normal (§7.1) haga el resto con el
## tiempo — acá solo se mueve el número de referencia para el próximo
## cruce que todavía no generó plantel.
func derivar_fuerza(rng: RandomNumberGenerator) -> void:
	fuerza_equipo = clamp(fuerza_equipo + rng.randf_range(-2.0, 2.0),
		Confederacion.MEDIA_MIN, Confederacion.MEDIA_MAX)
