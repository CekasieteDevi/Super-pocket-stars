extends SceneTree
## Cuánto cuesta cada parte del paso de MundoV2 (etapa 0), en us por paso.
func _initialize() -> void:
	var m := MundoV2.new(20260929)
	var c := CerebroFalsoV2.new(m)
	var t := {"cerebro": 0, "cuerpos": 0, "separar": 0, "pelota": 0}
	var n := 60 * 60 * 10
	for k in n:
		var a := Time.get_ticks_usec()
		c.pensar()
		var b := Time.get_ticks_usec()
		m.pos_previa = m.pos
		m.pelota_previa = m.pelota_pos
		m._mover_cuerpos()
		var c2 := Time.get_ticks_usec()
		var d := Time.get_ticks_usec()
		m._separar_cuerpos()
		var e := Time.get_ticks_usec()
		m._mover_pelota()
		var f := Time.get_ticks_usec()
		m.paso += 1
		t["cerebro"] += b - a
		t["cuerpos"] += c2 - b
		t["separar"] += e - d
		t["pelota"] += f - e
	for k in t:
		print("%s %.2f us" % [k, float(t[k]) / n])
	quit()
