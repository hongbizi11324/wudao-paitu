extends Node

var _pool: Dictionary = {}
var _active: Dictionary = {}

func acquire(scene) -> Node:
	var path = scene.resource_path
	if not _pool.has(path):
		_pool[path] = []
	
	# 清理野指针 + 找空闲节点
	var pool: Array = _pool[path]
	var i = 0
	while i < pool.size():
		var obj = pool[i]
		if not is_instance_valid(obj):
			pool.remove_at(i)
			continue
		var id = obj.get_instance_id()
		if not _active.has(id):
			_active[id] = true
			obj.visible = true
			_reset_node(obj)
			return obj
		i += 1
	
	var new_obj = scene.instantiate()
	pool.append(new_obj)
	_active[new_obj.get_instance_id()] = true
	return new_obj


func release(node):
	if not is_instance_valid(node):
		return
	var id = node.get_instance_id()
	if not _active.erase(id):
		if node.get_parent():
			node.get_parent().remove_child(node)
		node.queue_free()
		return
	if node.get_parent():
		node.get_parent().remove_child(node)
	node.visible = false
	_reset_node(node)


func _reset_node(node):
	if node.has_method("reset_pooled"):
		node.reset_pooled()
