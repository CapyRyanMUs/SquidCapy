extends RefCounted
class_name SnapshotCodec

# Eleven float32 values per actor; 20 actors fit comfortably below ENet's MTU.
const WIDTH := 11
const CHUNK_SIZE := 20
const OUTCOMES := ["active", "won", "dead", "abandoned"]

static func pack(states: Array) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	for state in states:
		var flags := int(state.run) | (int(state.fallen) << 1) | (int(state.marked) << 2)
		buffer.append_array(PackedFloat32Array([state.id, state.p.x, state.p.y, state.v.x, state.v.y,
			state.f, flags, state.push, state.up, state.ack, OUTCOMES.find(state.outcome)]))
	return buffer

static func unpack(buffer: PackedFloat32Array) -> Array:
	var states: Array = []
	if buffer.size() % WIDTH != 0:
		return states
	for index in range(0, buffer.size(), WIDTH):
		var flags := int(buffer[index + 6])
		var result := int(buffer[index + 10])
		if result < 0 or result >= OUTCOMES.size():
			continue
		states.append({"id": int(buffer[index]), "p": Vector2(buffer[index + 1], buffer[index + 2]),
			"v": Vector2(buffer[index + 3], buffer[index + 4]), "f": int(buffer[index + 5]),
			"run": bool(flags & 1), "fallen": bool(flags & 2), "marked": bool(flags & 4),
			"push": buffer[index + 7], "up": buffer[index + 8], "ack": int(buffer[index + 9]),
			"outcome": OUTCOMES[result]})
	return states
