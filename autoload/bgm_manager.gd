extends Node

# ==============================
# 背景音乐管理器（自动加载）
# 跨场景持续播放，可开关
# ==============================

var is_enabled: bool = true
var _player: AudioStreamPlayer = null
var _click_player: AudioStreamPlayer = null
var _stop_timer: Timer = null

# 点击音效裁剪范围
var _click_start: float = 1.5   # 从第几秒开始播
var _click_duration: float = 1.0  # 播多久后停


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
	
	# 停止定时器（播放1秒后停止）
	_stop_timer = Timer.new()
	_stop_timer.name = "ClickStopTimer"
	_stop_timer.one_shot = true
	_stop_timer.timeout.connect(_stop_click)
	add_child(_stop_timer)
	
	# 读取上次设置
	if FileAccess.file_exists("user://bgm_setting.cfg"):
		var f = FileAccess.open("user://bgm_setting.cfg", FileAccess.READ)
		if f:
			is_enabled = f.get_var(true)
			f.close()
	
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
	
	var f = FileAccess.open("user://bgm_setting.cfg", FileAccess.WRITE)
	if f:
		f.store_var(is_enabled)
		f.close()


func get_icon() -> String:
	return "🔊 音乐" if is_enabled else "🔇 静音"
