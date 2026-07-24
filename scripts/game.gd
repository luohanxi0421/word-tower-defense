# Game.gd - Main gameplay scene
# Tower Defense + Word Spelling mechaincs

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

# --- Enemy Spawning ---
var spawn_timer: Timer
var wave_size: int = 5
var spawn_interval: float = 2.0
var current_word_index: int = 0
var current_enemy: Node2D = null
var level_words: Array = []
var wave_count: int = 0
const WORDS_PER_WAVE: int = 5
const TOTAL_WAVES: int = 3
const ENEMY_SPEED: float = 60.0

func _ready() -> void:
    GameState.load_level(GameState.current_level)
    level_words = GameState.words_for_level.duplicate()
    
    # Connect signals
    spell_input.text_changed.connect(_on_spell_text_changed)
    spell_input.text_submitted.connect(_on_spell_submitted)
    
    # Setup spawn timer
    spawn_timer = Timer.new()
    spawn_timer.one_shot = false
    spawn_timer.timeout.connect(_spawn_next_enemy)
    add_child(spawn_timer)
    
    # Initialize UI
    _update_hud()
    _start_wave()

func _start_wave() -> void:
    wave_count += 1
    wave_label.text = "波次: %d/%d" % [wave_count, TOTAL_WAVES]
    message_label.text = "🌊 第 %d 波来袭！" % wave_count
    message_label.modulate = Color(1, 1, 0, 1)
    
    # Reset for this wave
    wave_size = min(WORDS_PER_WAVE, level_words.size())
    current_word_index = 0
    GameState.enemies_spawned = 0
    
    # Start spawning
    spawn_timer.start(spawn_interval)
    _show_enemy_prompt()

func _spawn_next_enemy() -> void:
    if current_word_index >= wave_size:
        spawn_timer.stop()
        return
    
    if current_enemy != null:
        # Previous enemy still alive - skip spawn
        return
    
    var word_data = level_words[0]  # Get first word
    level_words.pop_front()
    current_word_index += 1
    GameState.enemies_spawned += 1
    
    # Create enemy sprite
    var enemy = Sprite2D.new()
    enemy.texture = _generate_enemy_texture(word_data["cn"])
    enemy.position = enemy_spawn_path.curve.get_point_position(0)
    enemy.scale = Vector2(1.5, 1.5)
    enemy.z_index = 10
    add_child(enemy)
    
    # Add animation
    var tween = create_tween()
    tween.tween_property(enemy, "position", 
        enemy_spawn_path.curve.get_point_position(enemy_spawn_path.curve.point_count - 1), 
        ENEMY_SPEED / 30.0).set_trans(Tween.TRANS_LINEAR)
    
    # Set as current enemy and show prompt
    current_enemy = enemy
    _show_enemy_prompt(word_data)
    
    # If enemy reaches the end
    tween.finished.connect(func():
        if is_instance_valid(enemy):
            enemy.queue_free()
            current_enemy = null
            GameState.take_damage(1)
            _update_hud()
            _show_enemy_prompt()
    )

func _show_enemy_prompt(word_data: Dictionary = {}) -> void:
    if word_data.is_empty():
        spell_hint.text = "等待下一波..."
        enemy_label.text = ""
        spell_input.editable = false
        return
    
    enemy_label.text = "🛡️ 敌人: " + word_data["cn"]
    spell_hint.text = "提示: " + word_data["hint"]
    spell_input.placeholder_text = "输入英文..."
    spell_input.text = ""
    spell_input.editable = true
    spell_input.grab_focus()

func _on_spell_submitted(text: String) -> void:
    if current_enemy == null or level_words.is_empty():
        return
    
    var word_data = level_words[0]
    var attempt = text.strip_edges().to_lower()
    
    if attempt == word_data["en"].to_lower():
        # CORRECT!
        _on_correct_spelling(word_data)
    else:
        # WRONG!
        _on_wrong_spelling(word_data)

func _on_correct_spelling(word_data: Dictionary) -> void:
    # Kill the enemy with animation
    if is_instance_valid(current_enemy):
        var explosion = _create_explosion(current_enemy.position)
        current_enemy.queue_free()
        current_enemy = null
    
    # Award points
    GameState.add_score(10)
    GameState.enemies_killed += 1
    message_label.text = "✅ 正确！ +10分"
    message_label.modulate = Color(0, 1, 0, 1)
    _update_hud()
    
    # Check wave completion
    if GameState.enemies_killed >= wave_size * wave_count:
        if wave_count >= TOTAL_WAVES:
            # Level complete!
            GameState.complete_level()
        else:
            # Start next wave
            await get_tree().create_timer(1.0).timeout
            _start_wave()

func _on_wrong_spelling(word_data: Dictionary) -> void:
    message_label.text = "❌ 错误！正确答案: " + word_data["en"]
    message_label.modulate = Color(1, 0, 0, 1)
    spell_input.text = ""
    # Let them try again - but enemy moves closer!

func _create_explosion(pos: Vector2) -> Node2D:
    var explosion = Sprite2D.new()
    explosion.position = pos
    explosion.scale = Vector2(2, 2)
    add_child(explosion)
    
    # Fade out effect
    var tween = create_tween()
    tween.tween_property(explosion, "modulate", Color(1, 1, 1, 0), 0.5)
    tween.tween_callback(func(): 
        if is_instance_valid(explosion):
            explosion.queue_free()
    )
    return explosion

func _generate_enemy_texture(cn_name: String) -> ImageTexture:
    # Create colored rectangle as placeholder enemy
    # (In production, these would be actual sprite images)
    var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
    var color = Color(0.8, 0.2, 0.2) if "敌人" in cn_name else Color(0.5, 0.3, 0.8)
    img.fill(color)
    return ImageTexture.create_from_image(img)

func _on_spell_text_changed(new_text: String) -> void:
    # Real-time feedback - light up matching letters
    pass

func _update_hud() -> void:
    hp_bar.value = float(GameState.player_hp) / float(GameState.max_hp) * 100.0
    hp_label.text = "❤️ %d/%d" % [GameState.player_hp, GameState.max_hp]
    score_label.text = "⭐ %d" % [GameState.score]
    level_label.text = "第 %d 关" % [GameState.current_level]

func _process(delta: float) -> void:
    # Move enemy along path if exists
    pass
