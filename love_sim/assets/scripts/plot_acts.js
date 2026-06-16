module.exports = {
  summary: "高三最后一个春天。当前Act1。林晓雨好感50，苏晚晴好感40（day5出场）。叙事张力20。距离高考108天。",
  premise: "在高三最后一个春天，你发现对青梅竹马林晓雨的感情早已不是友情——而转学生苏晚晴的出现让世界在春风里摇了摇。",
  acts: [
    { id:"act_1",name:"初识·日常",description:"高三开学。主角与林晓雨重新同班的微妙距离。苏晚晴day5以转学生身份出现——图书馆钢琴声改变教室空气。",phase_range:"day 1 — day 12",entry_condition:"剧本开始",exit_condition:"day≥12且触发过至少一次与苏晚晴互动",narrative_direction:"聚焦日常和人物建立。避免过早出现重大冲突。",tone:"轻松/新鲜/探索",mandatory_beats:["beat_1_1","beat_1_2","beat_1_3"],optional_beats:["beat_1_4"],pacing_hint:{plot_ratio:0.2,daily_ratio:0.6,sweet_ratio:0.2}},
    { id:"act_2",name:"靠近·试探",description:"春天渐深。图书馆偶遇变多天台出现第二个人。关系在日升温中也出现微妙张力。",phase_range:"day 13 — day 28",entry_condition:"day≥13",exit_condition:"day≥28且至少一次love_triangle或misunderstanding事件已触发",narrative_direction:"聚焦关系升温与试探。不要写狗血三角恋——高中生的感情是钝的闷的。",tone:"温暖/微涩/试探",mandatory_beats:["beat_2_1","beat_2_2"],optional_beats:["beat_2_3","beat_2_4"],pacing_hint:{plot_ratio:0.3,daily_ratio:0.4,sweet_ratio:0.3}},
    { id:"act_3",name:"冲突·选择",description:"五月。模考压力和感情拉扯同时升级。误会打破平衡。雨天图书馆同时响起肖邦和翻书声。",phase_range:"day 29 — day 45",entry_condition:"day≥29",exit_condition:"day≥45且至少一个forced_choice事件已完成",narrative_direction:"聚焦冲突和抉择。感情不再闷在心里——它溢出来了。",tone:"紧张/纠结/微甜",mandatory_beats:["beat_3_1","beat_3_2","beat_3_3"],optional_beats:["beat_3_4"],pacing_hint:{plot_ratio:0.5,daily_ratio:0.2,sweet_ratio:0.3}},
    { id:"act_4",name:"毕业·告白",description:"六月初。高考和毕业典礼像两扇同时打开的门。银杏树绿透了。有人在抽屉里留了一封信。",phase_range:"day 46 — day 60",entry_condition:"day≥46",exit_condition:"day≥60且结局已触发",narrative_direction:"聚焦告别的仪式感和告白的勇气。不是结束而是开始。",tone:"感动/释然/告白",mandatory_beats:["beat_4_1","beat_4_2","beat_4_3"],optional_beats:["beat_4_4"],pacing_hint:{plot_ratio:0.6,daily_ratio:0.1,sweet_ratio:0.3}}
  ]
};
