extends RefCounted
## City street grids. Every view is one block: a piece of one street
## between two crossing streets. A new game picks a city (set_city) and
## the whole game, until death, is played in it.
##
## A segment is Vector3i(family, street, k):
##   family 0 = A street, the block lies between B[k] and B[k + 1]
##   family 1 = B street, the block lies between A[k] and A[k + 1]
##
## For every city:
## - A streets are listed from the shore side (index 0, the far side of
##   it is the sea) away from it. On an A street the camera looks towards
##   the shore and +x on screen points towards higher B indexes.
## - B streets are listed so that on a B street the camera looks towards
##   higher B indexes and +x on screen points towards higher A indexes.
## - view_azimuth: compass direction the camera looks at on [A, B] streets.
## - map_u / map_v: screen directions (north up) of "along A" (B index)
##   and "across A" (A index) on the phone map.
## Street names stay in Finnish in every language.

const CITIES := [
	{
		"name": "Oulu",
		# SW–NE streets from the shore (NW) towards the railway (SE). The
		# canal and its parks run between Uusikatu and Mäkelininkatu.
		"a": ["Rantakatu", "Aleksanterinkatu", "Torikatu", "Kirkkokatu", "Isokatu",
			"Uusikatu", "Mäkelininkatu", "Koulukatu", "Rautatienkatu"],
		# NW–SE streets from SW to NE. Kauppurienkatu is Rotuaari.
		"b": ["Sepänkatu", "Albertinkatu", "Saaristonkatu", "Kauppurienkatu",
			"Pakkahuoneenkatu", "Hallituskatu", "Asemakatu"],
		"view_azimuth": [315.0, 45.0],
		"map_u": Vector2(0.7071, -0.7071),
		"map_v": Vector2(0.7071, 0.7071),
		"start": Vector3i(0, 3, 4),            # Kirkkokatu, Pakkahuoneenkatu–Hallituskatu
		"police": Vector3i(0, 4, 4),           # Isokatu, Pakkahuoneenkatu–Hallituskatu
		"police_door_x": 8.0,
		"pedestrian": "Kauppurienkatu",        # Rotuaari: no cars
	},
	{
		"name": "Raahe",
		# West–east streets from the shore (Kirkkolahti, north) southwards.
		# (Ämmänkatu and Nahkurinkuja are only partial streets.)
		"a": ["Kirkkolahdenkatu", "Pitkänkarinkatu", "Saaristokatu", "Cortenkatu",
			"Brahenkatu", "Koulukatu", "Sovionkatu"],
		# North–south streets from west to east.
		"b": ["Rantakatu", "Kauppakatu", "Kirkkokatu", "Reiponkatu", "Palokunnankatu"],
		"view_azimuth": [0.0, 90.0],
		"map_u": Vector2(1, 0),
		"map_v": Vector2(0, 1),
		"start": Vector3i(1, 2, 2),            # Kirkkokatu by the church, Saaristokatu–Cortenkatu
		"police": Vector3i(0, 4, 2),           # Brahenkatu, Kirkkokatu–Reiponkatu
		"police_door_x": 8.0,
		"pedestrian": "",
	},
]

static var city := 0
## Blocks closed today for roadworks (Vector3i segments). No one gets
## through them; the map shows them.
static var closed: Array = []


static func set_city(i: int) -> void:
	city = clampi(i, 0, CITIES.size() - 1)
	closed.clear()


static func city_name() -> String:
	return CITIES[city]["name"]


static func data() -> Dictionary:
	return CITIES[city]


static func start() -> Vector3i:
	return data()["start"]


static func police_station() -> Vector3i:
	return data()["police"]


static func police_door_x() -> float:
	return data()["police_door_x"]


static func view_azimuth(family: int) -> float:
	return data()["view_azimuth"][family]


static func is_pedestrian(seg: Vector3i) -> bool:
	return data()["pedestrian"] != "" and street_name(seg) == data()["pedestrian"]


static func streets(family: int) -> Array:
	return data()["a"] if family == 0 else data()["b"]


static func cross_streets(family: int) -> Array:
	return data()["b"] if family == 0 else data()["a"]


static func is_valid(seg: Vector3i) -> bool:
	if seg.x < 0 or seg.x > 1:
		return false
	var own := streets(seg.x)
	var cross := cross_streets(seg.x)
	return seg.y >= 0 and seg.y < own.size() and seg.z >= 0 and seg.z < cross.size() - 1


static func is_closed(seg: Vector3i) -> bool:
	return closed.has(seg)


## On the map and not closed for roadworks: can be walked into.
static func is_open(seg: Vector3i) -> bool:
	return is_valid(seg) and not closed.has(seg)


static func street_name(seg: Vector3i) -> String:
	return streets(seg.x)[seg.y]


## Crossing street at the left (-x) or right (+x) end of the block.
static func cross_name(seg: Vector3i, right: bool) -> String:
	return cross_streets(seg.x)[seg.z + (1 if right else 0)]


## The next block along the same street (dir = +1 right, -1 left).
static func next_along(seg: Vector3i, dir: int) -> Vector3i:
	return Vector3i(seg.x, seg.y, seg.z + dir)


## Turning at the left or right end of the block. `up` means away from the
## camera, `down` towards it. Returns {"seg", "enter_right"}; seg is invalid
## if there is no street there.
static func turn(seg: Vector3i, at_right: bool, up: bool) -> Dictionary:
	var node := seg.z + (1 if at_right else 0)
	if seg.x == 0:
		# On an A street: up = towards the shore along the B street.
		if up:
			return {"seg": Vector3i(1, node, seg.y - 1), "enter_right": true}
		return {"seg": Vector3i(1, node, seg.y), "enter_right": false}
	# On a B street: up = towards higher B indexes along the A street.
	if up:
		return {"seg": Vector3i(0, node, seg.y), "enter_right": false}
	return {"seg": Vector3i(0, node, seg.y - 1), "enter_right": true}


## There is an open street to turn into.
static func can_turn(seg: Vector3i, at_right: bool, up: bool) -> bool:
	return is_open(turn(seg, at_right, up)["seg"])


## There is a street there at all (maybe closed for roadworks).
static func has_turn(seg: Vector3i, at_right: bool, up: bool) -> bool:
	return is_valid(turn(seg, at_right, up)["seg"])


## The far side of the shore street (A street 0) is the sea.
static func far_side_is_sea(seg: Vector3i) -> bool:
	return seg.x == 0 and seg.y == 0


static func seed_of(seg: Vector3i) -> int:
	return city * 1000003 + seg.x * 10007 + seg.y * 101 + seg.z * 7 + 12345


static func random_segment(rng: RandomNumberGenerator) -> Vector3i:
	while true:
		var f := rng.randi() % 2
		var seg := Vector3i(f, rng.randi() % streets(f).size(), rng.randi() % (cross_streets(f).size() - 1))
		if is_open(seg):
			return seg
	return start()
