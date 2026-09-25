extends Node
## AudioManager — AudioBus 路由与动态音乐状态机（M0 空壳占位，REQ-ARC-012）
## 总线结构（backlog-draft §11）：Master → Music / SFX / UI / Jingle

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_JINGLE := "Jingle"

## 音乐状态机与动态叠加（无敌星、倒计时加速、P开关、耀西轨）属 M4 范围
