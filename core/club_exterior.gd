class_name ClubExterior
extends RefCounted

## Club del exterior — Fase 7 (GDD §10.5). Identidad horneada y fija
## (nombre, país, fuerza_equipo con deriva lenta); los jugadores NO existen
## hasta que el club se cruza con uno tuyo — generación perezosa, y una vez
## generados quedan guardados (no se vuelven a tirar cada vez).
##
## Nombres reales de clubes: se usan plantillas simples por ahora (no las
## plantillas creíbles por país del §10.1, que son puro contenido/nombres,
## no lógica) — mismo pendiente que los 200 clubes uruguayos (Fix 10 del
## GDD, generación del mundo horneada, todavía no se hizo para nadie).

var nombre: String
var pais: String
var fuerza_equipo: float  # 0-100, con deriva lenta temporada a temporada
var id_base: int  # rango de ids reservado para cuando se materialice

var _equipo: Team = null  # cache: null hasta el primer cruce


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
	var datos := {"nombre": nombre, "pais": pais, "fuerza_equipo": fuerza_equipo, "id_base": id_base}
	if _equipo != null:
		datos["equipo"] = _equipo.guardar()
	return datos


static func cargar(datos: Dictionary) -> ClubExterior:
	var c := ClubExterior.new()
	c.nombre = datos["nombre"]
	c.pais = datos["pais"]
	c.fuerza_equipo = datos["fuerza_equipo"]
	c.id_base = datos["id_base"]
	if datos.has("equipo"):
		c._equipo = Team.cargar(datos["equipo"])
	return c


## Devuelve el Team materializado, generándolo la primera vez que se pide.
func obtener_equipo(rng: RandomNumberGenerator) -> Team:
	if _equipo == null:
		_equipo = Team.generar(nombre, rng, id_base, int(round(fuerza_equipo)))
	return _equipo


## §10.5: la fuerza del club deriva despacio de temporada en temporada
## (un grande puede decaer en 20 años, un chico puede crecer). Si el club
## ya tiene un plantel generado, lo hace medio consistente con la nueva
## fuerza dejando que la progresión normal (§7.1) haga el resto con el
## tiempo — acá solo se mueve el número de referencia para el próximo
## cruce que todavía no generó plantel.
func derivar_fuerza(rng: RandomNumberGenerator) -> void:
	fuerza_equipo = clamp(fuerza_equipo + rng.randf_range(-3.0, 3.0), 20.0, 95.0)
