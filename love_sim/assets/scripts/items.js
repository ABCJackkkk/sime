module.exports = {
  gifts: [
    { id:"item_sakura_bookmark",name:"樱花书签",desc:"春天捡的樱花压在旧书里做成的书签。花瓣已经透明了，放在光下面看像一小片琥珀。主角自己做的——花了三天。",type:"gift",target_char:"xiaoyu",value:"love",obtain:"手工制作（day1起可做）",effect:{affection_change:{xiaoyu:5.0},mood_change:"joy"} },
    { id:"item_handmade_cookies",name:"手工曲奇",desc:"照着网上的配方做的曲奇——有点焦但形状是用心的。包装袋上画了一个极拙的银杏叶。",type:"gift",target_char:"xiaoyu",value:"love",obtain:"手工制作（需小卖部买饼干材料）",effect:{affection_change:{xiaoyu:4.0},mood_change:"joy"} },
    { id:"item_red_ribbon",name:"红丝带",desc:"不是新的——是一根旧的红丝带。和当年那块饼干的袋子颜色一模一样。主角在抽屉深处翻出来的。",type:"gift",target_char:"xiaoyu",value:"love",obtain:"回忆事件中获得",effect:{affection_change:{xiaoyu:6.0},mood_change:"joy"} },
    { id:"item_novel_spring",name:"春日未央",desc:"林晓雨写了三年的小说——打印出来订成的小册子。扉页写着'给陈默'。",type:"key_item",target_char:"player",value:"special",obtain:"beat_4_4完成",effect:{affection_change:{},unlock_ending:"ending_true"} },
    { id:"item_piano_score",name:"旧钢琴谱",desc:"图书馆旧钢琴旁的谱架里翻到的——手抄的肖邦练习曲。里面夹着一张便利贴——苏晚晴的字：'这台琴挺好的不用修。'",type:"key_item",target_char:"wanqing",value:"love",obtain:"beat_1_4完成",effect:{affection_change:{wanqing:3.0},mood_change:"joy"} },
    { id:"item_handwritten_score",name:"手抄的乐谱",desc:"主角听了苏晚晴弹的曲子后花了两晚写下来的简谱——不够专业但每一个音符都对。",type:"gift",target_char:"wanqing",value:"love",obtain:"手工制作（需触发琴声事件后）",effect:{affection_change:{wanqing:6.0},mood_change:"joy"} },
    { id:"item_vinyl_record",name:"老唱片",desc:"在旧货商店找到的周璇老唱片——《夜上海》。封套旧得发毛但唱盘还能放。",type:"gift",target_char:"wanqing",value:"like",obtain:"特殊事件获取",effect:{affection_change:{wanqing:3.0},mood_change:"joy"} },
    { id:"item_scarf",name:"围巾",desc:"深灰色的围巾——没织完。末端有松掉的针。主角跟妈妈学着织的——但时间不够所以在deadline前放弃了完美。",type:"gift",target_char:"xiaoyu",value:"like",obtain:"手工制作（需act_4前）",effect:{affection_change:{xiaoyu:4.0},mood_change:"joy"} },
    { id:"item_music_box",name:"音乐盒",desc:"一个袖珍音乐盒——装在小木盒里。打开是《致爱丽丝》——苏晚晴最不屑弹但又最熟悉的曲子。",type:"gift",target_char:"wanqing",value:"like",obtain:"小卖部购买",effect:{affection_change:{wanqing:3.0},mood_change:"joy"} },
    { id:"item_ginkgo_leaf",name:"银杏叶标本",desc:"主角偷偷从银杏树上摘的最绿的叶子——夹在《牛津字典》里压了一个月。",type:"gift",target_char:"xiaoyu",value:"like",obtain:"手工制作",effect:{affection_change:{xiaoyu:3.0},mood_change:"joy"} }
  ],
  shop_items: [
    { id:"item_bottled_water",name:"矿泉水",desc:"小卖部最畅销的商品。两元一瓶。夏天冰过的卖得快。",type:"consumable",cost:2,currency:"元",effect:{restore_stamina:10} },
    { id:"item_roasted_sweet_potato",name:"烤红薯",desc:"小卖部下午四点的明星产品。装在泡沫箱里用旧报纸裹着。掰开冒热气甜味飘十米。",type:"consumable",cost:5,currency:"元",effect:{restore_stamina:25,char_affection_if_shared:{xiaoyu:1.0,wanqing:1.0}} },
    { id:"item_ad_calcium_milk",name:"AD钙奶",desc:"阿姨在高考前放在收银台旁边——标签写'高三的拿非高三别碰'。",type:"consumable",cost:3,currency:"元",effect:{restore_stamina:15} },
    { id:"item_instant_noodles",name:"方便面",desc:"桶装的。晚自习前买的人最多——因为食堂六点就关了。",type:"consumable",cost:4,currency:"元",effect:{restore_stamina:20} },
    { id:"item_warm_patch",name:"暖宝宝",desc:"冬天穿少的时候阿姨会塞一片进你的书包——但正式购买的话两元。",type:"consumable",cost:2,currency:"元",effect:{restore_stamina:5,warmth_aura:"被关心了"} },
    { id:"item_cookie_material",name:"饼干材料包",desc:"小卖部角落里的面粉和黄油——阿姨开始进货是因为去年有学生问。",type:"material",cost:8,currency:"元",effect:{enables:"item_handmade_cookies"} },
    { id:"item_piano_cleaner",name:"琴键清洁液",desc:"塑料小喷瓶。阿姨说'那个弹钢琴的女孩子来过一次——说要擦一下图书馆的琴'。",type:"material",cost:5,currency:"元",effect:{enables:"与苏晚晴互动+0.5好感"} },
    { id:"item_pen_set",name:"笔芯套装",desc:"黑蓝红三色。高三学生最实用的东西——比任何礼物都实际。",type:"consumable",cost:3,currency:"元",effect:{restore_stamina:3} }
  ],
  consumables: {
    sources: ["小卖部购买","手工制作","事件奖励","阿姨赠予"],
    usage: "消耗品在背包中使用——可恢复体力或作为日常礼物赠送",
    max_capacity: 20
  },
  money: { currency:"元", starting_amount:50, earn_sources:["每周零花钱30元","小卖部帮阿姨搬货赚5元"], spend_primary:["小卖部购物"], achievement_bonus:"完成特定事件获得奖金" }
};
