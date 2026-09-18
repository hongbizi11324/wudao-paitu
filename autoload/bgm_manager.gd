extends Node

# ==============================
# 音频管理器（扩展原 BgmManager）
# BGM 播放 + 程序合成音效（不依赖外部素材）+ 音乐/音效音量设置（持久化）
# ==============================

var is_enabled: bool = true
var music_volume: float = 0.8
var sfx_volume: float = 0.8

var _player: AudioStreamPlayer = null
var _click_player: AudioStreamPlayer = null
var _stop_timer: Timer = null

# 音效：3 个轮询声道防重叠
var _sfx_players: Array = []
var _sfx_index: int = 0
var _sfx_cache: Dictionary = {}   # 音效名 -> AudioStreamWAV

# 点击音效裁剪范围
var _click_start: float = 1.5
var _click_duration: float = 1.0

const SFX_RATE: int = 22050
const CFG_PATH: String = "user://bgm_setting.cfg"


func _ready() -> void:
	# 背景音乐播放器
	_player = AudioStreamPlayer.new()
	_player.name = "BgmPlayer"
	_player.stream = load("res://assets/audio/游戏背景音乐 8.mp3")
	_player.bus = &"Master"
	add_child(_player)
	if _player.stream:
		_player.stream.set_loop(true)

	# 点击音效播放器
	_click_player = AudioStreamPlayer.new()
	_click_player.name = "ClickPlayer"
	_click_player.stream = load("res://assets/audio/点击音效.wav")
	_click_player.bus = &"Master"
	add_child(_click_player)

	# 停止定时器（点击音效播放短片段）
	_stop_timer = Timer.new()
	_stop_timer.name = "ClickStopTimer"
	_stop_timer.one_shot = true
	_stop_timer.timeout.connect(_stop_click)
	add_child(_stop_timer)

	# 音效声道池
	for i in range(3):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = &"Master"
		add_child(p)
		_sfx_players.append(p)

	# 读取上次设置（兼容旧版直接存 bool 的格式）
	if FileAccess.file_exists(CFG_PATH):
		var f = FileAccess.open(CFG_PATH, FileAccess.READ)
		if f:
			var data = f.get_var()
			if typeof(data) == TYPE_DICTIONARY:
				is_enabled = data.get("music_on", true)
				music_volume = float(data.get("music_volume", 0.8))
				sfx_volume = float(data.get("sfx_volume", 0.8))
			elif typeof(data) == TYPE_BOOL:
				is_enabled = data
			f.close()

	_apply_volumes()
	if is_enabled:
		_player.play()


func _input(event: InputEvent) -> void:
	# 任何鼠标点击 → 从第1秒播放到第2秒
	if event is InputEventMouseButton and event.pressed:
		_click_player.play(_click_start)
		_stop_timer.start(_click_duration)


func _stop_click() -> void:
	_click_player.stop()


func toggle() -> void:
	is_enabled = not is_enabled
	if is_enabled:
		_player.play()
	else:
		_player.stop()
	_save_cfg()


func get_icon() -> String:
	return "🔊 音乐" if is_enabled else "🔇 静音"


# ==============================
# 音量
# ==============================

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_cfg()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_save_cfg()


func _apply_volumes() -> void:
	if _player:
		_player.volume_db = linear_to_db(maxf(music_volume, 0.0001)) if music_volume > 0.0 else -80.0
	if _click_player:
		_click_player.volume_db = linear_to_db(maxf(sfx_volume, 0.0001)) if sfx_volume > 0.0 else -80.0
	for p in _sfx_players:
		p.volume_db = linear_to_db(maxf(sfx_volume, 0.0001)) if sfx_volume > 0.0 else -80.0


func _save_cfg() -> void:
	var f = FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f:
		f.store_var({
			"music_on": is_enabled,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
		})
		f.close()


# ==============================
# 音效播放（程序合成，无外部素材）
# ==============================

func play_sfx(name: String) -> void:
	if not is_enabled:
		return
	var stream: AudioStreamWAV = _sfx_cache.get(name)
	if stream == null:
		stream = _synth_sfx(name)
		if stream == null:
			return
		_sfx_cache[name] = stream

	# 轮询一个空闲声道（优先没在播的）
	var player: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_players[_sfx_index]
		_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = stream
	player.play()


