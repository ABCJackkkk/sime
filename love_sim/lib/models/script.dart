class ScriptMeta {
  final String id;
  final String name;
  final String version;
  final String author;
  final String genre;
  final String tone;
  final String mode;
  final String summary;
  final String type;
  final String description;

  ScriptMeta({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.genre,
    required this.tone,
    required this.mode,
    required this.summary,
    this.type = '',
    this.description = '',
  });

  factory ScriptMeta.fromJson(Map<String, dynamic> json) {
    return ScriptMeta(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      version: json['version'] ?? '',
      author: json['author'] ?? '',
      genre: json['genre'] ?? '',
      tone: json['tone'] ?? '',
      mode: json['mode'] ?? '',
      summary: json['summary'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class ScriptPlayer {
  final String name;
  final String avatarDesc;
  final String personalityHint;
  final String background;
  final String currentState;

  ScriptPlayer({
    this.name = '',
    this.avatarDesc = '',
    this.personalityHint = '',
    required this.background,
    required this.currentState,
  });

  factory ScriptPlayer.fromJson(Map<String, dynamic> json) {
    return ScriptPlayer(
      name: json['name'] ?? '',
      avatarDesc: json['avatar_desc'] ?? '',
      personalityHint: json['personality_hint'] ?? '',
      background: json['background'] ?? '',
      currentState: json['current_state'] ?? '',
    );
  }
}

class WorldCurrentTime {
  final int day;
  final String season;
  final String weather;
  final String phase;

  WorldCurrentTime({
    required this.day,
    required this.season,
    required this.weather,
    required this.phase,
  });

  factory WorldCurrentTime.fromJson(Map<String, dynamic> json) {
    return WorldCurrentTime(
      day: json['day'] ?? 1,
      season: json['season'] ?? '春',
      weather: json['weather'] ?? '晴',
      phase: json['phase'] ?? '上午',
    );
  }
}

class WorldMemory {
  final WorldCurrentTime currentTime;
  final List<dynamic> locationChanges;
  final Map<String, dynamic> worldHistory;
  final String worldSummary;

  WorldMemory({
    required this.currentTime,
    required this.locationChanges,
    required this.worldHistory,
    required this.worldSummary,
  });

  factory WorldMemory.fromJson(Map<String, dynamic> json) {
    final ct = json['current_time'];
    Map<String, dynamic> ctMap;
    if (ct is Map) {
      ctMap = ct.cast<String, dynamic>();
    } else if (ct is String) {
      ctMap = {'phase': ct};
    } else {
      ctMap = {};
    }
    return WorldMemory(
      currentTime: WorldCurrentTime.fromJson(ctMap),
      locationChanges: List<dynamic>.from(json['location_changes'] ?? []),
      worldHistory: json['world_history'] ?? {},
      worldSummary: json['world_summary'] ?? '',
    );
  }
}

class ScriptWorld {
  final String summary;
  final String setting;
  final Map<String, dynamic> atmosphere;
  final List<Map<String, dynamic>> locations;
  final Map<String, dynamic> specialRules;
  final WorldMemory memory;

  ScriptWorld({
    required this.summary,
    required this.setting,
    required this.atmosphere,
    required this.locations,
    required this.specialRules,
    required this.memory,
  });

  factory ScriptWorld.fromJson(Map<String, dynamic> json) {
    return ScriptWorld(
      summary: json['summary'] ?? '',
      setting: json['setting'] ?? '',
      atmosphere: json['atmosphere'] ?? {},
      locations: List<Map<String, dynamic>>.from(json['locations'] ?? []),
      specialRules: json['special_rules'] ?? {},
      memory: WorldMemory.fromJson(json['memory'] ?? {}),
    );
  }
}

class CharacterBasic {
  final String id;
  final String name;
  final String gender;
  final int age;
  final String height;
  final String weight;
  final String avatarDesc;
  final List<String> distinctiveMarks;

  CharacterBasic({
    required this.id,
    required this.name,
    required this.gender,
    required this.age,
    required this.height,
    required this.weight,
    required this.avatarDesc,
    required this.distinctiveMarks,
  });

  factory CharacterBasic.fromJson(dynamic json) {
    if (json is! Map) return CharacterBasic(id: '', name: '', gender: '', age: 0, height: '', weight: '', avatarDesc: '', distinctiveMarks: []);
    return CharacterBasic(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      age: json['age'] ?? 0,
      height: (json['height'] ?? '').toString(),
      weight: (json['weight'] ?? '').toString(),
      avatarDesc: (json['avatar_desc'] ?? '').toString(),
      distinctiveMarks: _parseStringList(json['distinctive_marks']),
    );
  }
}

class CharacterBackground {
  final String origin;
  final String history;
  final String currentSituation;

  CharacterBackground({
    this.origin = '',
    this.history = '',
    this.currentSituation = '',
  });

  factory CharacterBackground.fromJson(dynamic json) {
    if (json is! Map) return CharacterBackground();
    return CharacterBackground(
      origin: (json['origin'] ?? '').toString(),
      history: (json['history'] ?? '').toString(),
      currentSituation: (json['current_situation'] ?? '').toString(),
    );
  }
}

List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => e.toString()).toList();
  return [value.toString()];
}

class CharacterDetails {
  final List<String> goals;
  final List<String> fears;
  final List<String> secrets;
  final List<String> quirks;
  final List<String> habits;
  final List<String> dailyRoutine;
  final List<String> petPeeve;
  final List<String> secretHobby;

  CharacterDetails({
    List<String>? goals,
    List<String>? fears,
    List<String>? secrets,
    List<String>? quirks,
    List<String>? habits,
    List<String>? dailyRoutine,
    List<String>? petPeeve,
    List<String>? secretHobby,
  })  : goals = goals ?? [],
        fears = fears ?? [],
        secrets = secrets ?? [],
        quirks = quirks ?? [],
        habits = habits ?? [],
        dailyRoutine = dailyRoutine ?? [],
        petPeeve = petPeeve ?? [],
        secretHobby = secretHobby ?? [];

  factory CharacterDetails.fromJson(dynamic json) {
    if (json is! Map) return CharacterDetails();
    return CharacterDetails(
      goals: _parseStringList(json['goals']),
      fears: _parseStringList(json['fears']),
      secrets: _parseStringList(json['secrets']),
      quirks: _parseStringList(json['quirks']),
      habits: _parseStringList(json['habits']),
      dailyRoutine: _parseStringList(json['daily_routine']),
      petPeeve: _parseStringList(json['pet_peeve']),
      secretHobby: _parseStringList(json['secret_hobby']),
    );
  }
}

class CharacterSoulDualMode {
  final String toStranger;
  final String toClose;

  CharacterSoulDualMode({
    this.toStranger = '',
    this.toClose = '',
  });

  factory CharacterSoulDualMode.fromJson(dynamic json) {
    if (json is String) {
      return CharacterSoulDualMode(
        toStranger: json,
        toClose: json,
      );
    }
    if (json is! Map) {
      return CharacterSoulDualMode();
    }
    return CharacterSoulDualMode(
      toStranger: json['to_stranger'] ?? '',
      toClose: json['to_close'] ?? '',
    );
  }
}

class CharacterSoul {
  final String core;
  final String desire;
  final String wound;
  final String fear;
  final String contradiction;
  final CharacterSoulDualMode dualMode;

  CharacterSoul({
    this.core = '',
    this.desire = '',
    this.wound = '',
    this.fear = '',
    this.contradiction = '',
    CharacterSoulDualMode? dualMode,
  }) : dualMode = dualMode ?? CharacterSoulDualMode();

  factory CharacterSoul.fromJson(dynamic json) {
    if (json is String) return CharacterSoul(core: json);
    if (json is! Map) return CharacterSoul();
    return CharacterSoul(
      core: json['core'] ?? '',
      desire: json['desire'] ?? '',
      wound: json['wound'] ?? '',
      fear: json['fear'] ?? '',
      contradiction: json['contradiction'] ?? '',
      dualMode: CharacterSoulDualMode.fromJson(json['dual_mode'] ?? json['dualMode'] ?? {}),
    );
  }
}

class CharacterSpeechBigFive {
  final String openness;
  final String extraversion;
  final String agreeableness;
  final String conscientiousness;
  final String neuroticism;

  CharacterSpeechBigFive({
    this.openness = '',
    this.extraversion = '',
    this.agreeableness = '',
    this.conscientiousness = '',
    this.neuroticism = '',
  });

  factory CharacterSpeechBigFive.fromJson(dynamic json) {
    if (json is String) {
      return CharacterSpeechBigFive();
    }
    if (json is! Map) {
      return CharacterSpeechBigFive();
    }
    return CharacterSpeechBigFive(
      openness: (json['openness'] ?? json['O'] ?? 0.5).toString(),
      extraversion: (json['extraversion'] ?? json['E'] ?? 0.5).toString(),
      agreeableness: (json['agreeableness'] ?? json['A'] ?? 0.5).toString(),
      conscientiousness: (json['conscientiousness'] ?? json['C'] ?? 0.5).toString(),
      neuroticism: (json['neuroticism'] ?? json['N'] ?? 0.5).toString(),
    );
  }
}

class CharacterSpeechPhonetics {
  final String pitch;
  final String pace;
  final String stress;
  final String pause;

  CharacterSpeechPhonetics({
    this.pitch = '',
    this.pace = '',
    this.stress = '',
    this.pause = '',
  });

  factory CharacterSpeechPhonetics.fromJson(dynamic json) {
    if (json is String) {
      return CharacterSpeechPhonetics(pitch: json);
    }
    if (json is! Map) {
      return CharacterSpeechPhonetics();
    }
    return CharacterSpeechPhonetics(
      pitch: json['pitch'] ?? '',
      pace: json['pace'] ?? '',
      stress: json['stress'] ?? '',
      pause: json['pause'] ?? '',
    );
  }
}

class CharacterSpeechVocabulary {
  final String style;
  final String sentenceTendency;
  final String softener;
  final List<String> avoid;

  CharacterSpeechVocabulary({
    this.style = '',
    this.sentenceTendency = '',
    this.softener = '',
    List<String>? avoid,
  }) : avoid = avoid ?? [];

  factory CharacterSpeechVocabulary.fromJson(dynamic json) {
    if (json is String) {
      return CharacterSpeechVocabulary(style: json);
    }
    if (json is! Map) {
      return CharacterSpeechVocabulary();
    }
    return CharacterSpeechVocabulary(
      style: json['style'] ?? '',
      sentenceTendency: json['sentence_tendency'] ?? '',
      softener: json['softener'] ?? '',
      avoid: _parseStringList(json['avoid']),
    );
  }
}

class CharacterSpeechInteraction {
  final String turnTaking;
  final String politeness;
  final String questionStyle;
  final String topicControl;

  CharacterSpeechInteraction({
    this.turnTaking = '',
    this.politeness = '',
    this.questionStyle = '',
    this.topicControl = '',
  });

  factory CharacterSpeechInteraction.fromJson(dynamic json) {
    if (json is String) {
      return CharacterSpeechInteraction();
    }
    if (json is! Map) {
      return CharacterSpeechInteraction();
    }
    return CharacterSpeechInteraction(
      turnTaking: json['turn_taking'] ?? '',
      politeness: json['politeness'] ?? '',
      questionStyle: json['question_style'] ?? '',
      topicControl: json['topic_control'] ?? '',
    );
  }
}

class CharacterSpeechDualDetail {
  final String overview;
  final String example;

  CharacterSpeechDualDetail({
    this.overview = '',
    this.example = '',
  });

  factory CharacterSpeechDualDetail.fromJson(dynamic json) {
    if (json is String) return CharacterSpeechDualDetail(overview: json);
    if (json is! Map) return CharacterSpeechDualDetail();
    return CharacterSpeechDualDetail(
      overview: json['overview'] ?? '',
      example: json['example'] ?? '',
    );
  }
}

class CharacterSpeechDualMode {
  final CharacterSpeechDualDetail toStranger;
  final CharacterSpeechDualDetail toClose;

  CharacterSpeechDualMode({
    CharacterSpeechDualDetail? toStranger,
    CharacterSpeechDualDetail? toClose,
  })  : toStranger = toStranger ?? CharacterSpeechDualDetail(),
        toClose = toClose ?? CharacterSpeechDualDetail();

  factory CharacterSpeechDualMode.fromJson(dynamic json) {
    if (json is String) {
      return CharacterSpeechDualMode(
        toStranger: CharacterSpeechDualDetail(overview: json),
        toClose: CharacterSpeechDualDetail(overview: json),
      );
    }
    if (json is! Map) {
      return CharacterSpeechDualMode();
    }
    return CharacterSpeechDualMode(
      toStranger: CharacterSpeechDualDetail.fromJson(json['to_stranger'] ?? {}),
      toClose: CharacterSpeechDualDetail.fromJson(json['to_close'] ?? {}),
    );
  }
}

class CharacterSpeech {
  final CharacterSpeechBigFive bigFiveProfile;
  final CharacterSpeechPhonetics phonetics;
  final CharacterSpeechVocabulary vocabulary;
  final CharacterSpeechInteraction interaction;
  final CharacterSpeechDualMode dualMode;

  CharacterSpeech({
    CharacterSpeechBigFive? bigFiveProfile,
    CharacterSpeechPhonetics? phonetics,
    CharacterSpeechVocabulary? vocabulary,
    CharacterSpeechInteraction? interaction,
    CharacterSpeechDualMode? dualMode,
  })  : bigFiveProfile = bigFiveProfile ?? CharacterSpeechBigFive(),
        phonetics = phonetics ?? CharacterSpeechPhonetics(),
        vocabulary = vocabulary ?? CharacterSpeechVocabulary(),
        interaction = interaction ?? CharacterSpeechInteraction(),
        dualMode = dualMode ?? CharacterSpeechDualMode();

  factory CharacterSpeech.fromJson(dynamic json) {
    if (json is! Map) return CharacterSpeech();
    return CharacterSpeech(
      bigFiveProfile:
          CharacterSpeechBigFive.fromJson(json['big_five_profile'] ?? json['bigFiveProfile'] ?? {}),
      phonetics: CharacterSpeechPhonetics.fromJson(json['phonetics'] ?? {}),
      vocabulary:
          CharacterSpeechVocabulary.fromJson(json['vocabulary'] ?? {}),
      interaction:
          CharacterSpeechInteraction.fromJson(json['interaction'] ?? {}),
      dualMode:
          CharacterSpeechDualMode.fromJson(json['dual_mode'] ?? json['dualMode'] ?? {}),
    );
  }
}

class CharacterHumanityAntiAiRules {
  final String noSelfExplain;
  final String noEmotionLabel;
  final String noSafeWrapper;
  final String noStructure;
  final String noUniformAttention;

  CharacterHumanityAntiAiRules({
    this.noSelfExplain = '',
    this.noEmotionLabel = '',
    this.noSafeWrapper = '',
    this.noStructure = '',
    this.noUniformAttention = '',
  });

  factory CharacterHumanityAntiAiRules.fromJson(dynamic json) {
    if (json is! Map) return CharacterHumanityAntiAiRules();
    return CharacterHumanityAntiAiRules(
      noSelfExplain: json['no_self_explain'] ?? '',
      noEmotionLabel: json['no_emotion_label'] ?? '',
      noSafeWrapper: json['no_safe_wrapper'] ?? '',
      noStructure: json['no_structure'] ?? '',
      noUniformAttention: json['no_uniform_attention'] ?? '',
    );
  }
}

class CharacterHumanityWritingPosture {
  final String silenceIsSpeech;
  final String allowPrejudice;
  final String allowIncomplete;
  final String emotionOverAnalysis;

  CharacterHumanityWritingPosture({
    this.silenceIsSpeech = '',
    this.allowPrejudice = '',
    this.allowIncomplete = '',
    this.emotionOverAnalysis = '',
  });

  factory CharacterHumanityWritingPosture.fromJson(dynamic json) {
    if (json is! Map) return CharacterHumanityWritingPosture();
    return CharacterHumanityWritingPosture(
      silenceIsSpeech: json['silence_is_speech'] ?? '',
      allowPrejudice: json['allow_prejudice'] ?? '',
      allowIncomplete: json['allow_incomplete'] ?? '',
      emotionOverAnalysis: json['emotion_over_analysis'] ?? '',
    );
  }
}

class CharacterHumanity {
  final CharacterHumanityAntiAiRules antiAiRules;
  final CharacterHumanityWritingPosture writingPosture;
  final List<String> nonVerbal;

  CharacterHumanity({
    CharacterHumanityAntiAiRules? antiAiRules,
    CharacterHumanityWritingPosture? writingPosture,
    List<String>? nonVerbal,
  })  : antiAiRules = antiAiRules ?? CharacterHumanityAntiAiRules(),
        writingPosture = writingPosture ?? CharacterHumanityWritingPosture(),
        nonVerbal = nonVerbal ?? [];

  factory CharacterHumanity.fromJson(dynamic json) {
    if (json is! Map) return CharacterHumanity();
    return CharacterHumanity(
      antiAiRules:
          CharacterHumanityAntiAiRules.fromJson(json['anti_ai_rules'] ?? {}),
      writingPosture: CharacterHumanityWritingPosture.fromJson(
          json['writing_posture'] ?? {}),
      nonVerbal: _parseStringList(json['non_verbal']),
    );
  }
}

class CharacterAgentDualMode {
  final String toStranger;
  final String toClose;

  CharacterAgentDualMode({
    this.toStranger = '',
    this.toClose = '',
  });

  factory CharacterAgentDualMode.fromJson(dynamic json) {
    if (json is String) {
      return CharacterAgentDualMode(
        toStranger: json,
        toClose: json,
      );
    }
    if (json is! Map) {
      return CharacterAgentDualMode();
    }
    return CharacterAgentDualMode(
      toStranger: json['to_stranger'] ?? '',
      toClose: json['to_close'] ?? '',
    );
  }
}

class CharacterAgent {
  final String role;
  final String agenda;
  final CharacterAgentDualMode dualMode;

  CharacterAgent({
    this.role = '',
    this.agenda = '',
    CharacterAgentDualMode? dualMode,
  }) : dualMode = dualMode ?? CharacterAgentDualMode();

  factory CharacterAgent.fromJson(dynamic json) {
    if (json is! Map) return CharacterAgent();
    return CharacterAgent(
      role: json['role'] ?? '',
      agenda: json['agenda'] ?? '',
      dualMode: CharacterAgentDualMode.fromJson(json['dual_mode'] ?? json['dualMode'] ?? {}),
    );
  }
}

class CharacterAppearance {
  final String body;
  final String face;
  final String hair;
  final String eyes;
  final String clothing;
  final String accessory;
  final List<String> distinctiveFeatures;
  final String defaultWear;
  final String special;
  final String styleDesc;

  CharacterAppearance({
    this.body = '',
    this.face = '',
    this.hair = '',
    this.eyes = '',
    this.clothing = '',
    this.accessory = '',
    List<String>? distinctiveFeatures,
    this.defaultWear = '',
    this.special = '',
    this.styleDesc = '',
  }) : distinctiveFeatures = distinctiveFeatures ?? [];

  factory CharacterAppearance.fromJson(dynamic json) {
    if (json is String) return CharacterAppearance(styleDesc: json);
    if (json is! Map) return CharacterAppearance();
    return CharacterAppearance(
      body: json['body'] ?? '',
      face: json['face'] ?? '',
      hair: json['hair'] ?? '',
      eyes: json['eyes'] ?? '',
      clothing: json['clothing'] ?? '',
      accessory: json['accessory'] ?? '',
      distinctiveFeatures: _parseStringList(json['distinctive_features']),
      defaultWear: json['default'] ?? '',
      special: json['special'] ?? '',
      styleDesc: json['style_desc'] ?? '',
    );
  }
}

class CharacterPreferences {
  final List<String> likes;
  final List<String> dislikes;
  final String talent;

  CharacterPreferences({
    List<String>? likes,
    List<String>? dislikes,
    this.talent = '',
  })  : likes = likes ?? [],
        dislikes = dislikes ?? [];

  factory CharacterPreferences.fromJson(dynamic json) {
    if (json is! Map) {
      return CharacterPreferences();
    }
    dynamic rawLikes = json['likes'];
    dynamic rawDislikes = json['dislikes'];
    List<String> likesList;
    List<String> dislikesList;
    if (rawLikes is List) {
      likesList = List<String>.from(rawLikes);
    } else if (rawLikes is String) {
      likesList = [rawLikes];
    } else {
      likesList = [];
    }
    if (rawDislikes is List) {
      dislikesList = List<String>.from(rawDislikes);
    } else if (rawDislikes is String) {
      dislikesList = [rawDislikes];
    } else {
      dislikesList = [];
    }
    return CharacterPreferences(
      likes: likesList,
      dislikes: dislikesList,
      talent: json['talent'] ?? '',
    );
  }
}

class CharacterMoodTriggers {
  final List<String> joy;
  final List<String> anger;
  final List<String> sadness;
  final List<String> nervous;
  final List<String> jealous;

  CharacterMoodTriggers({
    List<String>? joy,
    List<String>? anger,
    List<String>? sadness,
    List<String>? nervous,
    List<String>? jealous,
  })  : joy = joy ?? [],
        anger = anger ?? [],
        sadness = sadness ?? [],
        nervous = nervous ?? [],
        jealous = jealous ?? [];

  factory CharacterMoodTriggers.fromJson(dynamic json) {
    if (json is String) {
      return CharacterMoodTriggers();
    }
    if (json is! Map) {
      return CharacterMoodTriggers();
    }
    return CharacterMoodTriggers(
      joy: _parseStringList(json['joy']),
      anger: _parseStringList(json['anger']),
      sadness: _parseStringList(json['sadness']),
      nervous: _parseStringList(json['nervous']),
      jealous: _parseStringList(json['jealous']),
    );
  }
}

class CharacterGiftResponseEntry {
  final String input;
  final String reaction;

  CharacterGiftResponseEntry({
    this.input = '',
    this.reaction = '',
  });

  factory CharacterGiftResponseEntry.fromJson(dynamic json) {
    if (json is String) return CharacterGiftResponseEntry(input: json);
    if (json is! Map) return CharacterGiftResponseEntry();
    return CharacterGiftResponseEntry(
      input: json['input'] ?? '',
      reaction: json['reaction'] ?? '',
    );
  }
}

class CharacterGiftResponse {
  final CharacterGiftResponseEntry love;
  final CharacterGiftResponseEntry like;
  final CharacterGiftResponseEntry neutral;
  final CharacterGiftResponseEntry dislike;
  final CharacterGiftResponseEntry hate;

  CharacterGiftResponse({
    CharacterGiftResponseEntry? love,
    CharacterGiftResponseEntry? like,
    CharacterGiftResponseEntry? neutral,
    CharacterGiftResponseEntry? dislike,
    CharacterGiftResponseEntry? hate,
  })  : love = love ?? CharacterGiftResponseEntry(),
        like = like ?? CharacterGiftResponseEntry(),
        neutral = neutral ?? CharacterGiftResponseEntry(),
        dislike = dislike ?? CharacterGiftResponseEntry(),
        hate = hate ?? CharacterGiftResponseEntry();

  factory CharacterGiftResponse.fromJson(dynamic json) {
    if (json is! Map) return CharacterGiftResponse();
    return CharacterGiftResponse(
      love: CharacterGiftResponseEntry.fromJson(json['love'] ?? {}),
      like: CharacterGiftResponseEntry.fromJson(json['like'] ?? {}),
      neutral: CharacterGiftResponseEntry.fromJson(json['neutral'] ?? {}),
      dislike: CharacterGiftResponseEntry.fromJson(json['dislike'] ?? {}),
      hate: CharacterGiftResponseEntry.fromJson(json['hate'] ?? {}),
    );
  }
}

class CharacterBoundary {
  final String physical;
  final String emotional;
  final String paceHint;
  final List<String> topicTaboo;

  CharacterBoundary({
    this.physical = '',
    this.emotional = '',
    this.paceHint = '',
    List<String>? topicTaboo,
  }) : topicTaboo = topicTaboo ?? [];

  factory CharacterBoundary.fromJson(dynamic json) {
    if (json is String) {
      return CharacterBoundary(physical: json);
    }
    if (json is! Map) {
      return CharacterBoundary();
    }
    return CharacterBoundary(
      physical: json['physical'] ?? '',
      emotional: json['emotional'] ?? '',
      paceHint: json['pace_hint'] ?? '',
      topicTaboo: _parseStringList(json['topic_taboo']),
    );
  }
}

class CharacterEvolutionStageEntry {
  final String stage;
  final String range;
  final String narrativeHint;

  CharacterEvolutionStageEntry({
    this.stage = '',
    this.range = '',
    this.narrativeHint = '',
  });

  factory CharacterEvolutionStageEntry.fromJson(dynamic json) {
    if (json is String) return CharacterEvolutionStageEntry(stage: json);
    if (json is! Map) return CharacterEvolutionStageEntry();
    return CharacterEvolutionStageEntry(
      stage: json['stage']?.toString() ?? '',
      range: json['range']?.toString() ?? '',
      narrativeHint: json['narrative_hint']?.toString() ?? '',
    );
  }
}

class CharacterEvolution {
  final List<CharacterEvolutionStageEntry> affectionStages;
  final List<String>? specialItems;

  CharacterEvolution({
    List<CharacterEvolutionStageEntry>? affectionStages,
    this.specialItems,
  }) : affectionStages = affectionStages ?? [];

  factory CharacterEvolution.fromJson(dynamic json) {
    if (json is! Map) return CharacterEvolution();
    List<CharacterEvolutionStageEntry> stages = [];
    final raw = json['affection_stages'];
    if (raw is List) {
      stages = raw.map((e) => CharacterEvolutionStageEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    } else if (raw is Map<String, dynamic>) {
      stages = raw.entries.map((e) => CharacterEvolutionStageEntry(range: e.key, narrativeHint: (e.value as String?) ?? '')).toList();
    }
    final items = json['special_items'];
    final List<String>? specialItems = items is List ? items.map((e) => e.toString()).toList() : null;
    return CharacterEvolution(affectionStages: stages, specialItems: specialItems);
  }
}

class CharacterMemoryImpression {
  final List<String> keywords;
  final String lastUpdated;
  final String trend;

  CharacterMemoryImpression({
    List<String>? keywords,
    this.lastUpdated = '',
    this.trend = '',
  }) : keywords = keywords ?? [];

  factory CharacterMemoryImpression.fromJson(dynamic json) {
    if (json is! Map) return CharacterMemoryImpression();
    return CharacterMemoryImpression(
      keywords: _parseStringList(json['keywords']),
      lastUpdated: json['last_updated'] ?? '',
      trend: json['trend'] ?? '',
    );
  }
}

class CharacterMemory {
  final List<dynamic> episodic;
  final List<dynamic> chatLog;
  final CharacterMemoryImpression impression;

  CharacterMemory({
    List<dynamic>? episodic,
    List<dynamic>? chatLog,
    CharacterMemoryImpression? impression,
  })  : episodic = episodic ?? [],
        chatLog = chatLog ?? [],
        impression = impression ?? CharacterMemoryImpression();

  factory CharacterMemory.fromJson(dynamic json) {
    if (json is! Map) return CharacterMemory();
    return CharacterMemory(
      episodic: List<dynamic>.from(json['episodic'] ?? []),
      chatLog: List<dynamic>.from(json['chat_log'] ?? []),
      impression:
          CharacterMemoryImpression.fromJson(json['impression'] ?? {}),
    );
  }
}

class CharacterRelations {
  final List<Map<String, dynamic>> flat;
  final List<Map<String, dynamic>> dimensional;

  CharacterRelations({
    List<Map<String, dynamic>>? flat,
    List<Map<String, dynamic>>? dimensional,
  })  : flat = flat ?? [],
        dimensional = dimensional ?? [];

  factory CharacterRelations.fromJson(dynamic json) {
    if (json is! Map) return CharacterRelations();
    final flatList = (json['flat'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final dimensionalList = (json['dimensional'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    return CharacterRelations(
      flat: flatList,
      dimensional: dimensionalList,
    );
  }
}

class Character {
  final bool fullCharacter;
  final String summary;
  final CharacterBasic basic;
  final double initialAffection;
  final CharacterBackground? background;
  final CharacterDetails? details;
  final CharacterSoul? soul;
  final CharacterSpeech? speech;
  final CharacterHumanity? humanity;
  final CharacterAgent? agent;
  final CharacterAppearance? appearance;
  final CharacterPreferences? preferences;
  final CharacterMoodTriggers? moodTriggers;
  final CharacterGiftResponse? giftResponse;
  final CharacterBoundary? boundary;
  final CharacterEvolution? evolution;
  final CharacterMemory? memory;
  final CharacterRelations? relations;
  final CharacterSchedule? schedule;
  final List<CharacterStat>? stats;
  final List<CharacterGrade>? grades;
  final String discoveryCondition;
  final String? coopArcana;
  final Map<String, dynamic>? memoryTags;

  Character({
    required this.fullCharacter,
    required this.summary,
    required this.basic,
    this.initialAffection = 50.0,
    this.background,
    this.details,
    this.soul,
    this.speech,
    this.humanity,
    this.agent,
    this.appearance,
    this.preferences,
    this.moodTriggers,
    this.giftResponse,
    this.boundary,
    this.evolution,
    this.memory,
    this.relations,
    this.schedule,
    this.stats,
    this.grades,
    this.discoveryCondition = '',
    this.coopArcana,
    this.memoryTags,
  });

  factory Character.fromJson(dynamic json) {
    if (json is! Map) return Character(fullCharacter: false, summary: '', basic: CharacterBasic(id: '', name: '', gender: '', age: 0, height: '', weight: '', avatarDesc: '', distinctiveMarks: []));
    CharacterBasic _b; try { _b = CharacterBasic.fromJson(json['basic'] ?? {}); } catch(e) { throw Exception('basic: $e'); }
    final initialAff = (json['basic'] as Map<String, dynamic>?)?['initial_affection'] ?? 50.0;
    CharacterBackground? _bg; try { _bg = json['background'] != null ? CharacterBackground.fromJson(json['background']) : null; } catch(e) { throw Exception('background: $e'); }
    CharacterDetails? _d; try { _d = json['details'] != null ? CharacterDetails.fromJson(json['details']) : null; } catch(e) { throw Exception('details: $e'); }
    CharacterSoul? _s; try { _s = json['soul'] != null ? CharacterSoul.fromJson(json['soul']) : null; } catch(e) { throw Exception('soul: $e'); }
    CharacterSpeech? _sp; try { _sp = json['speech'] != null ? CharacterSpeech.fromJson(json['speech']) : null; } catch(e) { throw Exception('speech: $e'); }
    CharacterHumanity? _h; try { _h = json['humanity'] != null ? CharacterHumanity.fromJson(json['humanity']) : null; } catch(e) { throw Exception('humanity: $e'); }
    CharacterAgent? _a; try { _a = json['agent'] != null ? CharacterAgent.fromJson(json['agent']) : null; } catch(e) { throw Exception('agent: $e'); }
    CharacterAppearance? _ap; try { _ap = json['appearance'] != null ? CharacterAppearance.fromJson(json['appearance']) : null; } catch(e) { throw Exception('appearance: $e'); }
    CharacterPreferences? _p; try { _p = json['preferences'] != null ? CharacterPreferences.fromJson(json['preferences']) : null; } catch(e) { throw Exception('preferences: $e'); }
    CharacterMoodTriggers? _mt; try { _mt = json['mood_triggers'] != null ? CharacterMoodTriggers.fromJson(json['mood_triggers']) : null; } catch(e) { throw Exception('moodTriggers: $e'); }
    CharacterGiftResponse? _gr; try { _gr = json['gift_response'] != null ? CharacterGiftResponse.fromJson(json['gift_response']) : null; } catch(e) { throw Exception('giftResponse: $e'); }
    CharacterBoundary? _bo; try { _bo = json['boundary'] != null ? CharacterBoundary.fromJson(json['boundary']) : null; } catch(e) { throw Exception('boundary: $e'); }
    CharacterEvolution? _ev; try { _ev = json['evolution'] != null ? CharacterEvolution.fromJson(json['evolution']) : null; } catch(e) { throw Exception('evolution: $e'); }
    CharacterMemory? _m; try { _m = json['memory'] != null ? CharacterMemory.fromJson(json['memory']) : null; } catch(e) { throw Exception('memory: $e'); }
    CharacterRelations? _r; try { _r = json['relations'] != null ? CharacterRelations.fromJson(json['relations']) : null; } catch(e) { throw Exception('relations: $e'); }
    CharacterSchedule? _sc; try { _sc = json['schedule'] != null ? CharacterSchedule.fromJson(json['schedule']) : null; } catch(e) { _sc = null; }
    final stats = (json['stats'] as List<dynamic>?)?.map((e) => CharacterStat.fromJson(e)).toList();
    final grades = (json['grades'] as List<dynamic>?)?.map((e) => CharacterGrade.fromJson(e)).toList();
    final memoryTags = json['memory_tags'] is Map ? Map<String, dynamic>.from(json['memory_tags'] as Map) : null;

    _b = _enrichBasicFromAppearance(_b, json['appearance'] as Map<String, dynamic>?);

    return Character(
      fullCharacter: json['full_character'] ?? false,
      summary: json['summary'] ?? '',
      basic: _b, initialAffection: (initialAff as num).toDouble(), background: _bg, details: _d, soul: _s, speech: _sp,
      humanity: _h, agent: _a, appearance: _ap, preferences: _p,
      moodTriggers: _mt, giftResponse: _gr, boundary: _bo,
      evolution: _ev, memory: _m, relations: _r, schedule: _sc,
      stats: stats, grades: grades, discoveryCondition: json['discovery_condition'] ?? '', coopArcana: json['coop']?['arcana']?.toString(),
      memoryTags: memoryTags,
    );
  }
}

CharacterBasic _enrichBasicFromAppearance(CharacterBasic basic, Map<String, dynamic>? appearance) {
  if (appearance == null) return basic;
  final av = basic.avatarDesc.isEmpty ? [
    if (appearance['body'] is String && (appearance['body'] as String).isNotEmpty) appearance['body'],
    if (appearance['face'] is String && (appearance['face'] as String).isNotEmpty) appearance['face'],
    if (appearance['hair'] is String && (appearance['hair'] as String).isNotEmpty) appearance['hair'],
    if (appearance['eyes'] is String && (appearance['eyes'] as String).isNotEmpty) appearance['eyes'],
    if (appearance['clothing'] is String && (appearance['clothing'] as String).isNotEmpty) appearance['clothing'],
  ].join(' ') : basic.avatarDesc;
  final marks = basic.distinctiveMarks.isEmpty
      ? List<String>.from(appearance['distinctive_features'] is List ? appearance['distinctive_features'] : [])
      : basic.distinctiveMarks;
  return CharacterBasic(
    id: basic.id, name: basic.name, gender: basic.gender, age: basic.age,
    height: basic.height, weight: basic.weight, avatarDesc: av, distinctiveMarks: marks,
  );
}

class ShopItem {
  final String id;
  final String name;
  final String desc;
  final String type;
  final int cost;
  final String currency;
  final String obtain;
  final String targetChar;
  final String value;

  ShopItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.type,
    this.cost = 0,
    this.currency = '元',
    this.obtain = '',
    this.targetChar = '',
    this.value = '',
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      desc: json['desc'] ?? '',
      type: json['type'] ?? '',
      cost: json['cost'] ?? 0,
      currency: json['currency'] ?? '元',
      obtain: json['obtain'] ?? '',
      targetChar: json['target_char'] ?? '',
      value: json['value'] ?? '',
    );
  }
}

class ScriptItems {
  final List<ShopItem> gifts;
  final List<ShopItem> shopItems;

  ScriptItems({
    required this.gifts,
    required this.shopItems,
  });

  factory ScriptItems.fromJson(Map<String, dynamic> json) {
    return ScriptItems(
      gifts: (json['gifts'] as List<dynamic>?)
              ?.map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      shopItems: (json['shop_items'] as List<dynamic>?)
              ?.map((e) => ShopItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class InteractionConfig {
  final int totalDays;
  final int startDay;
  final int endDay;
  final String season;
  final List<String> phases;

  InteractionConfig({
    required this.totalDays,
    required this.startDay,
    required this.endDay,
    required this.season,
    required this.phases,
  });

  factory InteractionConfig.fromJson(Map<String, dynamic> json) {
    final timeConfig = json['time_config'] ?? {};
    return InteractionConfig(
      totalDays: timeConfig['total_days'] ?? 60,
      startDay: timeConfig['start_day'] ?? 1,
      endDay: timeConfig['end_day'] ?? 60,
      season: timeConfig['season'] ?? 'spring',
      phases: (timeConfig['phases'] as List<dynamic>?)
              ?.map((e) => e is String ? e : (e is Map ? (e['id']?.toString() ?? '') : ''))
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
    );
  }
}

class LocationNarrativeProfile {
  final Map<String, double> eventAffinity;
  final List<String> narrativeKeywords;

  LocationNarrativeProfile({
    Map<String, double>? eventAffinity,
    List<String>? narrativeKeywords,
  })  : eventAffinity = eventAffinity ?? {},
       narrativeKeywords = narrativeKeywords ?? [];

  factory LocationNarrativeProfile.fromJson(Map<String, dynamic> json) {
    final rawAffinity = json['event_affinity'] as Map<String, dynamic>?;
    return LocationNarrativeProfile(
      eventAffinity: rawAffinity?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      narrativeKeywords: List<String>.from(json['keywords'] ?? []),
    );
  }
}

class SceneLocation {
  final String id;
  final String name;
  final String desc;
  final String visibilityDefault;
  final String eventsHint;
  final List<String> availablePhases;
  final List<String> sceneMoods;
  final LocationNarrativeProfile? narrativeProfile;

  SceneLocation({
    this.id = '',
    this.name = '',
    this.desc = '',
    this.visibilityDefault = '',
    this.eventsHint = '',
    List<String>? availablePhases,
    List<String>? sceneMoods,
    this.narrativeProfile,
  })  : availablePhases = availablePhases ?? [],
        sceneMoods = sceneMoods ?? [];

  factory SceneLocation.fromJson(Map<String, dynamic> json) {
    return SceneLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      desc: json['desc'] ?? '',
      visibilityDefault: json['visibility_default'] ?? '',
      eventsHint: json['events_hint'] ?? '',
      availablePhases:
          List<String>.from(json['available_phases'] ?? []),
      sceneMoods: List<String>.from(json['scene_moods'] ?? []),
      narrativeProfile: json['narrative_profile'] != null
          ? LocationNarrativeProfile.fromJson(json['narrative_profile'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ScriptEventType {
  final String id;
  final String name;
  final String desc;

  ScriptEventType({
    this.id = '',
    this.name = '',
    this.desc = '',
  });

  factory ScriptEventType.fromJson(Map<String, dynamic> json) {
    return ScriptEventType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      desc: json['desc'] ?? '',
    );
  }
}

class SceneEvent {
  final String id;
  final String name;
  final String desc;
  final String locationId;
  final String charId;
  final String triggerType;
  final double affectionMin;
  final double affectionMax;
  final int dayMin;
  final int dayMax;
  final String phase;
  final String requiredItemId;
  final double affectionEffect;

  SceneEvent({
    this.id = '',
    this.name = '',
    this.desc = '',
    this.locationId = '',
    this.charId = '',
    this.triggerType = '',
    this.affectionMin = 0.0,
    this.affectionMax = 0.0,
    this.dayMin = 0,
    this.dayMax = 0,
    this.phase = '',
    this.requiredItemId = '',
    this.affectionEffect = 0.0,
  });

  factory SceneEvent.fromJson(Map<String, dynamic> json) {
    return SceneEvent(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      desc: json['desc'] ?? '',
      locationId: json['location_id'] ?? '',
      charId: json['char_id'] ?? '',
      triggerType: json['trigger_type'] ?? '',
      affectionMin: (json['affection_min'] as num?)?.toDouble() ?? 0.0,
      affectionMax: (json['affection_max'] as num?)?.toDouble() ?? 0.0,
      dayMin: json['day_min'] ?? 0,
      dayMax: json['day_max'] ?? 0,
      phase: json['phase'] ?? '',
      requiredItemId: json['required_item_id'] ?? '',
      affectionEffect:
          (json['affection_effect'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ScriptEvents {
  final List<SceneLocation> sceneLocations;
  final List<SceneEvent> sceneEvents;

  ScriptEvents({
    List<SceneLocation>? sceneLocations,
    List<SceneEvent>? sceneEvents,
  })  : sceneLocations = sceneLocations ?? [],
        sceneEvents = sceneEvents ?? [];

  factory ScriptEvents.fromJson(Map<String, dynamic> json,
      {List<Map<String, dynamic>>? worldLocations}) {
    var locations = (json['scene_locations'] as List<dynamic>?)
            ?.map(
                (e) => SceneLocation.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    if (locations.isEmpty &&
        worldLocations != null &&
        worldLocations.isNotEmpty) {
      locations = worldLocations
          .map((e) => SceneLocation.fromJson(e))
          .toList();
    }

    final events = (json['scene_events'] as List<dynamic>?)
            ?.map((e) => SceneEvent.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ScriptEvents(
      sceneLocations: locations,
      sceneEvents: events,
    );
  }
}

class GameScript {
  final ScriptMeta meta;
  final ScriptPlayer player;
  final ScriptWorld world;
  final List<Character> characters;
  final ScriptItems items;
  final InteractionConfig interaction;
  final ScriptEvents? events;
  final GamePlot? plot;
  final GameEvents? gameEvents;
  final GameDialogue? dialogue;
  final GameItems? gameItems;
  final GameInteraction? gameInteraction;
  final GameDataLayer? dataLayer;
  final ActionRules? actionRules;
  final FallbackNarratives? fallbackNarratives;
  final InterCharRelationConfig? interCharRelationConfig;
  final InformationSystemConfig? informationSystemConfig;
  final Map<String, dynamic> rhythmConfig;
  final Map<String, dynamic> memoryConfig;

  GameScript({
    required this.meta,
    required this.player,
    required this.world,
    required this.characters,
    required this.items,
    required this.interaction,
    this.events,
    this.plot,
    this.gameEvents,
    this.dialogue,
    this.gameItems,
    this.gameInteraction,
    this.dataLayer,
    this.actionRules,
    this.fallbackNarratives,
    Map<String, dynamic>? rhythmConfig,
    Map<String, dynamic>? memoryConfig,
    this.interCharRelationConfig,
    this.informationSystemConfig,
  }) : rhythmConfig = rhythmConfig ?? {},
       memoryConfig = memoryConfig ?? {};

  factory GameScript.fromJson(Map<String, dynamic> json) {
    final worldJson = json['world'] ?? {};
    final worldLocations = (worldJson['locations'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    return GameScript(
      meta: ScriptMeta.fromJson(json['meta'] ?? {}),
      player: ScriptPlayer.fromJson(json['player'] ?? {}),
      world: ScriptWorld.fromJson(worldJson),
      characters: _parseCharacters(json['characters']),
      items: _safeParseTop(json, 'items', (v) => ScriptItems.fromJson(v)) ?? ScriptItems(gifts: [], shopItems: []),
      interaction: _safeParseTop(json, 'interaction', (v) => InteractionConfig.fromJson(v)) ?? InteractionConfig(totalDays: 60, startDay: 1, endDay: 60, season: 'spring', phases: []),
      events: json['events'] != null
          ? _parseEventsSafe(json['events'], worldLocations: worldLocations)
          : null,
      plot: _safeParse(json, 'plot', (v)=>GamePlot.fromJson(v)),
      gameEvents: _safeParse(json, 'events', (v)=>GameEvents.fromJson(v)),
      dialogue: _safeParse(json, 'dialogue', (v)=>GameDialogue.fromJson(v)),
      gameItems: _safeParse(json, 'items', (v)=>GameItems.fromJson(v)),
      gameInteraction: _safeParse(json, 'interaction', (v)=>GameInteraction.fromJson(v)),
      dataLayer: _safeParse(json, 'data_layer', (v)=>GameDataLayer.fromJson(v)),
      actionRules: _safeParseTop(json, 'action_rules', (v) => ActionRules.fromJson(v)),
      fallbackNarratives: _safeParseTop(json, 'fallback_narratives', (v) => FallbackNarratives.fromJson(v)),
      rhythmConfig: json['rhythm_config'] is Map ? Map<String, dynamic>.from(json['rhythm_config'] as Map) : null,
      memoryConfig: json['memory_config'] is Map ? Map<String, dynamic>.from(json['memory_config'] as Map) : null,
      interCharRelationConfig: _safeParseTop(json, 'inter_character_relationships', (v) => InterCharRelationConfig.fromJson(v)),
      informationSystemConfig: _safeParseTop(json, 'information_system', (v) => InformationSystemConfig.fromJson(v)),
    );
  }
  static List<Character> _parseCharacters(dynamic list) {
    if (list is! List) return [];
    final result = <Character>[];
    for (int i = 0; i < list.length; i++) {
      try {
        final e = list[i];
        if (e is Map) {
          result.add(Character.fromJson(Map<String, dynamic>.from(e)));
        }
      } catch (_) {}
    }
    return result;
  }
  static T? _safeParse<T>(Map<String,dynamic> json, String key, T? Function(Map<String,dynamic>) parser) {
    if (json[key] == null) return null;
    try { return parser(json[key]); } catch(_) { return null; }
  }
  static T? _safeParseTop<T>(Map<String,dynamic> json, String key, T? Function(Map<String,dynamic>) parser) {
    final src = json[key];
    if (src is! Map) return null;
    try { return parser(src.cast<String,dynamic>()); } catch(_) { return null; }
  }
  static ScriptEvents? _parseEventsSafe(Map<String,dynamic> events, {List<Map<String,dynamic>>? worldLocations}) {
    try { return ScriptEvents.fromJson(events, worldLocations: worldLocations??[]); } catch(_) { return null; }
  }
}

class PlotPacingHint {
  final double plotRatio;
  final double dailyRatio;
  final double sweetRatio;
  PlotPacingHint({this.plotRatio = 0.0, this.dailyRatio = 0.0, this.sweetRatio = 0.0});
  factory PlotPacingHint.fromJson(Map<String, dynamic> json) => PlotPacingHint(
    plotRatio: (json['plot_ratio'] as num?)?.toDouble() ?? 0.0,
    dailyRatio: (json['daily_ratio'] as num?)?.toDouble() ?? 0.0,
    sweetRatio: (json['sweet_ratio'] as num?)?.toDouble() ?? 0.0,
  );
}

class PlotAct {
  final String id;
  final String name;
  final String description;
  final String phaseRange;
  final String entryCondition;
  final String exitCondition;
  final String narrativeDirection;
  final String tone;
  final List<String> mandatoryBeats;
  final List<String> optionalBeats;
  final PlotPacingHint pacingHint;
  PlotAct({this.id='',this.name='',this.description='',this.phaseRange='',this.entryCondition='',this.exitCondition='',this.narrativeDirection='',this.tone='',List<String>? mandatoryBeats,List<String>? optionalBeats,PlotPacingHint? pacingHint}):mandatoryBeats=mandatoryBeats??[],optionalBeats=optionalBeats??[],pacingHint=pacingHint??PlotPacingHint();
  factory PlotAct.fromJson(Map<String, dynamic> json) => PlotAct(
    id: json['id']??'',name: json['name']??'',description: json['description']??'',phaseRange: json['phase_range']??'',entryCondition: json['entry_condition']??'',exitCondition: json['exit_condition']??'',narrativeDirection: json['narrative_direction']??'',tone: json['tone']??'',
    mandatoryBeats: List<String>.from(json['mandatory_beats']??[]),optionalBeats: List<String>.from(json['optional_beats']??[]),pacingHint: PlotPacingHint.fromJson(json['pacing_hint']??{}),
  );
}

class PlotBeatTrigger {
  final Map<String, dynamic> time;
  final Map<String, dynamic> affection;
  final List<String> preBeats;
  final List<String> preEvents;
  final List<String> items;
  final double chaosMin;
  PlotBeatTrigger({Map<String,dynamic>? time,Map<String,dynamic>? affection,List<String>? preBeats,List<String>? preEvents,List<String>? items,this.chaosMin=0.0}):time=time??{},affection=affection??{},preBeats=preBeats??[],preEvents=preEvents??[],items=items??[];
  factory PlotBeatTrigger.fromJson(Map<String, dynamic> json) => PlotBeatTrigger(
    time: json['time']??{},affection: json['affection']??{},preBeats: List<String>.from(json['pre_beats']??[]),preEvents: List<String>.from(json['pre_events']??[]),items: List<String>.from(json['items']??[]),chaosMin: (json['chaos_min'] as num?)?.toDouble() ?? 0.0,
  );
}

class PlotBeatOutcome {
  final Map<String, dynamic> affectionChanges;
  final String narrativeShift;
  final List<String> unlockBeats;
  final List<String> unlockItems;
  final List<String> unlockLocations;
  final bool advanceAct;
  PlotBeatOutcome({Map<String,dynamic>? affectionChanges,this.narrativeShift='',List<String>? unlockBeats,List<String>? unlockItems,List<String>? unlockLocations,this.advanceAct=false}):affectionChanges=affectionChanges??{},unlockBeats=unlockBeats??[],unlockItems=unlockItems??[],unlockLocations=unlockLocations??[];
  factory PlotBeatOutcome.fromJson(Map<String, dynamic> json) => PlotBeatOutcome(
    affectionChanges: json['affection_changes']??{},narrativeShift: json['narrative_shift']??'',unlockBeats: List<String>.from(json['unlock_beats']??[]),unlockItems: List<String>.from(json['unlock_items']??[]),unlockLocations: List<String>.from(json['unlock_locations']??[]),advanceAct: json['advance_act']??false,
  );
}

class PlotBeat {
  final String id;
  final String name;
  final String act;
  final String desc;
  final PlotBeatTrigger trigger;
  final String aiHint;
  final PlotBeatOutcome outcome;
  final String priority;
  final bool once;
  final bool alwaysMemory;
  PlotBeat({this.id='',this.name='',this.act='',this.desc='',PlotBeatTrigger? trigger,this.aiHint='',PlotBeatOutcome? outcome,this.priority='optional',this.once=true,this.alwaysMemory=true}):trigger=trigger??PlotBeatTrigger(),outcome=outcome??PlotBeatOutcome();
  factory PlotBeat.fromJson(Map<String, dynamic> json) => PlotBeat(
    id: json['id']??'',name: json['name']??'',act: json['act']??'',desc: json['desc']??'',trigger: PlotBeatTrigger.fromJson(json['trigger']??{}),aiHint: json['ai_hint']??'',outcome: PlotBeatOutcome.fromJson(json['outcome']??{}),priority: json['priority']??'optional',once: json['once']??true,alwaysMemory: json['always_memory']??true,
  );
}

class PlotEndingCondition {
  final Map<String, dynamic> affection;
  final List<String> beatsTriggered;
  final List<String> beatsNotTriggered;
  final List<String> items;
  final Map<String, dynamic> dayRange;
  final String special;
  PlotEndingCondition({Map<String,dynamic>? affection,List<String>? beatsTriggered,List<String>? beatsNotTriggered,List<String>? items,Map<String,dynamic>? dayRange,this.special=''}):affection=affection??{},beatsTriggered=beatsTriggered??[],beatsNotTriggered=beatsNotTriggered??[],items=items??[],dayRange=dayRange??{};
  factory PlotEndingCondition.fromJson(Map<String, dynamic> json) => PlotEndingCondition(
    affection: json['affection']??{},beatsTriggered: List<String>.from(json['beats_triggered']??[]),beatsNotTriggered: List<String>.from(json['beats_not_triggered']??[]),items: List<String>.from(json['items']??[]),dayRange: json['day_range']??{},special: json['special']??'',
  );
}

class PlotEnding {
  final String id;
  final String title;
  final String type;
  final String typeDesc;
  final String character;
  final PlotEndingCondition conditions;
  final String aiHint;
  final int priority;
  PlotEnding({this.id='',this.title='',this.type='',this.typeDesc='',this.character='',PlotEndingCondition? conditions,this.aiHint='',this.priority=0}):conditions=conditions??PlotEndingCondition();
  factory PlotEnding.fromJson(Map<String, dynamic> json) => PlotEnding(
    id: json['id']??'',title: json['title']??'',type: json['type']??'',typeDesc: json['type_desc']??'',character: json['character']??'',conditions: PlotEndingCondition.fromJson(json['conditions']??{}),aiHint: json['ai_hint']??'',priority: (json['priority'] as num?)?.toInt()??0,
  );
}

class NarrativeTensionEffect {
  final String label;
  final String hint;
  NarrativeTensionEffect({this.label='',this.hint=''});
  factory NarrativeTensionEffect.fromJson(Map<String, dynamic> json) => NarrativeTensionEffect(label: json['label']??'',hint: json['hint']??'');
}

class NarrativeTensionModifier {
  final String chaosFactorBoost;
  final String highAffectionTension;
  final String forcedChoiceTension;
  NarrativeTensionModifier({this.chaosFactorBoost='',this.highAffectionTension='',this.forcedChoiceTension=''});
  factory NarrativeTensionModifier.fromJson(Map<String, dynamic> json) => NarrativeTensionModifier(chaosFactorBoost: json['chaos_factor_boost']??'',highAffectionTension: json['high_affection_tension']??'',forcedChoiceTension: json['forced_choice_tension']??'');
}

class NarrativeTension {
  final double currentLevel;
  final double min;
  final double max;
  final Map<String, double> perActBase;
  final Map<String, NarrativeTensionEffect> effects;
  final NarrativeTensionModifier modifiers;
  double _actualLevel;
  double get actualLevel => _actualLevel;
  void setLevel(double v) { _actualLevel = v.clamp(min, max); }
  NarrativeTension({this.currentLevel=20.0,this.min=0.0,this.max=100.0,Map<String,double>? perActBase,Map<String,NarrativeTensionEffect>? effects,NarrativeTensionModifier? modifiers}):perActBase=perActBase??{},effects=effects??{},modifiers=modifiers??NarrativeTensionModifier(),_actualLevel=currentLevel.clamp(min,max);
  factory NarrativeTension.fromJson(Map<String, dynamic> json) {
    final perAct = <String,double>{};
    (json['per_act_base'] as Map<String,dynamic>?)?.forEach((k,v)=>perAct[k]=(v as num).toDouble());
    final eff = <String,NarrativeTensionEffect>{};
    (json['effects'] as Map<String,dynamic>?)?.forEach((k,v)=>eff[k]=NarrativeTensionEffect.fromJson(v));
    final t = NarrativeTension(currentLevel: (json['current_level'] as num?)?.toDouble()??20.0,min: (json['min'] as num?)?.toDouble()??0.0,max: (json['max'] as num?)?.toDouble()??100.0,perActBase: perAct,effects: eff,modifiers: NarrativeTensionModifier.fromJson(json['modifiers']??{}));
    t.setLevel(t.currentLevel);
    return t;
  }
}

class PlotBranchRoute {
  final String id;
  final String name;
  final Map<String, dynamic> conditions;
  final bool active;
  PlotBranchRoute({this.id='',this.name='',Map<String,dynamic>? conditions,this.active=false}):conditions=conditions??{};
  factory PlotBranchRoute.fromJson(Map<String, dynamic> json) => PlotBranchRoute(id: json['id']??'',name: json['name']??'',conditions: json['conditions']??{},active: json['active']??false);
}

class PlotBranchSystem {
  final List<PlotBranchRoute> routes;
  final List<Map<String, dynamic>> branchHistory;
  PlotBranchSystem({List<PlotBranchRoute>? routes,List<Map<String,dynamic>>? branchHistory}):routes=routes??[],branchHistory=branchHistory??[];
  factory PlotBranchSystem.fromJson(Map<String, dynamic> json) => PlotBranchSystem(
    routes: (json['routes'] as List<dynamic>?)?.map((e)=>PlotBranchRoute.fromJson(e)).toList()??[],branchHistory: List<Map<String,dynamic>>.from(json['branch_history']??[]),
  );
}

class ForeshadowEntry {
  final String id;
  final String beatId;
  final String hint;
  final String payoffHint;
  final String targetBeat;
  final int plantedDay;
  ForeshadowEntry({this.id='',this.beatId='',this.hint='',this.payoffHint='',this.targetBeat='',this.plantedDay=0});
  factory ForeshadowEntry.fromJson(Map<String, dynamic> json) => ForeshadowEntry(id: json['id']??'',beatId: json['beat_id']??'',hint: json['hint']??'',payoffHint: json['payoff_hint']??'',targetBeat: json['target_beat']??'',plantedDay: json['planted_day']??0);
  Map<String, dynamic> toJson() => {'id':id,'beat_id':beatId,'hint':hint,'payoff_hint':payoffHint,'target_beat':targetBeat,'planted_day':plantedDay};
}

class ForeshadowSystem {
  final List<ForeshadowEntry> planted;
  final List<ForeshadowEntry> resolved;
  final double autoPlantChance;
  ForeshadowSystem({List<ForeshadowEntry>? planted,List<ForeshadowEntry>? resolved,this.autoPlantChance=0.1}):planted=planted??[],resolved=resolved??[];
  factory ForeshadowSystem.fromJson(Map<String, dynamic> json) => ForeshadowSystem(
    planted: (json['planted'] as List<dynamic>?)?.map((e)=>ForeshadowEntry.fromJson(e)).toList()??[],resolved: (json['resolved'] as List<dynamic>?)?.map((e)=>ForeshadowEntry.fromJson(e)).toList()??[],autoPlantChance: (json['auto_plant_chance'] as num?)?.toDouble()??0.1,
  );
}

class PlotPostEnding {
  final String toneShift;
  final List<String> eventFocus;
  final String availableMessages;
  PlotPostEnding({this.toneShift='',List<String>? eventFocus,this.availableMessages=''}):eventFocus=eventFocus??[];
  factory PlotPostEnding.fromJson(Map<String, dynamic> json) => PlotPostEnding(toneShift: json['tone_shift']??'',eventFocus: List<String>.from(json['event_focus']??[]),availableMessages: json['available_messages']??'');
}

class PlotMemory {
  String currentAct;
  int dayEnteredAct;
  final List<String> triggeredBeats;
  final List<Map<String, dynamic>> activeForeshadow;
  final Map<String, double> endingProgress;
  final List<String> activeRoutes;
  String narrativeSummary;
  PlotMemory({this.currentAct='',this.dayEnteredAct=0,List<String>? triggeredBeats,List<Map<String,dynamic>>? activeForeshadow,Map<String,double>? endingProgress,List<String>? activeRoutes,this.narrativeSummary=''}):triggeredBeats=triggeredBeats??[],activeForeshadow=activeForeshadow??[],endingProgress=endingProgress??{},activeRoutes=activeRoutes??[];
  factory PlotMemory.fromJson(Map<String, dynamic> json) {
    final ep = <String,double>{};
    (json['ending_progress'] as Map<String,dynamic>?)?.forEach((k,v)=>ep[k]=(v as num).toDouble());
    return PlotMemory(currentAct: json['current_act']??'',dayEnteredAct: json['day_entered_act']??0,triggeredBeats: List<String>.from(json['triggered_beats']??[]),activeForeshadow: List<Map<String,dynamic>>.from(json['active_foreshadow']??[]),endingProgress: ep,activeRoutes: List<String>.from(json['active_routes']??[]),narrativeSummary: json['narrative_summary']??'');
  }
}

class GamePlot {
  final String summary;
  final String premise;
  final List<PlotAct> acts;
  final List<PlotBeat> beats;
  final List<PlotEnding> endings;
  final NarrativeTension narrativeTension;
  final PlotBranchSystem branchSystem;
  final ForeshadowSystem foreshadowSystem;
  final PlotPostEnding? postEnding;
  final PlotMemory memory;
  GamePlot({this.summary='',this.premise='',List<PlotAct>? acts,List<PlotBeat>? beats,List<PlotEnding>? endings,NarrativeTension? narrativeTension,PlotBranchSystem? branchSystem,ForeshadowSystem? foreshadowSystem,this.postEnding,PlotMemory? memory}):acts=acts??[],beats=beats??[],endings=endings??[],narrativeTension=narrativeTension??NarrativeTension(),branchSystem=branchSystem??PlotBranchSystem(),foreshadowSystem=foreshadowSystem??ForeshadowSystem(),memory=memory??PlotMemory();
  factory GamePlot.fromJson(Map<String, dynamic> json) => GamePlot(
    summary: json['summary']??'',premise: json['premise']??'',
    acts: (json['acts'] as List<dynamic>?)?.map((e)=>PlotAct.fromJson(e)).toList()??[],
    beats: (json['beats'] as List<dynamic>?)?.map((e)=>PlotBeat.fromJson(e)).toList()??[],
    endings: (json['endings'] as List<dynamic>?)?.map((e)=>PlotEnding.fromJson(e)).toList()??[],
    narrativeTension: NarrativeTension.fromJson(json['narrative_tension']??{}),
    branchSystem: PlotBranchSystem.fromJson(json['branch_system']??{}),
    foreshadowSystem: ForeshadowSystem.fromJson(json['foreshadow_system']??{}),
    postEnding: json['post_ending']!=null?PlotPostEnding.fromJson(json['post_ending']):null,
    memory: PlotMemory.fromJson(json['memory']??{}),
  );
}

class EventTemplate {
  final String id;
  final String name;
  final String aiHint;
  final String aiRule;
  final double weight;
  final String severity;
  final String mood;
  final List<String> contextTags;
  final List<String> locationReq;
  final List<String> requiredChars;
  final bool alwaysMemory;
  final String duration;
  final int maxSteps;
  EventTemplate({this.id='',this.name='',this.aiHint='',this.aiRule='fixed',this.weight=1.0,this.severity='medium',this.mood='',List<String>? contextTags,List<String>? locationReq,List<String>? requiredChars,this.alwaysMemory=false,this.duration='short',this.maxSteps=3}):contextTags=contextTags??[],locationReq=locationReq??[],requiredChars=requiredChars??[];
  factory EventTemplate.fromJson(dynamic json) {
    if (json is String) return EventTemplate(id: json);
    if (json is! Map) return EventTemplate();
    return EventTemplate(id: (json['id'] ?? '').toString(),name: (json['name'] ?? '').toString(),aiHint: (json['ai_hint'] ?? '').toString(),aiRule: (json['ai_rule'] ?? 'fixed').toString(),weight: (json['weight'] as num?)?.toDouble()??1.0,severity: (json['severity'] ?? 'medium').toString(),mood: (json['mood'] ?? '').toString(),contextTags: _parseStringList(json['context_tags']),locationReq: _parseStringList(json['location_req']),requiredChars: _parseStringList(json['required_chars']),alwaysMemory: json['always_memory']??false,duration: (json['duration'] ?? 'short').toString(),maxSteps: (json['max_steps'] as num?)?.toInt()??3);
  }
}

class DailyScene {
  final String locationId;
  final List<String> phases;
  final List<String> moods;
  final String hintTemplate;
  DailyScene({this.locationId='',List<String>? phases,List<String>? moods,this.hintTemplate=''}):phases=phases??[],moods=moods??[];
  factory DailyScene.fromJson(dynamic json) {
    if (json is String) return DailyScene(locationId: json);
    if (json is! Map) return DailyScene();
    return DailyScene(locationId: (json['location']??'').toString(),phases: _parseStringList(json['phases']),moods: _parseStringList(json['moods']),hintTemplate: (json['hint_template']??'').toString());
  }
}

class ForcedChoiceOption {
  final String id;
  final String text;
  final String aiOutcomeHint;
  final Map<String,dynamic> affectionChanges;
  final List<String> unlockEvents;
  final List<String> unlockItems;
  final Map<String,dynamic> require;
  ForcedChoiceOption({this.id='',this.text='',this.aiOutcomeHint='',Map<String,dynamic>? affectionChanges,List<String>? unlockEvents,List<String>? unlockItems,Map<String,dynamic>? require}):affectionChanges=affectionChanges??{},unlockEvents=unlockEvents??[],unlockItems=unlockItems??[],require=require??{};
  factory ForcedChoiceOption.fromJson(Map<String,dynamic> json)=>ForcedChoiceOption(id: json['id']??'',text: json['text']??'',aiOutcomeHint: json['ai_outcome_hint']??'',affectionChanges: json['affection_changes']??{},unlockEvents: List<String>.from(json['unlock_events']??[]),unlockItems: List<String>.from(json['unlock_items']??[]),require: json['require']??{});
}

class EventCondition {
  final String id;
  final Map<String,dynamic> when;
  final List<String> eventRefs;
  final double weightBoost;
  EventCondition({this.id='',Map<String,dynamic>? when,List<String>? eventRefs,this.weightBoost=1.0}):when=when??{},eventRefs=eventRefs??[];
  factory EventCondition.fromJson(dynamic json) {
    if (json is! Map) return EventCondition();
    return EventCondition(id: (json['id']??'').toString(),when: json['when'] is Map ? Map<String,dynamic>.from(json['when']) : <String,dynamic>{},eventRefs: _parseStringList(json['event_refs']),weightBoost: (json['weight_boost'] as num?)?.toDouble()??1.0);
  }
}

class EventChain {
  final String id;
  final List<String> sequence;
  final String unlockCondition;
  EventChain({this.id='',List<String>? sequence,this.unlockCondition=''}):sequence=sequence??[];
  factory EventChain.fromJson(dynamic json) {
    if (json is! Map) return EventChain();
    return EventChain(id: (json['id']??'').toString(),sequence: _parseStringList(json['sequence']),unlockCondition: (json['unlock_condition']??'').toString());
  }
}

class EventButterfly {
  final List<Map<String,dynamic>> seeds;
  final int maxSeeds;
  final double bloomChance;
  EventButterfly({List<Map<String,dynamic>>? seeds,this.maxSeeds=5,this.bloomChance=0.2}):seeds=seeds??[];
  factory EventButterfly.fromJson(dynamic json) {
    if (json is! Map) return EventButterfly();
    return EventButterfly(seeds: json['seeds'] is List ? List<Map<String,dynamic>>.from(json['seeds']) : [],maxSeeds: json['max_seeds']??5,bloomChance: (json['bloom_chance'] as num?)?.toDouble()??0.2);
  }
}

class EventMemory {
  final List<Map<String,dynamic>> recentEvents;
  final List<Map<String,dynamic>> compressed;
  int eventCounter;
  EventMemory({List<Map<String,dynamic>>? recentEvents,List<Map<String,dynamic>>? compressed,this.eventCounter=0}):recentEvents=recentEvents??[],compressed=compressed??[];
  factory EventMemory.fromJson(dynamic json) {
    if (json is! Map) return EventMemory();
    return EventMemory(recentEvents: json['recent_events'] is List ? List<Map<String,dynamic>>.from(json['recent_events']) : [],compressed: json['compressed'] is List ? List<Map<String,dynamic>>.from(json['compressed']) : [],eventCounter: json['event_counter']??0);
  }
}

class GameEvents {
  final String summary;
  final Map<String,dynamic> generationRules;
  final List<EventTemplate> plotEvents;
  final List<EventTemplate> boundaryEvents;
  final List<EventTemplate> dailyEvents;
  final List<EventTemplate> sweetMinor;
  final List<EventTemplate> sweetMajor;
  final List<EventTemplate> loveTriangle;
  final List<EventTemplate> reversal;
  final List<EventTemplate> echo;
  final List<EventTemplate> misunderstanding;
  final List<EventTemplate> ensemble;
  final List<EventTemplate> worldShift;
  final List<Map<String,dynamic>> forcedChoice;
  final List<EventTemplate> resource;
  final List<EventTemplate> dialogueTrigger;
  final EventButterfly butterflySystem;
  final Map<String,double> tensionField;
  final List<EventCondition> conditions;
  final List<EventChain> chains;
  final List<EventTemplate> postEndingPool;
  final List<DailyScene> dailyScenes;
  final EventMemory memory;
  GameEvents({this.summary='',Map<String,dynamic>? generationRules,List<EventTemplate>? plotEvents,List<EventTemplate>? boundaryEvents,List<EventTemplate>? dailyEvents,List<EventTemplate>? sweetMinor,List<EventTemplate>? sweetMajor,List<EventTemplate>? loveTriangle,List<EventTemplate>? reversal,List<EventTemplate>? echo,List<EventTemplate>? misunderstanding,List<EventTemplate>? ensemble,List<EventTemplate>? worldShift,List<Map<String,dynamic>>? forcedChoice,List<EventTemplate>? resource,List<EventTemplate>? dialogueTrigger,EventButterfly? butterflySystem,Map<String,double>? tensionField,List<EventCondition>? conditions,List<EventChain>? chains,List<EventTemplate>? postEndingPool,List<DailyScene>? dailyScenes,EventMemory? memory}):generationRules=generationRules??{},plotEvents=plotEvents??[],boundaryEvents=boundaryEvents??[],dailyEvents=dailyEvents??[],sweetMinor=sweetMinor??[],sweetMajor=sweetMajor??[],loveTriangle=loveTriangle??[],reversal=reversal??[],echo=echo??[],misunderstanding=misunderstanding??[],ensemble=ensemble??[],worldShift=worldShift??[],forcedChoice=forcedChoice??[],resource=resource??[],dialogueTrigger=dialogueTrigger??[],butterflySystem=butterflySystem??EventButterfly(),tensionField=tensionField??{},conditions=conditions??[],chains=chains??[],postEndingPool=postEndingPool??[],dailyScenes=dailyScenes??[],memory=memory??EventMemory();

  factory GameEvents.fromJson(dynamic json) {
    if (json is! Map) return GameEvents();
    final tf = <String,double>{};
    (json['tension_field'] as Map<String,dynamic>?)?.forEach((k,v)=>tf[k]=(v is Map)?(v['value']??0.0):(v as num).toDouble());
    final sweet = json['sweet'];
    List<EventTemplate> sweetMinor = [];
    List<EventTemplate> sweetMajor = [];
    if (sweet is Map<String, dynamic>) {
      sweetMinor = _parseEvents(sweet['minor']);
      sweetMajor = _parseEvents(sweet['major']);
    } else if (sweet is List) {
      sweetMinor = _parseEvents(sweet);
    }
    return GameEvents(
      summary: json['summary']??'',generationRules: json['generation_rules']??{},
      plotEvents: _parseEvents(json['plot']),boundaryEvents: _parseEvents(json['boundary']),
      dailyEvents: _parseEvents(json['daily']),sweetMinor: sweetMinor,
      sweetMajor: sweetMajor,loveTriangle: _parseEvents(json['love_triangle']),
      reversal: _parseEvents(json['reversal']),echo: _parseEvents(json['echo']),
      misunderstanding: _parseEvents(json['misunderstanding']),ensemble: _parseEvents(json['ensemble']),
      worldShift: _parseEvents(json['world_shift']),
      forcedChoice: List<Map<String,dynamic>>.from(json['forced_choice']??[]),
      resource: _parseEvents(json['resource']),dialogueTrigger: _parseEvents(json['dialogue_trigger']),
      butterflySystem: EventButterfly.fromJson(json['butterfly_system']??{}),
      tensionField: tf,conditions: (json['conditions'] as List<dynamic>?)?.map((e)=>EventCondition.fromJson(e)).toList()??[],
      chains: (json['chains'] as List<dynamic>?)?.map((e)=>EventChain.fromJson(e)).toList()??[],
      postEndingPool: _parseEvents(json['post_ending_pool']),
      dailyScenes: (json['daily_scenes'] as List<dynamic>?)?.map((e)=>DailyScene.fromJson(e as Map<String,dynamic>)).toList()??[],
      memory: EventMemory.fromJson(json['memory']??{}),
    );
  }
  static List<EventTemplate> _parseEvents(dynamic list) {
    if (list==null) return [];
    if (list is! List) return [];
    return list.map((e)=>EventTemplate.fromJson(e)).toList();
  }
}

class DialogueMessageTrigger {
  final String id;
  final String trigger;
  final String charId;
  final String condition;
  final String aiHint;
  final bool once;
  final int cooldownDays;
  final int priority;
  DialogueMessageTrigger({this.id='',this.trigger='',this.charId='',this.condition='',this.aiHint='',this.once=false,this.cooldownDays=0,this.priority=0});
  factory DialogueMessageTrigger.fromJson(Map<String,dynamic> json)=>DialogueMessageTrigger(id: json['id']??'',trigger: json['trigger']??'',charId: json['char_id']??'',condition: json['condition']??'',aiHint: json['ai_hint']??'',once: json['once']??false,cooldownDays: json['cooldown_days']??0,priority: (json['priority'] as num?)?.toInt()??0);
}

class GameDialogue {
  final String summary;
  final Map<String,dynamic> engines;
  final List<DialogueMessageTrigger> messageFromChar;
  final Map<String,dynamic> eventAftermath;
  final Map<String,dynamic> chatRestrictions;
  final Map<String,dynamic> flatCharDefaults;
  final Map<String,dynamic> memory;
  GameDialogue({this.summary='',Map<String,dynamic>? engines,List<DialogueMessageTrigger>? messageFromChar,Map<String,dynamic>? eventAftermath,Map<String,dynamic>? chatRestrictions,Map<String,dynamic>? flatCharDefaults,Map<String,dynamic>? memory}):engines=engines??{},messageFromChar=messageFromChar??[],eventAftermath=eventAftermath??{},chatRestrictions=chatRestrictions??{},flatCharDefaults=flatCharDefaults??{},memory=memory??{};
  factory GameDialogue.fromJson(Map<String,dynamic> json)=>GameDialogue(summary: json['summary']??'',engines: json['engines']??{},messageFromChar: (json['triggers']?['message_from_char'] as List<dynamic>?)?.map((e)=>DialogueMessageTrigger.fromJson(e)).toList()??[],eventAftermath: json['triggers']?['event_aftermath']??{},chatRestrictions: json['triggers']?['chat_restrictions']??{},flatCharDefaults: json['flat_character_defaults']??{},memory: json['memory']??{});
}

class ItemEffect {
  final Map<String,dynamic> affectionMod;
  final Map<String,dynamic> statMod;
  final String unlockEvent;
  final String unlockLocation;
  final int durationTurns;
  final bool permanent;
  ItemEffect({Map<String,dynamic>? affectionMod,Map<String,dynamic>? statMod,this.unlockEvent='',this.unlockLocation='',this.durationTurns=0,this.permanent=false}):affectionMod=affectionMod??{},statMod=statMod??{};
  factory ItemEffect.fromJson(Map<String,dynamic> json)=>ItemEffect(affectionMod: json['affection_mod']??{},statMod: json['stat_mod']??{},unlockEvent: json['unlock_event']??'',unlockLocation: json['unlock_location']??'',durationTurns: json['duration_turns']??0,permanent: json['permanent']??false);
}

class ItemGiftMeta {
  final String category;
  final String hint;
  ItemGiftMeta({this.category='neutral',this.hint=''});
  factory ItemGiftMeta.fromJson(Map<String,dynamic> json)=>ItemGiftMeta(category: json['category']??'neutral',hint: json['hint']??'');
}

class ItemRequirement {
  final Map<String,dynamic> minAffection;
  final int dayMin;
  final List<String> preItems;
  final List<String> preBeats;
  ItemRequirement({Map<String,dynamic>? minAffection,this.dayMin=0,List<String>? preItems,List<String>? preBeats}):minAffection=minAffection??{},preItems=preItems??[],preBeats=preBeats??[];
  factory ItemRequirement.fromJson(Map<String,dynamic> json)=>ItemRequirement(minAffection: json['min_affection']??{},dayMin: json['day_min']??0,preItems: List<String>.from(json['pre_items']??[]),preBeats: List<String>.from(json['pre_beats']??[]));
}

class ScriptItem {
  final String itemId;
  final String name;
  final String type;
  final String rarity;
  final String desc;
  final String flavorText;
  final int price;
  final bool canSell;
  final int sellPrice;
  final bool stackable;
  final int maxStack;
  final String obtain;
  final String obtainHint;
  final ItemEffect effects;
  final ItemGiftMeta giftMeta;
  final ItemRequirement requirements;
  final bool isShopItem;
  final Map<String, double> equipStats;
  final String slot;
  final int durability;
  ScriptItem({this.itemId='',this.name='',this.type='',this.rarity='common',this.desc='',this.flavorText='',this.price=0,this.canSell=true,this.sellPrice=0,this.stackable=true,this.maxStack=99,this.obtain='',this.obtainHint='',ItemEffect? effects,ItemGiftMeta? giftMeta,ItemRequirement? requirements,this.isShopItem=false,Map<String,double>? equipStats,this.slot='',this.durability=100}):effects=effects??ItemEffect(),giftMeta=giftMeta??ItemGiftMeta(),requirements=requirements??ItemRequirement(),equipStats=equipStats??{};
  factory ScriptItem.fromJson(Map<String,dynamic> json)=>ScriptItem(itemId: json['item_id']??'',name: json['name']??'',type: json['type']??'',rarity: json['rarity']??'common',desc: json['desc']??'',flavorText: json['flavor_text']??'',price: json['price']??0,canSell: json['can_sell']??true,sellPrice: json['sell_price']??0,stackable: json['stackable']??true,maxStack: json['max_stack']??99,obtain: json['obtain']??'',obtainHint: json['obtain_hint']??'',effects: ItemEffect.fromJson(json['effects']??{}),giftMeta: ItemGiftMeta.fromJson(json['gift_meta']??{}),requirements: ItemRequirement.fromJson(json['requirements']??{}),equipStats: (json['equip_stats'] as Map<String,dynamic>?)?.map((k,v)=>MapEntry(k,(v as num).toDouble()))??{},slot: json['slot']??'',durability: json['durability']??100);
}

class ShopRestockRule {
  final String type;
  final String hint;
  ShopRestockRule({this.type='daily',this.hint=''});
  factory ShopRestockRule.fromJson(Map<String,dynamic> json)=>ShopRestockRule(type: json['type']??'daily',hint: json['hint']??'');
}

class GameShop {
  final String name;
  final List<String> categories;
  final int slots;
  final ShopRestockRule restockRule;
  final double priceMultiplier;
  final Map<String,dynamic> specialItems;
  GameShop({this.name='商店',List<String>? categories,this.slots=8,ShopRestockRule? restockRule,this.priceMultiplier=1.0,Map<String,dynamic>? specialItems}):categories=categories??['gift'],restockRule=restockRule??ShopRestockRule(),specialItems=specialItems??{};
  factory GameShop.fromJson(Map<String,dynamic> json)=>GameShop(name: json['name']??'商店',categories: List<String>.from(json['categories']??['gift']),slots: json['slots']??8,restockRule: ShopRestockRule.fromJson(json['restock_rule']??{}),priceMultiplier: (json['price_multiplier'] as num?)?.toDouble()??1.0,specialItems: json['special_items']??{});
}

class GiftingRules {
  final Map<String,dynamic> cooldownPerChar;
  final Map<String,dynamic> reactionRule;
  final String uniqueGiftRule;
  final String chainGifting;
  GiftingRules({Map<String,dynamic>? cooldownPerChar,Map<String,dynamic>? reactionRule,this.uniqueGiftRule='',this.chainGifting=''}):cooldownPerChar=cooldownPerChar??{},reactionRule=reactionRule??{};
  factory GiftingRules.fromJson(Map<String,dynamic> json)=>GiftingRules(cooldownPerChar: json['cooldown_per_char']??{},reactionRule: json['reaction_rule']??{},uniqueGiftRule: json['unique_gift_rule']??'',chainGifting: json['chain_gifting']??'');
}

class GameItems {
  final String summary;
  final List<Map<String,dynamic>> currency;
  final List<ScriptItem> list;
  final GameShop shop;
  final GiftingRules gifting;
  final Map<String,dynamic> crafting;
  final Map<String,dynamic> memory;
  GameItems({this.summary='',List<Map<String,dynamic>>? currency,List<ScriptItem>? list,GameShop? shop,GiftingRules? gifting,Map<String,dynamic>? crafting,Map<String,dynamic>? memory}):currency=currency??[],list=list??[],shop=shop??GameShop(),gifting=gifting??GiftingRules(),crafting=crafting??{},memory=memory??{};
  factory GameItems.fromJson(Map<String,dynamic> json)=>GameItems(summary: json['summary']??'',currency: List<Map<String,dynamic>>.from(json['currency']??[]),list: (json['list'] as List<dynamic>?)?.map((e)=>ScriptItem.fromJson(e)).toList()??[],shop: GameShop.fromJson(json['shop']??{}),gifting: GiftingRules.fromJson(json['gifting']??{}),crafting: json['crafting']??{},memory: json['memory']??{});
}

class InteractionAdvanceMode {
  final String label;
  final String description;
  final Map<String,dynamic> timeAdvance;
  final List<String> eventsPool;
  final Map<String,dynamic> eventsCount;
  final int cooldownSeconds;
  final bool canTriggerWorldShift;
  final bool canTriggerForcedChoice;
  final bool canTriggerMilestone;
  final bool writesWorldHistory;
  final String affectionRule;
  final CustomActionRuling? rulingEngine;
  InteractionAdvanceMode({this.label='',this.description='',Map<String,dynamic>? timeAdvance,List<String>? eventsPool,Map<String,dynamic>? eventsCount,this.cooldownSeconds=0,this.canTriggerWorldShift=false,this.canTriggerForcedChoice=false,this.canTriggerMilestone=false,this.writesWorldHistory=false,this.affectionRule='',this.rulingEngine}):timeAdvance=timeAdvance??{},eventsPool=eventsPool??[],eventsCount=eventsCount??{};
  factory InteractionAdvanceMode.fromJson(Map<String,dynamic> json)=>InteractionAdvanceMode(label: json['label']??'',description: json['description']??'',timeAdvance: json['time_advance']??{},eventsPool: List<String>.from(json['events_pool']??[]),eventsCount: json['events_count']??{},cooldownSeconds: json['cooldown_seconds']??0,canTriggerWorldShift: json['can_trigger_world_shift']??false,canTriggerForcedChoice: json['can_trigger_forced_choice']??false,canTriggerMilestone: json['can_trigger_milestone']??false,writesWorldHistory: json['writes_world_history']??false,affectionRule: json['affection_rule']??'',rulingEngine: json['ruling_engine'] != null ? CustomActionRuling.fromJson(json['ruling_engine']) : null);
}

class CustomActionRuling {
  final List<String> allowedActionTypes;
  final String violencePolicy;
  final String reasonabilityHint;
  final List<String> outputRules;
  CustomActionRuling({List<String>? allowedActionTypes,this.violencePolicy='',this.reasonabilityHint='',List<String>? outputRules}):allowedActionTypes=allowedActionTypes??[],outputRules=outputRules??[];
  factory CustomActionRuling.fromJson(Map<String,dynamic> json)=>CustomActionRuling(allowedActionTypes: List<String>.from(json['allowed_action_types']??[]),violencePolicy: json['violence_policy']??'',reasonabilityHint: json['reasonability_hint']??'',outputRules: List<String>.from(json['output_rules']??[]));
}

class InteractionAffectionBoundary {
  final String rule;
  final String requires;
  final String breakthroughEvent;
  final String eventType;
  final Map<String,dynamic> outcomeRange;
  InteractionAffectionBoundary({this.rule='',this.requires='',this.breakthroughEvent='',this.eventType='',Map<String,dynamic>? outcomeRange}):outcomeRange=outcomeRange??{};
  factory InteractionAffectionBoundary.fromJson(Map<String,dynamic> json)=>InteractionAffectionBoundary(rule: json['rule']??'',requires: json['requires']??'',breakthroughEvent: json['breakthrough_event']??'',eventType: json['event_type']??'',outcomeRange: json['outcome_range']??{});
}

class InteractionAffectionTier {
  final String rule;
  final String hint;
  InteractionAffectionTier({this.rule='',this.hint=''});
  factory InteractionAffectionTier.fromJson(Map<String,dynamic> json)=>InteractionAffectionTier(rule: json['rule']??'',hint: json['hint']??'');
}

class AffectionDiffCurveEntry {
  final double multiplier;
  final String feel;
  AffectionDiffCurveEntry({this.multiplier=1.0,this.feel=''});
  factory AffectionDiffCurveEntry.fromJson(dynamic val) {
    if (val is Map) return AffectionDiffCurveEntry(multiplier: (val['multiplier'] as num?)?.toDouble()??1.0,feel: val['feel']??'');
    return AffectionDiffCurveEntry();
  }
}

class InteractionAffection {
  final double min;
  final double max;
  final double precision;
  final List<double> tiers;
  final InteractionAffectionBoundary boundaryEvents;
  final Map<String,InteractionAffectionTier> tierBreakthrough;
  final String overflowPool;
  final Map<String,AffectionDiffCurveEntry> gainMultiplier;
  final Map<String,AffectionDiffCurveEntry> declineMultiplier;
  final Map<String,String> declineRules;
  final Map<String,String> tiersDesc;
  final Map<String,dynamic> uniqueBond;
  InteractionAffection({this.min=1.0,this.max=100.0,this.precision=0.01,List<double>? tiers,InteractionAffectionBoundary? boundaryEvents,Map<String,InteractionAffectionTier>? tierBreakthrough,this.overflowPool='',Map<String,AffectionDiffCurveEntry>? gainMultiplier,Map<String,AffectionDiffCurveEntry>? declineMultiplier,Map<String,String>? declineRules,Map<String,String>? tiersDesc,Map<String,dynamic>? uniqueBond}):tiers=tiers??[],boundaryEvents=boundaryEvents??InteractionAffectionBoundary(),tierBreakthrough=tierBreakthrough??{},gainMultiplier=gainMultiplier??{},declineMultiplier=declineMultiplier??{},declineRules=declineRules??{},tiersDesc=tiersDesc??{},uniqueBond=uniqueBond??{};
  factory InteractionAffection.fromJson(Map<String,dynamic> json) {
    final gm = <String,AffectionDiffCurveEntry>{};
    (json['difficulty_curve']?['gain_multiplier'] as Map<String,dynamic>?)?.forEach((k,v)=>gm[k]=AffectionDiffCurveEntry.fromJson(v));
    final dm = <String,AffectionDiffCurveEntry>{};
    (json['difficulty_curve']?['decline_multiplier'] as Map<String,dynamic>?)?.forEach((k,v)=>dm[k]=AffectionDiffCurveEntry.fromJson(v));
    final dr = <String,String>{};(json['decline_rules'] as Map<String,dynamic>?)?.forEach((k,v)=>dr[k]=v.toString());
    final td = <String,String>{};(json['tiers_desc'] as Map<String,dynamic>?)?.forEach((k,v)=>td[k]=v.toString());
    final tb = <String,InteractionAffectionTier>{};(json['tier_breakthrough'] as Map<String,dynamic>?)?.forEach((k,v)=>tb[k]=InteractionAffectionTier.fromJson(v));
    return InteractionAffection(min: (json['min'] as num?)?.toDouble()??1.0,max: (json['max'] as num?)?.toDouble()??100.0,precision: (json['precision'] as num?)?.toDouble()??0.01,tiers: (json['tiers'] as List<dynamic>?)?.map((e)=>(e as num).toDouble()).toList()??[],boundaryEvents: InteractionAffectionBoundary.fromJson(json['boundary_events']??{}),tierBreakthrough: tb,overflowPool: json['overflow_pool']??'',gainMultiplier: gm,declineMultiplier: dm,declineRules: dr,tiersDesc: td,uniqueBond: json['unique_bond']??{});
  }
}

class GameInteraction {
  final String summary;
  final Map<String,dynamic> timeConfig;
  final Map<String,InteractionAdvanceMode> advanceModes;
  final List<Map<String,dynamic>> seasons;
  final Map<String,dynamic> weatherSystem;
  final InteractionAffection affection;
  final Map<String,dynamic> chat;
  final Map<String,dynamic> messages;
  final String pace;
  final Map<String,dynamic> contextManagement;
  final Map<String,dynamic> memory;
  GameInteraction({this.summary='',Map<String,dynamic>? timeConfig,Map<String,InteractionAdvanceMode>? advanceModes,List<Map<String,dynamic>>? seasons,Map<String,dynamic>? weatherSystem,InteractionAffection? affection,Map<String,dynamic>? chat,Map<String,dynamic>? messages,this.pace='',Map<String,dynamic>? contextManagement,Map<String,dynamic>? memory}):timeConfig=timeConfig??{},advanceModes=advanceModes??{},seasons=seasons??[],weatherSystem=weatherSystem??{},affection=affection??InteractionAffection(),chat=chat??{},messages=messages??{},contextManagement=contextManagement??{},memory=memory??{};
  factory GameInteraction.fromJson(Map<String,dynamic> json) {
    final am = <String,InteractionAdvanceMode>{};
    final advRaw = json['advance_modes'];
    if (advRaw is Map<String,dynamic>) {
      advRaw.forEach((k,v)=>am[k]=InteractionAdvanceMode.fromJson(v));
    } else if (advRaw is List) {
      for (final m in advRaw) {
        if (m is Map<String,dynamic>) {
          final id = (m['id'] ?? m['name'] ?? 'daily').toString();
          am[id] = InteractionAdvanceMode(
            label: (m['name'] ?? m['id'] ?? '').toString(),
            description: (m['desc'] ?? '').toString(),
            timeAdvance: {'phases': 1},
            eventsPool: const ['daily','boundary','sweet_minor','sweet_major','ensemble'],
            eventsCount: const {'min':1,'max':2},
          );
        }
      }
    }
    InteractionAffection affection;
    try { affection = InteractionAffection.fromJson(json['affection']??{}); } catch(_) { affection = InteractionAffection(); }
    if (am.isEmpty) {
      am['daily'] = InteractionAdvanceMode(label:'日常推进',description:'推进日常时间',timeAdvance:{'skip_days':{'min':2,'max':4}},eventsPool:['daily','boundary','sweet_minor','sweet_major','love_triangle','ensemble'],eventsCount:{'min':1,'max':2});
      am['major'] = InteractionAdvanceMode(label:'重要推进',description:'推进剧情',timeAdvance:{'to_milestone':true},eventsPool:['plot','boundary','forced_choice','world_shift','echo','dialogue_trigger'],eventsCount:{'min':1,'max':1},canTriggerMilestone:true,writesWorldHistory:true);
    }
    return GameInteraction(summary: json['summary']??'',timeConfig: json['time_config'] is Map ? json['time_config'] : <String,dynamic>{},advanceModes: am,seasons: List<Map<String,dynamic>>.from(json['seasons']??[]),weatherSystem: json['weather_system']??{},affection: affection,chat: json['chat']??{},messages: json['messages']??{},pace: json['pace']??'',contextManagement: json['context_management']??{},memory: json['memory']??{});
  }
}

// --- 数据层模型 v2.0 ---

class PlayerStatDefinition {
  final String id;
  final String name;
  final String category;
  final double min;
  final double max;
  final double initial;
  PlayerStatDefinition({this.id='',this.name='',this.category='talent',this.min=0,this.max=100,this.initial=50});
  factory PlayerStatDefinition.fromJson(Map<String,dynamic> json)=>PlayerStatDefinition(
    id: json['id']??'',name: json['name']??'',category: json['category']??'talent',
    min: (json['min'] as num?)?.toDouble()??0,max: (json['max'] as num?)?.toDouble()??100,
    initial: (json['initial'] as num?)?.toDouble()??50);
}

class PlayerGradeDefinition {
  final String id;
  final String name;
  final double min;
  final double max;
  final double initial;
  PlayerGradeDefinition({this.id='',this.name='',this.min=0,this.max=150,this.initial=100});
  factory PlayerGradeDefinition.fromJson(Map<String,dynamic> json)=>PlayerGradeDefinition(
    id: json['id']??'',name: json['name']??'',
    min: (json['min'] as num?)?.toDouble()??0,max: (json['max'] as num?)?.toDouble()??150,
    initial: (json['initial'] as num?)?.toDouble()??100);
}

class RankingEventDef {
  final String id;
  final String name;
  final int intervalDays;
  final List<String> affects;
  RankingEventDef({this.id='',this.name='',this.intervalDays=0,List<String>? affects}):affects=affects??[];
  factory RankingEventDef.fromJson(Map<String,dynamic> json)=>RankingEventDef(
    id: json['id']??'',name: json['name']??'',intervalDays: json['interval_days']??0,
    affects: List<String>.from(json['affects']??[]));
}

class RankingSystemDef {
  final int totalStudents;
  final List<RankingEventDef> events;
  RankingSystemDef({this.totalStudents=800,List<RankingEventDef>? events}):events=events??[];
  factory RankingSystemDef.fromJson(Map<String,dynamic> json)=>RankingSystemDef(
    totalStudents: json['total_students']??800,
    events: (json['events'] as List<dynamic>?)?.map((e)=>RankingEventDef.fromJson(e)).toList()??[]);
}

class DataLayerMemory {
  final Map<String,double> statValues;
  final Map<String,double> gradeValues;
  final List<Map<String,dynamic>> gradeHistory;
  int lastRankingDay;
  DataLayerMemory({Map<String,double>? statValues,Map<String,double>? gradeValues,List<Map<String,dynamic>>? gradeHistory,this.lastRankingDay=0}):statValues=statValues??{},gradeValues=gradeValues??{},gradeHistory=gradeHistory??[];
  factory DataLayerMemory.fromJson(Map<String,dynamic> json) {
    final sv = <String,double>{};
    (json['stat_values'] as Map<String,dynamic>?)?.forEach((k,v)=>sv[k]=(v as num).toDouble());
    final gv = <String,double>{};
    (json['grade_values'] as Map<String,dynamic>?)?.forEach((k,v)=>gv[k]=(v as num).toDouble());
    return DataLayerMemory(
      statValues: sv,gradeValues: gv,
      gradeHistory: List<Map<String,dynamic>>.from(json['grade_history']??[]),
      lastRankingDay: json['last_ranking_day']??0);
  }
  Map<String,dynamic> toJson()=>{
    'stat_values':statValues,'grade_values':gradeValues,
    'grade_history':gradeHistory,'last_ranking_day':lastRankingDay};
}

class GameDataLayer {
  final Map<String,dynamic> playerProfile;
  final List<PlayerStatDefinition> stats;
  final List<PlayerGradeDefinition> grades;
  final RankingSystemDef ranking;
  final DataLayerMemory memory;
  final Map<String, GradeFormula> gradeFormulas;
  final double naturalGrowthRate;
  final Map<String, dynamic>? training;
  GameDataLayer({Map<String,dynamic>? playerProfile,List<PlayerStatDefinition>? stats,List<PlayerGradeDefinition>? grades,RankingSystemDef? ranking,DataLayerMemory? memory,Map<String, GradeFormula>? gradeFormulas,this.naturalGrowthRate=0.02,this.training}):playerProfile=playerProfile??{},stats=stats??[],grades=grades??[],ranking=ranking??RankingSystemDef(),memory=memory??DataLayerMemory(),gradeFormulas=gradeFormulas??{};
  factory GameDataLayer.fromJson(Map<String,dynamic> json) {
    final gfs = <String, GradeFormula>{};
    (json['grade_formulas'] as Map<String,dynamic>?)?.forEach((k, v) {
      gfs[k] = GradeFormula.fromJson(v);
    });
    return GameDataLayer(
      playerProfile: json['player_profile']??{},
      stats: (json['stats'] as List<dynamic>?)?.map((e)=>PlayerStatDefinition.fromJson(e)).toList()??[],
      grades: (json['grades'] as List<dynamic>?)?.map((e)=>PlayerGradeDefinition.fromJson(e)).toList()??[],
      ranking: RankingSystemDef.fromJson(json['ranking']??{}),
      memory: DataLayerMemory.fromJson(json['memory']??{}),
      gradeFormulas: gfs,
      naturalGrowthRate: (json['natural_growth_rate'] as num?)?.toDouble() ?? 0.02,
      training: json['training'] as Map<String, dynamic>?,
    );
  }
}

class GradeFormula {
  final double baseWeight;
  final double variance;
  final Map<String, double> statBonuses;
  GradeFormula({this.baseWeight=0.7,this.variance=10,Map<String,double>? statBonuses}):statBonuses=statBonuses??{};
  factory GradeFormula.fromJson(Map<String,dynamic> json) {
    final sb = <String, double>{};
    (json['stat_bonuses'] as Map<String,dynamic>?)?.forEach((k, v) {
      sb[k] = (v as num).toDouble();
    });
    return GradeFormula(
      baseWeight: (json['base_weight'] as num?)?.toDouble()??0.7,
      variance: (json['variance'] as num?)?.toDouble()??10,
      statBonuses: sb,
    );
  }
}

class CharacterScheduleSlot {
  final String phase;
  final String locationId;
  final String activity;
  final int priority;
  final List<String> conditions;
  CharacterScheduleSlot({this.phase='',this.locationId='',this.activity='',this.priority=50,List<String>? conditions}):conditions=conditions??[];
  factory CharacterScheduleSlot.fromJson(dynamic json) {
    if (json is! Map) return CharacterScheduleSlot();
    return CharacterScheduleSlot(phase: (json['phase']??'').toString(),locationId: (json['location']??'').toString(),activity: (json['activity']??'').toString(),priority: json['priority']??50,conditions: _parseStringList(json['conditions']));
  }
}

class CharacterSchedule {
  final List<CharacterScheduleSlot> weekday;
  final List<CharacterScheduleSlot> weekend;
  CharacterSchedule({List<CharacterScheduleSlot>? weekday,List<CharacterScheduleSlot>? weekend}):weekday=weekday??[],weekend=weekend??[];
  factory CharacterSchedule.fromJson(dynamic json) {
    if (json is! Map) return CharacterSchedule();
    return CharacterSchedule(weekday: (json['weekday'] is List ? (json['weekday'] as List).map((e)=>CharacterScheduleSlot.fromJson(e)).toList() : <CharacterScheduleSlot>[]),weekend: (json['weekend'] is List ? (json['weekend'] as List).map((e)=>CharacterScheduleSlot.fromJson(e)).toList() : <CharacterScheduleSlot>[]));
  }
}

class CharacterStat {
  final String id;
  final String name;
  final double value;
  final double max;
  CharacterStat({this.id='',this.name='',this.value=50,this.max=100});
  factory CharacterStat.fromJson(dynamic json) {
    if (json is! Map) return CharacterStat();
    return CharacterStat(id: (json['id']??'').toString(),name: (json['name']??'').toString(),value: (json['value'] as num?)?.toDouble()??50,max: (json['max'] as num?)?.toDouble()??100);
  }
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'value':value,'max':max};
}

class CharacterGrade {
  final String id;
  final String name;
  final double value;
  final double max;
  CharacterGrade({this.id='',this.name='',this.value=100,this.max=150});
  factory CharacterGrade.fromJson(dynamic json) {
    if (json is! Map) return CharacterGrade();
    return CharacterGrade(id: (json['id']??'').toString(),name: (json['name']??'').toString(),value: (json['value'] as num?)?.toDouble()??100,max: (json['max'] as num?)?.toDouble()??150);
  }
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'value':value,'max':max};
}

class InterCharInitAttitude {
  final String fromId;
  final String toId;
  final double affinity;
  final String label;
  final bool isSecretAdmirer;
  final String history;

  InterCharInitAttitude({
    this.fromId = '',
    this.toId = '',
    this.affinity = 0.0,
    this.label = '',
    this.isSecretAdmirer = false,
    this.history = '',
  });

  factory InterCharInitAttitude.fromJson(Map<String, dynamic> json) {
    return InterCharInitAttitude(
      fromId: json['from'] ?? '',
      toId: json['to'] ?? '',
      affinity: (json['affinity'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] ?? '',
      isSecretAdmirer: json['is_secret_admirer'] ?? false,
      history: json['history'] ?? '',
    );
  }
}

class InterCharRelationConfig {
  final List<InterCharInitAttitude> initialAttitudes;

  InterCharRelationConfig({
    List<InterCharInitAttitude>? initialAttitudes,
  }) : initialAttitudes = initialAttitudes ?? [];

  factory InterCharRelationConfig.fromJson(Map<String, dynamic> json) {
    return InterCharRelationConfig(
      initialAttitudes: (json['initial_attitudes'] as List<dynamic>?)
              ?.map((e) => InterCharInitAttitude.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class EncryptionStyleConfig {
  final double trust;
  final String desc;

  EncryptionStyleConfig({
    this.trust = 1.0,
    this.desc = '',
  });

  factory EncryptionStyleConfig.fromJson(Map<String, dynamic> json) {
    return EncryptionStyleConfig(
      trust: (json['trust'] as num?)?.toDouble() ?? 1.0,
      desc: json['desc'] ?? '',
    );
  }
}

class InformationSystemConfig {
  final Map<String, EncryptionStyleConfig> encryptionStyles;

  InformationSystemConfig({
    Map<String, EncryptionStyleConfig>? encryptionStyles,
  }) : encryptionStyles = encryptionStyles ?? {};

  factory InformationSystemConfig.fromJson(Map<String, dynamic> json) {
    final styles = <String, EncryptionStyleConfig>{};
    final rawStyles = json['encryption_styles'] as Map<String, dynamic>?;
    if (rawStyles != null) {
      for (final entry in rawStyles.entries) {
        styles[entry.key] =
            EncryptionStyleConfig.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return InformationSystemConfig(encryptionStyles: styles);
  }
}

class InterCharAttitude {
  final String fromCharId;
  final String toCharId;
  double affinity;
  String label;
  String history;
  DateTime lastUpdated;
  bool isSecretAdmirer;
  String lastInteractionNote;
  InterCharAttitude({required this.fromCharId,required this.toCharId,this.affinity=0.0,this.label='',this.history='',DateTime? lastUpdated,bool? isSecretAdmirer,this.lastInteractionNote=''}):lastUpdated=lastUpdated??DateTime.now(),isSecretAdmirer=isSecretAdmirer??false;
  factory InterCharAttitude.fromJson(Map<String,dynamic> json)=>InterCharAttitude(fromCharId: json['from']??'',toCharId: json['to']??'',affinity: (json['affinity'] as num?)?.toDouble()??0.0,label: json['label']??'',history: json['history']??'',lastUpdated: json['last_updated'] != null ? DateTime.tryParse(json['last_updated']) : DateTime.now(),isSecretAdmirer: json['is_secret_admirer']??false,lastInteractionNote: json['last_interaction']??'');
  Map<String,dynamic> toJson()=>{'from':fromCharId,'to':toCharId,'affinity':affinity,'label':label,'history':history,'last_updated':lastUpdated.toIso8601String(),'is_secret_admirer':isSecretAdmirer,'last_interaction':lastInteractionNote};
}

class InformationFragment {
  final String id;
  final String sourceEventId;
  final String witnessCharId;
  final String content;
  final String encryption;
  final int spreadRadius;
  final List<String> knownBy;
  final DateTime createdAt;
  double trustworthiness;
  bool active;
  int spreadCount;
  InformationFragment({this.id='',this.sourceEventId='',this.witnessCharId='',this.content='',this.encryption='',this.spreadRadius=1,List<String>? knownBy,DateTime? createdAt,this.trustworthiness=1.0,this.active=true,this.spreadCount=0}):knownBy=knownBy??[],createdAt=createdAt??DateTime.now();
  factory InformationFragment.fromJson(Map<String,dynamic> json)=>InformationFragment(id: json['id']??'',sourceEventId: json['source_event']??'',witnessCharId: json['witness_char']??'',content: json['content']??'',encryption: json['encryption']??'',spreadRadius: json['spread_radius']??1,knownBy: List<String>.from(json['known_by']??[]),createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : DateTime.now(),trustworthiness: (json['trustworthiness'] as num?)?.toDouble()??1.0,active: json['active']??true,spreadCount: json['spread_count']??0);
  Map<String,dynamic> toJson()=>{'id':id,'source_event':sourceEventId,'witness_char':witnessCharId,'content':content,'encryption':encryption,'spread_radius':spreadRadius,'known_by':knownBy,'created_at':createdAt.toIso8601String(),'trustworthiness':trustworthiness,'active':active,'spread_count':spreadCount};
}

class ActionBoundaryRule {
  final List<String> keywords;
  final double minAffection;
  final String rejectionNarrative;
  final double affectionPenalty;

  ActionBoundaryRule({
    List<String>? keywords,
    this.minAffection = 100.0,
    this.rejectionNarrative = '',
    this.affectionPenalty = -5.0,
  }) : keywords = keywords ?? [];

  factory ActionBoundaryRule.fromJson(Map<String, dynamic> json) {
    return ActionBoundaryRule(
      keywords: List<String>.from(json['keywords'] ?? []),
      minAffection: (json['min_affection'] as num?)?.toDouble() ?? 100.0,
      rejectionNarrative: json['rejection_narrative'] ?? '',
      affectionPenalty: (json['affection_penalty'] as num?)?.toDouble() ?? -5.0,
    );
  }
}

class ActionRules {
  final List<ActionBoundaryRule> boundaryChecks;
  final double topicTabooPenalty;
  final String topicTabooRejection;

  ActionRules({
    List<ActionBoundaryRule>? boundaryChecks,
    this.topicTabooPenalty = -3.0,
    this.topicTabooRejection = '',
  }) : boundaryChecks = boundaryChecks ?? [];

  factory ActionRules.fromJson(Map<String, dynamic> json) {
    return ActionRules(
      boundaryChecks: (json['boundary_checks'] as List<dynamic>?)
              ?.map((e) => ActionBoundaryRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topicTabooPenalty: (json['topic_taboo_penalty'] as num?)?.toDouble() ?? -3.0,
      topicTabooRejection: json['topic_taboo_rejection'] ?? '',
    );
  }
}

class FallbackNarratives {
  final Map<String, List<String>> templates;

  FallbackNarratives({Map<String, List<String>>? templates})
      : templates = templates ?? {};

  factory FallbackNarratives.fromJson(Map<String, dynamic> json) {
    final map = <String, List<String>>{};
    json.forEach((key, value) {
      if (value is List) {
        map[key] = value.map((e) => e.toString()).toList();
      }
    });
    return FallbackNarratives(templates: map);
  }

  List<String> operator [](String key) => templates[key] ?? [];
}