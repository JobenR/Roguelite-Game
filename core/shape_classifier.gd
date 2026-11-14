class_name ShapeClassifier
extends RefCounted
## Recognises a filled region as a circle, triangle, or square.
##
## Method: take the convex hull of the region. A very round hull is a circle.
## Otherwise count its real corners: repeatedly delete the
## hull corner that matters least (smallest triangle with its neighbours)
## until every remaining corner is significant. Three corners left is a
## triangle, four a square, five or more a circle. Hand-drawn wobble only
## creates insignificant corners, so it is ignored.

## Corners closer than this fraction of the shape's radius count as one.
const MERGE_DISTANCE := 0.45
## Hull roundness at or above this is a circle without counting corners.
const ROUNDNESS_CIRCLE := 0.88


## points: centres of the region's cells. area: the region's true area.
## Returns {kind, corners, centroid, radius, hull_area}. kind is "" when the
## region is too dented to be a clean shape (area well below its hull).
static func classify(points: PackedVector2Array, area: float, corner_threshold: float, min_fill_ratio: float) -> Dictionary:
	var result := {"kind": "", "corners": PackedVector2Array(), "centroid": Vector2.ZERO, "radius": 0.0, "hull_area": 0.0}
	if points.size() < 3:
		return result
	var centroid := Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= points.size()
	result["centroid"] = centroid

	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	if hull.size() < 3:
		return result
	var hull_area := polygon_area(hull)
	result["hull_area"] = hull_area
	var radius := 0.0
	for p in hull:
		radius = maxf(radius, p.distance_to(centroid))
	result["radius"] = radius
	if hull_area <= 0.0 or area / hull_area < min_fill_ratio:
		return result

	# Roundness test first: how close the hull is to a circle of the same
	# perimeter (1.0 = perfect circle, square 0.79, triangle 0.60). The hull
	# ignores wobble, so a shaky circle or an oval still scores high.
	var perimeter := 0.0
	for i in hull.size():
		perimeter += hull[i].distance_to(hull[(i + 1) % hull.size()])
	var roundness := 4.0 * PI * hull_area / (perimeter * perimeter)
	if roundness >= ROUNDNESS_CIRCLE:
		result["corners"] = hull
		result["kind"] = "circle"
		return result

	var limit := corner_threshold * hull_area
	while hull.size() > 3:
		var weakest := -1
		var weakest_area := limit
		for i in hull.size():
			var a := hull[(i - 1 + hull.size()) % hull.size()]
			var b := hull[i]
			var c := hull[(i + 1) % hull.size()]
			var tri := absf((b - a).cross(c - a)) * 0.5
			if tri < weakest_area:
				weakest_area = tri
				weakest = i
		if weakest == -1:
			break
		hull.remove_at(weakest)

	# A thick trail blunts sharp corners into two nearby points. Merge any
	# pair of corners that sit close together relative to the shape's size.
	while hull.size() > 3:
		var closest := -1
		var closest_dist := radius * MERGE_DISTANCE
		for i in hull.size():
			var d := hull[i].distance_to(hull[(i + 1) % hull.size()])
			if d < closest_dist:
				closest_dist = d
				closest = i
		if closest == -1:
			break
		var next := (closest + 1) % hull.size()
		hull[closest] = (hull[closest] + hull[next]) * 0.5
		hull.remove_at(next)

	result["corners"] = hull
	match hull.size():
		3:
			result["kind"] = "triangle"
		4:
			result["kind"] = "square"
		_:
			result["kind"] = "circle"
	return result


static func polygon_area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		total += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(total) * 0.5
