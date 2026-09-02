class_name Rumores
extends RefCounted

## Rumores de mercado: "tal club sigue de cerca a tal jugador".
##
## No mueven a nadie —el que decide los pases sigue siendo el mercado— y
## eso es a proposito: son la parte del feed que te avisa QUE MIRAR. Un
## rumor nombra a un jugador de la division, y desde el feed se le abre la
## ficha y se lo manda a investigar. Sin esto, para encontrar a alguien
## habia que abrir el buscador del mercado y filtrar a ciegas.
##
## Solo salen con el libro de pases abierto: fuera de la ventana nadie
## puede fichar a nadie y un rumor seria ruido.

## Cuantos por dia. Con dos meses de mercado (enero-febrero) y ~0,8 por
## dia, la solapa junta unos cincuenta en la ventana: alcanza para que
## siempre haya algo nuevo sin que tape a las otras categorias.
const CHANCE_SEGUNDO := 0.3

## Lo que ofrecerian, sobre el valor del jugador. Nadie rumorea una oferta
## por debajo del valor: eso no es noticia.
const PRIMA_MIN := 0.95
const PRIMA_MAX := 1.6

## Cuantos objetivos se tantean por rumor. Se eligen al azar y se queda el
## de mejor media entre los que el club pueda pagar: asi los rumores
## tienden a los mejores de la division sin ser siempre los mismos cinco.
const CANDIDATOS := 6

const PLANTILLAS := [
	"%s sigue de cerca a %s (%s, %s). Hablan de %s.",
	"%s quiere llevarse a %s (%s, %s) y pondria %s.",
	"Rumor: %s pregunto por %s (%s, %s). La cifra que suena es %s.",
]


## Devuelve 0, 1 o 2 rumores: {texto, jugador, club}. `liga` es la del
## jugador — es el unico mundo del que se sabe algo. `propio` nunca es el
## que pregunta: el club del jugador no ficha por su cuenta, y leer "tu
## club pregunto por X" cuando no hiciste nada es directamente mentira.
## Como VENDEDOR si entra: que vengan a buscarte a tus jugadores es
## justamente lo que hay que enterarse.
static func generar(liga: Liga, rng: RandomNumberGenerator, propio: Team = null) -> Array:
	var salida := []
	if liga.equipos.size() < 2:
		return salida
	var cuantos := 1 if rng.randf() >= CHANCE_SEGUNDO else 2
	for i in range(cuantos):
		var r := _uno(liga, rng, propio)
		if not r.is_empty():
			salida.append(r)
	return salida


static func _uno(liga: Liga, rng: RandomNumberGenerator, propio: Team) -> Dictionary:
	var comprador: Team = liga.equipos[rng.randi() % liga.equipos.size()]
	if comprador == propio:
		return {}
	var presupuesto: float = float(comprador.caja.get("fichajes", 0.0))
	if presupuesto <= 0.0:
		return {}

	# Se tiran varios candidatos y se queda el MEJOR que el club pueda
	# pagar, en vez de tirar uno solo y descartarlo si no le da la plata:
	# en division 10 las cajas son chicas y con un solo intento no salia
	# casi ningun rumor, que es donde el jugador arranca la partida.
	var mejor := {}
	for intento in range(CANDIDATOS):
		var vendedor: Team = liga.equipos[rng.randi() % liga.equipos.size()]
		if vendedor == comprador or vendedor.jugadores.is_empty():
			continue
		var j: Dictionary = vendedor.jugadores[rng.randi() % vendedor.jugadores.size()]
		var id := int(j["id"])
		var valor: float = ValorJugador.calcular(j,
			vendedor.animo.get(id, 50.0), vendedor.contratos.get(id, 3))
		var oferta: float = valor * rng.randf_range(PRIMA_MIN, PRIMA_MAX)
		# El rumor tiene que poder ser cierto: un club que no tiene con que
		# pagarlo no anda preguntando por el.
		if oferta > presupuesto:
			continue
		if mejor.is_empty() or float(j["media"]) > float(mejor["jugador"]["media"]):
			mejor = {"jugador": j, "club": vendedor, "oferta": oferta}
	if mejor.is_empty():
		return {}

	var objetivo: Dictionary = mejor["jugador"]
	var vendedor_final: Team = mejor["club"]
	var plantilla := str(PLANTILLAS[rng.randi() % PLANTILLAS.size()])
	return {
		"texto": plantilla % [comprador.nombre, ("%s %s" % [
			objetivo.get("nombre", ""), objetivo.get("apellido", "")]).strip_edges(),
			objetivo["posicion"], vendedor_final.nombre,
			Economia.formato_dinero(mejor["oferta"])],
		"jugador": objetivo,
		"club": vendedor_final.nombre,
	}
