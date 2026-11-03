extends RefCounted
## Oulu city centre street grid. Every view is one block: a piece of one
## street between two crossing streets.
##
## A segment is Vector3i(family, street, k):
##   family 0 = A street, the block lies between B_STREETS[k] and B_STREETS[k + 1]
##   family 1 = B street, the block lies between A_STREETS[k] and A_STREETS[k + 1]
##
## Edit the lists below to fix the street order. Street names stay in
## Finnish in every language.

## Streets running SW–NE, listed from the shore (NW) towards the railway (SE)
## (checked against a map). The canal and its parks run between Uusikatu
## and Mäkelininkatu; Vaarankatu is only a short street along the canal.
const A_STREETS := ["Rantakatu", "Aleksanterinkatu", "Torikatu", "Kirkkokatu", "Isokatu",
	"Uusikatu", "Mäkelininkatu", "Koulukatu", "Rautatienkatu"]

## Streets running NW–SE, listed from SW to NE (checked against a map).
## Kauppurienkatu (Rotuaari) lies between Saaristonkatu and Pakkahuoneenkatu.
## Nummikatu and Heinätorinkatu continue south-west of Sepänkatu (outside the area).
## TODO: Ojakatu's place is not known yet. Linnankatu, Kajaaninkatu and
## Heikinkatu only exist on the east side, which the full grid can't show yet.
const B_STREETS := ["Sepänkatu", "Albertinkatu", "Saaristonkatu", "Kauppurienkatu",
	"Pakkahuoneenkatu", "Hallituskatu", "Asemakatu"]

## Compass direction the camera looks at on each street family.
## A streets: camera looks NW, +x on screen points NE.
## B streets: camera looks NE, +x on screen points SE.
const VIEW_AZIMUTH := [315.0, 45.0]

const START := Vector3i(0, 3, 4)  # Kirkkokatu, Pakkahuoneenkatu–Hallituskatu


static func streets(family: int) -> Array:
	return A_STREETS if family == 0 else B_STREETS


static func cross_streets(family: int) -> Array:
	return B_STREETS if family == 0 else A_STREETS


static func is_valid(seg: Vector3i) -> bool:
	var own := streets(seg.x)
	var cross := cross_streets(seg.x)
	return seg.x >= 0 and seg.x <= 1 and seg.y >= 0 and seg.y < own.size() \
		and seg.z >= 0 and seg.z < cross.size() - 1


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
		# On an A street: up = NW, down = SE along the B street.
		if up:
			return {"seg": Vector3i(1, node, seg.y - 1), "enter_right": true}
		return {"seg": Vector3i(1, node, seg.y), "enter_right": false}
	# On a B street: up = NE, down = SW along the A street.
	if up:
		return {"seg": Vector3i(0, node, seg.y), "enter_right": false}
	return {"seg": Vector3i(0, node, seg.y - 1), "enter_right": true}


static func can_turn(seg: Vector3i, at_right: bool, up: bool) -> bool:
	return is_valid(turn(seg, at_right, up)["seg"])


## The far side of Rantakatu (looking NW) is the sea.
static func far_side_is_sea(seg: Vector3i) -> bool:
	return seg.x == 0 and seg.y == 0


static func seed_of(seg: Vector3i) -> int:
	return seg.x * 10007 + seg.y * 101 + seg.z * 7 + 12345


static func random_segment(rng: RandomNumberGenerator) -> Vector3i:
	while true:
		var f := rng.randi() % 2
		var seg := Vector3i(f, rng.randi() % streets(f).size(), rng.randi() % (cross_streets(f).size() - 1))
		if is_valid(seg):
			return seg
	return START
