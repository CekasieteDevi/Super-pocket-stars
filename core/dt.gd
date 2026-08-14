class_name DT
extends RefCounted

## DT rival (§8.6.4) — identidad fija del cuerpo técnico de cada club,
## horneada al generarlo (como nombre/escudo/estilo). Nivel 1-10 + un
## rasgo entre Conservador/Loco/Cantera/Chequera.
##
## Conectado en esta fase:
##  - nivel: define el config_cambios por default del club (Team.gd) — un
##    DT bueno rota bien (ver DT.config_cambios_de), uno malo deja
##    jugadores fundidos en cancha. El jugador humano sigue pudiendo
##    elegir el suyo a mano desde la UI, esto es solo el default de la IA.
##  - Conservador/Loco: modificador de bloque C atado al marcador y al
##    minuto (MatchEngine._bloques_equipo) — Loco tira gente al ataque si
##    va perdiendo pasado el minuto 60 (a costa de la marca), Conservador
##    se repliega si va ganando.
##  - Cantera/Chequera: sesgan las decisiones de fichajes/promoción de la
##    IA (ver core/mercado.gd y Liga._avanzar_cantera).
const RASGOS := ["Conservador", "Loco", "Cantera", "Chequera"]
const NIVEL_MIN := 1
const NIVEL_MAX := 10

const UMBRAL_MINUTO := 60
const BONUS_LOCO := 4.0
const MALUS_LOCO := 4.0
const BONUS_CONSERVADOR := 3.0
const MALUS_CONSERVADOR := 3.0

const ATRIBUTOS_OFENSIVOS := ["pases", "control", "tiro"]


static func generar(rng: RandomNumberGenerator) -> Dictionary:
	return {"nivel": rng.randi_range(NIVEL_MIN, NIVEL_MAX), "rasgo": RASGOS[rng.randi() % RASGOS.size()]}


## §8.6.4: "nivel alto hace bien los cambios, nivel bajo deja jugadores
## fundidos en cancha y no rota" — se traduce directo al umbral que ya usa
## MatchEngine._procesar_cambios (ver Team.config_cambios).
static func config_cambios_de(nivel: int) -> String:
	if nivel <= 3:
		return "rendimiento"
	if nivel >= 8:
		return "descanso"
	return "equilibrado"


## Modificador de bloque C para ESTE equipo en ESTE duelo, según el rasgo
## de su DT, el marcador actual y el minuto. Solo entra en juego pasado
## UMBRAL_MINUTO, para que sea una reacción tardía al resultado (como
## describe el GDD) y no un sesgo desde el arranque del partido.
static func modificador_partido(equipo: Team, rival: Team, atributo: String, minuto: int) -> float:
	if equipo.dt.is_empty() or minuto < UMBRAL_MINUTO:
		return 0.0
	var diferencia: int = equipo.goles - rival.goles
	var ofensivo: bool = ATRIBUTOS_OFENSIVOS.has(atributo)

	match equipo.dt["rasgo"]:
		"Loco":
			if diferencia < 0:
				return BONUS_LOCO if ofensivo else -MALUS_LOCO
		"Conservador":
			if diferencia > 0:
				return -MALUS_CONSERVADOR if ofensivo else BONUS_CONSERVADOR
	return 0.0


## §8.6.4 "Cantera: sube juveniles" / "Chequera: compra y no desarrolla" —
## sesgan qué tan exigente es la IA para promover cantera->banco y
## banco->titular (ver Team.promover_automatico/promover_banco_automatico,
## llamados desde Liga._procesar_cantera). Cantera promueve con una
## diferencia de media mucho menor a la que pediría un club normal;
## Chequera casi no promueve, prefiere resolverlo en el mercado.
const FACTOR_UMBRAL_CANTERA := 0.5
const FACTOR_UMBRAL_CANTERA_CHEQUERA := 1.6


static func factor_umbral_cantera(equipo: Team) -> float:
	if equipo.dt.is_empty():
		return 1.0
	match equipo.dt["rasgo"]:
		"Cantera":
			return FACTOR_UMBRAL_CANTERA
		"Chequera":
			return FACTOR_UMBRAL_CANTERA_CHEQUERA
	return 1.0


## Simétrico para el lado del mercado (core/mercado.gd, Mercado.
## ejecutar_ventana): Chequera acepta comprar por una diferencia de media
## mucho menor (cualquier mejora chica justifica gastar), Cantera pide
## mucha más diferencia porque prefiere resolverlo con su cantera.
const FACTOR_UMBRAL_FICHAJE_CHEQUERA := 0.6
const FACTOR_UMBRAL_FICHAJE_CANTERA := 1.4


static func factor_umbral_fichaje(equipo: Team) -> float:
	if equipo.dt.is_empty():
		return 1.0
	match equipo.dt["rasgo"]:
		"Chequera":
			return FACTOR_UMBRAL_FICHAJE_CHEQUERA
		"Cantera":
			return FACTOR_UMBRAL_FICHAJE_CANTERA
	return 1.0


## Ajuste chico a Mercado.resistencia_venta: Chequera se desprende de
## jugadores más fácil (financia sus compras vendiendo), Cantera es un
## poco más protector de su plantel desarrollado en casa.
const AJUSTE_RESISTENCIA_CHEQUERA := -0.15
const AJUSTE_RESISTENCIA_CANTERA := 0.1


static func ajuste_resistencia_venta(equipo: Team) -> float:
	if equipo.dt.is_empty():
		return 0.0
	match equipo.dt["rasgo"]:
		"Chequera":
			return AJUSTE_RESISTENCIA_CHEQUERA
		"Cantera":
			return AJUSTE_RESISTENCIA_CANTERA
	return 0.0
