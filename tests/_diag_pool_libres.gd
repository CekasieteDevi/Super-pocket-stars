extends SceneTree

## Medicion (no es test): como se llena y se vacia el pool de agentes
## libres a lo largo de las temporadas, ahora que entran los vencimientos
## de las diez divisiones, la IA ficha de ahi y los que nadie quiere se
## retiran. Correr con:
## godot --headless --script tests/_diag_pool_libres.gd

const SEED := 909
const TEMPORADAS := 16


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	print("temporada  pool  entran  ficha_ia  edad_media  media_media")
	for t in range(TEMPORADAS):
		piramide.jugar_temporada(rng)
		for liga in piramide.divisiones:
			liga.noticias.clear()
		piramide.fin_de_temporada(rng, null, t)
		var entran := 0
		var ficha_ia := 0
		for liga in piramide.divisiones:
			for n in liga.noticias:
				var texto: String = str(n) if typeof(n) == TYPE_STRING else str(n.get("texto", ""))
				if texto.contains("queda libre"):
					entran += 1
				elif texto.contains("ficha libre a"):
					ficha_ia += 1
		var pool: Array = piramide.agentes_libres
		var edad := 0.0
		var media := 0.0
		for a in pool:
			edad += float(a["edad"])
			media += float(a["media"])
		var n: float = maxf(float(pool.size()), 1.0)
		print("%9d  %4d  %6d  %8d  %10.1f  %11.1f" % [
			t + 1, pool.size(), entran, ficha_ia, edad / n, media / n])
	quit()
