module.exports = {
  endings: [
    { id:"ending_true",title:"春日未央",type:"true",type_desc:"林晓雨真结局——青梅竹马明白了彼此的心意。",character:"xiaoyu",conditions:{affection:{char_id:"xiaoyu",min:100},beats_triggered:["beat_4_3","beat_4_4","beat_3_3","beat_2_4"],beats_not_triggered:[],items:["item_novel_spring"],day_range:{min:58,max:60},special:"暴雨事件选择天台。与林晓雨进行关键对话。"},ai_hint:"天台。林晓雨解下旧红绳：'不是送——是还。你帮我保存着——下次见面的时候还给我。'她哭了但没偏头。你握着红绳——比她手腕还暖。夕阳里坐了十分钟没说话——因为终于不用说了。",priority:1},
    { id:"ending_normal",title:"四月的和弦",type:"normal",type_desc:"苏晚晴结局——转学生在青城找到自己的声音和心意。",character:"wanqing",conditions:{affection:{char_id:"wanqing",min:80},beats_triggered:["beat_4_3","beat_3_4","beat_3_3","beat_2_2"],beats_not_triggered:[],items:["item_handwritten_score"],day_range:{min:58,max:60},special:"暴雨事件选择图书馆。苏晚晴好感度≥80且未被林晓雨100锁定。"},ai_hint:"天台。苏晚晴口风琴吹《四月》：'我决定去上海音乐学院——不是因为家里是因为我想。跟我妈谈了——十二年第一次。所以——我想先去上海。如果你觉得我们——可以的话。'她没说完整。但她看着你——不再需要每句话都说完。因为知道你会接。",priority:2},
    { id:"ending_bad",title:"没说出口的名字",type:"bad",type_desc:"错过所有机会在毕业黄昏独自离去。",character:"",conditions:{affection:{},beats_triggered:[],beats_not_triggered:["beat_4_3","beat_4_4"],items:[],day_range:{min:58,max:60},special:"未满足任何结局条件。林晓雨和苏晚晴好感度均<80或关键节拍未触发。"},ai_hint:"天台没人。下楼时楼梯口遇林晓雨——正要上来。错身。她说'你今天也没待太久嘛'然后笑一下。你张嘴没说出名字。银杏树叶子在风里响了整个夏天。拿毕业证走出校门——回头。教学楼五楼灯灭。但知道有人在那。站一分钟然后走了。",priority:3}
  ],
  narrative_tension: { current_level:0,min:0,max:100,per_act_base:{act_1:20,act_2:45,act_3:70,act_4:55},effects:{"0-30":{label:"低张力",hint:"日常为主DS多用环境描写和细节"},"30-60":{label:"中张力",hint:"冲突和选择开始出现"},"60-100":{label:"高张力",hint:"高潮密集DS叙事紧凑克制"}},modifiers:{chaos_factor_boost:"chaos_factor每+0.1张力+3",high_affection_tension:"角色好感≥80时张力+10",forced_choice_tension:"强制选择事件触发时张力临时+15"} },
  branch_system: { routes:[{id:"route_xiaoyu",name:"林晓雨线",conditions:{affection:{xiaoyu:70},beats:["beat_2_4","beat_3_1"]},active:false},{id:"route_wanqing",name:"苏晚晴线",conditions:{affection:{wanqing:70},beats:["beat_3_2","beat_3_4"]},active:false}], branch_history:[] },
  foreshadow_system: { planted:[],resolved:[],auto_plant_chance:0.1 },
  post_ending: { tone_shift:"从紧张高中切换到悠闲暑假。世界还在转只是节奏慢了。",event_focus:["sweet_minor","daily","echo","ensemble","dialogue_trigger"],available_messages:"角色结局后聊天风格变化——更自然更频繁不再试探。" },
  memory: { current_act:"",day_entered_act:0,triggered_beats:[],active_foreshadow:[],ending_progress:{},active_routes:[],narrative_summary:"引擎维护。" }
};
