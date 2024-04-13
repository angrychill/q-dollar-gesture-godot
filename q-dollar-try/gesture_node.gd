class_name GestureNode extends Node2D


var points_normalized : Array[Vector3] #gesture points normalized
var points_normalized_int : Array[Vector3i] # turned into integers
var points_raw : Array[Vector3] #gesture points not normalized
var gesture_name : StringName #gesture name/class, maybe change to gesture type

@export var gesture_resource : Gesture

# vector 3 is used, where z represents stroke index of line

#region $Q parameters
# ------------------- $Q const options ----------------------
const SAMPLING_RES : int = 64
const MAX_INT_COORDS : int = 1024
const LUT_SIZE : int = 64
const LUT_SCALE_FACTOR : int = MAX_INT_COORDS / LUT_SIZE

# lookup table dictionary
# key is vector2
var LUT = {}
#endregion


#region line2d parameters
@export var line_width : float = 5
@export var joint_mode : int = 2
@export var cap_mode : int = 2
#endregion

var can_draw : bool = true
var stroke : Line2D
func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("start_gesture"):
		#print("space down")
		#can_draw = true
	#if event.is_action_released("start_gesture"):
		#print("space up")
		#can_draw = false
	if event.is_action_pressed("recognize_gesture"):
		print("call recognition function")
		register_gesture()
		var recognizer = QPointCloudRecognizer.new()
		recognizer.classify(gesture_resource)
		for child in get_children():
			child.queue_free()
		points_normalized.clear()
		points_normalized_int.clear()
		points_raw.clear()
		gesture_resource = null
		recognizer.queue_free()

	if can_draw:
		if event.is_action_pressed("line_press"):
			print("mouse down")
			stroke = Line2D.new()
			add_child(stroke)
			stroke.begin_cap_mode = cap_mode
			stroke.end_cap_mode = cap_mode
			stroke.antialiased = true
			stroke.width = line_width
		if event.is_action_released("line_press"):
			print("mouse up")
			stroke = null
			pass
		

# handles line drawing
func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if can_draw and stroke != null:
			stroke.add_point(get_global_mouse_position())

# ------------ create a gesture from array of points ------------------
# theoretically : each new stroke drawn is a new line2d spawned underneath the gesture
# at the end, each line2d is fed into a vec3 array, with the stroke index being the z value
func register_gesture():
	if get_child_count() > 0:
		var children = get_children()
		for i in range(children.size()):
			line_to_vec3_array(children[i], i)
		prints("points_raw size:", points_raw.size())
		print(points_raw)
		print("-----------------------------------------------------------------------------------")
		normalize_points()
		#prints("size:", points_normalized.size())
		#print(points_normalized)
		#print("-----------------------------------------------------------------------------------")
		prints("size int:", points_normalized_int.size())
		print(points_normalized_int)
		print("-----------------------------------------------------------------------------------")
		print("lookup table")
		print(LUT.size())
		
		save_gesture_to_resource()

func line_to_vec3_array(line : Line2D, index : int):
	for point in line.points:
		var vec3 : Vector3 = Vector3(point.x, point.y, index)
		points_raw.append(vec3)

func normalize_points():
	# resample, scale, translate
	# transform coords to int
	# construct lut
	
	points_normalized = normalization_resample(points_raw, SAMPLING_RES)
	points_normalized = normalization_scale(points_normalized)
	points_normalized = normalization_translate(points_normalized, centroid(points_normalized))
	
	transform_coords_to_integers()
	construct_LUT()
	pass

# normalization functions

func normalization_scale(points : Array[Vector3]):
	var minx : float = INF
	var miny : float = INF
	var maxy : float = -INF
	var maxx : float = -INF
	for point : Vector3 in points:
		if minx > point.x:
			minx = point.x
		if miny > point.y:
			miny = point.y
		if maxx < point.x:
			maxx = point.x
		if maxy < point.y:
			maxy = point.y
	
	var new_points : Array[Vector3]
	new_points.resize(points.size())
	var new_scale : float = max(maxx - minx, maxy - miny)
	prints("new scale", new_scale)
	for i in range (points.size()):
		var new_vec3 : Vector3 = Vector3((points[i].x - minx) / new_scale, (points[i].y - miny) / new_scale, points[i].z)
		new_points[i] = new_vec3
	return new_points


