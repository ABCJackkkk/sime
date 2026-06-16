module.exports = {
  time_config: {
    season: "spring",
    total_days: 60,
    start_day: 1,
    end_day: 60,
    phases: ["清晨","上午","课间","午休","下午","放学","傍晚","晚自习"],
    phase_duration_minutes: { "清晨":60,"上午":120,"课间":10,"午休":60,"下午":120,"放学":60,"傍晚":60,"晚自习":120 },
    weekdays_active: ["周一","周二","周三","周四","周五","周六"],
    rest_day: "周日（可选自由活动）",
    special_days: [
      { day:5, name:"苏晚晴转学日", effects:"苏晚晴加入班级——触发beat_1_3" },
      { day:30, name:"五一假期前夕", effects:"触发beat_3_3暴雨事件的条件最后一天" },
      { day:50, name:"第一次模考", effects:"全模拟考日——无日常事件" },
      { day:57, name:"高考结束", effects:"强制毕业典礼前置" },
      { day:60, name:"毕业日 / 最终日", effects:"触发结局" }
    ]
  },
  advance_modes: [
    { id:"mode_auto",name:"自动推进",desc:"游戏按时间自动推进到下一天。日常事件、随机偶遇、小卖部购买在自动模式下自动处理。",trigger:"手动点击'下一天'按钮或阶段结束时自动触发",default:true },
    { id:"mode_manual",name:"手动探索",desc:"在当前天内自由探索——切换地点、触发事件、和角色对话。无时间限制——玩家决定何时进入下一天。",trigger:"在每个阶段中自由操作",default:false },
    { id:"mode_event_pause",name:"事件暂停",desc:"关键事件触发时游戏暂停时间推进——玩家必须在事件中做出选择或完成对话才能继续。",trigger:"高severity事件或beat触发时自动激活",default:false }
  ],
  affection: {
    system: "数值制——0到100。初始值由角色设定。日常互动累积微小增量，关键事件触发跳跃增量。负面事件扣除。",
    difficulty_curve: {
      "0-30":"快速积累期——日常互动即可。适合开学初的互动。",
      "30-60":"稳定积累期——需要主动互动和礼物。适合act1-2。",
      "60-80":"慢速积累期——需要关键节拍或高价值事件。适合act2-3。",
      "80-95":"缓慢积累期——需要深度事件和对话触发。适合act3-4。",
      "95-100":"锁定区——最后一个阶段需要终极事件（beat或ending事件）。适合act4结尾。"
    },
    decay: { enabled:false, rate:0, desc:"本剧本不启用好感衰减——因为只持续60天" },
    visible_to_player: false,
    hint_system: "玩家不能看具体数字，但可以通过角色行为变化判断好感度区间。详见角色的affection_stages。"
  },
  seasons: [
    { name:"初春", days:"day 1-12", weather_patterns:{ "晴":0.4,"多云":0.3,"阴":0.2,"雨":0.1 }, temp_hint:"微凉——暖气刚停的教室。清晨穿外套，中午可以只穿毛衣。银杏树刚冒新芽。" },
    { name:"春深", days:"day 13-35", weather_patterns:{ "晴":0.3,"多云":0.3,"阴":0.2,"雨":0.2 }, temp_hint:"温暖——银杏叶变深绿。教室开窗有风进来，窗帘会飘。清明前后多雨时间，空气中湿度大。" },
    { name:"初夏", days:"day 36-60", weather_patterns:{ "晴":0.4,"多云":0.3,"阴":0.15,"雨":0.15 }, temp_hint:"闷热——五月底开始教室要开电扇了。银杏叶深绿浓密遮住了半个窗户。短袖校服正式启用。雨季渐渐过去——晴天的太阳开始毒。" }
  ],
  ui_hint: {
    day_indicator: "黑板上的倒计时数字——'距离高考还有X天'",
    character_status: "对话中角色的语气词和动作——不可直接看数值",
    affection_feedback: "角色的affection_stages决定了行为变化——玩家需要通过观察判断"
  }
};
