# Game.gd - Main gameplay scene
# Tower Defense + Word Spelling mechanics
extends Node2D

# --- Node References ---
@onready var spell_input: LineEdit = $UI/EnemyDisplay/SpellPanel/SpellInput
@onready var spell_hint: Label = $UI/EnemyDisplay/SpellPanel/HintLabel
@onready var enemy_label: Label = $UI/EnemyDisplay/EnemyLabel
@onready var hp_bar: TextureProgressBar = $UI/HUD/HPBar
@onready var hp_label: Label = $UI/HUD/HPLabel
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var level_label: Label = $UI/HUD/LevelLabel
@onready var wave_label: Label = $UI/HUD/WaveLabel
@onready var message_label: Label = $UI/MessageLabel
@onready var enemy_spawn_path: Path2D = $EnemyPath
@onready var tower_base: Node2D = $TowerBase
@onready var back_button: Button = $UI/BackButton

# --- Wave / Enemy Config ---
const WORDS_PER_WAVE: int = 5
const TOTAL_WAVES: int = 3
const ENEMY_SPEED: float = 60.0          # pixels per second along the path
const POINTS_PER_KILL: int = 10
const ENEMY_STATIC_PATH_FMT := "res://assets/enemies/enemy_%d.png"
const ENEMY_ANIM_PATH_FMT := "res://assets/enemies/enemy_%d_%d.png"
const EXPLOSION_ANIM_PATH_FMT := "res://assets/effects/explosion_%d.png"
const WHITE_TO_ALPHA_SHADER := preload("res://shaders/white_to_alpha.gdshader")
const SOUND_PATH_FMT := "res://assets/sounds/%s.wav"

# --- Runtime State ---
var level_words: Array = []
var wave_count: int = 0
var wave_size: int = 0
var wave_spawned: int = 0
var wave_resolved: int = 0               # killed OR reached end
var wave_killed: int = 0                 # killed only (scoring/stats)
var level_done: bool = false

var current_enemy: Node2D = null
var current_follow: PathFollow2D = null
var current_word_data: Dictionary = {}   # word for the enemy currently on screen
var _sound_players: Dictionary = {}      # sound name -> AudioStreamPlayer
var _last_input_text: String = ""        # detect real typing vs programmatic clears

func _ready() -> void:
	GameState.load_level(GameState.current_level)
	level_words = GameState.words_for_level.duplicate()

	# Build the path programmatically (right -> left). The README says
	# "enemies come from the right"; building it here avoids hand-writing
	# the Curve2D _data blob in the .tscn.
	enemy_spawn_path.curve = Curve2D.new()
	enemy_spawn_path.curve.add_point(Vector2(1280, 0))
	enemy_spawn_path.curve.add_point(Vector2(0, 0))

	spell_input.text_submitted.connect(_on_spell_submitted)
	spell_input.text_changed.connect(_on_spell_text_changed)
	back_button.pressed.connect(_on_back_button_pressed)

	_update_hud()
	_start_wave()

func _start_wave() -> void:
	wave_count += 1
	wave_size = min(WORDS_PER_WAVE, GameState.words_for_level.size())
	wave_spawned = 0
	wave_resolved = 0
	wave_killed = 0
	wave_label.text = "波次: %d/%d" % [wave_count, TOTAL_WAVES]
	message_label.text = "🌊 第 %d 波来袭！" % wave_count
	message_label.modulate = Color(1, 1, 0, 1)
	_spawn_next_enemy()

func _spawn_next_enemy() -> void:
	if level_done:
		return
	if current_enemy != null:
		return                          # one enemy on screen at a time
	if wave_spawned >= wave_size:
		return                          # wave already fully spawned
	if level_words.is_empty():
		# Bank ran out (e.g. 3 waves * 5 words > 10-word bank): refill
		# from the level's full list as review, so a wave can always
		# be completed.
		level_words = GameState.words_for_level.duplicate()
		level_words.shuffle()
	if level_words.is_empty():
		return

	var word_data: Dictionary = level_words[0]
	level_words.pop_front()
	wave_spawned += 1
	GameState.enemies_spawned += 1

	# Drive the enemy along the path with a PathFollow2D so movement is
	# real speed-based (pixels/sec), not a fixed-duration tween.
	var follow := PathFollow2D.new()
	follow.loop = false
	follow.rotates = false
	enemy_spawn_path.add_child(follow)

	var level := _enemy_level(String(word_data["en"]))
	var enemy := _create_enemy_visual(level)
	enemy.scale = Vector2(0.08, 0.08)
	enemy.z_index = 10
	follow.add_child(enemy)

	# Chinese word floating above the enemy block, so the player watches
	# the enemy while typing. Parented to the follow (not the scaled
	# sprite) so the text isn't enlarged.
	var cn_label := Label.new()
	cn_label.text = String(word_data["cn"])
	cn_label.add_theme_font_size_override("font_size", 28)
	cn_label.size = Vector2(240, 40)
	cn_label.position = Vector2(-120, -120)
	cn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cn_label.add_theme_color_override("font_color", Color.WHITE)
	cn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cn_label.add_theme_constant_override("outline_size", 6)
	cn_label.z_index = 11
	follow.add_child(cn_label)

	current_follow = follow
	current_enemy = enemy
	current_word_data = word_data       # remember THIS enemy's word (bug fix)

	_show_enemy_prompt(word_data)

