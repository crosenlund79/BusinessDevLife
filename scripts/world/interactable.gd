class_name Interactable
extends Node3D
## A clickable object in the office (laptop, coffee machine, a suspicious plant...).
## `id` is what the story director receives; `label_key` is the localised
## hover text. The player walks to `approach` before interacting.

var id := ""
var label_key := ""
var approach := Vector3.ZERO
var ring_radius := 0.6
var face_target := Vector3.ZERO


static func create(parent: Node3D, obj_id: String, label: String, center: Vector3, size: Vector3, approach_point: Vector3) -> Interactable:
	var it := Interactable.new()
	it.name = "Interact_" + obj_id
	it.id = obj_id
	it.label_key = label
	it.position = center
	it.approach = approach_point
	it.face_target = center
	it.ring_radius = clampf(maxf(size.x, size.z) * 0.6, 0.45, 1.6)
	var body := StaticBody3D.new()
	body.set_meta("interact_id", obj_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	it.add_child(body)
	parent.add_child(it)
	return it
