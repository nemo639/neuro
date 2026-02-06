import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Test phases
enum WordRecallPhase { instructions, learning, distraction, immediateRecall, delayedRecall, recognition, completed }

class WordRecallTestScreen extends StatefulWidget {
  const WordRecallTestScreen({super.key});

  @override
  State<WordRecallTestScreen> createState() => _WordRecallTestScreenState();
}

class _WordRecallTestScreenState extends State<WordRecallTestScreen>
    with TickerProviderStateMixin {
  
  WordRecallPhase _currentPhase = WordRecallPhase.instructions;

  // Animation controllers
  late AnimationController _fadeController;
  final Random _random = Random();

  // ==================== WORD POOLS ====================
  // Based on CERAD Word List methodology with expanded pools
  // Words are categorized for balanced difficulty
  
  // Pool 1: Concrete Objects (High imageability)
  static const List<String> _concreteNouns = [
    'APPLE', 'CHAIR', 'WINDOW', 'FLOWER', 'BRIDGE', 'CANDLE', 'GARDEN', 'CLOCK',
    'RIVER', 'FOREST', 'BOTTLE', 'PENCIL', 'MIRROR', 'PILLOW', 'BASKET', 'LADDER',
    'BUTTON', 'CARPET', 'FEATHER', 'HAMMER', 'KITCHEN', 'LETTER', 'MONKEY', 'NEEDLE',
    'ORANGE', 'PALACE', 'RABBIT', 'SADDLE', 'TEMPLE', 'VALLEY', 'WALLET', 'ANCHOR',
    'BARREL', 'CASTLE', 'DONKEY', 'ENGINE', 'FINGER', 'GUITAR', 'ISLAND', 'JACKET',
    'KETTLE', 'LEMON', 'MARKET', 'NAPKIN', 'OYSTER', 'PEPPER', 'RIBBON', 'SAUCER',
    'TIGER', 'UMBRELLA', 'VIOLIN', 'WAGON', 'ZEBRA', 'BRANCH', 'CAMERA', 'DRAGON',
    'FALCON', 'GLOVE', 'HELMET', 'INSECT', 'JUNGLE', 'KERNEL', 'LANTERN', 'MARBLE',
  ];

  // Pool 2: Abstract Concepts (Lower imageability - harder)
  static const List<String> _abstractNouns = [
    'PEACE', 'TRUTH', 'FREEDOM', 'JUSTICE', 'COURAGE', 'WISDOM', 'BEAUTY', 'HONOR',
    'PRIDE', 'MERCY', 'FAITH', 'HOPE', 'LOVE', 'GRACE', 'SPIRIT', 'DREAM',
    'MOTION', 'THEORY', 'REASON', 'METHOD', 'SYSTEM', 'PATTERN', 'MOMENT', 'CHANCE',
    'DANGER', 'SECRET', 'MEMORY', 'SILENCE', 'SHADOW', 'WONDER', 'TALENT', 'EFFORT',
  ];

  // Pool 3: Action Words (Verbs as nouns)
  static const List<String> _actionWords = [
    'DANCE', 'SPEECH', 'FIGHT', 'SLEEP', 'LAUGH', 'SMILE', 'TRAVEL', 'SEARCH',
    'ATTACK', 'RESCUE', 'ESCAPE', 'JOURNEY', 'BATTLE', 'PROTEST', 'PARADE', 'CONCERT',
  ];

  // Pool 4: Nature Words
  static const List<String> _natureWords = [
    'SUNSET', 'MOUNTAIN', 'OCEAN', 'THUNDER', 'LIGHTNING', 'RAINBOW', 'VOLCANO', 'GLACIER',
    'DESERT', 'MEADOW', 'CANYON', 'WATERFALL', 'SUNRISE', 'BREEZE', 'STORM', 'FROST',
    'CORAL', 'PEBBLE', 'BAMBOO', 'WILLOW', 'MAPLE', 'ORCHID', 'DAISY', 'LOTUS',
  ];

  // Pool 5: Household Items
  static const List<String> _householdWords = [
    'BLANKET', 'CURTAIN', 'DRAWER', 'FAUCET', 'CABINET', 'CUSHION', 'DOORBELL', 'FREEZER',
    'HANGER', 'IRONING', 'MATTRESS', 'OVEN', 'PLATTER', 'REMOTE', 'SPEAKER', 'TOASTER',
  ];

  // Pool 6: Food Items
  static const List<String> _foodWords = [
    'BUTTER', 'CHEESE', 'COOKIE', 'GINGER', 'HONEY', 'MANGO', 'PASTA', 'SALMON',
    'SPINACH', 'TOMATO', 'VANILLA', 'WALNUT', 'YOGURT', 'GARLIC', 'CARROT', 'CELERY',
  ];

  // Distractor words (for recognition phase - similar but not shown)
  static const List<String> _distractorPool = [
    'PEAR', 'TABLE', 'DOOR', 'TREE', 'ROAD', 'LAMP', 'PARK', 'WATCH',
    'LAKE', 'WOODS', 'JAR', 'PAPER', 'GLASS', 'SHEET', 'BOX', 'STAIR',
    'COIN', 'RUG', 'BIRD', 'TOOL', 'ROOM', 'NOTE', 'APE', 'PIN',
    'GRAPE', 'TOWER', 'HORSE', 'TRAIN', 'FARM', 'PLANT', 'BEACH', 'BREAD',
    'SILVER', 'GOLDEN', 'COPPER', 'IRON', 'STEEL', 'BRONZE', 'CHROME', 'NICKEL',
  ];

  // ==================== PARALLEL FORMS ====================
  // 3 equivalent forms (A, B, C) for repeated testing without practice effects
  // Each form has preset word indices for reproducibility in research
  
  static const Map<String, List<int>> _parallelForms = {
    'A': [0, 5, 12, 18, 25, 32, 40, 48, 55, 3, 8, 15, 22, 30, 38],
    'B': [1, 6, 13, 19, 26, 33, 41, 49, 56, 4, 9, 16, 23, 31, 39],
    'C': [2, 7, 14, 20, 27, 34, 42, 50, 57, 5, 10, 17, 24, 32, 40],
  };

  // ==================== TEST CONFIGURATION ====================
  
  // Current test words (randomly selected and shuffled)
  List<String> _currentWordList = [];
  List<String> _distractorWords = [];
  String _currentForm = 'RANDOM'; // 'A', 'B', 'C', or 'RANDOM'
  
  // Word display settings
  final int _wordsToShow = 15; // Standard CERAD uses 10, we use 15 for more data
  final int _displayTimePerWord = 2; // seconds per word
  int _currentWordIndex = 0;
  int _learningTrial = 1; // CERAD has 3 learning trials
  final int _totalLearningTrials = 3;
  
  // Trial results (for learning curve analysis)
  List<List<String>> _trialRecalls = []; // Words recalled in each trial
  
  // Distraction phase
  final int _distractionDuration = 60; // seconds (longer delay = harder)
  int _distractionTimeLeft = 60;
  int _countdownNumber = 100;
  final List<Map<String, dynamic>> _countdownResponses = [];// {expected, actual}
  Timer? _countdownTimer;
  final TextEditingController _countdownController = TextEditingController();

  // Immediate Recall phase
  final TextEditingController _recallController = TextEditingController();
  List<String> _recalledWords = [];
  final int _recallTimeLimit = 90; // seconds
  int _recallTimeLeft = 90;
  Timer? _recallTimer;

  // Delayed Recall (after distraction)
  List<String> _delayedRecalledWords = [];

  // Recognition phase
  List<Map<String, dynamic>> _recognitionItems = [];
  int _currentRecognitionIndex = 0;
  List<Map<String, dynamic>> _recognitionResponses = [];

  // Timers
  Timer? _wordTimer;
  Timer? _distractionTimer;

  // Timestamps for response time analysis
  DateTime? _recallStartTime;
  List<DateTime> _wordRecallTimes = [];

  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color greenAccent = Color(0xFF10B981);
  static const Color redAccent = Color(0xFFEF4444);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color tealAccent = Color(0xFF14B8A6);
  static const Color orangeAccent = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Generate randomized word list on init
    _generateWordList();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ==================== WORD LIST GENERATION ====================
  
  void _generateWordList() {
    if (_currentForm == 'RANDOM') {
      _generateRandomWordList();
    } else {
      _generateParallelFormList(_currentForm);
    }
    _generateDistractorList();
  }

  void _generateRandomWordList() {
    // Create master pool with category labels
    List<Map<String, String>> masterPool = [];
    
    for (var word in _concreteNouns) {
      masterPool.add({'word': word, 'category': 'concrete'});
    }
    for (var word in _abstractNouns) {
      masterPool.add({'word': word, 'category': 'abstract'});
    }
    for (var word in _actionWords) {
      masterPool.add({'word': word, 'category': 'action'});
    }
    for (var word in _natureWords) {
      masterPool.add({'word': word, 'category': 'nature'});
    }
    for (var word in _householdWords) {
      masterPool.add({'word': word, 'category': 'household'});
    }
    for (var word in _foodWords) {
      masterPool.add({'word': word, 'category': 'food'});
    }

    // Shuffle master pool
    masterPool.shuffle(_random);

    // Select words with balanced categories
    // Aim for: 5 concrete, 3 abstract, 2 action, 2 nature, 2 household, 1 food
    Map<String, int> categoryTargets = {
      'concrete': 5,
      'abstract': 3,
      'action': 2,
      'nature': 2,
      'household': 2,
      'food': 1,
    };

    Map<String, int> categoryCount = {
      'concrete': 0,
      'abstract': 0,
      'action': 0,
      'nature': 0,
      'household': 0,
      'food': 0,
    };

    _currentWordList = [];

    // First pass: fill category targets
    for (var item in masterPool) {
      String cat = item['category']!;
      if (categoryCount[cat]! < categoryTargets[cat]! && _currentWordList.length < _wordsToShow) {
        _currentWordList.add(item['word']!);
        categoryCount[cat] = categoryCount[cat]! + 1;
      }
    }

    // Second pass: fill remaining slots with any words
    for (var item in masterPool) {
      if (_currentWordList.length >= _wordsToShow) break;
      if (!_currentWordList.contains(item['word'])) {
        _currentWordList.add(item['word']!);
      }
    }

    // Final shuffle for presentation order
    _currentWordList.shuffle(_random);
  }

  void _generateParallelFormList(String form) {
    List<String> allWords = [
      ..._concreteNouns,
      ..._abstractNouns,
      ..._actionWords,
      ..._natureWords,
      ..._householdWords,
      ..._foodWords,
    ];

    List<int> indices = _parallelForms[form] ?? _parallelForms['A']!;
    _currentWordList = indices.map((i) => allWords[i % allWords.length]).toList();
    
    // Shuffle within form for presentation order randomization
    _currentWordList.shuffle(_random);
  }

  void _generateDistractorList() {
    // Create distractors: mix of pool distractors and semantically similar words
    List<String> allDistractors = [..._distractorPool];
    
    // Add some words from unused pools to increase difficulty
    List<String> allWords = [
      ..._concreteNouns,
      ..._abstractNouns,
      ..._actionWords,
      ..._natureWords,
      ..._householdWords,
      ..._foodWords,
    ];
    
    for (var word in allWords) {
      if (!_currentWordList.contains(word) && !allDistractors.contains(word)) {
        allDistractors.add(word);
      }
    }

    allDistractors.shuffle(_random);
    _distractorWords = allDistractors.take(_wordsToShow).toList();
  }

  void _prepareRecognitionPhase() {
    _recognitionItems = [];
    
    // Add all target words (correct answers = YES)
    for (var word in _currentWordList) {
      _recognitionItems.add({
        'word': word,
        'isTarget': true,
      });
    }
    
    // Add equal number of distractors (correct answers = NO)
    for (var word in _distractorWords) {
      _recognitionItems.add({
        'word': word,
        'isTarget': false,
      });
    }
    
    // Shuffle all items
    _recognitionItems.shuffle(_random);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _wordTimer?.cancel();
    _distractionTimer?.cancel();
    _countdownTimer?.cancel();
    _recallTimer?.cancel();
    _countdownController.dispose();
    _recallController.dispose();
    super.dispose();
  }

  // ==================== PHASE TRANSITIONS ====================

  void _startLearning() {
    setState(() {
      _currentPhase = WordRecallPhase.learning;
      _currentWordIndex = 0;
      _learningTrial = 1;
      _trialRecalls = [];
    });
    _showNextWord();
  }

  void _showNextWord() {
    if (_currentWordIndex >= _currentWordList.length) {
      // Done showing words for this trial, start immediate recall
      _startImmediateRecall();
      return;
    }

    _fadeController.forward(from: 0);

    _wordTimer = Timer(Duration(seconds: _displayTimePerWord), () {
      setState(() {
        _currentWordIndex++;
      });
      _showNextWord();
    });
  }

  void _startImmediateRecall() {
    setState(() {
      _currentPhase = WordRecallPhase.immediateRecall;
      _recallTimeLeft = _recallTimeLimit;
      _recalledWords = [];
      _recallStartTime = DateTime.now();
      _wordRecallTimes = [];
    });

    _recallTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recallTimeLeft--;
      });

      if (_recallTimeLeft <= 0) {
        timer.cancel();
        _completeImmediateRecall();
      }
    });
  }

  void _completeImmediateRecall() {
    _recallTimer?.cancel();
    
    // Save this trial's results
    _trialRecalls.add(List.from(_recalledWords));
    
    if (_learningTrial < _totalLearningTrials) {
      // More learning trials - re-show words
      setState(() {
        _learningTrial++;
        _currentWordIndex = 0;
        _currentPhase = WordRecallPhase.learning;
      });
      
      // Re-shuffle word order for next trial
      _currentWordList.shuffle(_random);
      
      // Short delay before next trial
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showNextWord();
      });
    } else {
      // All trials complete - start distraction
      _startDistraction();
    }
  }

  void _startDistraction() {
    setState(() {
      _currentPhase = WordRecallPhase.distraction;
      _distractionTimeLeft = _distractionDuration;
      _countdownNumber = 100;
      _countdownResponses.clear();
    });

    _distractionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _distractionTimeLeft--;
      });

      if (_distractionTimeLeft <= 0) {
        timer.cancel();
        _startDelayedRecall();
      }
    });
  }

  void _handleCountdownSubmit() {
    final input = int.tryParse(_countdownController.text);
    if (input != null) {
      final expected = _countdownNumber - 7;
      _countdownResponses.add({
        'expected': expected,
        'actual': input,
        'correct': input == expected,
      });
      _countdownController.clear();
      setState(() {
        _countdownNumber = input; // Use their answer as next starting point
        if (_countdownNumber < 0) _countdownNumber = 0;
      });
    }
  }

  void _startDelayedRecall() {
    setState(() {
      _currentPhase = WordRecallPhase.delayedRecall;
      _recallTimeLeft = _recallTimeLimit;
      _delayedRecalledWords = [];
      _recallStartTime = DateTime.now();
      _wordRecallTimes = [];
    });

    _recallTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recallTimeLeft--;
      });

      if (_recallTimeLeft <= 0) {
        timer.cancel();
        _startRecognition();
      }
    });
  }

  void _handleWordSubmit({bool isDelayed = false}) {
    final word = _recallController.text.trim().toUpperCase();
    if (word.isNotEmpty) {
      final targetList = isDelayed ? _delayedRecalledWords : _recalledWords;
      if (!targetList.contains(word)) {
        setState(() {
          targetList.add(word);
          _wordRecallTimes.add(DateTime.now());
        });
        HapticFeedback.lightImpact();
      }
      _recallController.clear();
    }
  }

  void _removeWord(String word, {bool isDelayed = false}) {
    setState(() {
      if (isDelayed) {
        _delayedRecalledWords.remove(word);
      } else {
        _recalledWords.remove(word);
      }
    });
  }

  void _completeDelayedRecall() {
    _recallTimer?.cancel();
    _startRecognition();
  }

  void _startRecognition() {
    _prepareRecognitionPhase();
    setState(() {
      _currentPhase = WordRecallPhase.recognition;
      _currentRecognitionIndex = 0;
      _recognitionResponses = [];
    });
  }

  void _handleRecognitionResponse(bool response) {
    final item = _recognitionItems[_currentRecognitionIndex];
    _recognitionResponses.add({
      'word': item['word'],
      'isTarget': item['isTarget'],
      'response': response,
      'correct': response == item['isTarget'],
      'timestamp': DateTime.now().toIso8601String(),
    });

    HapticFeedback.lightImpact();

    setState(() {
      _currentRecognitionIndex++;
    });

    if (_currentRecognitionIndex >= _recognitionItems.length) {
      _completeTest();
    }
  }

  void _completeTest() {
    setState(() {
      _currentPhase = WordRecallPhase.completed;
    });
  }

  // ==================== DATA COLLECTION ====================

  Map<String, dynamic> _getTestData() {
    // Immediate recall analysis (last trial)
    final lastTrialRecall = _trialRecalls.isNotEmpty ? _trialRecalls.last : <String>[];
    final immediateCorrect = lastTrialRecall.where((w) => _currentWordList.contains(w)).toList();
    final immediateIntrusions = lastTrialRecall.where((w) => !_currentWordList.contains(w)).toList();
    
    // Delayed recall analysis
    final delayedCorrect = _delayedRecalledWords.where((w) => _currentWordList.contains(w)).toList();
    final delayedIntrusions = _delayedRecalledWords.where((w) => !_currentWordList.contains(w)).toList();
    
    // Recognition analysis
    final recognitionHits = _recognitionResponses.where((r) => r['isTarget'] == true && r['response'] == true).length;
    final recognitionMisses = _recognitionResponses.where((r) => r['isTarget'] == true && r['response'] == false).length;
    final recognitionFalseAlarms = _recognitionResponses.where((r) => r['isTarget'] == false && r['response'] == true).length;
    final recognitionCorrectRejections = _recognitionResponses.where((r) => r['isTarget'] == false && r['response'] == false).length;
    
    // Calculate recognition discriminability (d')
    double hitRate = recognitionHits / _currentWordList.length;
    double faRate = recognitionFalseAlarms / _distractorWords.length;
    
    // Avoid infinite d' values
    hitRate = hitRate.clamp(0.01, 0.99);
    faRate = faRate.clamp(0.01, 0.99);
    
    // Learning curve (improvement across trials)
    List<int> trialScores = _trialRecalls.map((trial) => 
      trial.where((w) => _currentWordList.contains(w)).length
    ).toList();
    
    // Savings score (delayed vs immediate retention)
    double retentionRate = immediateCorrect.isNotEmpty 
      ? delayedCorrect.length / immediateCorrect.length 
      : 0;
    
    // Distraction task accuracy
    int correctCountdowns = _countdownResponses.where((r) => r['correct'] == true).length;
    double distractionAccuracy = _countdownResponses.isNotEmpty 
      ? correctCountdowns / _countdownResponses.length 
      : 0;

    return {
      'test_type': 'word_recall',
      'form_used': _currentForm,
      'timestamp': DateTime.now().toIso8601String(),
      
      // Word list info
      'words_shown': _currentWordList,
      'distractor_words': _distractorWords,
      'total_words': _currentWordList.length,
      
      // Learning trials
      'learning_trials': _totalLearningTrials,
      'trial_recalls': _trialRecalls,
      'trial_scores': trialScores,
      'learning_curve': trialScores,
      
      // Immediate recall (last trial)
      'immediate_recall': {
        'words_recalled': lastTrialRecall,
        'correct_words': immediateCorrect,
        'intrusion_errors': immediateIntrusions,
        'correct_count': immediateCorrect.length,
        'accuracy': immediateCorrect.length / _currentWordList.length,
        'intrusion_count': immediateIntrusions.length,
      },
      
      // Delayed recall
      'delayed_recall': {
        'words_recalled': _delayedRecalledWords,
        'correct_words': delayedCorrect,
        'intrusion_errors': delayedIntrusions,
        'correct_count': delayedCorrect.length,
        'accuracy': delayedCorrect.length / _currentWordList.length,
        'intrusion_count': delayedIntrusions.length,
        'delay_duration_seconds': _distractionDuration,
      },
      
      // Recognition
      'recognition': {
        'responses': _recognitionResponses,
        'hits': recognitionHits,
        'misses': recognitionMisses,
        'false_alarms': recognitionFalseAlarms,
        'correct_rejections': recognitionCorrectRejections,
        'hit_rate': hitRate,
        'false_alarm_rate': faRate,
        'accuracy': (recognitionHits + recognitionCorrectRejections) / _recognitionItems.length,
        'discriminability': _calculateDPrime(hitRate, faRate),
      },
      
      // Composite scores
      'retention_rate': retentionRate,
      'recall_accuracy': immediateCorrect.length / _currentWordList.length,
      'delayed_recall_accuracy': delayedCorrect.length / _currentWordList.length,
      'recognition_accuracy': (recognitionHits + recognitionCorrectRejections) / _recognitionItems.length,
      
      // Distraction task
      'distraction_task': {
        'responses': _countdownResponses,
        'correct_count': correctCountdowns,
        'total_responses': _countdownResponses.length,
        'accuracy': distractionAccuracy,
      },
      
      // Validity indicators
      'validity_indicators': {
        'completed_all_phases': true,
        'recognition_above_chance': (recognitionHits + recognitionCorrectRejections) / _recognitionItems.length > 0.6,
        'recall_less_than_recognition': immediateCorrect.length <= recognitionHits,
        'intrusion_rate': immediateIntrusions.length / (immediateCorrect.length + immediateIntrusions.length + 0.001),
      },
      
      'completed': true,
    };
  }

  double _calculateDPrime(double hitRate, double faRate) {
    // Z-score approximation using inverse normal
    double zHit = _inverseNormal(hitRate);
    double zFa = _inverseNormal(faRate);
    return zHit - zFa;
  }

  double _inverseNormal(double p) {
    // Approximation of inverse normal (probit) function
    // Using Abramowitz and Stegun approximation
    if (p <= 0) return -3.0;
    if (p >= 1) return 3.0;
    
    double t = sqrt(-2 * log(p < 0.5 ? p : 1 - p));
    double c0 = 2.515517;
    double c1 = 0.802853;
    double c2 = 0.010328;
    double d1 = 1.432788;
    double d2 = 0.189269;
    double d3 = 0.001308;
    
    double z = t - (c0 + c1 * t + c2 * t * t) / (1 + d1 * t + d2 * t * t + d3 * t * t * t);
    
    return p < 0.5 ? -z : z;
  }

  void _finishTest() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context, _getTestData());
  }

  void _exitTest() {
    _wordTimer?.cancel();
    _distractionTimer?.cancel();
    _recallTimer?.cancel();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Test?'),
        content: const Text('Your progress will be lost. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: redAccent)),
          ),
        ],
      ),
    );
  }

  // ==================== UI BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitTest,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Word List Recall',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(
                  _getPhaseText(),
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (_currentPhase == WordRecallPhase.learning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Trial $_learningTrial/$_totalLearningTrials',
                style: const TextStyle(
                  color: orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getPhaseText() {
    switch (_currentPhase) {
      case WordRecallPhase.instructions:
        return 'Read instructions carefully';
      case WordRecallPhase.learning:
        return 'Memorize each word (Trial $_learningTrial)';
      case WordRecallPhase.distraction:
        return 'Count backwards by 7';
      case WordRecallPhase.immediateRecall:
        return 'Type all words you remember';
      case WordRecallPhase.delayedRecall:
        return 'Recall words again';
      case WordRecallPhase.recognition:
        return 'Did you see this word?';
      case WordRecallPhase.completed:
        return 'Test completed';
    }
  }

  Widget _buildProgressBar() {
    double progress = 0;
    switch (_currentPhase) {
      case WordRecallPhase.instructions:
        progress = 0;
        break;
      case WordRecallPhase.learning:
        double trialProgress = (_learningTrial - 1) / _totalLearningTrials;
        double wordProgress = _currentWordIndex / _currentWordList.length / _totalLearningTrials;
        progress = 0.05 + (trialProgress + wordProgress) * 0.25;
        break;
      case WordRecallPhase.immediateRecall:
        progress = 0.30 + ((_learningTrial - 1) / _totalLearningTrials * 0.15);
        break;
      case WordRecallPhase.distraction:
        progress = 0.45 + ((1 - _distractionTimeLeft / _distractionDuration) * 0.15);
        break;
      case WordRecallPhase.delayedRecall:
        progress = 0.60 + ((1 - _recallTimeLeft / _recallTimeLimit) * 0.15);
        break;
      case WordRecallPhase.recognition:
        progress = 0.75 + (_currentRecognitionIndex / _recognitionItems.length * 0.20);
        break;
      case WordRecallPhase.completed:
        progress = 1.0;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 6,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0, 1),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [tealAccent, greenAccent]),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildPhaseContent(),
    );
  }

  Widget _buildPhaseContent() {
    switch (_currentPhase) {
      case WordRecallPhase.instructions:
        return _buildInstructionsPhase();
      case WordRecallPhase.learning:
        return _buildLearningPhase();
      case WordRecallPhase.immediateRecall:
        return _buildRecallPhase(isDelayed: false);
      case WordRecallPhase.distraction:
        return _buildDistractionPhase();
      case WordRecallPhase.delayedRecall:
        return _buildRecallPhase(isDelayed: true);
      case WordRecallPhase.recognition:
        return _buildRecognitionPhase();
      case WordRecallPhase.completed:
        return _buildCompletedPhase();
    }
  }

  Widget _buildInstructionsPhase() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded, color: tealAccent, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Word List Memory Test',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on CERAD Word List Protocol',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softLavender.withOpacity(0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _buildInstructionStep('1', 'You will see $_wordsToShow words, one at a time'),
                const SizedBox(height: 8),
                _buildInstructionStep('2', 'Try to memorize each word'),
                const SizedBox(height: 8),
                _buildInstructionStep('3', 'Recall words → 3 learning trials'),
                const SizedBox(height: 8),
                _buildInstructionStep('4', 'Count backwards (distraction task)'),
                const SizedBox(height: 8),
                _buildInstructionStep('5', 'Recall words again (delayed recall)'),
                const SizedBox(height: 8),
                _buildInstructionStep('6', 'Recognition: "Did you see this word?"'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: tealAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Each test uses randomized words',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: Colors.grey[500], size: 18),
              const SizedBox(width: 6),
              Text(
                'Total time: ~8-10 minutes',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _startLearning,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: tealAccent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: tealAccent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Start Test',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: tealAccent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ),
      ],
    );
  }

  Widget _buildLearningPhase() {
    if (_currentWordIndex >= _currentWordList.length) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: tealAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Word ${_currentWordIndex + 1} of ${_currentWordList.length}',
                style: const TextStyle(
                  color: tealAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: orangeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Trial $_learningTrial',
                style: const TextStyle(
                  color: orangeAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        FadeTransition(
          opacity: _fadeController,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tealAccent.withOpacity(0.3), width: 2),
            ),
            child: Text(
              _currentWordList[_currentWordIndex],
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        const Spacer(),
        Text(
          'Memorize this word',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        // Progress dots
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: List.generate(
            _currentWordList.length,
            (index) => Container(
              width: index == _currentWordIndex ? 10 : 6,
              height: index == _currentWordIndex ? 10 : 6,
              decoration: BoxDecoration(
                color: index <= _currentWordIndex ? tealAccent : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDistractionPhase() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: purpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: purpleAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${_distractionTimeLeft}s remaining',
                  style: const TextStyle(
                    color: purpleAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Count backwards by 7',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'What comes next?',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Text(
            '$_countdownNumber',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: purpleAccent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '- 7 = ?',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: TextField(
              controller: _countdownController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Your answer',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: purpleAccent, width: 2),
                ),
              ),
              onSubmitted: (_) => _handleCountdownSubmit(),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _handleCountdownSubmit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                color: purpleAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Text(
                  'This keeps your mind busy before recall',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecallPhase({required bool isDelayed}) {
    final recalledWords = isDelayed ? _delayedRecalledWords : _recalledWords;
    final phaseColor = isDelayed ? orangeAccent : tealAccent;
    final phaseTitle = isDelayed ? 'Delayed Recall' : 'Immediate Recall';
    
    return Column(
      children: [
        // Header with timer and count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: redAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_recallTimeLeft}s',
                    style: const TextStyle(
                      color: redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: phaseColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                phaseTitle,
                style: TextStyle(
                  color: phaseColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: greenAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${recalledWords.length} words',
                style: const TextStyle(
                  color: greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _recallController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Type a word...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: phaseColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _handleWordSubmit(isDelayed: isDelayed),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _handleWordSubmit(isDelayed: isDelayed),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: phaseColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Recalled words
        Expanded(
          child: recalledWords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.text_fields, color: Colors.grey[300], size: 40),
                      const SizedBox(height: 10),
                      Text(
                        'Type all words you remember',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recalledWords.map((word) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              word,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _removeWord(word, isDelayed: isDelayed),
                              child: Icon(Icons.close, size: 16, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        
        // Done button
        GestureDetector(
          onTap: isDelayed ? _completeDelayedRecall : _completeImmediateRecall,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'Done Recalling',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecognitionPhase() {
    if (_currentRecognitionIndex >= _recognitionItems.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final item = _recognitionItems[_currentRecognitionIndex];
    final word = item['word'] as String;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: blueAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_currentRecognitionIndex + 1} of ${_recognitionItems.length}',
            style: const TextStyle(
              color: blueAccent,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'Did you see this word?',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: blueAccent.withOpacity(0.3), width: 2),
          ),
          child: Text(
            word,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: 2,
            ),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _handleRecognitionResponse(false),
              child: Container(
                width: 100,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: redAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.close, color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text(
                      'NO',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 30),
            GestureDetector(
              onTap: () => _handleRecognitionResponse(true),
              child: Container(
                width: 100,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: greenAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text(
                      'YES',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCompletedPhase() {
    final data = _getTestData();
    final immediate = data['immediate_recall'] as Map<String, dynamic>;
    final delayed = data['delayed_recall'] as Map<String, dynamic>;
    final recognition = data['recognition'] as Map<String, dynamic>;
    
    final immediateAcc = ((immediate['accuracy'] as double) * 100).toStringAsFixed(0);
    final delayedAcc = ((delayed['accuracy'] as double) * 100).toStringAsFixed(0);
    final recognitionAcc = ((recognition['accuracy'] as double) * 100).toStringAsFixed(0);
    final retentionRate = ((data['retention_rate'] as double) * 100).toStringAsFixed(0);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: greenAccent, size: 45),
          ),
          const SizedBox(height: 16),
          const Text(
            'Test Completed!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          
          // Results summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: mintGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildResultRow('Immediate Recall', '$immediateAcc%', immediate['correct_count'], _currentWordList.length),
                const Divider(height: 16),
                _buildResultRow('Delayed Recall', '$delayedAcc%', delayed['correct_count'], _currentWordList.length),
                const Divider(height: 16),
                _buildResultRow('Recognition', '$recognitionAcc%', recognition['hits'] + recognition['correct_rejections'], _recognitionItems.length),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Retention Rate', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: int.parse(retentionRate) >= 70 ? greenAccent.withOpacity(0.2) : orangeAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$retentionRate%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: int.parse(retentionRate) >= 70 ? greenAccent : orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Learning curve
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learning Curve',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_trialRecalls.length, (i) {
                    final score = _trialRecalls[i].where((w) => _currentWordList.contains(w)).length;
                    return Column(
                      children: [
                        Text(
                          'Trial ${i + 1}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tealAccent.withOpacity(0.1 + (i * 0.1)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$score/${_currentWordList.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tealAccent,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Validity indicator
          if (data['validity_indicators'] != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (data['validity_indicators']['recognition_above_chance'] == true)
                    ? greenAccent.withOpacity(0.1)
                    : redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (data['validity_indicators']['recognition_above_chance'] == true)
                        ? Icons.verified
                        : Icons.warning_amber,
                    size: 16,
                    color: (data['validity_indicators']['recognition_above_chance'] == true)
                        ? greenAccent
                        : redAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    (data['validity_indicators']['recognition_above_chance'] == true)
                        ? 'Valid performance'
                        : 'Review validity',
                    style: TextStyle(
                      fontSize: 12,
                      color: (data['validity_indicators']['recognition_above_chance'] == true)
                          ? greenAccent
                          : redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          
          GestureDetector(
            onTap: _finishTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: greenAccent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Continue', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String percentage, int correct, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            Text('$correct / $total words', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        Text(percentage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}