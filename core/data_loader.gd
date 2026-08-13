class_name DataLoader
extends RefCounted

static func load_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir " + path)
		return null
	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Error parseando JSON " + path + ": " + json.get_error_message())
		return null
	return json.data
