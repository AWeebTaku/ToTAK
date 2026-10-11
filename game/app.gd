extends Node
## Autoload: settings, sound, scene switching, update check.

signal update_found(version: String, url: String)
signal update_checked(status: String)   # "latest" | "failed" (update_found covers "newer")

const SETTINGS_PATH := "user://settings.cfg"
const SFX := ["hit", "miss", "pickup", "use", "stairs", "die", "levelup", "step", "heartbeat"]

var sound_on := true
var check_updates := true
var current: GameState        # handed from menu to the game scene
var latest_version := ""
var latest_url := ""

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _drone: AudioStreamPlayer


func _ready() -> void:
	_load_settings()
	for n in SFX:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var drone_stream := load("res://assets/sfx/ambient.wav") as AudioStreamWAV
	drone_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drone_stream.loop_begin = 0
	drone_stream.loop_end = drone_stream.data.size() / 2     # 16-bit mono: samples = bytes / 2
	_drone = AudioStreamPlayer.new()
	_drone.stream = drone_stream
	_drone.volume_db = -8.0
	add_child(_drone)
	_apply_drone()
	if check_updates and not Version.VERSION.ends_with("-dev") and DisplayServer.get_name() != "headless":
		check_for_updates()


func play(name: String) -> void:
	if not sound_on or not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.play()
			return


func start_new_game() -> void:
	current = GameState.new_game()
	Save.write(current)
	get_tree().change_scene_to_file("res://game/ui/game.tscn")


func continue_game() -> bool:
	var gs := Save.read()
	if gs == null or gs.game_over:
		return false
	current = gs
	get_tree().change_scene_to_file("res://game/ui/game.tscn")
	return true


func to_menu() -> void:
	get_tree().change_scene_to_file("res://game/ui/menu.tscn")


func set_sound(v: bool) -> void:
	sound_on = v
	_apply_drone()
	_save_settings()


func _apply_drone() -> void:
	if sound_on and DisplayServer.get_name() != "headless":
		if not _drone.playing:
			_drone.play()
	else:
		_drone.stop()


func set_check_updates(v: bool) -> void:
	check_updates = v
	_save_settings()


func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) == OK:
		sound_on = c.get_value("main", "sound", true)
		check_updates = c.get_value("main", "check_updates", true)


func _save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("main", "sound", sound_on)
	c.set_value("main", "check_updates", check_updates)
	c.save(SETTINGS_PATH)


func check_for_updates() -> void:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, body: PackedByteArray):
		req.queue_free()
		if code != 200:
			update_checked.emit("failed")   # offline / rate limited: callers decide whether to show it
			return
		var d: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(d) == TYPE_DICTIONARY and d.has("tag_name") and Version.is_newer(d.tag_name, Version.VERSION):
			latest_version = String(d.tag_name).trim_prefix("v")
			latest_url = d.get("html_url", "https://github.com/%s/releases/latest" % Version.REPO)
			update_found.emit(latest_version, latest_url)
		else:
			update_checked.emit("latest"))
	req.request("https://api.github.com/repos/%s/releases/latest" % Version.REPO,
			["User-Agent: ToTAK/" + Version.VERSION, "Accept: application/vnd.github+json"])
