class_name Mercado
extends RefCounted

## Mercado de pases — Fase 6 (GDD §9.3), extendido en la fase del plantel
## de 25 (§14) para usar el banco de verdad. Sigue siendo un INTERCAMBIO
## directo entre dos clubes en la misma posición (no la cadena de
## reemplazo completa del GDD, que necesitaría agentes libres y un mercado
## de ofertas más rico) pero ahora, en vez de que el jugador que llega pise
## el puesto titular a la fuerza en ambos lados: el que compra sube al
## entrante como titular directo y manda a su titular saliente al banco; el
## que vende promueve a su suplente de esa posición y el que llega a cambio
## entra al banco. El único que sale del club de verdad es a quien no le
## queda lugar en el banco.

const UMBRAL_DIFERENCIA_MEDIA := 8.0
const POSICIONES := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]


## equipo_protegido: si se pasa (el club del jugador humano), nunca
## participa de estos intercambios automáticos — el mercado de la IA es
## entre clubes de la IA. Sin esto, el jugador se puede despertar con un
## fichaje que nunca pidió ni vio venir.
static func ejecutar_ventana(liga: Liga, rng: RandomNumberGenerator, equipo_protegido: Team = null) -> Array:
	var transferencias := []
	if liga.equipos.size() < 2:
		return transferencias

	var intentos: int = liga.equipos.size() * 2
	for i in range(intentos):
		var idx_a := rng.randi() % liga.equipos.size()
		var idx_b := rng.randi() % liga.equipos.size()
		if idx_a == idx_b:
			continue
		var club_a: Team = liga.equipos[idx_a]
		var club_b: Team = liga.equipos[idx_b]
		if club_a == equipo_protegido or club_b == equipo_protegido:
			continue

		var posicion: String = POSICIONES[rng.randi() % POSICIONES.size()]
		var indice_a := _indice_en_posicion(club_a, posicion, rng)
		var indice_b := _indice_en_posicion(club_b, posicion, rng)
		if indice_a < 0 or indice_b < 0:
			continue

		var jugador_a: Dictionary = club_a.jugadores[indice_a]
		var jugador_b: Dictionary = club_b.jugadores[indice_b]
		if jugador_a["media"] == jugador_b["media"]:
			continue

		var a_es_mejor: bool = jugador_a["media"] > jugador_b["media"]
		var mejor_club: Team = club_a if a_es_mejor else club_b
		var mejor_jugador: Dictionary = jugador_a if a_es_mejor else jugador_b
		var mejor_indice: int = indice_a if a_es_mejor else indice_b
		var peor_club: Team = club_b if a_es_mejor else club_a
		var peor_jugador: Dictionary = jugador_b if a_es_mejor else jugador_a
		var peor_indice: int = indice_b if a_es_mejor else indice_a

		if mejor_jugador["media"] - peor_jugador["media"] < UMBRAL_DIFERENCIA_MEDIA:
			continue

		var valor_mejor := ValorJugador.calcular(mejor_jugador, mejor_club.animo.get(mejor_jugador["id"], 50.0), mejor_club.contratos.get(mejor_jugador["id"], 1))
		var valor_peor := ValorJugador.calcular(peor_jugador, peor_club.animo.get(peor_jugador["id"], 50.0), peor_club.contratos.get(peor_jugador["id"], 1))
		var diferencia: float = max(0.0, valor_mejor - valor_peor)

		if peor_club.caja["fichajes"] < diferencia:
			continue

		peor_club.caja["fichajes"] -= diferencia
		mejor_club.caja["fichajes"] += diferencia

		# El que compra (peor_club) pisa el puesto titular directo con el
		# que llega — no hay que "banquear" a peor_jugador en peor_club
		# porque se va entero al otro club (ver vender_titular abajo), no
		# se queda de suplente en su club de origen.
		peor_club.jugadores[peor_indice] = mejor_jugador
		peor_club.recalcular_capitan()
		mejor_club.vender_titular(mejor_indice, peor_jugador)

		peor_club._registrar_fichaje(mejor_jugador, valor_mejor)
		mejor_club._registrar_fichaje(peor_jugador, valor_peor)
		peor_club._limpiar_registro(peor_jugador["id"])  # peor_jugador ya no es de este club
		mejor_club._limpiar_registro(mejor_jugador["id"])  # mejor_jugador ya no es de este club

		transferencias.append({
			"jugador_id": mejor_jugador["id"], "posicion": posicion,
			"de": mejor_club.nombre, "a": peor_club.nombre, "valor": valor_mejor,
		})

	return transferencias


