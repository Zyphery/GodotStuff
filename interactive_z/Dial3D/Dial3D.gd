@tool
class_name Dial3D
extends Interactive3D
## This node requires a [StaticBody3D] with a [CollisionShape3D] as a child in order to work![br][br]
## This script makes a Node3D interactive as a kind of Dial that the user can interact with.[br]
## It can rotate, snap, and be turned in one direction.[br][br]
## There are multiple modes of interaction and can be defined for each dial.[br]
## When the dial is being rotated it will rotate this [Node3D], you can add a [VisualInstance3D]
## as a child to make it visual in the world.

## Emitted when the dial is turned and the value is changed.[br]
## Param [param turn] is a float for the new turn rotation in radians.
signal value_changed(turn : float)

## Emitted when beginning to turn.
signal turn_started
## Emitted when starting to turn.[br]
## Param [param turn] is a float for the final turn rotation in radians.
signal turn_ended(turn : float)

## Specify how and which mode the dial is interacted with.[br][br]
## [b]CCW/CW:[/b] Rotates from the center (screen position) of the node
## relative to the mouse position in a counter clockwise or, clockwise manner.[br][br]
## [b]LR:[/b] Rotates the dial using the left and right offset of the
## mouse position.[br][br]
## [b]UD:[/b] Acts the same way as [b]LR[/b] but in up and down.[br][br]
## [b]MW:[/b] Uses the mouse wheel up and down motion to rotate the dial.
@export_enum("CCW/CW", "LR", "UD", "MW") var turn_type : int = 0:
	set(v):
		turn_type = v
		
		if not sprite_hint:
			return
		
		match v:
			0:
				sprite_hint.texture = rot_spr
			1:
				sprite_hint.texture = lr_spr
			2:
				sprite_hint.texture = ud_spr
			3:
				sprite_hint.texture = mw_spr

## The current rotation of the dial in degrees.
@export_range(0.0, 0.0, 0.01, "or_less", "or_greater", "hide_slider", "suffix:°") var turn : float = 0.0:
	set(v):
		turn_rad = deg_to_rad(v)
	get:
		return rad_to_deg(turn_rad)

## If [code]true[/code] a [Sprite3D] will be created on [method _ready].
## When [code]enabled[/code] the [Sprite3D] hint will be visible when the dial is selected.
@export var use_hint : bool = true:
	set(v):
		use_hint = v

@export_subgroup("Rotation")
## The vector as which the dial rotates from.[br][br]
## World axis use world vector coordiantes e.g.[br]"[i]World X[/i]" = [code]Vector3(1,0,0)[/code][br][br]
## Local axis use member [member basis] vectors e.g.[br]"[i]Local X[/i]" = [code]basis.x[/code][br][br]
## If set to [param Custom], will use [member custom_axis].
@export_enum("World X", "World Y", "World Z", "Local X", "Local Y", "Local Z", "Custom") var axis_of_rotation : int = 4
## Is based in world coordinates, determines the axis of rotation.[br][br]
## Only used if [member axis_of_rotation] is set to [param Custom].[br]
## Will be normalized when used.
@export var custom_axis : Vector3 = Vector3.UP

@export_subgroup("Limits")
## If [code]true[/code] the dial can only be turned in one direction.[br]
## The direction is based on [member limit_turn_direction].
@export var one_way_turn : bool = false
## Determines the direction the dial can be turned.[br]
## Only occurs if [member one_way_turn] is [code]true[/code]. 
@export_enum("Positive", "Negative") var limit_turn_direction = 0
## If [code]true[/code] the amount the dial can be turned will be clamped between [member min_turn] and [member max_turn].
@export var limit_turn : bool = false
## The minimum turn of the dial in degrees.[br][br]
## This value is used only if [member limit_turn] is set to [code]true[/code].
@export_range(-360.0, 360.0, 0.01, "or_greater", "or_less", "suffix:°") var min_turn : float = 0.0:
	set(v):
		if max_turn < v:
			min_turn = v
			max_turn = v
		
		min_turn = v
		min_turn_rad = deg_to_rad(min_turn)
## The maximum turn of the dial in degrees.[br][br]
## This value is used only if [member limit_turn] is set to [code]true[/code].
@export_range(-360.0, 360.0, 0.01, "or_greater", "or_less", "suffix:°") var max_turn : float = 0.0:
	set(v):
		if min_turn > v:
			min_turn = v
			max_turn = v
		
		max_turn = v
		max_turn_rad = deg_to_rad(max_turn)

@export_subgroup("Values")
## If [code]true[/code] inverts the total turn value
@export var invert_values : bool = false
## If [code]true[/code] the dial will snap to multiples of [member snap_degrees].
@export var snap_values : bool = false
## The amount of degrees to snap to.[br][br]
## This value is used only if [member snap_values] is set to [code]true[/code].
@export_range(0.0, 360.0, 0.01, "suffix:°") var snap_degrees : float = 0.0

