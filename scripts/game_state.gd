# Word Tower Defense - Global Game State (AutoLoad singleton)
# Handles player progress, word bank (loaded from CSV), and persistent
# per-player records (wrong words, level completion) stored under user://.
extends Node

# --- Player State ---
var player_hp: int = 10
var max_hp: int = 10
var score: int = 0
var current_level: int = 1
var gold: int = 0
var current_user: String = ""

# --- Word Bank ---
# Loaded at runtime from res://data/words.csv. The small dictionary below
# is a FALLBACK used only if the CSV is missing or fails to parse, so the
# game still runs. Edit data/words.csv to change the real word data.
const WORDS_CSV_PATH := "res://data/words.csv"

var word_bank: Dictionary = {
	1: [
		{"cn": "苹果", "en": "apple", "hint": "a__le"},
		{"cn": "猫", "en": "cat", "hint": "c_t"},
		{"cn": "书", "en": "book", "hint": "b__k"},
	],
	2: [
		{"cn": "工程师", "en": "engineer", "hint": "en_in__r"},
		{"cn": "美丽的", "en": "beautiful", "hint": "be_ut_f_l"},
		{"cn": "重要的", "en": "important", "hint": "imp_rt_nt"},
	],
	3: [
		{"cn": "大气层", "en": "atmosphere", "hint": "at_osph_re"},
		{"cn": "文明", "en": "civilization", "hint": "c_v_l_z_t_on"},
		{"cn": "知识", "en": "knowledge", "hint": "kn_wl_dge"},
	],
}

# --- Persistent Records (per player, under user://) ---
const LAST_USER_PATH := "user://last_user.txt"
const WRONG_WORDS_PATH := "user://wrong_words.csv"
const LEVEL_RECORDS_PATH := "user://level_records.csv"
const PROGRESS_PATH := "user://progress.csv"

# Current enemy wave state
var current_enemies: Array = []
var enemies_spawned: int = 0
var enemies_killed: int = 0
var words_for_level: Array = []

signal score_changed(new_score: int)
signal hp_changed(new_hp: int)
signal level_completed(level: int, score: int)

func _ready() -> void:
	_load_word_bank_from_csv()
	load_level(current_level)

# --- CSV word bank loading ---
# CSV format (UTF-8, comma-separated, first line is header):
#   level,cn,en,hint
# `hint` is optional: leave it empty and a mask is auto-generated from `en`.
func _load_word_bank_from_csv() -> void:
	if not FileAccess.file_exists(WORDS_CSV_PATH):
		push_warning("Words CSV not found at %s, using built-in fallback." % WORDS_CSV_PATH)
		return
	var f := FileAccess.open(WORDS_CSV_PATH, FileAccess.READ)
	if f == null:
		push_warning("Cannot open words CSV (%s), using built-in fallback." % WORDS_CSV_PATH)
		return
	var loaded: Dictionary = {}
	var header_seen := false
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		if not header_seen:
			header_seen = true
			continue   # skip header row
		var parts := _csv_parse_line(line)
		if parts.size() < 3:
			continue   # malformed line
		var level := int(parts[0].strip_edges())
		var cn := String(parts[1]).strip_edges()
		var en := String(parts[2]).strip_edges()
		var hint := ""
		if parts.size() >= 4:
			hint = String(parts[3]).strip_edges()
		if hint == "":
			hint = _generate_hint(en)
		if not loaded.has(level):
			loaded[level] = []
		loaded[level].append({"cn": cn, "en": en, "hint": hint})
	if loaded.is_empty():
		push_warning("Words CSV loaded no rows, using built-in fallback.")
		return
	word_bank = loaded
	print("Word bank loaded from CSV: %d levels" % word_bank.size())

# Generate a spelling hint by masking ~40% of letters (first letter kept).
func _generate_hint(en: String) -> String:
	var s := en.to_lower()
	var n := s.length()
	if n <= 1:
		return s
	var hide_count: int = clampi(int(n * 0.4), 1, n - 1)
	var indices := range(1, n)   # never mask the first letter
	indices.shuffle()
	var masked: Dictionary = {}
	for i in range(hide_count):
		masked[indices[i]] = true
	var result := ""
	for i in range(n):
		if masked.has(i):
			result += "_"
		else:
			result += s[i]
	return result

func load_level(level: int) -> void:
	if not word_bank.has(level):
		level = 1
	current_level = level
	enemies_spawned = 0
	enemies_killed = 0
	words_for_level = word_bank[level].duplicate()
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
	record_level_complete(current_level, score)
	save_progress(current_user, current_level + 1)
	get_tree().change_scene_to_file("res://scenes/level_complete.tscn")

func reset() -> void:
	player_hp = max_hp
	score = 0
	gold = 0
	current_level = 1

# --- Player name persistence ---
func load_last_user() -> String:
	var f := FileAccess.open(LAST_USER_PATH, FileAccess.READ)
	if f == null:
		return ""
	var user := f.get_as_text().strip_edges()
	f.close()
	return user