func _process(delta: float) -> void:
	if current_follow != null and is_instance_valid(current_follow):
		current_follow.progress += ENEMY_SPEED * delta
		if current_follow.progress_ratio >= 1.0:
			_enemy_reached_end()
	# Keep the input focused while an enemy is on screen, so the player
	# never has to click the box again after a correct/wrong submission.
	# Never yank focus from another control the player is interacting with
	# (e.g. the BackButton): grabbing every frame cancels its click.
	if current_enemy != null and spell_input.editable and not spell_input.has_focus():
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner == null:
			spell_input.grab_focus()

func _enemy_reached_end() -> void:
	_clear_current_enemy()
	wave_resolved += 1
	message_label.text = "💔 敌人突破防线！"
	message_label.modulate = Color(1, 0.4, 0.4, 1)
	GameState.take_damage(1)
	_update_hud()
	_show_enemy_prompt({})
	_check_wave_or_level()

func _on_spell_text_changed(new_text: String) -> void:
	# Play a key click only when the player types a new character (text
	# grows), not when the box is programmatically cleared.
	if new_text.length() > _last_input_text.length():
		_play_sound("key")
	_last_input_text = new_text

func _on_spell_submitted(text: String) -> void:
	if current_enemy == null or current_word_data.is_empty():
		return
	var attempt := text.strip_edges().to_lower()
	if attempt == String(current_word_data["en"]).to_lower():
		_on_correct_spelling()
	else:
		_on_wrong_spelling(attempt)

func _on_correct_spelling() -> void:
	_play_sound("hit")
	if current_enemy != null and is_instance_valid(current_enemy):
		_create_explosion(current_enemy.global_position)
	_clear_current_enemy()

	GameState.add_score(POINTS_PER_KILL)
	GameState.enemies_killed += 1
	wave_killed += 1
	wave_resolved += 1
	message_label.text = "✅ 正确！ +%d分" % POINTS_PER_KILL
	message_label.modulate = Color(0, 1, 0, 1)
	_update_hud()
	_check_wave_or_level()

func _on_wrong_spelling(attempt: String) -> void:
	_play_sound("error")
	message_label.text = "❌ 拼错了，再试试！提示: " + String(current_word_data["hint"])
	message_label.modulate = Color(1, 0, 0, 1)
	GameState.record_wrong_word(String(current_word_data["cn"]), attempt, String(current_word_data["en"]))
	spell_input.text = ""
	spell_input.grab_focus()

# Abandon the current run and return to the main menu. MainMenu._ready()
# calls GameState.reset(), discarding HP/score/level; progress is only
# saved on complete_level(), so a mid-level quit simply forfeits the run.
func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _check_wave_or_level() -> void:
	if wave_resolved >= wave_size:
		# Current wave fully resolved (killed or escaped).
		if wave_count >= TOTAL_WAVES:
			level_done = true
			message_label.text = "🎉 关卡通过！"
			message_label.modulate = Color(0, 1, 0, 1)
			await get_tree().create_timer(1.5).timeout
			GameState.complete_level()
		else:
			await get_tree().create_timer(1.0).timeout
			_start_wave()
	else:
		_spawn_next_enemy()

func _clear_current_enemy() -> void:
	# Freeing the follow frees the enemy sprite parented under it.
	if current_follow != null and is_instance_valid(current_follow):
		current_follow.queue_free()
	current_enemy = null
	current_follow = null
	current_word_data = {}

func _show_enemy_prompt(word_data: Dictionary = {}) -> void:
	if word_data.is_empty():
		enemy_label.text = "等待下一只敌人..."
		spell_hint.text = ""
		spell_input.editable = false
		spell_input.text = ""
		return
	enemy_label.text = "⚔️ 输入英文击杀敌人！"
	spell_hint.text = "提示: " + String(word_data["hint"])
	spell_input.text = ""
	spell_input.editable = true
	spell_input.grab_focus()

