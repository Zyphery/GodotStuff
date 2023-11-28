class_name Interactive3D
extends Node3D

## Emitted when disabled flag is changed.[br]
## Param [param disabled] is a bool for the new disabled state.
signal disabled_changed(disabled : bool)

signal selected(mouse_button)
signal deselected(mouse_button)

## If [code]false[/code] the Node cannot be interacted with.
@export var disabled : bool = false:
	set(v):
		disabled = v

## Binary mask to choose which mouse buttons this button will respond to.[br][br]
## To allow both left-click and right-click, use [code]MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT[/code].
@export_flags("Mouse Left:1", "Mouse Right:2") var button_mask : int = 1

var is_hovered : bool = false

var collider : CollisionObject3D

func _ready():
	for sbc in get_children():
		if sbc is CollisionObject3D:
			collider = sbc
			break
			
	collider.mouse_entered.connect(
		func():
			if disabled:
				return
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			is_hovered = true
			)
	
	collider.mouse_exited.connect(
		func():
			if disabled:
				return
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			is_hovered = false
			)

func _input(event):
	if disabled:
		return
	
	if event is InputEventMouseButton:
		if (1 << event.button_index - 1) & button_mask != 0:
			if event.pressed:
				if is_hovered:
					selected.emit(event.button_index)
			else:
				deselected.emit(event.button_index)

func get_collider() -> CollisionObject3D:
	return collider
