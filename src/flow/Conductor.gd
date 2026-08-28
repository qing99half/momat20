extends Node
# 音乐指挥(autoload):管理 BGM 播放与「音乐骤停」。
# 登记见 README.md「Autoload 登记」一节。
# 说明:完整节拍器(三音轨 / EventBus.beat / 暂停续播 / 循环点)属任务3,由清九后续补齐;
# 此处仅提供「音乐骤停」所需的最小接口。

var _music: AudioStreamPlayer


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "MusicPlayer"
	add_child(_music)


## 播放指定路径的 BGM(真素材 M1/M2/M3 到位后路径直接复用)。
func play(path: String) -> void:
	_music.stream = load(path)
	_music.play()


## 音乐立即静音(骤停)。「妈妈」黑屏大字时由 BlackscreenText 调用。
func stop_music_immediately() -> void:
	_music.stop()


func is_playing() -> bool:
	return _music.playing