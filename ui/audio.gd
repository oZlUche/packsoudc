## 204：声音（自动加载 `Audio`，见架构文档「音频」一节）。
##
## - 两条总线 `SFX` / `Music`（运行时 `AudioServer.add_bus` 造，送 Master；不手写总线布局）；音量来自 [member GameSettings.sfx_volume] / `music_volume`（[method apply_settings]）。
## - 音效：[method play_cue] 按 cue 名查 [CueTable]，8 个播放器轮用（都忙就抢最早那个）；不在表里的静默、记进 [member missing]。
## - 按钮音一处钩子：凡 [BaseButton] 进树就接它的 `pressed`（松开时发，拖出去不响），播按钮 meta `sfx`（默认 `ui.press`，空串 = 不响）。
##   要专属声在造按钮的地方 `set_meta("sfx", &"…")`，不加新钩子。
## - 配乐：[method play_music] 换曲交叉淡入淡出（表先空着，等曲子）。
## 无头跑测试是 Dummy 音频驱动，照常走一遍、静默；测试看 [member recent]
##
## 别处调静态的 [method play] / [method apply]（转给自动加载那一份）：`--script` 跑的主脚本先于自动加载编译，
## 直接写自动加载的名字 `Audio` 在测试里编译不过
class_name AudioHub
extends Node

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
const POOL := 8
const RECENT_MAX := 32
## 按钮默认的 cue；按钮 meta 的键
const PRESS := &"ui.press"
const META_KEY := &"sfx"

## 关掉 = 什么都不播、不记（测试可关）
var enabled: bool = true
## 最近播过的 cue（最多 [constant RECENT_MAX] 个，新的在末尾；表里有但还没素材的也记）
var recent: Array[StringName] = []
## 表里没有的 cue（每个记一次）
var missing: Array[StringName] = []
var table: CueTable = null

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
## cue → 上次播的时刻（秒）、上次挑的文件下标
var _last_at: Dictionary = {}
var _last_file: Dictionary = {}
## 路径 → AudioStream（读不到的记 null，不再试）
var _streams: Dictionary = {}
var _music: AudioStreamPlayer = null
var _music_track: StringName = &""
## 自动加载的那一份（没有 = 什么都不做）
static var _inst: AudioHub = null


## 自动加载的那一份（测试看）
static func instance() -> AudioHub:
	return _inst if is_instance_valid(_inst) else null


## 播一个音效 cue（见 [method play_cue]）
static func play(cue: StringName) -> void:
	if instance() != null:
		_inst.play_cue(cue)


## 设置里的两个音量套到总线上（见 [method apply_settings]）
static func apply(settings: GameSettings) -> void:
	if instance() != null:
		_inst.apply_settings(settings)


## 换配乐（见 [method play_music]）
static func music(track: StringName, fade: float = 0.8) -> void:
	if instance() != null:
		_inst.play_music(track, fade)


func _enter_tree() -> void:
	_inst = self


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # 暂停菜单里的按钮也响
	_bus(SFX_BUS)
	_bus(MUSIC_BUS)
	table = CueTable.load_default()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


## 设置里的两个音量（0～1）套到总线上；0 = 静音
func apply_settings(settings: GameSettings) -> void:
	if settings == null:
		return
	_volume(SFX_BUS, settings.sfx_volume)
	_volume(MUSIC_BUS, settings.music_volume)


## 播一个音效 cue：表里挑一个文件（连续两次不挑同一个）、套音量与音高；同一 cue 冷却内的不响；不在表里的记进 [member missing]
func play_cue(cue: StringName) -> void:
	if not enabled or cue == &"" or table == null:
		return
	var c := table.cue(cue)
	if c.is_empty():
		if not missing.has(cue):
			missing.append(cue)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _last_at.has(cue) and now - float(_last_at[cue]) < float(c["cooldown"]):
		return     # 同一下（同一帧连发两次）只响一次
	_last_at[cue] = now
	recent.append(cue)
	if recent.size() > RECENT_MAX:
		recent.pop_front()
	var files: Array = c["files"]
	if files.is_empty():
		return     # 素材还没到：接好了、静默
	var i := randi() % files.size()
	if files.size() > 1 and i == int(_last_file.get(cue, -1)):
		i = (i + 1) % files.size()     # 连续两次不挑同一个
	_last_file[cue] = i
	var stream := _stream(CueTable.ASSET_ROOT + String(files[i]))
	if stream == null:
		return
	var p := _player()
	p.stream = stream
	p.volume_db = float(c["volume_db"])
	var pv := float(c["pitch_var"])
	p.pitch_scale = 1.0 + randf_range(-pv, pv)
	p.play()


## 换配乐（[param track] 空 = 淡出停掉）；同一首不重开
func play_music(track: StringName, fade: float = 0.8) -> void:
	if not enabled or table == null or track == _music_track:
		return
	var m := table.track(track) if track != &"" else {}
	if track != &"" and m.is_empty():
		if not missing.has(track):
			missing.append(track)
		return
	_music_track = track
	if _music != null:
		var old := _music
		_music = null
		var out := old.create_tween()
		out.tween_property(old, "volume_db", -60.0, fade)
		out.tween_callback(old.queue_free)
	if m.is_empty():
		return
	var stream := _stream(CueTable.ASSET_ROOT + String(m["file"]))
	if stream == null:
		return
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.stream = stream
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	_music.create_tween().tween_property(_music, "volume_db", float(m["volume_db"]), fade)


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var cb := _on_button.bind(n)
		if not (n as BaseButton).pressed.is_connected(cb):     # 挪了父节点再进树不重复接
			(n as BaseButton).pressed.connect(cb)


func _on_button(b: BaseButton) -> void:
	play_cue(StringName(b.get_meta(META_KEY, PRESS)))


## 空着的播放器；都在响就抢下一个（轮着来，抢到的是最早开始的）
func _player() -> AudioStreamPlayer:
	for k in POOL:
		var p := _players[(_next + k) % POOL]
		if not p.playing:
			_next = (_next + k + 1) % POOL
			return p
	var p := _players[_next]
	_next = (_next + 1) % POOL
	return p


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[path]


static func _bus(name: StringName) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, &"Master")


static func _volume(name: StringName, v: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx < 0:
		return
	var lin := clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, lin <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(lin) if lin > 0.0 else -80.0)
