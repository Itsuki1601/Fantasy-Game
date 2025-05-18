extends PanelContainer


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if visible:
		pass

func add_property(title: String, value, order: int):
	var target
	target = $MarginContainer/VBoxContainer.find_child(title, true, false)
	if !target:
		target = Label.new()
		$MarginContainer/VboxContainer.add_child(target)
		target.name = title
		target.text = title + ": " + str(value)
	elif visible:
		target.text = title + ": " + str(value)
		$MarginContainer/VBoxContainer.move_child(target, order)
