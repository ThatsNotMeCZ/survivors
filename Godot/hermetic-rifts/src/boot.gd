extends Node


func _ready() -> void:
	var app := get_node_or_null("/root/App")
	var audio := get_node_or_null("/root/GameAudio")
	if app != null and audio != null:
		audio.apply_settings(app.settings)
		audio.play_menu()