func save_last_user(user: String) -> void:
	var f := FileAccess.open(LAST_USER_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot save last user to %s" % LAST_USER_PATH)
		return
	f.store_string(user)
	f.close()

# --- Level progress per user ---
# Returns the level the user last reached (next to play), or 1 if none
# or if the stored level no longer exists in the word bank.
func load_progress(user: String) -> int:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return 1
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	if f == null:
		return 1
	var header_seen := false
	var found_level := 1
	var found := false
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		if not header_seen:
			header_seen = true
			continue
		var parts := _csv_parse_line(line)
		if parts.size() >= 2 and parts[0] == user:
			found_level = int(parts[1])
			found = true
			break
	f.close()
	if not found or not word_bank.has(found_level):
		return 1
	return found_level

# Update (or insert) the user's reached level, rewriting the file.
func save_progress(user: String, level: int) -> void:
	if user == "":
		return
	var entries: Array = []
	if FileAccess.file_exists(PROGRESS_PATH):
		var fr := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
		if fr != null:
			var header_seen := false
			while not fr.eof_reached():
				var line := fr.get_line()
				if line.strip_edges() == "":
					continue
				if not header_seen:
					header_seen = true
					continue
				var parts := _csv_parse_line(line)
				if parts.size() >= 2:
					entries.append([parts[0], int(parts[1])])
			fr.close()
	var found := false
	for i in range(entries.size()):
		if entries[i][0] == user:
			entries[i][1] = level
			found = true
			break
	if not found:
		entries.append([user, level])
	var fw := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if fw == null:
		push_warning("Cannot save progress to %s" % PROGRESS_PATH)
		return
	fw.store_line("user,level")
	for e in entries:
		fw.store_line("%s,%d" % [_csv_escape(String(e[0])), int(e[1])])
	fw.close()

# --- Wrong-word recording ---
func record_wrong_word(cn: String, wrong: String, correct: String) -> void:
	if current_user == "":
		return
	_ensure_csv_header(WRONG_WORDS_PATH, "user,time,cn,wrong_input,correct_en")
	var f := FileAccess.open(WRONG_WORDS_PATH, FileAccess.READ_WRITE)
	if f == null:
		push_warning("Cannot write wrong words to %s" % WRONG_WORDS_PATH)
		return
	f.seek_end()
	var time := Time.get_datetime_string_from_system()
	f.store_line("%s,%s,%s,%s,%s" % [_csv_escape(current_user), time, _csv_escape(cn), _csv_escape(wrong), _csv_escape(correct)])
	f.close()

# --- Level completion recording ---
func record_level_complete(level: int, sc: int) -> void:
	if current_user == "":
		return
	_ensure_csv_header(LEVEL_RECORDS_PATH, "user,level,score,time")
	var f := FileAccess.open(LEVEL_RECORDS_PATH, FileAccess.READ_WRITE)
	if f == null:
		push_warning("Cannot write level records to %s" % LEVEL_RECORDS_PATH)
		return
	f.seek_end()
	var time := Time.get_datetime_string_from_system()
	f.store_line("%s,%d,%d,%s" % [_csv_escape(current_user), level, sc, time])
	f.close()

# --- Read back records for a given user ---
func get_wrong_words(user: String) -> Array:
	var result: Array = []
	if not FileAccess.file_exists(WRONG_WORDS_PATH):
		return result
	var f := FileAccess.open(WRONG_WORDS_PATH, FileAccess.READ)
	if f == null:
		return result
	var header_seen := false
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		if not header_seen:
			header_seen = true
			continue
		var parts := _csv_parse_line(line)
		if parts.size() >= 5 and parts[0] == user:
			result.append({"time": parts[1], "cn": parts[2], "wrong": parts[3], "correct": parts[4]})
	f.close()
	return result

func get_level_records(user: String) -> Array:
	var result: Array = []
	if not FileAccess.file_exists(LEVEL_RECORDS_PATH):
		return result
	var f := FileAccess.open(LEVEL_RECORDS_PATH, FileAccess.READ)
	if f == null:
		return result
	var header_seen := false
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		if not header_seen:
			header_seen = true
			continue
		var parts := _csv_parse_line(line)
		if parts.size() >= 4 and parts[0] == user:
			result.append({"level": int(parts[1]), "score": int(parts[2]), "time": parts[3]})
	f.close()
	return result

# --- CSV helpers ---
func _ensure_csv_header(path: String, header: String) -> void:
	if not FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_line(header)
			f.close()

# Wrap a field in quotes if it contains a comma or quote; escape quotes.
func _csv_escape(s: String) -> String:
	if s.find(",") != -1 or s.find("\"") != -1:
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s

# Simple CSV parser supporting quoted fields with escaped ("") quotes.
func _csv_parse_line(line: String) -> Array:
	var result: Array = []
	var i := 0
	var n := line.length()
	while i < n:
		var ch := line[i]
		if ch == "\"":
			i += 1
			var field := ""
			while i < n:
				if line[i] == "\"":
					if i + 1 < n and line[i + 1] == "\"":
						field += "\""
						i += 2
					else:
						i += 1
						break
				else:
					field += line[i]
					i += 1
			result.append(field)
			if i < n and line[i] == ",":
				i += 1
		else:
			var field := ""
			while i < n and line[i] != ",":
				field += line[i]
				i += 1
			result.append(field)
			if i < n and line[i] == ",":
				i += 1
	return result
