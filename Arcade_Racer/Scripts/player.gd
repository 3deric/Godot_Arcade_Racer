extends Node3D

const SPHERE_OFFSET : Vector3 = Vector3(0.0, -1.0, 0.0)

var acceleration : float = 65
var steering : float = 21.0
var turn_speed : float = 5.0
var turn_stop_limit = 0.75
var xform = null
var wiggle_velocity : Vector3 = Vector3.ZERO
var spring_strength : float = 100.0
var damping : float = 0.95
var input : Vector2 = Vector2(0.0, 0.0)
var spring_target : Vector3 = Vector3.ZERO

@onready var ray_ground : RayCast3D = $Car/RayCast3D
@onready var rigid_body : RigidBody3D = $RigidBody3D
@onready var car : Node3D = $Car
@onready var wiggle_offset: Node3D = $WiggleOffset
@onready var car_mesh : Node3D = $CarMesh
@onready var cpu_particles_3d: CPUParticles3D = $Car/CPUParticles3D
@onready var steering_fr: Node3D = $Car/steering_fr
@onready var steering_fl: Node3D = $Car/steering_fl

func _ready() -> void:
	pass 

func _process(delta: float) -> void:
	if not ray_ground.is_colliding():
		return
	_input_handler()
	car.global_transform = _rotate_transform(car, delta)
	steering_fl.rotation_degrees = Vector3(0,input.x * 60,0)
	steering_fr.rotation_degrees = Vector3(0,input.x * 60,0)

func _physics_process(delta: float) -> void:
	xform = car.global_transform
	car.transform.origin = rigid_body.transform.origin + SPHERE_OFFSET
	rigid_body.apply_central_force(car.global_transform.basis.z * input.y * acceleration)
	_wiggle_node(car_mesh, delta)
	_emit_particles(xform, rigid_body.linear_velocity)	

func _input_handler(): 
	input.x = int(Input.is_action_pressed('Left')) - int(Input.is_action_pressed('Right'))
	input.y = int(Input.is_action_pressed('Up')) - int(Input.is_action_pressed('Down'))
	
func _setup():
	ray_ground.add_exception(rigid_body)
	
func _round_to_dec(num, digit):
	return round(num * pow(10.0, digit)) / pow(10.0, digit)
	
func _rotate_transform(node : Node3D, delta: float):
	var _turn_dir : int = 1
	if rigid_body.linear_velocity.dot(xform.basis.z) < 0:
		_turn_dir = -1
	var _turn_speed : float = remap(_round_to_dec(rigid_body.linear_velocity.length(), 2), 0.0, 10.0, 0.0, turn_speed)
	var _new_basis : Basis = node.global_transform.basis.rotated(node.global_transform.basis.y, input.x * deg_to_rad(steering))
	node.global_transform.basis = node.global_transform.basis.slerp(_new_basis, _turn_speed * _turn_dir * delta)
	return node.global_transform.orthonormalized()	

func _wiggle_node(node : Node3D, delta : float) -> void:
	var target_pos = car.position * Vector3(1.0, 0.0, 1.0)
	var acceleration = (target_pos - wiggle_offset.position) * spring_strength
	wiggle_velocity += acceleration * delta
	wiggle_velocity *= damping

	spring_target += wiggle_velocity * delta
	spring_target.y = car.global_position.y
	wiggle_offset.global_position = spring_target + xform.basis.y * 5.0
	
	var new_up = (wiggle_offset.global_position - car.global_position).normalized()
	var current_forward = -xform.basis.z
	var new_right = current_forward.cross(new_up).normalized()
	var new_forward_adjusted = new_up.cross(new_right).normalized()
	var new_basis = Basis(new_right, new_up, -new_forward_adjusted)
	node.basis = new_basis
	node.global_position = rigid_body.global_position + xform.basis.y * SPHERE_OFFSET
	
func _emit_particles(xform : Transform3D, velocity) -> void:
	var _emit : bool = false
	if abs(xform.basis.x.dot(velocity.normalized())) > 0.35 and velocity.length() > 2.0:
		_emit = true
	cpu_particles_3d.emitting = _emit
