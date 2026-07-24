# Word Tower Defense - 单词塔防

🎮 **一个通过塔防游戏背高中英语单词的 Godot 4.3 项目**

![Godot 4.3](https://img.shields.io/badge/Godot-4.3-478CBF?logo=godot-engine&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

## 项目定位

> **目标学生：** 理科还行但英语极差的高一学生（偏科型）  
> **核心理念：** 用游戏化方式解决"高一学生从初中到高中学习方式转变"的痛点  
> **验证路径：** 先做 Demo → 拿 Demo 找高中老师合作 → 验证后扩展全科

## 玩法机制

### 英语塔防模式
1. 敌人（携带中文标注的 3D 物品形象）从右侧走来
2. 玩家看到中文和拼写提示（如 `a__le`）
3. 输入正确的英文单词才能发射子弹击杀敌人
4. 拼错则敌人继续前进，走到终点扣血
5. 正确率 = 攻击力，击杀数 = 得分

### 内容架构
- **关卡推进：** 3 关 × 3 波 × 每波 5 个单词
- **视频教学：** 关键知识点以短视频形式嵌入关卡
- **试卷测验：** 过关后弹出选择题试卷，考察学习成果

## 项目结构

```
word-tower-defense/
├── project.godot          # Godot 4.3 项目配置
├── scenes/                # 场景文件
│   ├── main_menu.tscn     # 主菜单
│   ├── game.tscn          # 塔防游戏主场景
│   ├── level_complete.tscn # 过关结算
│   ├── game_over.tscn     # 失败重试
│   ├── video_lesson.tscn  # 视频教学（占位）
│   └── quiz.tscn          # 试卷测验
└── scripts/               # GDScript 脚本
    ├── game_state.gd      # 游戏状态单例（AutoLoad）
    ├── game.gd            # 塔防核心玩法逻辑
    ├── main_menu.gd       # 主菜单逻辑
    ├── level_complete.gd  # 过关结算逻辑
    ├── game_over.gd       # 失败逻辑
    ├── quiz.gd            # 试卷测验逻辑
    └── video_lesson.gd    # 视频教学逻辑
```

## 快速开始

```bash
# 1. 下载 Godot 4.3
wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip

# 2. 运行
./Godot_v4.3-stable_linux.x86_64 --path /path/to/word-tower-defense
```

或者直接在 Godot 编辑器中：
1. File → Open → 选择项目目录
2. 点击 ▶ 运行

## 开发计划

- [ ] 完善美术资源（替换纯色方块为 3D 物品形象）
- [ ] NPC 对话系统（异性 NPC 驱动剧情线）
- [ ] 连击/计时/音效系统
- [ ] Web 导出（直接发链接给老师/学生试玩）
- [ ] 后端词库管理 + 学习进度追踪
- [ ] 物理/化学实验动画扩展

## 商业模式

- **合作模式：** 找资深高中老师合作（内容 + 教学大纲），技术方负责开发运营
- **收费方式：** 社群会员制，每月 2000 元，最少半年起付
- **验证点：** ① 学生是否主动玩（留存） ② 拼写正确率是否提升（效果） ③ 家长是否付费（付费意愿）

## License

MIT
