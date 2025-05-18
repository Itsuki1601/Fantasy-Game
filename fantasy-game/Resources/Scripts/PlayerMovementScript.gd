extends CharacterBody3D


#region Character Export Group

## The settings for the character's movement and feel.
@export_category("Character")
## The speed that the character moves at without crouching or sprinting.
@export var base_speed : float = 3.0
## The speed that the character moves at when sprinting.
@export var sprint_speed : float = 6.0
## The speed that the character moves at when crouching.
@export var crouch_speed : float = 1.0

## The fov of the camera when the player is not sprinting.
@export var base_fov : float = 75.0
## The fov of the camera when the player is sprinting.
@export var sprint_fov : float = 85.0

## How fast the character speeds up and slows down when Motion Smoothing is on.
@export var acceleration : float = 10.0
## How high the player jumps.
@export var jump_velocity : float = 4.5
## How far the player turns when the mouse is moved.
@export var mouse_sensitivity : float = 0.1
## Whether the player can use movement inputs. Does not stop outside forces or jumping. See Jumping Enabled.
@export var immobile : bool = false;


@export_file var default_reticle

#endregion


#region Nodes Export Group

@export_group("Nodes")
## A reference to the camera for use in the character script. This is the parent node to the camera and is rotated instead of the camera for mouse input.
@export var HEAD : Node3D
## A reference to the camera for use in the character script.
@export var CAMERA : Camera3D
## A reference to the headbob animation for use in the character script.
@export var COLLISION_MESH : CollisionShape3D

#endregion


#region Controls Export Group

# We are using UI controls because they are built into Godot Engine so they can be used right away
@export_group("Controls")
## Use the Input Map to map a mouse/keyboard input to an action and add a reference to it to this dictionary to be used in the script.
@export var controls : Dictionary = {
	LEFT = "strafe_left",
	RIGHT = "strafe_right",
	FORWARD = "move_forward",
	BACKWARD = "move_backward",
	JUMP = "jump",
	CROUCH = "crouch",
	SPRINT = "sprint",
	PAUSE = "pause"
	}

#endregion


#region Feature Settings Export Group

@export_group("Feature Settings")
## Enable or disable jumping. Useful for restrictive storytelling environments.
@export var jumping_enabled : bool = true
## Smooths the feel of walking.
@export var motion_smoothing : bool = true
## Enables or disables sprinting.
@export var sprint_enabled : bool = true
## Enables or disables crouching.
@export var crouch_enabled : bool = true
## Wether sprinting should effect FOV.
@export var dynamic_fov : bool = true
## Enables an immersive animation when the player jumps and hits the ground.
@export var jump_animation : bool = true
## This determines wether the player can use the pause button, not wether the game will actually pause.
@export var pausing_enabled : bool = true

#endregion


#region Member Variable Initialization

# These are variables used in this script that don't need to be exposed in the editor.
var speed : float = base_speed
var current_speed : float = 0.0
# States: normal, crouching, sprinting
var state : String = "normal"
var low_ceiling : bool = false # This is for when the ceiling is too low and the player needs to crouch.
var was_on_floor : bool = true # Was the player on the floor last frame (for landing animation)

# The reticle should always have a Control node as the root
var RETICLE : Control

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity") # Don't set this as a const, see the gravity section in _physics_process

# Stores mouse input for rotating the camera in the physics process
var mouseInput : Vector2 = Vector2(0,0)

#endregion


#region Main Control Flow

func _ready():
	#It is safe to comment this line if your game doesn't start with the mouse captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# If the controller is rotated in a certain direction for game design purposes, redirect this rotation into the head.
	HEAD.rotation.y = rotation.y
	rotation.y = 0

	if default_reticle:
		change_reticle(default_reticle)

	initialize_animations()
	enter_normal_state()

func _process(_delta):
	if pausing_enabled:
		handle_pausing()
		
	update_debug_menu_per_frame()

func _physics_process(delta):
	if not is_on_floor() and gravity:
		velocity.y -= gravity * delta
	
	handle_jumping()
	
	var input_dir = Vector2.ZERO
	
	if not immobile:
		input_dir = Input.get_vector(controls.LEFT, controls.RIGHT, controls.FORWARD, controls.BACKWARD)
	
	handle_movement(delta, input_dir)
	
	handle_head_rotation()
	
	# The player is not able to stand up if the ceiling is too low.
	low_ceiling = $CrouchCeilingDetection.is_colliding()
	
	handle_state(input_dir)
	if dynamic_fov: # This may be changed to an AnimationPlayer
		update_camera_fov()
	
	update_debug_menu_per_tick()
	
	was_on_floor = is_on_floor() # Must always be at the end of the physics process.

