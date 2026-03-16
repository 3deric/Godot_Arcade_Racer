extends Node3D

const SPHERE_OFFSET : Vector3 = Vector3(0.0, -1.0, 0.0)

var acceleration : float = 65.0
var steering : float = 21.0
var steer_rot : float = 0.0
var turn_speed : float = 5.0
var xform= null
var wiggle_velocity : Vector3 = Vector3.ZERO
var spring_strength : float = 100.0
var damping : float = 0.95
var input : Vector2 = Vector2(0.0, 0.0)
var spring_target : Vector3 = Vector3.ZERO
var spring_pos : Vector3 = Vector3.ZERO
var car_up_direction : Vector3 = Vector3.UP

@onready var ray_ground : RayCast3D = $Car/RayCast3D
@onready var rigid_body : RigidBody3D = $RigidBody3D
@onready var car : Node3D = $Car
@onready var car_body_mesh : Node3D = $CarBodyMesh
@onready var car_base_mesh : Node3D = $CarBaseMesh
@onready var cpu_particles_3d: CPUParticles3D = $CarBaseMesh/CPUParticles3D
@onready var steering_fr: Node3D = $CarBaseMesh/steering_fr
@onready var steering_fl: Node3D = $CarBaseMesh/steering_fl
@onready var camera_root: Node3D = $CameraRoot

func _ready() -> void:
	_setup()
	
func _setup():
	ray_ground.add_exception(rigid_body)

func _process(delta: float) -> void:
	_move_camera(delta, 5.0)
	if not ray_ground.is_colliding():
		return
	_input_handler()
	car.global_transform = _rotate_transform(car, delta)
	_wheel_steering(input.x, delta, 5.0)

func _physics_process(delta: float) -> void:
	xform = car.global_transform
	car.transform.origin = rigid_body.transform.origin + SPHERE_OFFSET
	if ray_ground.is_colliding():
		var normal = ray_ground.get_collision_normal()
		if normal.dot(Vector3.UP) > 0.5:
			rigid_body.apply_central_force(car.global_transform.basis.z * input.y * acceleration)
			car.basis = _set_car_up_direction(ray_ground.get_collision_normal())
			car_up_direction = lerp(car_up_direction, car.global_basis.y, delta * 8.0)
	else:
		car_up_direction = lerp(car_up_direction, Vector3.UP, delta * 8.0)
	_wiggle_node(car_body_mesh, delta)
	car_base_mesh.transform = car.transform
	_emit_particles(xform, rigid_body.linear_velocity)	

func _input_handler():
	input.x = int(Input.is_action_pressed('Left')) - int(Input.is_action_pressed('Right'))
	input.y = int(Input.is_action_pressed('Up')) - int(Input.is_action_pressed('Down'))
	
func _wheel_steering(dir : float, delta : float, speed : float):
	# smoothly interpolate rotation of the front wheels
	# has no impact on the gameplay
	steer_rot = lerpf(steer_rot, dir, delta * speed)
	steering_fl.rotation_degrees = Vector3(0,steer_rot * 60,0)
	steering_fr.rotation_degrees = Vector3(0,steer_rot * 60,0)
	
func _rotate_transform(node : Node3D, delta: float):
	# steering logic
	# steering is inverted when the car drives backwards
	# turn speed is based on the current speed, car needs to move to turn
	var _turn_dir : int = 1
	if rigid_body.linear_velocity.dot(xform.basis.z) < 0:
		_turn_dir = -1
	var _turn_speed : float = remap(_round_to_dec(rigid_body.linear_velocity.length(), 2), 0.0, 10.0, 0.0, turn_speed)
	var _new_basis : Basis = node.global_transform.basis.rotated(node.global_transform.basis.y, input.x * deg_to_rad(steering))
	node.global_transform.basis = node.global_transform.basis.slerp(_new_basis, _turn_speed * _turn_dir * delta)
	return node.global_transform.orthonormalized()	
	
func _set_car_up_direction(new_up : Vector3) -> Basis:
	# Calculates a new basis based on the up direction
	var _forward = -xform.basis.z
	var _right = _forward.cross(new_up).normalized()
	var _forward_adjusted = new_up.cross(_right).normalized()
	var _basis = Basis(_right, new_up, -_forward_adjusted)
	return _basis

func _wiggle_node(node : Node3D, delta : float) -> void:
	# Set the spring target position above the car
	var _target_pos : Vector3 = car.global_position + car_up_direction * 5.0
	# Calculate the 2d spring force on the x/z plane
	var _offset : Vector3 = spring_pos - _target_pos
	var _horizontal_offset : Vector3 = _offset - car_up_direction * _offset.dot(car_up_direction)
	wiggle_velocity += -_horizontal_offset * spring_strength * delta
	wiggle_velocity *= damping
	# Keep velocity horizontal
	wiggle_velocity -= car_up_direction * wiggle_velocity.dot(car_up_direction)
	# Update position
	spring_pos = _target_pos + _horizontal_offset + wiggle_velocity * delta
	# Update the orientation of the car body mesh
	var up : Vector3 = (spring_pos - car.global_position).normalized()
	var forward : Vector3= xform.basis.z  # Original forward direction
	var right : Vector3 = up.cross(forward).normalized()
	forward = right.cross(up).normalized()
	node.basis = Basis(right, up, forward)
	node.global_position = rigid_body.global_position + xform.basis.y * SPHERE_OFFSET
	
func _emit_particles(xform : Transform3D, velocity) -> void:
	var _emit : bool = false
	# emit particles on the wheels only when a certain speed threshold is reached
	# emit particles only while drifting left or right
	if abs(xform.basis.x.dot(velocity.normalized())) > 0.35 and velocity.length() > 2.0:
		_emit = true
	cpu_particles_3d.emitting = _emit

func _move_camera(delta, speed) -> void:
	camera_root.position = lerp(camera_root.position, car.position, delta * speed)

func _round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)
