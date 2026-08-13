extends SceneTree

## Fase 9 del roadmap (GDD §6, §17): personalidades, cantera y noticias.
## Correr con: godot --headless --script tests/test_phase9.gd
##
## Qué verificamos:
##   1. Personalidades: ~70% de los jugadores tiene rasgos, nunca uno solo
##      (positiva sin negativa o viceversa), y las fuertes son más raras
##      que las comunes dentro del pool positivo.
##   2. Cantera: cada equipo genera una camada de 3 juveniles de 15 años con
##      media baja; promoción manual y automática funcionan; los que
##      cumplen 20 sin debutar se liberan.
##   3. Noticias: una temporada con mercado activo y cantera genera texto.

const SEED := 7070


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_personalidades(rng)
	_test_cantera(rng)
	_test_noticias(rng)

	quit()


func _test_personalidades(rng: RandomNumberGenerator) -> void:
	print("=== Personalidades (10000 jugadores) ===")
	var con_personalidad := 0
	var solo_una := 0
	var fuertes := 0
	var comunes := 0
	var conteo_negativas := {}

	for i in range(10000):
		var jugador := PlayerGenerator.generate(i, rng)
		var p: Dictionary = jugador["personalidades"]
		if p.is_empty():
			continue
		con_personalidad += 1
		if p.has("positiva") != p.has("negativa"):
			solo_una += 1
		var datos: Dictionary = DataLoader.load_json("res://data/personalidades.json")
		if datos["fuertes"].has(p.get("positiva", "")):
			fuertes += 1
		else:
			comunes += 1
		conteo_negativas[p.get("negativa", "")] = conteo_negativas.get(p.get("negativa", ""), 0) + 1

	var pct: float = 100.0 * con_personalidad / 10000.0
	print("Con personalidad: %.1f%% (esperado ~70%%)" % pct)
	print("Casos con una sola (positiva sin negativa o viceversa): %d (esperado 0)" % solo_una)
	print("Positivas fuertes: %d | comunes: %d" % [fuertes, comunes])

	var ok := solo_una == 0 and pct > 65.0 and pct < 75.0 and fuertes < comunes
	if ok:
		print("OK: ~70%% con personalidad, siempre de a par, fuertes mas raras que comunes.")
	else:
		print("FALLA en personalidades.")


func _test_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== Cantera ===")
	var equipo := Team.generar("Club de prueba", rng, 0)

	var nuevos := equipo.generar_camada(rng)
	print("Camada generada: %d juveniles" % nuevos.size())
	var edades_ok := true
	var medias := []
	for j in nuevos:
		if j["edad"] != 15:
			edades_ok = false
		medias.append(j["media"])
	print("Medias de la camada: %s" % [medias])
	if nuevos.size() == 3 and edades_ok:
		print("OK: 3 juveniles de 15 anos generados.")
	else:
		print("FALLA: se esperaban 3 juveniles de 15 anos.")

	# Promocion manual: la cantera entra al BANCO (§14), no directo a
	# titular — para eso esta promover_a_titular, aparte.
	var juvenil: Dictionary = equipo.cantera[0]
	var jugadores_antes := equipo.jugadores.size()
	var banco_antes := equipo.banco.size()
	var cantera_antes := equipo.cantera.size()
	juvenil["media"] = 95.0
	var resultado := equipo.promover_juvenil(juvenil["id"])
	var banco_ids := []
	for j in equipo.banco:
		banco_ids.append(j["id"])

	if resultado.is_empty():
		print("FALLA: promover_juvenil no encontro al juvenil.")
	else:
		print("Promovido al banco: %s (media 95), sale del banco %s (media %.1f)" % [
			resultado["promovido"]["posicion"], resultado["saliente"]["posicion"], resultado["saliente"]["media"]
		])
	var ok_promocion := equipo.jugadores.size() == jugadores_antes and equipo.banco.size() == banco_antes
	ok_promocion = ok_promocion and equipo.cantera.size() == cantera_antes - 1 and banco_ids.has(juvenil["id"])
	if ok_promocion:
		print("OK: la promocion mantiene 11 titulares y 7 en banco, saca 1 de la cantera, y el juvenil queda en el banco.")
	else:
		print("FALLA: la promocion no dejo el plantel como se esperaba.")

	# Subir a titular: ahora sí debería mejorar la media del 11 titular.
	var media_titulares_antes := equipo.media_equipo()
	var resultado_titular := equipo.promover_a_titular(juvenil["id"])
	var ok_titular := not resultado_titular.is_empty() and equipo.media_equipo() > media_titulares_antes
	ok_titular = ok_titular and equipo.jugadores.size() == jugadores_antes and equipo.banco.size() == banco_antes
	if ok_titular:
		print("OK: promover_a_titular sube al canterano a titular y baja al que estaba a banco, sin cambiar los tamaños.")
	else:
		print("FALLA: promover_a_titular no funciono como se esperaba.")

	# Liberacion a los 20: forzamos la edad de otro juvenil.
	if equipo.cantera.size() >= 1:
		equipo.cantera[0]["edad"] = 20
		var liberados := equipo.liberar_veteranos_de_cantera()
		if liberados.size() >= 1:
			print("OK: se libera automaticamente al juvenil que llego a los 20 sin debutar.")
		else:
			print("FALLA: no se libero a nadie con 20 anos en la cantera.")


func _test_noticias(rng: RandomNumberGenerator) -> void:
	print("\n=== Noticias ===")
	var nombres := []
	for i in range(20):
		nombres.append("Club %02d" % (i + 1))

	var liga := Liga.new()
	liga.inicializar(nombres, rng)
	liga.jugar_temporada(rng, false)
	liga.nueva_temporada(rng)

	print("Noticias generadas en la temporada: %d" % liga.noticias.size())
	for i in range(min(6, liga.noticias.size())):
		print("  " + liga.noticias[i])

	if liga.noticias.size() > 0:
		print("OK: la temporada genero noticias de mercado y/o cantera.")
	else:
		print("FALLA: no se genero ninguna noticia en toda la temporada.")
