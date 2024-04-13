extends Node
class_name QPointCloudRecognizer

@export var early_abandoning : bool = true
@export var lower_bounding : bool = true

@export var gesture_set : Array[Gesture]

signal classified_gesture(gesture_name : StringName)

func _init() -> void:
	var dir = DirAccess.open("res://gesture_templates")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var rname = "res://gesture_templates/" + str(file_name)
			gesture_set.append(ResourceLoader.load(rname))
			file_name = dir.get_next()

func classify(candidate : Gesture) -> StringName: #-> string, takes gesture candidate, template set
	prints("received candidate", candidate)
	var min_distance : float = INF
	var gesture_class : StringName = "";
	for template : Gesture in gesture_set:
		var dist : float = greedy_cloud_match(candidate, template, min_distance)
		if dist < min_distance:
			min_distance = dist
			gesture_class = template.gesture_name
	prints("recognized gesture:", gesture_class)
	classified_gesture.emit(gesture_class)
	return gesture_class

func greedy_cloud_match(gesture_1 : Gesture, gesture_2 : Gesture, min_so_far : float) -> float: #-> float, takes two gestures, minsofar
	var n : int = gesture_1.points_int.size()
	var eps : float = 0.5 # number of greedy search trials (0.0 - 1.0)
	var step : int = floor(pow(n, 1.0 - eps))
	
	if lower_bounding:
		var LB1 : Array[float] = compute_lower_bound(gesture_1, gesture_2, gesture_2.LUT, step)
		var LB2 : Array[float] = compute_lower_bound(gesture_2, gesture_1, gesture_1.LUT, step)
		
		var indexLB : int = 0
		for i in range(0, n, step):
			if LB1[indexLB] < min_so_far:
				min_so_far = min(min_so_far, cloud_distance(gesture_1.points_int, gesture_2.points_int, i, min_so_far))
			if LB2[indexLB] < min_so_far:
				min_so_far = min(min_so_far, cloud_distance(gesture_2.points_int, gesture_1.points_int, i, min_so_far))
			indexLB += 1
	else:
		for i in range(0, n, step):
			min_so_far = min(min_so_far, cloud_distance(gesture_1.points_int, gesture_2.points_int, i, min_so_far))
			min_so_far = min(min_so_far, cloud_distance(gesture_2.points_int, gesture_1.points_int, i, min_so_far))
			
	
	return min_so_far


func compute_lower_bound(gesture_1 : Gesture, gesture_2 : Gesture, LUT : Dictionary, step : int) -> Array[float]: #-> float array, takes arrays points1, points2, int double array
	pass
	# for lookup table, int step
	var n : int = gesture_1.points.size()
	var LB : Array[float]
	LB.resize(n / step + 1)
	var SAT : Array[float]
	SAT.resize(n)
	
	LB[0] = 0
	
	for i in range(0, n):
		var index : int = LUT[Vector2(gesture_1.points_int[i].x / GestureNode.LUT_SCALE_FACTOR, gesture_1.points_int[i].y / GestureNode.LUT_SCALE_FACTOR)]
		var dist : float = sq_euclidean_distance(gesture_1.points[i], gesture_2.points[index])
		if (i == 0):
			SAT[i] = dist
		else:
			SAT[i] = SAT[i-1] + dist
		#SAT[i] = dist if i == 0 else SAT[i-1] + dist
		LB[0] += (n-i) * dist
	
	#var i = step
	var indexLB = 1
	
	for j in range(step, n, step):
		LB[indexLB] = LB[0] + j * SAT[n - 1] - n * SAT[j - 1]
		indexLB += 1
	pass
	return LB


func cloud_distance(points1 : Array[Vector3i], points2 : Array[Vector3i], start_index : int, min_so_far : float): #-> float, takes arrays points1, points2, int startindex, float minsofar
	var n : int = points1.size()
	var indexes_not_matched : Array[int]
	indexes_not_matched.resize(n)
	for j in range(0, n):
		indexes_not_matched[j] = j
	
	var sum : float = 0
	var i : int = start_index
	var weight : int = n
	var index_not_matched : int = 0
	
	while weight > 0:
		var index : int = -1
		var min_distance : float = INF
		for j in range(index_not_matched, n):
			var dist : float = sq_euclidean_distance(points1[i], points2[indexes_not_matched[j]])
			if dist < min_distance:
				min_distance = dist
				index = j
		indexes_not_matched[index] = indexes_not_matched[index_not_matched]
		sum += weight * min_distance
		weight -= 1
		
		if early_abandoning:
			if sum >= min_so_far:
				return sum
		
		i = (i + 1) % n
		index_not_matched += 1
	
	return sum

func euclidean_distance(a : Vector3, b : Vector3) -> float:
	return float(sqrt(sq_euclidean_distance(a, b)))

func sq_euclidean_distance(a : Vector3, b : Vector3) -> float:
	var z : float = pow((a.x-b.x),2) + pow((a.y-b.y), 2)
	return z

#region gesture input
var can_draw : bool = false
func _input(event: InputEvent) -> void:

	if event.is_action_pressed("start_gesture"):
		print("space down")
		can_draw = true
	if event.is_action_released("start_gesture"):
		print("space up")
		can_draw = false
	if event.is_action_pressed("recognize_gesture"):
		print("call recognition function")
		#register_gesture()
#endregion
