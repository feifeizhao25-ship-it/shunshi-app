import 'package:flutter/material.dart';

/// 体质数据模型
class _ConstitutionItem {
  final String name;
  final String emoji;
  final Color color;
  final String characteristics;
  final String manifestations;
  final List<String> recommendedFoods;
  final List<String> avoidFoods;
  final List<String> recommendedExercises;
  final List<String> teas;
  final String notes;
  final String seasonalAdvice;

  const _ConstitutionItem({
    required this.name,
    required this.emoji,
    required this.color,
    required this.characteristics,
    required this.manifestations,
    required this.recommendedFoods,
    required this.avoidFoods,
    required this.recommendedExercises,
    required this.teas,
    required this.notes,
    required this.seasonalAdvice,
  });
}

/// 九种体质常量数据
const List<_ConstitutionItem> _kConstitutions = [
  _ConstitutionItem(
    name: '平和质',
    emoji: '😊',
    color: Colors.green,
    characteristics: '阴阳气血调和，体态适中，面色润泽，精力充沛，是最理想的体质状态。',
    manifestations: '面色红润有光泽，头发浓密有光泽，目光有神，鼻色明润，嗅觉通利，唇色红润，精力充沛，睡眠良好，二便正常，舌色淡红，苔薄白',
    recommendedFoods: ['五谷杂粮均衡摄入', '蔬菜水果适量搭配', '肉类以鱼、禽为主', '豆类及坚果适量'],
    avoidFoods: ['暴饮暴食', '偏食偏嗜', '过度寒凉或燥热食物'],
    recommendedExercises: ['太极拳', '八段锦', '慢跑', '游泳', '登山'],
    teas: ['菊花枸杞茶 — 日常保健', '绿茶 — 清热提神', '红枣枸杞茶 — 养血补气'],
    notes: '平和质虽然是最健康的体质，但也要注意保持。起居有常、饮食有节、劳逸适度是维持平和质的关键。',
    seasonalAdvice: '顺应四季变化调整饮食起居。春养肝、夏养心、秋养肺、冬养肾，保持阴阳平衡。',
  ),
  _ConstitutionItem(
    name: '气虚质',
    emoji: '😰',
    color: Colors.yellow,
    characteristics: '元气不足，以疲乏、气短、自汗等为主要特征。多因先天不足或后天失养所致。',
    manifestations: '容易疲劳，说话声音低弱，容易出汗，动则汗出，容易感冒，面色偏白或萎黄，食欲不振，大便溏薄，舌淡苔白，脉虚弱',
    recommendedFoods: ['黄芪炖鸡 — 补气固表', '山药粥 — 健脾益气', '红枣桂圆 — 补气养血', '小米粥 — 健脾养胃', '花生 — 补中益气'],
    avoidFoods: ['生冷食物', '过于辛辣的食物', '破气食物如萝卜', '过度劳累'],
    recommendedExercises: ['八段锦 — 柔和补气', '站桩功 — 培补元气', '散步 — 缓和运动', '太极拳 — 调息养气'],
    teas: ['黄芪党参茶 — 补气健脾', '红枣桂圆茶 — 益气养血', '人参茶 — 大补元气'],
    notes: '气虚者不宜剧烈运动，以微微出汗为度。注意保暖防风，避免汗出当风。',
    seasonalAdvice: '春季尤应注意补气，避免过度消耗。冬季适合进补，可多吃温补食物。',
  ),
  _ConstitutionItem(
    name: '阳虚质',
    emoji: '🥶',
    color: Colors.blue,
    characteristics: '阳气不足，以畏寒怕冷、手足不温等虚寒表现为主要特征。多因先天禀赋不足或久病伤阳所致。',
    manifestations: '手脚冰凉，畏寒怕冷，喜热饮食，精神不振，面色苍白，小便清长，大便溏薄，舌淡胖嫩，脉沉迟',
    recommendedFoods: ['羊肉汤 — 温中散寒', '生姜红糖水 — 暖胃驱寒', '桂圆红枣 — 温补气血', '韭菜 — 温阳补肾', '核桃 — 温补肺肾'],
    avoidFoods: ['生冷寒凉食物', '冰镇饮料', '西瓜等寒凉水果', '苦寒类药物'],
    recommendedExercises: ['太极拳 — 温养阳气', '八段锦 — 调和气血', '慢跑 — 动则生阳', '艾灸足三里 — 温补脾胃'],
    teas: ['生姜红糖茶 — 温中散寒', '当归羊肉汤茶 — 温补气血', '桂皮红茶 — 温阳暖身'],
    notes: '阳虚者应多晒太阳，尤其是背部（督脉循行处）。注意腰腹和足部保暖。',
    seasonalAdvice: '冬季是阳虚质进补的最佳时机，可食用羊肉、狗肉等温补食物。夏季避免长时间待在空调房。',
  ),
  _ConstitutionItem(
    name: '阴虚质',
    emoji: '🔥',
    color: Colors.red,
    characteristics: '体内阴液亏少，以口燥咽干、手足心热等虚热表现为主要特征。',
    manifestations: '口干咽燥，手足心热，容易盗汗，面色潮红，两颧发红，大便干燥，小便短赤，舌红少津，脉细数',
    recommendedFoods: ['银耳莲子羹 — 滋阴润肺', '百合粥 — 养阴清心', '梨子 — 润肺生津', '鸭肉 — 滋阴补虚', '黑芝麻 — 滋养肝肾'],
    avoidFoods: ['辛辣刺激食物', '煎炸燥热食物', '羊肉等温热肉类', '酒类', '熬夜'],
    recommendedExercises: ['太极拳 — 静养阴液', '游泳 — 清凉养阴', '瑜伽 — 柔和舒缓', '八段锦 — 调和阴阳'],
    teas: ['百合茶 — 养阴安神', '银耳莲子茶 — 滋阴润肺', '沙参麦冬茶 — 养阴清热', '枸杞菊花茶 — 滋阴明目'],
    notes: '阴虚质宜静不宜动，运动以舒缓为主，不可大汗淋漓。忌熬夜，保证充足睡眠。',
    seasonalAdvice: '秋季是阴虚质最需要注意的季节，秋燥易伤阴。多食用滋阴润燥食物，保持室内湿度。',
  ),
  _ConstitutionItem(
    name: '痰湿质',
    emoji: '😪',
    color: Colors.purple,
    characteristics: '痰湿凝聚，以形体肥胖、腹部肥满、口黏腻等为主要特征。多因饮食不节、运动不足所致。',
    manifestations: '体形肥胖，腹部肥满松软，面部油脂较多，多汗且黏，胸闷痰多，口黏腻或甜，喜食肥甘甜黏，舌体胖大，苔滑腻',
    recommendedFoods: ['薏米粥 — 健脾祛湿', '冬瓜汤 — 利水消肿', '荷叶茶 — 降脂减肥', '白萝卜 — 化痰理气', '山药 — 健脾化湿'],
    avoidFoods: ['肥甘厚腻食物', '甜食零食', '生冷食物', '过度饮水', '宵夜'],
    recommendedExercises: ['快走 — 促进代谢', '慢跑 — 消耗脂肪', '游泳 — 全身运动', '八段锦 — 调理脾胃', '控制体重是关键'],
    teas: ['荷叶山楂茶 — 降脂祛湿', '陈皮茶 — 理气化痰', '茯苓薏米茶 — 健脾渗湿', '决明子茶 — 润肠通便'],
    notes: '痰湿质应控制饮食总量，少食多餐。饮食宜清淡，多食蔬菜水果，少吃甜食油腻。',
    seasonalAdvice: '长夏（夏秋之交）湿气最重，痰湿质此时更应注意饮食清淡，多运动发汗。',
  ),
  _ConstitutionItem(
    name: '湿热质',
    emoji: '🤢',
    color: Colors.orange,
    characteristics: '湿热内蕴，以面垢油光、口苦、苔黄腻等湿热表现为主要特征。',
    manifestations: '面垢油光，易生痤疮，口苦口干，身重困倦，大便黏滞不畅或燥结，小便短黄，男性阴囊潮湿，女性带下增多，舌红苔黄腻',
    recommendedFoods: ['绿豆汤 — 清热解毒', '苦瓜 — 清热泻火', '冬瓜 — 清热利湿', '薏米 — 健脾利湿', '芹菜 — 清热平肝'],
    avoidFoods: ['辛辣食物', '煎炸烧烤', '酒类', '肥甘厚味', '羊肉等温热食物'],
    recommendedExercises: ['游泳 — 清凉降火', '快走 — 排汗祛湿', '太极拳 — 调和气血', '瑜伽 — 清心降火'],
    teas: ['金银花茶 — 清热解毒', '菊花决明子茶 — 清肝降火', '竹叶茶 — 清心除烦', '茵陈茶 — 清热利湿'],
    notes: '湿热质应避免高温环境和潮湿环境。居住环境宜通风干燥，保持皮肤清洁。',
    seasonalAdvice: '夏季湿热最重，此时应多食清热利湿食物，避免烈日下活动，保持心情舒畅。',
  ),
  _ConstitutionItem(
    name: '血瘀质',
    emoji: '😣',
    color: Colors.teal,
    characteristics: '血行不畅，以肤色晦暗、舌质紫暗等血瘀表现为主要特征。',
    manifestations: '面色晦暗，皮肤偏暗有色素沉着，容易出现瘀斑，口唇暗淡，舌暗有瘀点，女性多见痛经，眼眶暗黑，鼻部暗滞',
    recommendedFoods: ['山楂 — 活血化瘀', '黑木耳 — 养血活血', '红花茶 — 活血通经', '玫瑰花茶 — 疏肝活血', '当归鸡蛋汤 — 养血活血'],
    avoidFoods: ['寒凉食物', '油腻食物', '高盐饮食', '久坐不动'],
    recommendedExercises: ['快走 — 促进血液循环', '八段锦 — 疏通经络', '太极拳 — 调和气血', '瑜伽 — 舒展经络', '按摩穴位 — 疏通气血'],
    teas: ['玫瑰花茶 — 疏肝活血化瘀', '山楂茶 — 活血化瘀降脂', '红花茶 — 活血通经', '当归茶 — 养血活血'],
    notes: '血瘀质应特别注意保暖，寒则凝、温则行。避免久坐，定时活动身体促进气血流通。',
    seasonalAdvice: '春季宜疏肝活血，多做户外运动。冬季注意保暖，避免寒凝血瘀加重。',
  ),
  _ConstitutionItem(
    name: '气郁质',
    emoji: '😔',
    color: Colors.indigo,
    characteristics: '气机郁滞，以神情抑郁、忧虑脆弱等气郁表现为主要特征。',
    manifestations: '性格内向不稳定，敏感多疑，情志不畅，胸胁胀满，善太息（常叹气），咽中如有异物梗阻，舌淡红苔薄白',
    recommendedFoods: ['玫瑰花茶 — 疏肝解郁', '佛手 — 理气化痰', '柑橘 — 理气开胃', '荞麦 — 行气消积', '金桔 — 理气解郁'],
    avoidFoods: ['过度饮酒', '大量饮咖啡', '肥甘厚腻', '睡前思虑过重'],
    recommendedExercises: ['跑步 — 疏通气机', '游泳 — 放松身心', '太极拳 — 调息养神', '瑜伽 — 疏通经络', '户外登山 — 舒展情志'],
    teas: ['玫瑰花茶 — 疏肝解郁', '佛手茶 — 理气化痰', '合欢花茶 — 安神解郁', '茉莉花茶 — 理气开郁'],
    notes: '气郁质应多参加社交活动，保持心情愉悦。可多听舒缓音乐，培养兴趣爱好，学会表达情绪。',
    seasonalAdvice: '春季是气郁质调理的关键时期，顺应肝气升发之势，多做户外运动，保持心情开朗。',
  ),
  _ConstitutionItem(
    name: '特禀质',
    emoji: '🤧',
    color: Colors.pink,
    characteristics: '先天失常，以生理缺陷或过敏反应等为主要特征。多为先天遗传或过敏体质。',
    manifestations: '过敏体质者常见鼻塞、打喷嚏、皮肤易起荨麻疹，对花粉、药物、食物等易过敏，遗传性疾病表现各异，胎传性疾病为母体影响胎儿发育',
    recommendedFoods: ['黄芪 — 益气固表', '灵芝 — 增强免疫', '大枣 — 补中益气', '山药 — 健脾益肺', '蜂蜜 — 润肺抗敏'],
    avoidFoods: ['已知过敏原食物', '辛辣刺激食物', '海鲜（如有过敏）', '生冷食物', '过度加工食品'],
    recommendedExercises: ['太极拳 — 增强体质', '散步 — 适度运动', '八段锦 — 调和气血', '游泳 — 增强肺功能'],
    teas: ['黄芪防风茶 — 益气固表防敏', '大枣甘草茶 — 补中益气', '灵芝茶 — 增强免疫'],
    notes: '特禀质最重要的是避免接触过敏原。建议做过敏原检测，明确过敏物质。居室保持清洁，避免尘螨等。',
    seasonalAdvice: '春季花粉增多，过敏体质者应注意防护。秋季气候变化大，注意增减衣物，预防感冒。',
  ),
];

