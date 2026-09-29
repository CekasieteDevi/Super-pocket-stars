extends SceneTree
## -- a.png b.png salida.png : cuenta pixeles distintos y guarda la diferencia x4.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var a := Image.load_from_file(args[0])
	var b := Image.load_from_file(args[1])
	var d := Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8)
	var n := 0
	var mx := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var m := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			mx = maxf(mx, m)
			if m > 8.0 / 255.0: n += 1
			d.set_pixel(x, y, Color(minf(1, absf(ca.r - cb.r) * 4), minf(1, absf(ca.g - cb.g) * 4), minf(1, absf(ca.b - cb.b) * 4)))
	d.save_png(args[2])
	print("DISTINTOS>8: ", n, " MAX: ", roundi(mx * 255))
	quit()