func normalization_translate(points : Array[Vector3], c : Vector3) -> Array[Vector3]:
	var new_points : Array[Vector3]
	new_points.resize(points.size())
	for i in range(points.size()):
		var new_vec3 = Vector3(points[i].x - c.x, points[i].y - c.y, points[i].z)
		new_points[i] = new_vec3
	return new_points


func centroid(points : Array[Vector3]) -> Vector3:
	var cx : float = 0
	var cy : float = 0
	for point : Vector3 in points:
		cx += point.x
		cy += point.y
	return Vector3(cx / points.size(), cy / points.size(), 0)


func normalization_resample(points : Array[Vector3], n : int) -> Array[Vector3]:
	# n = SAMPLING_RES
	var new_points : Array[Vector3]
	new_points.resize(n)
	new_points[0] = points[0]
	var num_points : int = 1
	
	var interval_length : float = path_length(points) / (n-1)
	var d : float = 0
	for i in range(1, points.size()):
		if points[i].z == points[i-1].z:
			var small_d : float = euclidean_distance(points[i-1], points[i])
			if (d + small_d >= interval_length):
				var first_point : Vector3 = points[i-1]
				while (d + small_d >= interval_length):
					var t : float = min(max((interval_length - d) / small_d, 0.0), 1.0)
					if is_nan(t):
						t = 0.5
					var new_vec3 = Vector3((1.0 - t) * first_point.x + t * points[i].x, (1.0 - t) * first_point.y + t * points[i].y, points[i].z)
					new_points[num_points] = new_vec3
					num_points += 1
					
					small_d = d + small_d - interval_length
					d = 0
					first_point = new_points[num_points - 1]
				d = small_d
			else:
				d += small_d
	if num_points == n - 1:
		new_points[num_points] = Vector3(points.back().x, points.back().y, points.back().z)
	return new_points


func euclidean_distance(a : Vector3, b : Vector3) -> float:
	return float(sqrt(sq_euclidean_distance(a, b)))

func sq_euclidean_distance(a : Vector3, b : Vector3) -> float:
	var z : float = pow((a.x-b.x),2) + pow((a.y-b.y), 2)
	return z
	

# maybe have to add conversion to ints later but whatever

func path_length(points : Array[Vector3]) -> float:
	var length : float = 0
	for i : int in range(1, points.size()):
		if points[i].z == points[i-1].z:
			length += euclidean_distance(points[i-1], points[i])
	return length

func transform_coords_to_integers():
	points_normalized_int.resize(points_normalized.size())
	for i in range(points_normalized.size()):
		points_normalized_int[i].x = int((points_normalized[i].x + 1.0) / 2.0 * (MAX_INT_COORDS - 1))
		points_normalized_int[i].y = int((points_normalized[i].y + 1.0) / 2.0 * (MAX_INT_COORDS - 1))
		points_normalized_int[i].z = points_normalized[i].z
		

func construct_LUT():
	for i : int in range(LUT_SIZE):
		for j : int in range(LUT_SIZE):
			var min_dist : int = INF
			var index_min : int = -1
			for t : int in range(points_normalized_int.size()):
				var row : int = points_normalized_int[t].y / LUT_SCALE_FACTOR
				var col : int = points_normalized_int[t].x / LUT_SCALE_FACTOR
				var dist : int = pow((row-i),2) + pow((col-j), 2)
				if dist < min_dist:
					min_dist = dist
					index_min = t
			LUT[Vector2(i, j)] = index_min

func save_gesture_to_resource():
	gesture_resource = Gesture.new()
	gesture_resource.points_int = points_normalized_int
	gesture_resource.points = points_normalized
	gesture_resource.LUT = LUT
	#gesture_resource.constants.merge({
		#"SAMPLING_RES" : SAMPLING_RES,
		#"MAX_INT_COORDS" : MAX_INT_COORDS,
		#"LUT_SIZE" : LUT_SIZE,
		#"LUT_SCALE_FACTOR" : LUT_SCALE_FACTOR
	#}, true)
	#var save_path = "res://res.res"
	#ResourceSaver.save(gesture_resource, save_path)
	#print(ResourceLoader.load(save_path))
