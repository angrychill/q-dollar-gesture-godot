class_name QPointCloudRecognizer extends Node

@export var early_abandoning : bool = true
@export var lower_bounding : bool = true

@export var gesture_set : Array[Gesture]

func classify(candidate : Gesture, template_set : Array[Gesture]): #-> string, takes gesture candidate, template set
	var min_distance : float = INF
	var gesture_class : StringName = "";
	for template : Gesture in template_set:
		var dist : float = greedy_cloud_match(candidate, template, min_distance)


func greedy_cloud_match(gesture_1 : Gesture, gesture_2 : Gesture, min_so_far : float) -> float: #-> float, takes two gestures, minsofar
	var n : int = gesture_1.points_normalized_int.size()
	var eps : float = 0.5 # number of greedy search trials (0.0 - 1.0)
	var step : int = floori(pow(n, 1.0 - eps))
	
	if lower_bounding:
		var LB1 : Array[float] = compute_lower_bound(gesture_1.points_normalized_int, gesture_2.points_normalized_int, gesture_2.LUT, step)
		var LB2 : Array[float] = compute_lower_bound(gesture_2.points_normalized_int, gesture_1.points_normalized_int, gesture_1.LUT, step)
	return 1.0


func compute_lower_bound(points1 : Array[Vector3i], points2 : Array[Vector3i], LUT : Dictionary, step : int) -> Array[float]: #-> float array, takes arrays points1, points2, int double array
	# for lookup table, int step
	var n : int = points1.size()
	var LB : Array[float]
	LB.resize(n / step + 1)
	var SAT : Array[float]
	SAT.resize(n)
	
	LB[0] = 0
	
	for i in range(0, n):
		var index : int = LUT[Vector2(points1[i].x / Gesture.LUT_SCALE_FACTOR, points1[i].y / Gesture.LUT_SCALE_FACTOR)]
		var dist : float = sq_euclidean_distance(points1[i], points2[index])
		SAT[i] = dist if i == 0 else SAT[i-1] + dist
		LB[0] += (n-i) * dist
	
	var i = step
	var indexLB = 1
	while (i < n):
		LB[indexLB] = LB[0] + i * SAT[n - 1] - n * SAT[i - 1]
		i += step
		indexLB += 1
	
	return LB


func cloud_distance(): #-> float, takes arrays points1, points2, int startindex, float minsofar
	pass


func euclidean_distance(a : Vector3, b : Vector3) -> float:
	return float(sqrt(sq_euclidean_distance(a, b)))

func sq_euclidean_distance(a : Vector3, b : Vector3) -> float:
	var z : float = pow((a.x-b.x),2) + pow((a.y-b.y), 2)
	return z

