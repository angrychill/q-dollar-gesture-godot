extends Control

@onready var label: Label = $MarginContainer/Label
@onready var gesture_node: GestureNode = $GestureNode

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gesture_node.gesture_classified.connect(on_gesture_classified)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_gesture_classified(gesture_name : StringName):
	label.text = gesture_name