func _create_explosion(pos: Vector2) -> void:
	_play_sound("explosion")
	var frames := _build_explosion_frames()
	if frames.get_frame_count("boom") > 0:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.position = pos
		anim.scale = Vector2(0.1, 0.1)
		anim.z_index = 20
		_apply_white_to_alpha(anim)
		add_child(anim)
		anim.play("boom")
		anim.animation_finished.connect(func():
			if is_instance_valid(anim):
				anim.queue_free()
		)
		return
	# Fallback: orange square scaling + fading (no explosion assets yet)
	var explosion := Sprite2D.new()
	explosion.position = pos
	explosion.scale = Vector2(2, 2)
	explosion.z_index = 20
	explosion.texture = _generate_explosion_texture()
	add_child(explosion)
	var tween := create_tween()
	tween.tween_property(explosion, "scale", Vector2(4, 4), 0.4)
	tween.parallel().tween_property(explosion, "modulate", Color(1, 1, 1, 0), 0.4)
	tween.tween_callback(func():
		if is_instance_valid(explosion):
			explosion.queue_free()
	)

# Collect explosion frames explosion_1.png, _2.png, ... into a one-shot
# "boom" animation. Returns an empty animation if no frames exist.
func _build_explosion_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("boom")
	frames.set_animation_loop("boom", false)
	frames.set_animation_speed("boom", 8.0)
	var i := 1
	while true:
		var path := EXPLOSION_ANIM_PATH_FMT % i
		if not ResourceLoader.exists(path):
			break
		frames.add_frame("boom", load(path))
		i += 1
	return frames

# Enemy tier by English word length:
#   1-3 -> lv1, 4-5 -> lv2, 6-8 -> lv3, 9-13 -> lv4, >=14 -> lv5
func _enemy_level(en: String) -> int:
	var n := en.length()
	if n <= 3:
		return 1
	if n <= 5:
		return 2
	if n <= 8:
		return 3
	if n <= 13:
		return 4
	return 5

# Build the enemy's visual node for a level, in priority order:
#   1. Animated walk-cycle frames (enemy_{level}_1.png, _2.png, ...)
#   2. A single static sprite (enemy_{level}.png)
#   3. Colored square fallback (so the game runs with no assets)
func _create_enemy_visual(level: int) -> Node2D:
	var frames := _build_enemy_sprite_frames(level)
	if frames.get_frame_count("walk") > 0:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.play("walk")
		_apply_white_to_alpha(anim)
		return anim
	var static_path := ENEMY_STATIC_PATH_FMT % level
	if ResourceLoader.exists(static_path):
		var s := Sprite2D.new()
		s.texture = load(static_path)
		_apply_white_to_alpha(s)
		return s
	var fb := Sprite2D.new()
	fb.texture = _generate_enemy_texture(level)
	return fb

# AI-generated sprites come on a white background (no alpha channel).
# This shader knocks out near-white pixels so only the monster shows.
func _apply_white_to_alpha(node: CanvasItem) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WHITE_TO_ALPHA_SHADER
	node.material = mat

# Play a sound effect by name (loads lazily; silent if asset is missing).
# Names: "key" (typing), "hit" (correct word), "explosion" (enemy dies),
# "error" (wrong spelling).
func _play_sound(sound_name: String) -> void:
	var path := SOUND_PATH_FMT % sound_name
	if not ResourceLoader.exists(path):
		return
	if not _sound_players.has(sound_name):
		var player := AudioStreamPlayer.new()
		player.stream = load(path)
		player.volume_db = 3.0   # slight boost on top of ffmpeg-normalized assets
		add_child(player)
		_sound_players[sound_name] = player
	var player = _sound_players[sound_name]
	player.play()

# Collect walk-cycle frames enemy_{level}_1.png, _2.png, ... into a
# looping SpriteFrames animation. Returns an empty "walk" animation if
# no frames exist (caller falls back to static/colored square).
func _build_enemy_sprite_frames(level: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	var i := 1
	while true:
		var path := ENEMY_ANIM_PATH_FMT % [level, i]
		if not ResourceLoader.exists(path):
			break
		frames.add_frame("walk", load(path))
		i += 1
	return frames

func _generate_enemy_texture(level: int) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [Color(0.3, 0.8, 0.3), Color(0.8, 0.8, 0.2), Color(0.8, 0.4, 0.2), Color(0.8, 0.2, 0.2), Color(0.5, 0.2, 0.7)]
	var color := colors[clampi(level - 1, 0, colors.size() - 1)]
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _generate_explosion_texture() -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.6, 0.1, 1))
	return ImageTexture.create_from_image(img)

func _update_hud() -> void:
	hp_bar.value = float(GameState.player_hp) / float(GameState.max_hp) * 100.0
	hp_label.text = "❤️ %d/%d" % [GameState.player_hp, GameState.max_hp]
	score_label.text = "⭐ %d" % GameState.score
	level_label.text = "第 %d 关" % GameState.current_level