#endregion


#region Input Handling

func handle_jumping():
	if jumping_enabled:
		if Input.is_action_just_pressed(controls.JUMP) and is_on_floor() and !low_ceiling:
			# play jump animation
			velocity.y += jump_velocity

func handle_movement(delta, input_dir):
	var direction = input_dir.rotated(-HEAD.rotation.y)
	direction = Vector3(direction.x, 0, direction.y)
	move_and_slide()

	if is_on_floor():
		if motion_smoothing:
			velocity.x = lerp(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = lerp(velocity.z, direction.z * speed, acceleration * delta)
		else:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed

func handle_head_rotation():
	HEAD.rotation_degrees.y -= mouseInput.x * mouse_sensitivity
	HEAD.rotation_degrees.x -= mouseInput.y * mouse_sensitivity
	
	mouseInput = Vector2.ZERO
	HEAD.rotation.x = clamp(HEAD.rotation.x, deg_to_rad(-90), deg_to_rad(90))

#endregion


#region State Handling

func handle_state(moving):
	if sprint_enabled:
		if Input.is_action_pressed(controls.SPRINT) and state != "couching":
			if moving:
				if state != "sprinting":
					enter_sprint_state()
			else:
				if state == "sprinting":
					enter_normal_state()
		elif state == "sprinting":
			enter_normal_state()
	
	if crouch_enabled:
		if Input.is_action_pressed(controls.CROUCH) and state != "sprinting":
			if state != "crouching":
				enter_crouch_state()
		elif state == "crouching" and !$CrouchCeilingDetection.is_colliding():
			enter_normal_state()

# Any enter state function should only be called when you enter the state and not every frame.
func enter_normal_state():
	var prev_state = state
	if prev_state == "crouching":
		pass
		#play uncrouch animation
	state = "normal"
	speed = base_speed

func enter_crouch_state():
	state = "crouching"
	speed = crouch_speed
	# play crouch animation
	
func enter_sprint_state():
	var prev_state = state
	if prev_state == "crouching":
		pass
		#play uncrouch animation
	state = "sprinting"
	speed = sprint_speed

#endregion

#region Animation Handling
func initialize_animations():
	pass

#endregion


#region DebugMenu
	
func update_debug_menu_per_frame():
	$UserInterface/DebugPanel.add_property("FPS", Performance.get_monitor(Performance.TIME_FPS), 0)
	var status : String = state
	if !is_on_floor():
		status += " in the air"
	$UserInterface/DebugPanel.add_property("State", status, 4)

func update_debug_menu_per_tick():
	current_speed = Vector3.ZERO.distance_to(get_real_velocity())
	$UserInterface/DebugPanel.add_property("Speed", snappedf(current_speed, 0.001), 1)
	$UserInterface/DebugPanel.add_property("Target speed", speed, 2)
	var cv : Vector3 = get_real_velocity()
	var vd : Array[float] = [
		snappedf(cv.x, 0.001),
		snappedf(cv.y, 0.001),
		snappedf(cv.z, 0.001),
	]
	var readable_velocity : String = "X: " + str(vd[0]) + "Y: " + str(vd[1])+ "Z: " + str(vd[2])
	$UserInterface/DebugPanel.add_property("Velocity", readable_velocity, 3)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseInput.x += event.relative.x
		mouseInput.y += event.relative.y
	#Toggle debug menu
	elif event is InputEventKey:
		if event.is_released():
			# This is defo going to need to change.
			if event.keycode == 4194338: # F7
				$UserInterface/DebugPanel.visible = $UserInterface/DebugPanel.visible

#endregion


#region Misc Functions

func change_reticle(reticle):
	if RETICLE:
		RETICLE.queue_free()
	
	RETICLE = load(reticle).instantiate()
	RETICLE.character = self
	$UserInterface.add_child(RETICLE)

func update_camera_fov():
	if state == "sprinting":
		CAMERA.fov = lerp(CAMERA.fov, sprint_fov, 0.3)
	else:
		CAMERA.fov = lerp(CAMERA.fov, base_fov, 0.3)

func handle_pausing():
	if Input.is_action_just_pressed(controls.PAUSE):
		# May want another node to handle pausing, because this player may get paused too.
		match Input.mouse_mode:
			Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				#get_tree().paused = false
			Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				#get_tree().paused = true

#endregion
