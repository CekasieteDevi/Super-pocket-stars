extends SceneTree

## OJO: este diag midio la amortiguacion ANTES de que existiera en el
## motor. Hoy ValorJugador.media_salarial ya la aplica, asi que las
## columnas amortiguadas de aca la aplican DOS VECES y sus numeros ya no
## son los del juego. Queda por la historia de como se eligio el 0.35;
## para medir el estado actual usar tests/_diag_masa_salarial.gd.

## Solucion 1: el sueldo se paga por lo que destacas SOBRE tu division,
## no por tu media cruda. El de media alta sigue cobrando mas que el de
## media baja — la funcion es creciente — pero la distancia se achica.
##
##   media_efectiva = media_de(division) + (media - media_de(division)) * k
##
## Solo para el SUELDO (ValorJugador.base_salarial). El pase no se toca:
## el escalon de elite queda igual y un crack se sigue vendiendo caro.

const SEED := 777
const VALORES := [1.0, 0.5, 0.35, 0.25]
const MEDIAS := [30, 37, 45, 55, 65, 76, 86, 96]


func _init() -> void:
	var ingresos := _ingresos_por_division()

	for division in [9, 7, 4, 2]:
		var ref: float = NivelDivision.media_de(division)
		var ing: float = ingresos[division]
		print("")
		print("=== DIVISION %d — media de referencia %d — ingresos del club %s ===" % [
			division + 1, int(ref), Economia.formato_dinero(ing)])
		var cab := "media | ef.k=.35 | sueldo hoy |"
		for v in VALORES:
			cab += " k=%.2f |" % v
		print(cab + " pct.ing hoy | pct.ing k=.35 | veces el de media %d" % int(ref))
		var base_ref := _sueldo(_jug(int(ref)), division, 0.35)
		for media in MEDIAS:
			var j := _jug(media)
			var hoy := _sueldo(j, division, 1.0)
			var fila := "%5d | %9d | %10s |" % [
				media, int(_media_efectiva(media, ref, 0.35)),
				Economia.formato_dinero(hoy)]
			for v in VALORES:
				fila += " %7s |" % Economia.formato_dinero(_sueldo(j, division, float(v)))
			var k35 := _sueldo(j, division, 0.35)
			print(fila + " %10.1f%% | %12.1f%% | %.2fx" % [
				hoy / ing * 100.0, k35 / ing * 100.0, k35 / maxf(base_ref, 0.01)])

	print("")
	print("=== EL MISMO JUGADOR (media 76, edad 22) SEGUN DONDE JUEGUE, k=0.35 ===")
	print("div | ref | sueldo hoy | sueldo k=0.35 | %ingresos hoy | %ingresos k=0.35")
	for division in range(10):
		var j := _jug(76)
		var hoy := _sueldo(j, division, 1.0)
		var k35 := _sueldo(j, division, 0.35)
		var ing: float = ingresos[division]
		print("%3d | %3d | %10s | %13s | %12.0f%% | %14.1f%%" % [
			division + 1, int(NivelDivision.media_de(division)),
			Economia.formato_dinero(hoy), Economia.formato_dinero(k35),
			hoy / ing * 100.0, k35 / ing * 100.0])

	print("")
	print("=== EL PASE NO SE TOCA (ValorJugador.calcular, sin cambios) ===")
	for media in [55, 65, 76, 86, 96]:
		print("  media %2d: pase %s" % [
			media, Economia.formato_dinero(ValorJugador.calcular(_jug(media), 50.0, 3))])
	quit()


func _jug(media: int) -> Dictionary:
	return {"media": media, "edad": 22, "id": 1, "nombre": "X", "apellido": "Y",
		"posicion": "MC", "personalidad": ""}


func _media_efectiva(media: float, ref: float, k: float) -> float:
	if media <= ref:
		return media
	return ref + (media - ref) * k


func _sueldo(jugador: Dictionary, division: int, k: float) -> float:
	var copia := jugador.duplicate()
	copia["media"] = _media_efectiva(
		float(jugador["media"]), NivelDivision.media_de(division), k)
	return Economia.sueldo_de_ficha(copia, 3)


## Ingreso del club promedio de cada division, para poder decir "esto es
## el X% de lo que entra". Se mide con calcular_temporada, que no toca al
## club.
func _ingresos_por_division() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var salida := []
	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var suma := 0.0
		for i in range(liga.equipos.size()):
			suma += float(Economia.calcular_temporada(
				liga.equipos[i], i + 1, liga.equipos.size(), d)["ingresos"])
		salida.append(suma / liga.equipos.size())
	return salida
