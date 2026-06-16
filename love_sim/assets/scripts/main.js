const fs = require('fs');

const world = require('./world.js');
const charXiaoyu = require('./char_xiaoyu.js');
const charWanqing = require('./char_wanqing.js');
const flatChars = require('./flat_chars.js');
const plotActs = require('./plot_acts.js');
const plotBeats = require('./plot_beats.js');
const plotEndings = require('./plot_endings.js');
const events1 = require('./events_part1.js');
const events2 = require('./events_part2.js');
const events3 = require('./events_part3.js');
const dialogue = require('./dialogue.js');
const items = require('./items.js');
const interaction = require('./interaction.js');

const events = { ...events1, ...events2, ...events3 };

const output = {
  meta: { id:"campus_love_01", name:"春日未央", version:"1.0.0", author:"剧本组", genre:"校园纯爱", tone:"温暖/青春/微涩", mode:"endings", summary:"高三最后一个春天，青梅竹马与转学生之间，少年在六十天里学习爱与选择。不是谁更好——而是谁让你的心跳有了名字。" },
  player: { name:"陈默", avatar_desc:"身高176cm，利落黑色短发，眉眼温和，笑起来有点腼腆。校服白衬衫总是最上面那颗扣子不系。右肩常年背半旧的帆布书包，拉链上挂着林晓雨小时候编的红绳结。", personality_hint:"话不多但有分寸。成绩中等——不是不聪明是注意力容易飘到窗外银杏树上。对在意的人会默默记下所有细节。善良但不软弱——被逼到墙角会站直了说话。", background:"普通双职工家庭，爸妈在城南菜市场开了间粮油铺。从小独立，六岁就会自己热饭。小学二年级认识了隔壁搬来的林晓雨——往她桌上放了一盒饼干，从此人生多了一个安静的坐标。高三分班重新同班，坐在她后面一排。", current_state:"高三下学期开学第一天。黑板上的倒计时写着'距离高考108天'。你坐在靠窗第三排，看着前桌那个后脑勺——她剪了头发，比去年短了一截。你想说点什么，但还没想好。" },
  world: world,
  characters: [charXiaoyu[0], charWanqing, ...flatChars],
  plot: { ...plotActs, beats: plotBeats, ...plotEndings },
  events: { ...events, summary: "事件层初始状态。计数器0无已存储事件。tension_field初始0。butterfly种子池空。chaos_factor初始0.3。" },
  dialogue: dialogue,
  items: items,
  interaction: interaction
};

fs.writeFileSync('d:/AR/love_sim/assets/scripts/campus_love.json', JSON.stringify(output, null, 2), 'utf-8');
console.log('campus_love.json generated successfully!');
console.log('Characters:', output.characters.length);
console.log('Plot beats:', output.plot.beats.length);
console.log('Event types:', Object.keys(output.events).filter(k => k !== 'summary' && k !== 'generation_rules').length);
