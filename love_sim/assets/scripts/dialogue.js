module.exports = {
  engines: {
    daily_chat: { desc:"日常聊天引擎——处理课间、午休等非剧情时间中的自由对话", enabled:true, prompt:"你是一个高中三年级的学生，正在和{player_name}聊天。用自然的语气说话，符合你的性格设定。", temperature:0.8, max_tokens:150 },
    event_chat: { desc:"事件对话引擎——处理事件/节拍中的角色对话", enabled:true, prompt:"你是一个高中三年级的学生，正在经历{event_name}。用自然的语气说话，符合当前事件氛围。", temperature:0.7, max_tokens:250 },
    inner_voice: { desc:"内心独白引擎——处理角色内心活动", enabled:true, prompt:"你是{char_name}，正在想关于{player_name}的事。不要说出来——这是你的内心活动。", temperature:0.9, max_tokens:100 },
    memory_recall: { desc:"记忆召回引擎——处理角色对过去事件的回忆", enabled:true, prompt:"你记得那天{memory_summary}。回想过往的细节——可能是零星的片段，不是完整故事。", temperature:0.6, max_tokens:120 },
    gossip: { desc:"群聊/八卦引擎——张伟或其他配角参与的聊天", enabled:true, prompt:"你和其他同学在聊{player_name}和{target_char}。语气轻松但不是恶意——是关心。", temperature:0.85, max_tokens:200 }
  },
  triggers: [
    { id:"trig_location_entry",name:"进入地点",desc:"玩家切换地点时触发该地点的角色对话",enabled:true,cooldown:2},
    { id:"trig_time_phase",name:"时间段变换",desc:"上午→午休、午休→下午等时间段变化时触发对应角色行为",enabled:true,cooldown:1},
    { id:"trig_affection_tier",name:"好感度破阶",desc:"好感度越过阶段性阈值时触发特殊对话",enabled:true,cooldown:0},
    { id:"trig_item_gift",name:"赠送礼物",desc:"玩家赠送物品时触发角色回应",enabled:true,cooldown:1},
    { id:"trig_beat_event",name:"节拍事件",desc:"关键节拍触发时引擎接管角色对话生成",enabled:true,cooldown:0},
    { id:"trig_random_encounter",name:"随机偶遇",desc:"非强制时间中的随机偶遇对话",enabled:true,cooldown:3}
  ],
  chat_memory: { max_stored:50, retention_policy:"按重要性保留关键对话和日常对话的摘要", working_memory_size:10 }
};