## 程序合成音效：正弦/方波/噪声 + 快起音指数衰减包络
func _synth_sfx(name: String) -> AudioStreamWAV:
	var out: PackedFloat32Array = PackedFloat32Array()

	match name:
		"play":
			# 出牌：短促"噗"（方波 180Hz + 噪声尾巴）
			_tone(out, 180.0, 0.09, 0.35, "square")
			_tone(out, 0.0, 0.05, 0.12, "noise")
		"draw":
			# 抽牌：轻快上滑
			_slide(out, 300.0, 520.0, 0.12, 0.25)
		"hit":
			# 伤害命中：低沉"咚"
			_tone(out, 110.0, 0.16, 0.5, "sine")
			_tone(out, 55.0, 0.12, 0.3, "sine")
		"block":
			# 格挡：金属"叮"
			_tone(out, 880.0, 0.14, 0.3, "sine")
			_tone(out, 1320.0, 0.1, 0.15, "sine")
		"heal":
			# 回血：上行琶音
			_tone(out, 523.0, 0.09, 0.25, "sine")
			_tone(out, 659.0, 0.09, 0.25, "sine")
			_tone(out, 784.0, 0.12, 0.25, "sine")
		"energy":
			# 内力：双声轻鸣
			_tone(out, 660.0, 0.08, 0.22, "sine")
			_tone(out, 880.0, 0.1, 0.22, "sine")
		"power":
			# POWER 激活：上升滑音
			_slide(out, 220.0, 880.0, 0.28, 0.4)
		"hurt":
			# 玩家受击：下行闷响
			_tone(out, 150.0, 0.2, 0.5, "sine")
			_tone(out, 75.0, 0.16, 0.35, "sine")
		"victory":
			# 胜利：上行三音
			_tone(out, 523.0, 0.12, 0.3, "sine")
			_tone(out, 659.0, 0.12, 0.3, "sine")
			_tone(out, 784.0, 0.18, 0.35, "sine")
			_tone(out, 1046.0, 0.3, 0.35, "sine")
		"defeat":
			# 败北：下行二音
			_tone(out, 392.0, 0.2, 0.3, "sine")
			_tone(out, 262.0, 0.35, 0.3, "sine")
		"breakthrough":
			# 突破：辉煌和弦
			_tone(out, 523.0, 0.2, 0.3, "sine")
			_tone(out, 659.0, 0.2, 0.3, "sine")
			_tone(out, 784.0, 0.2, 0.3, "sine")
			_tone(out, 1046.0, 0.4, 0.3, "sine")
		_:
			return null

	if out.is_empty():
		return null

	# 转 16bit PCM
	var bytes := PackedByteArray()
	bytes.resize(out.size() * 2)
	for i in range(out.size()):
		var s: int = int(clampf(out[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = s & 0xFF
		bytes[i * 2 + 1] = (s >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SFX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## 追加一个音（freq=0 时用噪声）
func _tone(out: PackedFloat32Array, freq: float, duration: float, vol: float, wave: String) -> void:
	var n := int(duration * SFX_RATE)
	for i in range(n):
		var t := float(i) / SFX_RATE
		# 快起音 + 指数衰减包络
		var env: float = minf(1.0, t / 0.012) * exp(-3.2 * t / maxf(duration, 0.01))
		var v: float = 0.0
		match wave:
			"square":
				v = 1.0 if fmod(freq * t, 1.0) < 0.5 else -1.0
			"noise":
				v = randf_range(-1.0, 1.0)
			_:
				v = sin(TAU * freq * t)
		out.append(v * env * vol)


## 追加一个滑音（从 f0 线性滑到 f1）
func _slide(out: PackedFloat32Array, f0: float, f1: float, duration: float, vol: float) -> void:
	var n := int(duration * SFX_RATE)
	for i in range(n):
		var t := float(i) / SFX_RATE
		var freq: float = lerpf(f0, f1, t / duration)
		var env: float = minf(1.0, t / 0.015) * exp(-3.0 * t / maxf(duration, 0.01))
		out.append(sin(TAU * freq * t) * env * vol)
