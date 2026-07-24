# Quiz Scene - Test after completing a level
extends Control

@onready var question_label: Label = $VBoxContainer/QuestionLabel
@onready var option_a: Button = $VBoxContainer/Options/AButton
@onready var option_b: Button = $VBoxContainer/Options/BButton
@onready var option_c: Button = $VBoxContainer/Options/CButton
@onready var option_d: Button = $VBoxContainer/Options/DButton
@onready var feedback_label: Label = $VBoxContainer/FeedbackLabel
@onready var progress_label: Label = $VBoxContainer/ProgressLabel
@onready var result_label: Label = $VBoxContainer/ResultLabel

var questions: Array = []
var current_q: int = 0
var correct_count: int = 0
const TOTAL_QUESTIONS: int = 5

func _ready() -> void:
    result_label.hide()
    _generate_questions()
    _show_question()

func _generate_questions() -> void:
    var words = GameState.word_bank.get(GameState.current_level, GameState.word_bank[1])
    words.shuffle()
    for i in range(min(TOTAL_QUESTIONS, words.size())):
        var w = words[i]
        var wrong_options = words.duplicate()
        wrong_options.shuffle()
        var options = [w["en"]]
        for opt in wrong_options:
            if opt["en"] != w["en"] and options.size() < 4:
                options.append(opt["en"])
        options.shuffle()
        questions.append({
            "cn": w["cn"],
            "correct": w["en"],
            "options": options
        })

func _show_question() -> void:
    if current_q >= questions.size():
        _show_result()
        return
    
    var q = questions[current_q]
    question_label.text = "请选择 \"%s\" 的英文翻译：" % q["cn"]
    option_a.text = q["options"][0]
    option_b.text = q["options"][1]
    option_c.text = q["options"][2]
    option_d.text = q["options"][3] if q["options"].size() > 3 else "(空)"
    feedback_label.text = ""
    progress_label.text = "题目 %d/%d" % [current_q + 1, questions.size()]

func _on_option_pressed(option_text: String) -> void:
    var q = questions[current_q]
    if option_text == q["correct"]:
        correct_count += 1
        feedback_label.text = "✅ 正确！"
        feedback_label.modulate = Color(0, 1, 0, 1)
    else:
        feedback_label.text = "❌ 正确答案是: " + q["correct"]
        feedback_label.modulate = Color(1, 0, 0, 1)
    
    current_q += 1
    await get_tree().create_timer(1.0).timeout
    _show_question()

func _show_result() -> void:
    question_label.hide()
    $VBoxContainer/Options.hide()
    feedback_label.hide()
    progress_label.hide()
    
    result_label.show()
    result_label.text = "📝 测验完成！\n\n正确: %d / %d\n\n%s" % [
        correct_count, questions.size(),
        "太棒了！你已经掌握了这些单词！" if correct_count >= questions.size() * 0.8 else "继续加油，再来一次！"
    ]

func _on_back_button_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