## Oferta del jugador humano por un jugador puntual de otro club — a
## diferencia de ejecutar_ventana() (automático, entre clubes de la IA),
## esto lo dispara la UI cuando el usuario elige a alguien. El que sale a
## cambio es siempre tu titular más débil en esa misma posición (pasa a tu
## banco, no se libera), y solo se permite si el objetivo es realmente
## mejor — si no, no tiene sentido la oferta.
static func ofertar_por_jugador(comprador: Team, vendedor: Team, jugador_objetivo_id: int) -> Dictionary:
	var indice_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["id"] == jugador_objetivo_id:
			indice_objetivo = i
			break
	if indice_objetivo < 0:
		return {"exito": false, "motivo": "Ese jugador ya no juega en ese club."}

	var jugador_objetivo: Dictionary = vendedor.jugadores[indice_objetivo]
	var posicion: String = jugador_objetivo["posicion"]

	var indice_saliente := -1
	for i in range(comprador.jugadores.size()):
		if comprador.jugadores[i]["posicion"] == posicion:
			if indice_saliente == -1 or comprador.jugadores[i]["media"] < comprador.jugadores[indice_saliente]["media"]:
				indice_saliente = i
	if indice_saliente < 0:
		return {"exito": false, "motivo": "No tenés ningún jugador en esa posición para dar de cambio."}

	var jugador_saliente: Dictionary = comprador.jugadores[indice_saliente]
	if jugador_objetivo["media"] <= jugador_saliente["media"]:
		return {"exito": false, "motivo": "Tu jugador actual en esa posición ya es igual o mejor."}

	var valor_objetivo := ValorJugador.calcular(jugador_objetivo, vendedor.animo.get(jugador_objetivo["id"], 50.0), vendedor.contratos.get(jugador_objetivo["id"], 1))
	var valor_saliente := ValorJugador.calcular(jugador_saliente, comprador.animo.get(jugador_saliente["id"], 50.0), comprador.contratos.get(jugador_saliente["id"], 1))
	var diferencia: float = max(0.0, valor_objetivo - valor_saliente)

	if comprador.caja["fichajes"] < diferencia:
		return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes.", "diferencia": diferencia, "disponible": comprador.caja["fichajes"]}

	comprador.caja["fichajes"] -= diferencia
	vendedor.caja["fichajes"] += diferencia

	# El comprador pisa el puesto titular directo — jugador_saliente se va
	# entero al club vendedor (ver vender_titular), no se banquea en el
	# suyo propio.
	comprador.jugadores[indice_saliente] = jugador_objetivo
	comprador.recalcular_capitan()
	vendedor.vender_titular(indice_objetivo, jugador_saliente)

	comprador._registrar_fichaje(jugador_objetivo, valor_objetivo)
	vendedor._registrar_fichaje(jugador_saliente, valor_saliente)
	comprador._limpiar_registro(jugador_saliente["id"])  # jugador_saliente ya no es de este club
	vendedor._limpiar_registro(jugador_objetivo["id"])  # jugador_objetivo ya no es de este club

	return {
		"exito": true, "jugador_entra": jugador_objetivo, "jugador_sale": jugador_saliente,
		"diferencia": diferencia, "posicion": posicion,
	}


static func _indice_en_posicion(equipo: Team, posicion: String, rng: RandomNumberGenerator) -> int:
	var candidatos := []
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["posicion"] == posicion:
			candidatos.append(i)
	if candidatos.is_empty():
		return -1
	return candidatos[rng.randi() % candidatos.size()]