/// 体质调理页面
class ConstitutionPage extends StatefulWidget {
  const ConstitutionPage({super.key});

  @override
  State<ConstitutionPage> createState() => _ConstitutionPageState();
}

class _ConstitutionPageState extends State<ConstitutionPage> {
  String? _selectedConstitution;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('体质调理'),
        backgroundColor: Colors.purple[50],
      ),
      body: Column(
        children: [
          // AI 测试入口
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[200]!, Colors.purple[400]!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/chat'),
              borderRadius: BorderRadius.circular(16),
              child: const Row(
                children: [
                  Text('🤖', style: TextStyle(fontSize: 40)),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 体质测试',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '了解你的专属体质报告',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white),
                ],
              ),
            ),
          ),
          // 体质列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kConstitutions.length,
              itemBuilder: (context, index) {
                final constitution = _kConstitutions[index];
                final isSelected = _selectedConstitution == constitution.name;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected ? constitution.color.withValues(alpha: 0.1) : null,
                  child: InkWell(
                    onTap: () => setState(() {
                      _selectedConstitution = _selectedConstitution == constitution.name
                          ? null
                          : constitution.name;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: constitution.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                constitution.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  constitution.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  constitution.characteristics,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: constitution.color,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 详细建议
          if (_selectedConstitution != null) _buildAdvice(),
        ],
      ),
    );
  }

  Widget _buildAdvice() {
    final constitution = _kConstitutions.firstWhere(
      (c) => c.name == _selectedConstitution,
    );
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: constitution.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: constitution.color),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(constitution.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  '${constitution.name} 调理方案',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 常见表现
            _buildSection('常见表现', constitution.manifestations, Icons.person_search),
            const SizedBox(height: 12),
            // 推荐食材
            _buildListSection('推荐食材', constitution.recommendedFoods, Icons.restaurant),
            const SizedBox(height: 12),
            // 忌食
            _buildListSection('注意事项', constitution.avoidFoods, Icons.block),
            const SizedBox(height: 12),
            // 推荐运动
            _buildListSection('推荐运动', constitution.recommendedExercises, Icons.fitness_center),
            const SizedBox(height: 12),
            // 推荐茶饮
            _buildListSection('推荐茶饮', constitution.teas, Icons.local_cafe),
            const SizedBox(height: 12),
            // 注意事项
            _buildSection('调理要点', constitution.notes, Icons.info_outline),
            const SizedBox(height: 12),
            // 季节建议
            _buildSection('季节养生', constitution.seasonalAdvice, Icons.calendar_today),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/chat'),
                icon: const Icon(Icons.chat),
                label: const Text('获取个性化调理方案'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: constitution.color,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(content, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $item', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              )),
            ],
          ),
        ),
      ],
    );
  }
}