var sprite_hint : Sprite3D

var ud_spr = preload("res://addons/interactive_z/Dial3D/icons/UD_dir.png") as Texture
var lr_spr = preload("res://addons/interactive_z/Dial3D/icons/LR_dir.png") as Texture
var rot_spr = preload("res://addons/interactive_z/Dial3D/icons/ROT_dir.png") as Texture
var mw_spr = preload("res://addons/interactive_z/Dial3D/icons/MW_dir.png") as Texture

var is_selected = false

var viewpoint : Camera3D
var last_turn_rad = 0.0
var turn_rad = 0.0
var min_turn_rad
var max_turn_rad

var total_turn : float = 0.0
const wheel_delta = 0.0490874
const move_delta = 0.005

func _create_nodes():
	if use_hint:
		sprite_hint = Sprite3D.new()
		sprite_hint.name = "SpriteHint"
		
		sprite_hint.visible = false
		sprite_hint.texture = rot_spr
		
		sprite_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite_hint.shaded = true
		sprite_hint.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite_hint.alpha_scissor_threshold = 0.375
		sprite_hint.pixel_size = 0.0025
		
		add_child(sprite_hint, false)

func _ready():
	super._ready()
	_create_nodes()
	
	selected.connect(
		func(_mb):
			is_selected = true
			
			if sprite_hint:
				sprite_hint.visible = true
			
			viewpoint = get_viewport().get_camera_3d()
			var center = viewpoint.unproject_position(position)
			var mpos = get_viewport().get_mouse_position()
			last_turn_rad = atan2(center.y - mpos.y, center.x - mpos.x)
			turn_started.emit()
	)
	deselected.connect(
		func(_mb):
			is_selected = false
			
			if sprite_hint:
				sprite_hint.visible = false
			
			turn_ended.emit(turn_rad)
	)

	turn_type = turn_type
	dial(turn_rad)

func _input(event):
	super._input(event)
	if disabled:
		return
	
	if not is_selected:
		return
	
	match turn_type:
		0:
			if event is InputEventMouseMotion:
				var center = viewpoint.unproject_position(position)
				var angle = atan2(center.y - event.position.y, center.x - event.position.x)
				var angle_delta = last_turn_rad - angle
				
				if angle_delta > PI:
					angle_delta -= TAU
				elif angle_delta < -PI:
					angle_delta += TAU
				
				last_turn_rad = angle
				dial(angle_delta)
		1:
			if event is InputEventMouseMotion:
				dial(event.relative.x * -move_delta)
		2:
			if event is InputEventMouseMotion:
				dial(event.relative.y * -move_delta)
		3:
			if event is InputEventMouseButton:
				var scroll = 0.0
				match event.button_index:
					MOUSE_BUTTON_WHEEL_UP:
						scroll = 1.0
					MOUSE_BUTTON_WHEEL_DOWN:
						scroll = -1.0
				dial(scroll * wheel_delta)

## Returns the total number of turns
func get_total_turn() -> float:
	var tt = total_turn
	if invert_values:
		tt = -tt
	if snap_values:
		var snap_rad = deg_to_rad(snap_degrees)
		tt = round(tt / snap_rad) * snap_rad
	return tt / TAU

## Turns the dial by [param delta] amount
## The function is called by internal functions but can be called externally
func dial(delta : float) -> void:
	if one_way_turn:
		match limit_turn_direction:
			0:
				delta = max(0.0, delta)
			1:
				delta = min(0.0, delta)
	
	turn_rad += delta
	total_turn += delta
	
	if limit_turn:
		turn_rad = clamp(turn_rad, min_turn_rad, max_turn_rad)
		total_turn = clamp(total_turn, min_turn_rad, max_turn_rad)
	
	var snapped_turn = turn_rad
	if snap_values:
		var snap_rad = deg_to_rad(snap_degrees)
		snapped_turn = round(snapped_turn / snap_rad) * snap_rad
		
	var rot_basis 
	match axis_of_rotation:
		0:
			rot_basis = Basis(Vector3.RIGHT, snapped_turn)
		1:
			rot_basis = Basis(Vector3.UP, snapped_turn)
		2:
			rot_basis = Basis(Vector3.BACK, snapped_turn)
		3:
			rot_basis = Basis(basis.x, snapped_turn)
		4:
			rot_basis = Basis(basis.y, snapped_turn)
		5:
			rot_basis = Basis(basis.z, snapped_turn)
		6:
			rot_basis = Basis(custom_axis.normalized(), snapped_turn)
	
	basis = rot_basis
	
	value_changed.emit(turn_rad)
