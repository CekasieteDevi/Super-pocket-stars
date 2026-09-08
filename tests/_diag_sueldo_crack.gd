extends SceneTree

## OJO: este diag midio la amortiguacion ANTES de que existiera en el
## motor. Hoy ValorJugador.media_salarial ya la aplica, asi que las
## columnas amortiguadas de aca la aplican DOS VECES y sus numeros ya no
## son los del juego. Queda por la historia de como se eligio el 0.35;
## para medir el estado actual usar tests/_diag_masa_salarial.gd.

## El caso del jugador: un crack comprado barato en division 10 que en una
## temporada salta a media 76. ¿Cuanto pide y contra que ingreso?
##
## Compara la formula de hoy con dos candidatas:
##   A) amortiguar la media contra la de la division (NivelDivision.media_de)
##   B) topear el sueldo a una fraccion de los ingresos del club

const SEED := 777
const AMORTIGUACION := 0.5
const TOPE_INGRESO := 0.15


func _init() -> void:
	print("Sueldo anual pedido por un jugador segun media (edad 22, animo 50, 3 años)")
	print("media | valor pase | sueldo hoy | sueldo amortiguado div10 | ingreso club div10")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var liga := Liga.new()
	var nombres := []
	var usados := {}
	for i in range(20):
		nombres.append(GeneradorNombres.nombre_club(rng, usados))
	liga.inicializar(nombres, rng, 0, 9)
	var club: Team = liga.equipos[0]
	var informe := Economia.calcular_temporada(club, 10, 20, 9)
	var ingreso: float = float(informe["ingresos"])

	for media in [37, 45, 55, 65, 76, 86, 96]:
		var j := {"media": media, "edad": 22, "id": 1, "nombre": "X", "apellido": "Y",
			"posicion": "MC", "personalidad": ""}
		var valor := ValorJugador.calcular(j, 50.0, 3)
		var sueldo := Economia.sueldo_de_ficha(j, 3)
		var amort := _sueldo_amortiguado(j, 3, 9)
		print("%5d | %10s | %10s | %24s | %s (%.0f%% de los ingresos hoy, %.0f%% amortiguado)" % [
			media, Economia.formato_dinero(valor), Economia.formato_dinero(sueldo),
			Economia.formato_dinero(amort), Economia.formato_dinero(ingreso),
			sueldo / ingreso * 100.0, amort / ingreso * 100.0])

	print("")
	print("Tope por ingresos (B): %.0f%% de %s = %s" % [
		TOPE_INGRESO * 100.0, Economia.formato_dinero(ingreso),
		Economia.formato_dinero(ingreso * TOPE_INGRESO)])

	print("")
	print("Media de referencia por division (NivelDivision.media_de):")
	var linea := ""
	for d in range(10):
		linea += "d%d=%d  " % [d + 1, int(NivelDivision.media_de(d))]
	print("  " + linea)
	quit()


## Candidata A: la media que se paga no es la cruda, es la distancia a la
## media de la division amortiguada. Un crack en decima sigue siendo el
## mejor pago del club, pero no cobra sueldo de primera con ingreso de
## decima.
func _sueldo_amortiguado(jugador: Dictionary, anios: int, division: int) -> float:
	var ref: float = NivelDivision.media_de(division)
	var media: float = float(jugador["media"])
	if media <= ref:
		return Economia.sueldo_de_ficha(jugador, anios)
	var copia := jugador.duplicate()
	copia["media"] = ref + (media - ref) * AMORTIGUACION
	return Economia.sueldo_de_ficha(copia, anios)
