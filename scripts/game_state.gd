# Word Tower Defense - Global Game State (AutoLoad singleton)
# Handles player progress, word bank, settings

extends Node

# --- Player State ---
var player_hp: int = 10
var max_hp: int = 10
var score: int = 0
var current_level: int = 1
var gold: int = 0

# --- Word Bank ---
# Each level has a list of { "cn": "中文", "en": "english", "hint": "h__t" }
var word_bank: Dictionary = {
    1: [
        {"cn": "苹果", "en": "apple", "hint": "a__le"},
        {"cn": "香蕉", "en": "banana", "hint": "b_n_n_"},
        {"cn": "猫", "en": "cat", "hint": "c_t"},
        {"cn": "狗", "en": "dog", "hint": "d_g"},
        {"cn": "书", "en": "book", "hint": "b__k"},
        {"cn": "桌子", "en": "desk", "hint": "d__k"},
        {"cn": "钢笔", "en": "pen", "hint": "p_n"},
        {"cn": "汽车", "en": "car", "hint": "c_r"},
        {"cn": "房子", "en": "house", "hint": "h__se"},
        {"cn": "学校", "en": "school", "hint": "sch__l"},
    ],
    2: [
        {"cn": "工程师", "en": "engineer", "hint": "en_in__r"},
        {"cn": "图书馆", "en": "library", "hint": "l_br_ry"},
        {"cn": "美丽的", "en": "beautiful", "hint": "be_ut_f_l"},
        {"cn": "不同的", "en": "different", "hint": "d_ff_r_nt"},
        {"cn": "重要的", "en": "important", "hint": "imp_rt_nt"},
        {"cn": "困难的", "en": "difficult", "hint": "d_ff_c_lt"},
        {"cn": "有趣的", "en": "interesting", "hint": "int_r_st_ng"},
        {"cn": "普通的", "en": "ordinary", "hint": "or_in_ry"},
        {"cn": "著名的", "en": "famous", "hint": "f_m__s"},
        {"cn": "危险的", "en": "dangerous", "hint": "d_ng_r_us"},
    ],
    3: [
        {"cn": "大气层", "en": "atmosphere", "hint": "at_osph_re"},
        {"cn": "生物多样性", "en": "biodiversity", "hint": "b_o_ivers_ty"},
        {"cn": "文明", "en": "civilization", "hint": "c_v_l_z_t_on"},
        {"cn": "民主", "en": "democracy", "hint": "dem_cr_cy"},
        {"cn": "环境", "en": "environment", "hint": "en_ir_nm_nt"},
        {"cn": "地理", "en": "geography", "hint": "ge_gr_phy"},
        {"cn": "假设", "en": "hypothesis", "hint": "hyp_th_s_s"},
        {"cn": "识别", "en": "identify", "hint": "id_nt_fy"},
        {"cn": "知识", "en": "knowledge", "hint": "kn_wl_dge"},
        {"cn": "文学", "en": "literature", "hint": "l_t_r_t_re"},
    ],
}

# Current enemy wave state
var current_enemies: Array = []
var enemies_spawned: int = 0
var enemies_killed: int = 0
var words_for_level: Array = []

signal score_changed(new_score: int)
signal hp_changed(new_hp: int)
signal level_completed(level: int, score: int)

func _ready() -> void:
    load_level(current_level)

func load_level(level: int) -> void:
    current_level = level
    enemies_spawned = 0
    enemies_killed = 0
    words_for_level = word_bank.get(level, word_bank[1]).duplicate()
    words_for_level.shuffle()
    print("Level %d loaded with %d words" % [level, words_for_level.size()])

func add_score(points: int) -> void:
    score += points
    score_changed.emit(score)

func take_damage(amount: int = 1) -> void:
    player_hp -= amount
    hp_changed.emit(player_hp)
    if player_hp <= 0:
        game_over()

func game_over() -> void:
    print("Game Over! Final score: %d" % score)
    get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func complete_level() -> void:
    level_completed.emit(current_level, score)
    get_tree().change_scene_to_file("res://scenes/level_complete.tscn")

func reset() -> void:
    player_hp = max_hp
    score = 0
    gold = 0
    current_level = 1
