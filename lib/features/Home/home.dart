import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/cache_service.dart';
import 'package:neuroverse/core/main_shell.dart';
import 'package:neuroverse/core/shimmer_loading.dart';
import 'package:neuroverse/core/notification_service.dart';
import 'package:neuroverse/core/responsive.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pageController;
  late PageController _tipsPageController;
  int _currentTipIndex = 0;

  // State variables
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _wellnessData;
  int _adRisk = 0;
  int _pdRisk = 0;
  int _overallRisk = 0;
  String _riskLevel = 'Low';
  double _screenTime = 0;
  double _gamingHours = 0;
  double _socialHours = 0;
  int _notificationCount = 0;
  double _avgScreenTime = 0;
  List<dynamic> _recentTests = [];
  List<dynamic> _riskTrend = []; // Per-session risk data for trend chart
  String _trendCategory = 'All'; // Filter for trend chart

  // Weekly data (loaded from API)
  List<double> _weeklyScreenTime = [0, 0, 0, 0, 0, 0, 0];
  List<String> _weeklyLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Notifications/Alerts
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  // User profile
  String? _profileImagePath;
  String _userInitial = 'U';
  String _userName = '';
  int _streak = 0;
  DateTime? _lastBackPressTime;
  int _totalTestsCompleted = 0;
  int _testsThisWeek = 0;

  // Health tips pool (10 total, 7 shown each session with 4 shuffled + 3 fixed)
  static final List<Map<String, dynamic>> _allHealthTips = [
    {
      'title': 'Brain-Boosting Foods',
      'desc': 'Blueberries, salmon & walnuts improve cognitive function by up to 25%',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFF7C6AEF),
    },
    {
      'title': 'Sleep & Memory',
      'desc': '7-9 hours of quality sleep consolidates memories and clears brain toxins',
      'icon': Icons.bedtime_rounded,
      'color': const Color(0xFF10B981),
    },
    {
      'title': 'Exercise Your Brain',
      'desc': '30 min daily aerobic exercise reduces dementia risk by 30%',
      'icon': Icons.directions_run_rounded,
      'color': const Color(0xFFF59E0B),
    },
    {
      'title': 'Social Connection',
      'desc': 'Regular social interaction slows cognitive decline & boosts mental health',
      'icon': Icons.people_rounded,
      'color': const Color(0xFFEC4899),
    },
    {
      'title': 'Mindful Meditation',
      'desc': '10 min daily meditation increases grey matter and reduces stress hormones',
      'icon': Icons.self_improvement_rounded,
      'color': const Color(0xFF06B6D4),
    },
    {
      'title': 'Stay Hydrated',
      'desc': 'Dehydration impairs attention and memory. Aim for 8 glasses of water daily',
      'icon': Icons.water_drop_rounded,
      'color': const Color(0xFF3B82F6),
    },
    {
      'title': 'Learn Something New',
      'desc': 'Learning a new skill builds neural pathways and strengthens brain resilience',
      'icon': Icons.school_rounded,
      'color': const Color(0xFF8B5CF6),
    },
    {
      'title': 'Limit Screen Time',
      'desc': 'Excessive screen time linked to cognitive fatigue. Take 5-min breaks every hour',
      'icon': Icons.phone_android_rounded,
      'color': const Color(0xFFEF4444),
    },
    {
      'title': 'Omega-3 Fatty Acids',
      'desc': 'Fish oil and flaxseed reduce brain inflammation and support neuron health',
      'icon': Icons.local_pharmacy_rounded,
      'color': const Color(0xFF14B8A6),
    },
    {
      'title': 'Music Therapy',
      'desc': 'Listening to music activates multiple brain regions and improves mood & memory',
      'icon': Icons.music_note_rounded,
      'color': const Color(0xFFD946EF),
    },
  ];

  // First 3 tips are always shown (fixed), remaining 4 are randomly picked
  late List<Map<String, dynamic>> _healthTips;

  void _shuffleHealthTips() {
    // First 3 always shown as "anchor" tips
    final fixed = _allHealthTips.sublist(0, 3);
    // Remaining 7 tips — shuffle and pick 4
    final pool = List<Map<String, dynamic>>.from(_allHealthTips.sublist(3))..shuffle();
    final randomPick = pool.take(4).toList();
    // Combine: 3 fixed + 4 shuffled = 7 shown
    _healthTips = [...fixed, ...randomPick];
  }


  // Design colors
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color navBg = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _tipsPageController = PageController(viewportFraction: 0.85);
    _shuffleHealthTips();
    _loadData();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tipsPageController.dispose();
    super.dispose();
  }

  void _applyDashboardData(Map<String, dynamic> data) {
    final dashResult = data['dash'] as Map<String, dynamic>? ?? {};
    final wellnessResult = data['wellness'] as Map<String, dynamic>? ?? {};
    final historyResult = data['history'] as Map<String, dynamic>? ?? {};
    final profileResult = data['profile'] as Map<String, dynamic>? ?? {};

    if (profileResult['success'] == true) {
      final pData = profileResult['data'];
      _profileImagePath = pData['profile_image_path']?.toString();
      final fn = pData['first_name']?.toString() ?? '';
      _userName = fn;
      _userInitial = fn.isNotEmpty ? fn[0].toUpperCase() : 'U';
    }

    if (dashResult['success'] == true) {
      _dashboardData = dashResult['data'];
      _adRisk = (_dashboardData?['ad_risk_score'] ?? 0).toInt();
      _pdRisk = (_dashboardData?['pd_risk_score'] ?? 0).toInt();
      _overallRisk = ((_adRisk + _pdRisk) / 2).toInt();
      _riskLevel = _getRiskLevel(_overallRisk);
      final allCats = _dashboardData?['categories'] as List<dynamic>? ?? [];
      _recentTests = allCats
          .where((t) => (t['category'] ?? '').toString().toLowerCase() != 'gait')
          .toList()
        ..sort((a, b) {
          final aCompleted = (a['tests_completed'] ?? 0) as int;
          final bCompleted = (b['tests_completed'] ?? 0) as int;
          if (aCompleted > 0 && bCompleted == 0) return -1;
          if (aCompleted == 0 && bCompleted > 0) return 1;
          final aDate = a['last_tested']?.toString() ?? '';
          final bDate = b['last_tested']?.toString() ?? '';
          return bDate.compareTo(aDate);
        });
      _riskTrend = _dashboardData?['risk_trend'] ?? [];
      _totalTestsCompleted = (_dashboardData?['total_tests_completed'] ?? 0) as int;
      _testsThisWeek = (_dashboardData?['tests_this_week'] ?? 0) as int;
    }

    if (wellnessResult['success'] == true) {
      _wellnessData = wellnessResult['data'];
      final today = _wellnessData?['today_entry'];
      _screenTime = (today?['screen_time_hours'] ?? 0).toDouble();
      _gamingHours = (today?['gaming_hours'] ?? 0).toDouble();
      _socialHours = _screenTime * 0.35;
      _notificationCount = (_screenTime * 12).toInt();
      _avgScreenTime = (_wellnessData?['avg_screen_time'] ?? 0).toDouble();
      _streak = (_wellnessData?['logging_streak'] ?? 0) as int;
    }

    if (historyResult['success'] == true) {
      _buildWeeklyChartData(historyResult['data']);
    }
  }

  Future<void> _loadData() async {
    // Show cached data instantly if available
    final cached = await CacheService.get('home_dashboard');
    if (cached != null && mounted) {
      _applyDashboardData(cached);
      setState(() => _isLoading = false);
    }

    // Fetch all in parallel
    final results = await Future.wait([
      ApiService.getUserDashboard(),
      ApiService.getWellnessDashboard(),
      ApiService.getWellnessHistory(days: 7, limit: 7),
      ApiService.getUserProfile(),
    ]);

    final dashResult = results[0];
    final wellnessResult = results[1];
    final historyResult = results[2];
    final profileResult = results[3];

    // Cache the fresh data
    await CacheService.set('home_dashboard', {
      'dash': dashResult,
      'wellness': wellnessResult,
      'history': historyResult,
      'profile': profileResult,
    });

    // Reuse profile + dash for ProfileScreen cache (avoids duplicate fetch when user opens Profile tab)
    await CacheService.set('profile_data', {
      'profile': profileResult,
      'dash': dashResult,
    });

    if (mounted) {
      _applyDashboardData({
        'dash': dashResult,
        'wellness': wellnessResult,
        'history': historyResult,
        'profile': profileResult,
      });
      setState(() => _isLoading = false);
    }

    // Load notifications and ring for new unread ones
    final notifResult = await ApiService.getNotifications(limit: 10);
    if (mounted && notifResult['success']) {
      final notifs = notifResult['data']?['notifications'] ?? [];
      setState(() {
        _notifications = notifs;
        _unreadCount = notifResult['data']?['unread_count'] ?? 0;
      });
      // Trigger local push notification with sound for new unread alerts
      await NotificationService.showNewAlerts(notifs);
    }

    // Auto-collect device usage and submit to backend, then refresh wellness
    await _collectAndSubmitDeviceUsage();

    // Check streak milestones and fire notification
    _checkStreakMilestone();

    // Prefetch other tabs' data into cache so navigation feels instant
    _prefetchOtherTabs();
  }

  Future<void> _prefetchOtherTabs() async {
    // Fire-and-forget; warms caches used by Tests, Reports, XAI screens.
    // Profile cache is already populated above from the shared profile+dash fetch.
    Future.wait([
      ApiService.getTestDashboard().then((r) => CacheService.set('tests_dashboard', r)),
      ApiService.listReports().then((r) {
        if (r['success'] == true) return CacheService.set('reports_list', r);
      }),
      ApiService.getLatestTestResults().then((r) {
        if (r['success'] == true && r['data'] != null) {
          return CacheService.set('xai_latest_results', r['data'] as Map<String, dynamic>);
        }
      }),
    ]).catchError((_) => <dynamic>[]);
  }

  Future<void> _checkStreakMilestone() async {
    // --- Achievement badge unlock notifications (only for newly unlocked) ---
    final prefs = await SharedPreferences.getInstance();
    final notifiedBadges = prefs.getStringList('notified_badges') ?? [];

    final badges = <Map<String, dynamic>>[
      {'id': 'first_test', 'title': 'First Test', 'unlocked': _totalTestsCompleted >= 1, 'icon': '🎯'},
      {'id': 'tests_10', 'title': '10 Tests', 'unlocked': _totalTestsCompleted >= 10, 'icon': '⭐'},
      {'id': 'tests_25', 'title': '25 Tests', 'unlocked': _totalTestsCompleted >= 25, 'icon': '🏅'},
      {'id': 'tests_50', 'title': '50 Tests', 'unlocked': _totalTestsCompleted >= 50, 'icon': '💎'},
      {'id': 'weekly_active', 'title': 'Weekly Active', 'unlocked': _testsThisWeek >= 3, 'icon': '📅'},
      {'id': 'fast_learner', 'title': 'Fast Learner', 'unlocked': _totalTestsCompleted >= 5 && _testsThisWeek >= 2, 'icon': '⚡'},
      {'id': 'health_guard', 'title': 'Health Guard', 'unlocked': _streak >= 7 && _totalTestsCompleted >= 10, 'icon': '🛡️'},
      {'id': 'streak_3', 'title': '3-Day Streak', 'unlocked': _streak >= 3, 'icon': '🔥'},
      {'id': 'streak_7', 'title': '7-Day Streak', 'unlocked': _streak >= 7, 'icon': '🔥'},
      {'id': 'streak_14', 'title': '14-Day Streak', 'unlocked': _streak >= 14, 'icon': '⚡'},
      {'id': 'streak_30', 'title': '30-Day Streak', 'unlocked': _streak >= 30, 'icon': '🏆'},
      {'id': 'streak_100', 'title': '100-Day Streak', 'unlocked': _streak >= 100, 'icon': '🏆'},
    ];

    final newlyUnlocked = <String>[];
    for (final badge in badges) {
      final id = badge['id'] as String;
      if (badge['unlocked'] == true && !notifiedBadges.contains(id)) {
        newlyUnlocked.add(id);
        await NotificationService.show(
          id: 8000 + id.hashCode.abs() % 999,
          title: '${badge['icon']} Badge Unlocked: ${badge['title']}!',
          body: 'Congratulations! You\'ve earned the "${badge['title']}" achievement badge. Keep it up!',
        );
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await prefs.setStringList('notified_badges', [...notifiedBadges, ...newlyUnlocked]);
    }
  }

  /// Collect device screen time via platform channel and submit to backend.
  /// Falls back to backend data if unavailable.
  static const _usageChannel = MethodChannel('com.neuroverse/usage_stats');

  Future<void> _collectAndSubmitDeviceUsage() async {
    try {
      // Check if usage permission is granted
      final hasPermission = await _usageChannel.invokeMethod<bool>('hasUsagePermission') ?? false;

      if (!hasPermission) {
        // Show a dialog asking the user to grant usage access
        if (mounted) {
          _showUsagePermissionDialog();
        }
        _applyFallbackWellness();
        return;
      }

      final result = await _usageChannel.invokeMethod<Map>('getUsageStats');
      if (result != null) {
        final screenHours = (result['screenTimeMinutes'] ?? 0) / 60.0;
        final gamingHrs = (result['gamingMinutes'] ?? 0) / 60.0;
        final socialMinutes = (result['socialMinutes'] ?? 0).toDouble();
        final notifs = (result['notificationCount'] ?? 0) as int;

        await ApiService.submitWellnessData(
          screenTimeHours: double.parse(screenHours.toStringAsFixed(2)),
          gamingHours: double.parse(gamingHrs.toStringAsFixed(2)),
        );

        if (mounted) {
          setState(() {
            _screenTime = screenHours;
            _gamingHours = gamingHrs;
            _socialHours = socialMinutes / 60.0;
            _notificationCount = notifs;
          });
        }

        // Refresh wellness dashboard so weekly chart & averages update
        final refreshed = await ApiService.getWellnessDashboard();
        if (mounted && refreshed['success']) {
          final rData = refreshed['data'];
          setState(() {
            _wellnessData = rData;
            _avgScreenTime = (rData?['avg_screen_time'] ?? 0).toDouble();
            _streak = (rData?['logging_streak'] ?? 0) as int;
          });
          // Also refresh weekly chart
          final hist = await ApiService.getWellnessHistory(days: 7, limit: 7);
          if (mounted && hist['success']) {
            setState(() => _buildWeeklyChartData(hist['data']));
          }
        }
        return;
      }
    } catch (_) {
      // Platform channel not available (e.g. iOS or desktop)
    }

    _applyFallbackWellness();
  }

  void _applyFallbackWellness() {
    if (mounted) {
      setState(() {
        _socialHours = _screenTime * 0.35;
        _notificationCount = (_screenTime * 12).toInt();
      });
    }
  }

  void _showUsagePermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: Color(0xFF7C6AEF)),
            SizedBox(width: 8),
            Expanded(child: Text('Enable Usage Access', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          ],
        ),
        content: const Text(
          'NeuroVerse needs usage access permission to track your screen time, gaming, and social media usage for Digital Wellness monitoring.\n\nTap "Open Settings" and enable access for NeuroVerse.',
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _usageChannel.invokeMethod('requestUsagePermission');
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C6AEF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _buildWeeklyChartData(Map<String, dynamic> historyData) {
    final dailySummary = historyData['daily_summary'] as List<dynamic>? ?? [];
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final screenByDay = <int, double>{};

    for (var entry in dailySummary) {
      final dateStr = entry['date'] as String?;
      if (dateStr == null) continue;
      try {
        final date = DateTime.parse(dateStr);
        final dayIndex = (date.weekday - 1) % 7; // Mon=0, Sun=6
        screenByDay[dayIndex] = (entry['screen_time'] ?? 0).toDouble();
      } catch (_) {}
    }

    _weeklyLabels = dayLabels;
    _weeklyScreenTime = List.generate(7, (i) => screenByDay[i] ?? 0);

    // Inject today's live screen time so the chart always shows the current day
    final todayIndex = (DateTime.now().weekday - 1) % 7;
    if (_screenTime > 0 && _weeklyScreenTime[todayIndex] == 0) {
      _weeklyScreenTime[todayIndex] = _screenTime;
    }
  }


  String _getRiskLevel(int score) {
    if (score < 25) return 'Low';
    if (score < 50) return 'Moderate';
    if (score < 75) return 'Elevated';
    return 'High';
  }

  Color _getBadgeColor(int score) {
    if (score < 25) return const Color(0xFF10B981);  // green
    if (score < 50) return const Color(0xFFF59E0B);  // amber
    if (score < 75) return const Color(0xFFF97316);  // orange
    return const Color(0xFFEF4444);                    // red
  }

  // Get test config (icon, subtitle, color) from category data
  Map<String, dynamic> _getTestConfig(String category) {
    switch (category.toLowerCase()) {
      case 'speech':
        return {
          'title': 'Speech Test',
          'subtitle': 'Story recall',
          'icon': Icons.mic_rounded,
          'bgColor': creamBeige,
        };
      case 'motor':
        return {
          'title': 'Motor Test',
          'subtitle': 'Spiral drawing',
          'icon': Icons.gesture_rounded,
          'bgColor': const Color(0xFFE0F2FE),
        };
      case 'cognitive':
        return {
          'title': 'Cognitive',
          'subtitle': 'Memory & TMT',
          'icon': Icons.extension_rounded,
          'bgColor': softLavender.withOpacity(0.6),
        };
      case 'gait':
        return {
          'title': 'Gait Test',
          'subtitle': 'Walk analysis',
          'icon': Icons.directions_walk_rounded,
          'bgColor': mintGreen.withOpacity(0.5),
        };
      case 'facial':
        return {
          'title': 'Facial Test',
          'subtitle': 'Expression analysis',
          'icon': Icons.face_rounded,
          'bgColor': const Color(0xFFFCE7F3),
        };
      default:
        return {
          'title': category,
          'subtitle': 'Assessment',
          'icon': Icons.science_rounded,
          'bgColor': Colors.white,
        };
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Pending';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return 'Pending';
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: ShimmerLoading(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: const [
                        SkeletonCircle(size: 44),
                        SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SkeletonLine(width: 100, height: 12),
                          SizedBox(height: 6),
                          SkeletonLine(width: 140, height: 16),
                        ]),
                      ]),
                      const SkeletonCircle(size: 44),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Welcome
                  const SkeletonLine(width: 200, height: 22),
                  const SizedBox(height: 8),
                  const SkeletonLine(width: 260, height: 14),
                  const SizedBox(height: 24),
                  // Risk card
                  const SkeletonBox(width: double.infinity, height: 180, borderRadius: 24),
                  const SizedBox(height: 16),
                  // Stats row
                  Row(children: const [
                    Expanded(child: SkeletonBox(width: double.infinity, height: 90, borderRadius: 18)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(width: double.infinity, height: 90, borderRadius: 18)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(width: double.infinity, height: 90, borderRadius: 18)),
                  ]),
                  const SizedBox(height: 24),
                  // Recent tests
                  const SkeletonLine(width: 130, height: 18),
                  const SizedBox(height: 12),
                  Row(children: const [
                    Expanded(child: SkeletonBox(width: double.infinity, height: 100, borderRadius: 16)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(width: double.infinity, height: 100, borderRadius: 16)),
                  ]),
                  const SizedBox(height: 24),
                  // Quick actions
                  const SkeletonLine(width: 130, height: 18),
                  const SizedBox(height: 12),
                  Row(children: const [
                    Expanded(child: SkeletonBox(width: double.infinity, height: 80, borderRadius: 16)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(width: double.infinity, height: 80, borderRadius: 16)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: const [
                    Expanded(child: SkeletonBox(width: double.infinity, height: 80, borderRadius: 16)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(width: double.infinity, height: 80, borderRadius: 16)),
                  ]),
                  const SizedBox(height: 24),
                  // Wellness card
                  const SkeletonBox(width: double.infinity, height: 140, borderRadius: 20),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final r = Responsive(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit', style: TextStyle(color: Colors.white)),
              backgroundColor: darkCard,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.w(12))),
              margin: EdgeInsets.symmetric(horizontal: r.w(40), vertical: r.h(20)),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: r.h(16)),
                    _buildHeader(r),
                    SizedBox(height: r.h(20)),
                    _buildWelcomeSection(r),
                    SizedBox(height: r.h(24)),
                    _buildMainRiskCard(r),
                    SizedBox(height: r.h(16)),
                    _buildStatsRow(r),
                    SizedBox(height: r.h(24)),
                    _buildRecentTestsSection(r),
                    SizedBox(height: r.h(24)),
                    _buildQuickActionsGrid(r),
                    SizedBox(height: r.h(24)),
                    _buildHealthTipsCarousel(r),
                    SizedBox(height: r.h(24)),
                    _buildCognitiveScoreTrend(r),
                    SizedBox(height: r.h(24)),
                    _buildDigitalWellnessCard(r),
                    SizedBox(height: r.h(14)),
                    _buildWellnessInsightBanner(r),
                    SizedBox(height: r.h(24)),
                    _buildNeuroEducationCards(r),
                    SizedBox(height: r.h(24)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  // ===================== HEADER =====================
  Widget _buildHeader(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: r.dp(44),
                  height: r.dp(44),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(r.w(14)),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: r.w(8),
                        offset: Offset(0, r.h(2)),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.all(r.w(4)),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: CustomPaint(
                          size: Size(r.dp(24), r.dp(24)),
                          painter: BrainIconPainter(),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.w(12)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NeuroVerse',
                      style: TextStyle(
                        fontSize: r.sp(18),
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'AI Health Platform',
                      style: TextStyle(
                        fontSize: r.sp(11),
                        fontWeight: FontWeight.w500,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showNotificationsSheet();
                  },
                  child: Container(
                    width: r.dp(44),
                    height: r.dp(44),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(r.w(14)),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: r.dp(22),
                            color: Colors.black87,
                          ),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            top: r.h(8),
                            right: r.w(8),
                            child: Container(
                              width: r.dp(18), height: r.dp(18),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  style: TextStyle(fontSize: r.sp(9), fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: r.w(10)),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    MainShell.switchTab(context, 5);
                  },
                  child: Container(
                    width: r.dp(44),
                    height: r.dp(44),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(r.w(14)),
                      border: Border.all(color: Colors.black.withOpacity(0.08), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(r.w(12)),
                      child: (_profileImagePath != null && _profileImagePath!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: '${ApiService.baseUrl}/uploads/$_profileImagePath',
                              width: r.dp(44),
                              height: r.dp(44),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Center(
                                child: Text(_userInitial, style: TextStyle(fontSize: r.sp(18), fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                            )
                          : Center(
                              child: Text(_userInitial, style: TextStyle(fontSize: r.sp(18), fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ===================== WELCOME =====================
  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    const Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (_unreadCount > 0)
                      GestureDetector(
                        onTap: () async {
                          await ApiService.markAllNotificationsRead();
                          setState(() {
                            for (var n in _notifications) { n['is_read'] = true; }
                            _unreadCount = 0;
                          });
                          setSheetState(() {});
                        },
                        child: Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1).withOpacity(0.8)),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_rounded, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No notifications yet', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _notifications.length,
                        itemBuilder: (ctx, index) {
                          final n = _notifications[index];
                          final type = n['type'] ?? 'system';
                          final isRead = n['is_read'] ?? false;
                          final notifId = n['id'] as int?;

                          IconData icon;
                          Color color;
                          switch (type) {
                            case 'report_ready':
                              icon = Icons.description_rounded;
                              color = const Color(0xFF8B5CF6);
                              break;
                            case 'login_alert':
                              icon = Icons.login_rounded;
                              color = const Color(0xFF3B82F6);
                              break;
                            case 'test_reminder':
                              icon = Icons.assignment_late_rounded;
                              color = const Color(0xFFF59E0B);
                              break;
                            case 'doctor_message':
                              icon = Icons.medical_services_rounded;
                              color = const Color(0xFF10B981);
                              break;
                            default:
                              icon = Icons.notifications_rounded;
                              color = const Color(0xFF6366F1);
                          }

                          return Dismissible(
                            key: ValueKey(notifId ?? index),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                            ),
                            onDismissed: (_) async {
                              final removed = _notifications.removeAt(index);
                              final wasUnread = !(removed['is_read'] ?? false);
                              if (wasUnread) _unreadCount = (_unreadCount - 1).clamp(0, 999);
                              setState(() {});
                              setSheetState(() {});
                              if (notifId != null) {
                                await ApiService.deleteNotification(notifId);
                              }
                            },
                            child: GestureDetector(
                              onTap: () async {
                                if (notifId != null && !isRead) {
                                  await ApiService.markNotificationRead(notifId);
                                  setState(() {
                                    n['is_read'] = true;
                                    _unreadCount = (_unreadCount - 1).clamp(0, 999);
                                  });
                                  setSheetState(() {});
                                }
                                if (n['action_type'] == 'view_report' && mounted) {
                                  Navigator.pop(ctx);
                                  MainShell.switchTab(context, 4);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.grey[50] : color.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isRead ? Colors.transparent : color.withOpacity(0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(isRead ? 0.08 : 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(icon, size: 20, color: color),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  n['title'] ?? '',
                                                  style: TextStyle(fontSize: 14, fontWeight: isRead ? FontWeight.w600 : FontWeight.w700),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            n['message'] ?? '',
                                            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5), height: 1.3),
                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _timeAgo(n['created_at']?.toString()),
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.3)),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  _notifications.removeAt(index);
                                                  if (!isRead) _unreadCount = (_unreadCount - 1).clamp(0, 999);
                                                  setState(() {});
                                                  setSheetState(() {});
                                                  if (notifId != null) {
                                                    await ApiService.deleteNotification(notifId);
                                                  }
                                                },
                                                child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.black.withOpacity(0.25)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.05,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Neuro Health',
              style: TextStyle(
                fontSize: r.sp(38),
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.85),
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
            Text(
              'Overview',
              style: TextStyle(
                fontSize: r.sp(38),
                fontWeight: FontWeight.w800,
                color: Colors.black.withOpacity(0.85),
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== MAIN RISK CARD =====================
  Widget _buildMainRiskCard(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.15,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            MainShell.switchTab(context, 2);
          },
          child: Container(
            padding: EdgeInsets.all(r.w(24)),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(r.w(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall',
                          style: TextStyle(
                            fontSize: r.sp(14),
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          'Risk',
                          style: TextStyle(
                            fontSize: r.sp(28),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Assessment',
                          style: TextStyle(
                            fontSize: r.sp(28),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    _buildCircularIndicator(_overallRisk, r),
                  ],
                ),
                SizedBox(height: r.h(24)),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(10)),
                      decoration: BoxDecoration(
                        color: mintGreen,
                        borderRadius: BorderRadius.circular(r.w(20)),
                      ),
                      child: Text(
                        '$_riskLevel Risk',
                        style: TextStyle(
                          fontSize: r.sp(13),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(width: r.w(12)),
                    Text(
                      'Tap to view XAI',
                      style: TextStyle(
                        fontSize: r.sp(13),
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: r.dp(44),
                      height: r.dp(44),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(r.w(14)),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: r.dp(22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularIndicator(int value, Responsive r) {
    final indicatorSize = r.dp(100);
    return Container(
      width: indicatorSize,
      height: indicatorSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: r.w(3),
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size(indicatorSize, indicatorSize),
            painter: CircularProgressPainter(
              progress: value / 100,
              strokeWidth: r.w(6),
              backgroundColor: Colors.white.withOpacity(0.1),
              progressColor: mintGreen,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style: TextStyle(
                        fontSize: r.sp(36),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        fontSize: r.sp(14),
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Text(
                  'RISK',
                  style: TextStyle(
                    fontSize: r.sp(10),
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== STATS ROW =====================
  Widget _buildStatsRow(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.2,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.w(20)),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: "Alzheimer's",
                subtitle: 'Risk Score',
                value: _adRisk.toString(),
                unit: '/100',
                badge: _getRiskLevel(_adRisk),
                badgeColor: _getBadgeColor(_adRisk),
                bgColor: mintGreen,
                icon: Icons.memory_rounded,
                r: r,
              ),
            ),
            SizedBox(width: r.w(14)),
            Expanded(
              child: _buildStatCard(
                title: "Parkinson's",
                subtitle: 'Risk Score',
                value: _pdRisk.toString(),
                unit: '/100',
                badge: _getRiskLevel(_pdRisk),
                badgeColor: _getBadgeColor(_pdRisk),
                bgColor: softLavender,
                icon: Icons.timeline_rounded,
                r: r,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String subtitle,
    required String value,
    required String unit,
    required String badge,
    required Color badgeColor,
    required Color bgColor,
    required IconData icon,
    required Responsive r,
  }) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: EdgeInsets.all(r.w(18)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(r.w(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: r.dp(22), color: Colors.black54),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: r.w(10), vertical: r.h(4)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(r.w(10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: r.dp(6),
                        height: r.dp(6),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: r.w(5)),
                      Text(
                        badge,
                        style: TextStyle(
                          fontSize: r.sp(11),
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.h(16)),
            Text(
              title,
              style: TextStyle(
                fontSize: r.sp(15),
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: r.h(2)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: r.sp(12),
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            SizedBox(height: r.h(12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: r.sp(34),
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: r.h(4), left: r.w(2)),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: r.sp(14),
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================== RECENT TESTS (DYNAMIC) =====================
  Widget _buildRecentTestsSection(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.25,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Tests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: () => MainShell.switchTab(context, 1),
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 155,
            child: _recentTests.isEmpty
                ? Center(
                    child: Text(
                      'No tests yet. Start your first assessment!',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _recentTests.length,
                    itemBuilder: (context, index) {
                      final test = _recentTests[index];
                      final category = test['category'] ?? '';
                      final config = _getTestConfig(category);
                      final score = (test['score'] ?? 0).toDouble();
                      final status = test['status'] ?? 'pending';
                      final isCompleted = (test['tests_completed'] ?? 0) > 0;
                      final lastTested = test['last_tested'];
                      final timeStr = _timeAgo(lastTested?.toString());

                      return _buildTestCard(
                        title: config['title'],
                        subtitle: config['subtitle'],
                        time: timeStr,
                        icon: config['icon'],
                        bgColor: config['bgColor'],
                        isCompleted: isCompleted,
                        score: score,
                        status: status,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required Color bgColor,
    required bool isCompleted,
    required double score,
    required String status,
  }) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'good':
      case 'normal':
        statusColor = const Color(0xFF10B981);
        break;
      case 'moderate':
      case 'mild':
        statusColor = const Color(0xFFF59E0B);
        break;
      case 'elevated':
      case 'high':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFF9CA3AF);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        MainShell.switchTab(context, 1);
      },
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          border: bgColor == Colors.white
              ? Border.all(color: Colors.black.withOpacity(0.08))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: Colors.black87),
                ),
                if (isCompleted)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (isCompleted) ...[
                      // Score badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${score.toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.black.withOpacity(0.4)
                              : const Color(0xFFD97706),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===================== HEALTH TIPS CAROUSEL =====================
  Widget _buildHealthTipsCarousel(Responsive r) {
    return _buildAnimatedWidget(
      delay: 0.28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Health Tips',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                // Dot indicators
                Row(
                  children: List.generate(
                    _healthTips.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(left: 4),
                      width: _currentTipIndex == i ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentTipIndex == i
                            ? darkCard
                            : Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: PageView.builder(
              controller: _tipsPageController,
              itemCount: _healthTips.length,
              onPageChanged: (i) => setState(() => _currentTipIndex = i),
              itemBuilder: (context, index) {
                final tip = _healthTips[index];
                return AnimatedScale(
                  scale: _currentTipIndex == index ? 1.0 : 0.95,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (tip['color'] as Color).withOpacity(0.85),
                          (tip['color'] as Color),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: (tip['color'] as Color).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tip['title'],
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tip['desc'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            tip['icon'],
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  // ===================== QUICK ACTIONS GRID =====================
  Widget _buildQuickActionsGrid(Responsive r) {
    final actions = [
      {
        'title': 'Take Test',
        'icon': Icons.assignment_outlined,
        'color': const Color(0xFF7C6AEF),
        'bgColor': const Color(0xFFEDE9FE),
        'tab': 1,
      },
      {
        'title': 'View Reports',
        'icon': Icons.description_outlined,
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFD1FAE5),
        'tab': 4,
      },
      {
        'title': 'Chat Neuro',
        'icon': Icons.stars_rounded,
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFEF3C7),
        'tab': 3,
      },
      {
        'title': 'XAI Insights',
        'icon': Icons.auto_awesome_rounded,
        'color': const Color(0xFFEC4899),
        'bgColor': const Color(0xFFFCE7F3),
        'tab': 2,
      },
    ];

    return _buildAnimatedWidget(
      delay: 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: actions.map((action) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      MainShell.switchTab(context, action['tab'] as int);
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                        right: action != actions.last ? 10 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: action['bgColor'] as Color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: (action['color'] as Color).withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: (action['color'] as Color).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              action['icon'] as IconData,
                              size: 22,
                              color: action['color'] as Color,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            action['title'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: (action['color'] as Color),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== COGNITIVE SCORE TREND =====================
  Widget _buildCognitiveScoreTrend(Responsive r) {
    // Fixed category list (no gait — not trained)
    final categories = ['All', 'Cognitive', 'Speech', 'Motor', 'Facial'];

    // Filter risk_trend data by selected category
    final filtered = _trendCategory == 'All'
        ? _riskTrend
        : _riskTrend.where((t) => (t['category'] ?? '').toString().toLowerCase() == _trendCategory.toLowerCase()).toList();

    final List<double> trendPoints = [];
    final List<String> trendLabels = [];

    for (var entry in filtered) {
      // Use AD risk as the trend value (average of ad+pd would also work)
      final ad = (entry['ad'] ?? 0).toDouble();
      final pd = (entry['pd'] ?? 0).toDouble();
      final score = ((ad + pd) / 2);
      trendPoints.add(score);
      final cat = (entry['category'] ?? '').toString();
      trendLabels.add(cat.isNotEmpty ? cat[0].toUpperCase() : '?');
    }

    // Placeholder if not enough data
    if (trendPoints.length < 2) {
      trendPoints.clear();
      trendLabels.clear();
      trendPoints.addAll([35, 28, 42, 30, 25]);
      trendLabels.addAll(['S', 'M', 'C', 'M', 'S']);
    }

    final maxVal = trendPoints.reduce((a, b) => a > b ? a : b);
    final minVal = trendPoints.reduce((a, b) => a < b ? a : b);
    final avgVal = trendPoints.reduce((a, b) => a + b) / trendPoints.length;
    final lastVal = trendPoints.last;
    final prevVal = trendPoints.length >= 2 ? trendPoints[trendPoints.length - 2] : lastVal;
    final change = lastVal - prevVal;

    return _buildAnimatedWidget(
      delay: 0.33,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Risk Score Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Across your recent tests',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: change <= 0
                          ? const Color(0xFF10B981).withOpacity(0.12)
                          : const Color(0xFFEF4444).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: change <= 0
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : const Color(0xFFEF4444).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          change <= 0
                              ? Icons.trending_down_rounded
                              : Icons.trending_up_rounded,
                          size: 14,
                          color: change <= 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${change.abs().toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: change <= 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Category filter chips
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: categories.map((cat) {
                    final isSelected = _trendCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _trendCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? darkCard : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // Chart area
              SizedBox(
                height: 120,
                child: CustomPaint(
                  size: const Size(double.infinity, 120),
                  painter: _TrendChartPainter(
                    points: trendPoints,
                    labels: trendLabels,
                    maxValue: maxVal > 0 ? maxVal * 1.2 : 100,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  _buildTrendStat('Average', '${avgVal.toStringAsFixed(0)}%', const Color(0xFF7C6AEF)),
                  const SizedBox(width: 12),
                  _buildTrendStat('Lowest', '${minVal.toStringAsFixed(0)}%', const Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  _buildTrendStat('Highest', '${maxVal.toStringAsFixed(0)}%', const Color(0xFFEF4444)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== EDUCATIONAL NEURO CARDS =====================
  static final List<Map<String, dynamic>> _neuroCards = [
    {
      'title': 'Early Signs of Alzheimer\'s',
      'content': 'Memory loss that disrupts daily life, challenges in planning, difficulty completing familiar tasks, confusion with time or place, and trouble understanding visual images.',
      'icon': Icons.extension_rounded,
      'color': const Color(0xFF8B5CF6),
      'category': 'Alzheimer\'s',
    },
    {
      'title': 'Parkinson\'s: More Than Tremors',
      'content': 'Besides tremors, PD includes rigidity, slow movement (bradykinesia), balance problems, and non-motor symptoms like sleep disorders, depression, and loss of smell.',
      'icon': Icons.accessibility_new_rounded,
      'color': const Color(0xFF06B6D4),
      'category': 'Parkinson\'s',
    },
    {
      'title': 'The Power of Early Detection',
      'content': 'Early diagnosis of neurodegenerative diseases can slow progression by up to 40% with proper intervention. Regular screening is key to maintaining quality of life.',
      'icon': Icons.search_rounded,
      'color': const Color(0xFF10B981),
      'category': 'Prevention',
    },
    {
      'title': 'How AI Helps Screening',
      'content': 'AI can detect subtle patterns in speech, handwriting, and movement that humans might miss. NeuroVerse uses multimodal AI to screen for early neurological signs.',
      'icon': Icons.auto_awesome_rounded,
      'color': const Color(0xFFF59E0B),
      'category': 'Technology',
    },
    {
      'title': 'Protect Your Brain Daily',
      'content': 'Mediterranean diet, 150 min weekly exercise, quality sleep, social engagement, and mental stimulation can reduce dementia risk by up to 60%.',
      'icon': Icons.shield_rounded,
      'color': const Color(0xFFEC4899),
      'category': 'Prevention',
    },
    {
      'title': 'Understanding XAI Results',
      'content': 'Explainable AI (XAI) shows WHY the AI made its prediction. SHAP values, GradCAM heatmaps, and LIME help you and your doctor understand your screening results.',
      'icon': Icons.insights_rounded,
      'color': const Color(0xFF6366F1),
      'category': 'Technology',
    },
    {
      'title': 'Myth: Dementia Is Inevitable',
      'content': 'FACT: Dementia is NOT a normal part of aging. Up to 40% of dementia cases could be prevented or delayed by addressing modifiable risk factors like hypertension and diabetes.',
      'icon': Icons.lightbulb_rounded,
      'color': const Color(0xFFEF4444),
      'category': 'Myths vs Facts',
    },
    {
      'title': 'Clock Drawing Test (CDT)',
      'content': 'Drawing a clock face tests visuospatial ability, memory, and executive function. Errors in number placement or hand positioning can indicate early cognitive impairment.',
      'icon': Icons.schedule_rounded,
      'color': const Color(0xFF14B8A6),
      'category': 'Tests',
    },
  ];

  int _neuroCardIndex = 0;

  Widget _buildNeuroEducationCards(Responsive r) {
    final neuroPageController = PageController(viewportFraction: 0.85);
    return _buildAnimatedWidget(
      delay: 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Neuro Education',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                const Spacer(),
                Text(
                  '${_neuroCardIndex + 1}/${_neuroCards.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: neuroPageController,
              itemCount: _neuroCards.length,
              onPageChanged: (i) => setState(() => _neuroCardIndex = i),
              itemBuilder: (context, index) {
                final card = _neuroCards[index];
                final color = card['color'] as Color;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, color.withOpacity(0.75)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Background decorative circle
                      Positioned(
                        right: -20, top: -20,
                        child: Icon(
                          card['icon'] as IconData,
                          size: 120,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(card['icon'] as IconData, size: 14, color: Colors.white),
                                      const SizedBox(width: 5),
                                      Text(
                                        card['category'] as String,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              card['title'] as String,
                              style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: Colors.white, height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                card['content'] as String,
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.88), height: 1.5,
                                ),
                                maxLines: 4, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Dot indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_neuroCards.length, (i) {
              final isActive = i == _neuroCardIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF6366F1) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===================== DIGITAL WELLNESS =====================
  String _formatTime(double hours) {
    final h = hours.toInt();
    final m = ((hours - h) * 60).round();
    if (h == 0 && m == 0) return '0m';
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Widget _buildDigitalWellnessCard(Responsive r) {
    // Calculate trend
    final screenLimit = 6.0;
    final pctOfLimit = _screenTime > 0 ? ((_screenTime / screenLimit) * 100).round() : 0;
    final isUnder = _screenTime <= screenLimit;

    return _buildAnimatedWidget(
      delay: 0.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      softLavender.withOpacity(0.5),
                      mintGreen.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: darkCard,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_android_rounded, size: 12, color: Colors.white70),
                              SizedBox(width: 6),
                              Text('Digital Wellness', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isUnder ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUnder ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                                size: 14, color: isUnder ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$pctOfLimit% of limit',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isUnder ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(_screenTime),
                          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.black87, height: 1, letterSpacing: -1),
                        ),
                        const Spacer(),
                        Text('Total Screen Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.4))),
                      ],
                    ),
                  ],
                ),
              ),

              // Stats Row — phone-trackable metrics (no sleep)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildWellnessStatCard(
                      icon: Icons.phone_android_rounded,
                      label: 'Screen',
                      value: _formatTime(_screenTime),
                      bgColor: softLavender,
                      iconColor: const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(width: 8),
                    _buildWellnessStatCard(
                      icon: Icons.sports_esports_rounded,
                      label: 'Gaming',
                      value: _formatTime(_gamingHours),
                      bgColor: const Color(0xFFFFE4E6),
                      iconColor: const Color(0xFFEC4899),
                    ),
                    const SizedBox(width: 8),
                    _buildWellnessStatCard(
                      icon: Icons.people_rounded,
                      label: 'Social',
                      value: _formatTime(_socialHours),
                      bgColor: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildWellnessStatCard(
                      icon: Icons.notifications_rounded,
                      label: 'Alerts',
                      value: '$_notificationCount',
                      bgColor: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),

              // Weekly Patterns
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: darkCard.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 18),
                            SizedBox(width: 8),
                            Text('Weekly Screen Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Avg ${_avgScreenTime.toStringAsFixed(1)}h',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white60),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 85,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final todayIndex = (DateTime.now().weekday - 1) % 7;
                          return _buildWeeklyBar(_weeklyLabels[i], _weeklyScreenTime[i], i == todayIndex);
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: mintGreen, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Text('Screen Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.5))),
                        const SizedBox(width: 16),
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: softLavender, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.5))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWellnessInsightBanner(Responsive r) {
    // Build insight text based on data
    String insight;
    IconData insightIcon;
    Color insightColor;

    if (_screenTime > 6) {
      insight = 'High screen time detected. Consider taking breaks every 30 minutes to reduce eye strain and cognitive fatigue.';
      insightIcon = Icons.warning_amber_rounded;
      insightColor = const Color(0xFFEF4444);
    } else if (_screenTime > 4) {
      insight = 'Moderate usage today. Your digital habits are within a healthy range — keep balancing screen and offline time.';
      insightIcon = Icons.info_outline_rounded;
      insightColor = const Color(0xFFF59E0B);
    } else if (_screenTime > 0) {
      insight = 'Great digital balance! Low screen time is linked to better sleep quality and reduced stress levels.';
      insightIcon = Icons.check_circle_outline_rounded;
      insightColor = const Color(0xFF10B981);
    } else {
      insight = 'No usage data yet today. Your wellness metrics update as you use your phone throughout the day.';
      insightIcon = Icons.lightbulb_outline_rounded;
      insightColor = const Color(0xFF6366F1);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _showWellnessInsightSheet();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: insightColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: insightColor.withOpacity(0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: insightColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(insightIcon, size: 18, color: insightColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wellness Insight',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: insightColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      insight,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.55), height: 1.45),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: insightColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  void _showWellnessInsightSheet() {
    final screenScore = _screenTime <= 2 ? 95.0 : _screenTime <= 4 ? 75.0 : _screenTime <= 6 ? 50.0 : 25.0;
    final gamingScore = _gamingHours <= 1 ? 90.0 : _gamingHours <= 2 ? 65.0 : 35.0;
    final socialScore = _socialHours <= 1 ? 90.0 : _socialHours <= 2 ? 65.0 : 35.0;
    final overallScore = ((screenScore + gamingScore + socialScore) / 3).round();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wellness Insights', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                        Text('Digital health breakdown', style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.4))),
                      ],
                    ),
                  ),
                  // Overall score circle
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: overallScore >= 70 ? const Color(0xFF10B981).withOpacity(0.1) : overallScore >= 40 ? const Color(0xFFF59E0B).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        '$overallScore',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: overallScore >= 70 ? const Color(0xFF10B981) : overallScore >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                children: [
                  // ── Today's Summary Grid ──
                  Row(
                    children: [
                      _buildInsightMetric('Screen Time', _formatTime(_screenTime), Icons.phone_android_rounded, const Color(0xFF8B5CF6)),
                      const SizedBox(width: 10),
                      _buildInsightMetric('Gaming', _formatTime(_gamingHours), Icons.sports_esports_rounded, const Color(0xFFEC4899)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildInsightMetric('Social Apps', _formatTime(_socialHours), Icons.people_rounded, const Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      _buildInsightMetric('Notifications', '$_notificationCount', Icons.notifications_rounded, const Color(0xFFF59E0B)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Extra usage metrics row
                  Row(
                    children: [
                      _buildInsightMetric('Pickups', '${(_screenTime * 4.5).round()}', Icons.touch_app_rounded, const Color(0xFF3B82F6)),
                      const SizedBox(width: 10),
                      _buildInsightMetric('Longest Session', _formatTime(_screenTime > 0 ? (_screenTime * 0.38).clamp(0.1, 4.0) : 0), Icons.hourglass_top_rounded, const Color(0xFFF97316)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Daily Limit Progress ──
                  _buildSectionTitle('Daily Limit Progress'),
                  const SizedBox(height: 12),
                  _buildLimitProgressCard('Screen Time', _screenTime, 6.0, const Color(0xFF8B5CF6)),
                  const SizedBox(height: 8),
                  _buildLimitProgressCard('Gaming', _gamingHours, 2.0, const Color(0xFFEC4899)),
                  const SizedBox(height: 8),
                  _buildLimitProgressCard('Social Media', _socialHours, 2.0, const Color(0xFF10B981)),
                  const SizedBox(height: 20),

                  // ── App Category Breakdown ──
                  _buildSectionTitle('App Category Breakdown'),
                  const SizedBox(height: 12),
                  _buildCategoryBreakdown(),
                  const SizedBox(height: 20),

                  // ── Health Scores ──
                  _buildSectionTitle('Health Scores'),
                  const SizedBox(height: 12),
                  _buildScoreBar('Focus & Attention', screenScore, const Color(0xFF8B5CF6)),
                  const SizedBox(height: 8),
                  _buildScoreBar('Gaming Balance', gamingScore, const Color(0xFFEC4899)),
                  const SizedBox(height: 8),
                  _buildScoreBar('Social Balance', socialScore, const Color(0xFF10B981)),
                  const SizedBox(height: 8),
                  _buildScoreBar('Notification Load', _notificationCount <= 30 ? 90.0 : _notificationCount <= 60 ? 60.0 : 30.0, const Color(0xFFF59E0B)),
                  const SizedBox(height: 8),
                  _buildScoreBar('Digital Detox', _screenTime <= 3 ? 95.0 : _screenTime <= 5 ? 60.0 : 20.0, const Color(0xFF06B6D4)),
                  const SizedBox(height: 20),

                  // ── Cognitive Impact ──
                  _buildSectionTitle('Cognitive Impact'),
                  const SizedBox(height: 12),
                  _buildCognitiveImpactCard(),
                  const SizedBox(height: 20),

                  // ── Recommendations ──
                  _buildSectionTitle('Recommendations'),
                  const SizedBox(height: 12),
                  if (_screenTime > 4) _buildRecommendation(
                    'Reduce Screen Time',
                    'Try the 20-20-20 rule: every 20 min, look at something 20 feet away for 20 seconds.',
                    Icons.visibility_rounded, const Color(0xFF8B5CF6),
                  ),
                  if (_gamingHours > 1.5) _buildRecommendation(
                    'Limit Gaming Sessions',
                    'Set a timer for gaming. Take 10-min breaks between sessions to rest your eyes and mind.',
                    Icons.timer_rounded, const Color(0xFFEC4899),
                  ),
                  if (_socialHours > 1.5) _buildRecommendation(
                    'Social Media Detox',
                    'Turn off non-essential notifications. Try batching social media checks to set times.',
                    Icons.do_not_disturb_on_rounded, const Color(0xFF10B981),
                  ),
                  if (_notificationCount > 50) _buildRecommendation(
                    'Notification Overload',
                    'You\'ve received $_notificationCount notifications today. Mute non-essential apps to reduce distractions.',
                    Icons.notifications_off_rounded, const Color(0xFFF59E0B),
                  ),
                  _buildRecommendation(
                    'Stay Active',
                    '30 minutes of daily exercise reduces dementia risk by 30% and improves cognitive function.',
                    Icons.directions_run_rounded, const Color(0xFFF59E0B),
                  ),
                  _buildRecommendation(
                    'Mindful Breaks',
                    '5-minute meditation breaks between screen sessions reduce stress and improve focus.',
                    Icons.self_improvement_rounded, const Color(0xFF06B6D4),
                  ),
                  _buildRecommendation(
                    'Blue Light Exposure',
                    'Enable night mode after 8 PM. Blue light suppresses melatonin and disrupts sleep quality.',
                    Icons.nightlight_round, const Color(0xFF6366F1),
                  ),
                  const SizedBox(height: 20),

                  // ── Weekly comparison ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _screenTime < _avgScreenTime ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                          color: const Color(0xFF6366F1), size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Weekly Average', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                'Your avg screen time is ${_formatTime(_avgScreenTime)}/day this week',
                                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5)),
                              ),
                              if (_avgScreenTime > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _screenTime < _avgScreenTime
                                      ? '${((_avgScreenTime - _screenTime) / _avgScreenTime * 100).round()}% less than your average today'
                                      : '${((_screenTime - _avgScreenTime) / _avgScreenTime * 100).round()}% more than your average today',
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600,
                                    color: _screenTime < _avgScreenTime ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar(String label, double score, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: score >= 70 ? const Color(0xFF10B981) : score >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${score.toInt()}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildRecommendation(String title, String desc, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11, color: Colors.black.withOpacity(0.5), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }

  Widget _buildLimitProgressCard(String label, double current, double limit, Color color) {
    final pct = limit > 0 ? (current / limit).clamp(0.0, 1.5) : 0.0;
    final overLimit = current > limit;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                '${_formatTime(current)} / ${_formatTime(limit)}',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: overLimit ? const Color(0xFFEF4444) : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              ),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: overLimit
                          ? [const Color(0xFFEF4444), const Color(0xFFF87171)]
                          : [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          if (overLimit) ...[
            const SizedBox(height: 4),
            Text(
              '${_formatTime(current - limit)} over limit',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    // Derive app category breakdown from available data
    final otherHours = (_screenTime - _gamingHours - _socialHours).clamp(0.0, 24.0);
    final categories = <Map<String, dynamic>>[
      {'name': 'Social Media', 'hours': _socialHours, 'icon': Icons.people_rounded, 'color': const Color(0xFF10B981)},
      {'name': 'Gaming', 'hours': _gamingHours, 'icon': Icons.sports_esports_rounded, 'color': const Color(0xFFEC4899)},
      {'name': 'Productivity', 'hours': otherHours * 0.4, 'icon': Icons.work_rounded, 'color': const Color(0xFF3B82F6)},
      {'name': 'Entertainment', 'hours': otherHours * 0.35, 'icon': Icons.movie_rounded, 'color': const Color(0xFFF59E0B)},
      {'name': 'Utilities', 'hours': otherHours * 0.25, 'icon': Icons.build_rounded, 'color': const Color(0xFF8B5CF6)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: categories.map((cat) {
          final hours = (cat['hours'] as double).clamp(0.0, 24.0);
          final pct = _screenTime > 0 ? (hours / _screenTime * 100).round() : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: (cat['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(cat['icon'] as IconData, size: 16, color: cat['color'] as Color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cat['name'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('${_formatTime(hours)}  $pct%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.4))),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _screenTime > 0 ? (hours / _screenTime).clamp(0.0, 1.0) : 0,
                          minHeight: 5,
                          backgroundColor: Colors.grey[200],
                          color: cat['color'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCognitiveImpactCard() {
    final focusScore = _screenTime <= 3 ? 'High' : _screenTime <= 5 ? 'Moderate' : 'Low';
    final focusColor = _screenTime <= 3 ? const Color(0xFF10B981) : _screenTime <= 5 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final memoryRisk = _screenTime > 6 ? 'Elevated' : _screenTime > 4 ? 'Moderate' : 'Low';
    final memoryColor = _screenTime > 6 ? const Color(0xFFEF4444) : _screenTime > 4 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final sleepImpact = _screenTime > 5 ? 'Disrupted' : _screenTime > 3 ? 'Mild' : 'Minimal';
    final sleepColor = _screenTime > 5 ? const Color(0xFFEF4444) : _screenTime > 3 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    final items = [
      {'label': 'Focus Capacity', 'value': focusScore, 'icon': Icons.center_focus_strong_rounded, 'color': focusColor,
       'desc': 'Based on screen breaks and session lengths'},
      {'label': 'Memory Risk', 'value': memoryRisk, 'icon': Icons.extension_rounded, 'color': memoryColor,
       'desc': 'Prolonged screen use correlates with reduced memory consolidation'},
      {'label': 'Sleep Impact', 'value': sleepImpact, 'icon': Icons.bedtime_rounded, 'color': sleepColor,
       'desc': 'Blue light exposure affects melatonin production'},
      {'label': 'Stress Indicator', 'value': _notificationCount > 60 ? 'High' : _notificationCount > 30 ? 'Moderate' : 'Low',
       'icon': Icons.favorite_rounded, 'color': _notificationCount > 60 ? const Color(0xFFEF4444) : _notificationCount > 30 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
       'desc': 'Notification frequency impacts cortisol levels'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item['icon'] as IconData, size: 18, color: item['color'] as Color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['label'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(item['value'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: item['color'] as Color)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(item['desc'] as String, style: TextStyle(fontSize: 10, color: Colors.black.withOpacity(0.4), height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWellnessStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: bgColor),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBar(String day, double screenTimeHours, bool isToday) {
    final hasData = screenTimeHours > 0;
    final normalizedValue = (screenTimeHours / 12).clamp(0.0, 1.0);
    // Minimum visible bar height of 6px when there's data, 4px placeholder when empty
    final barHeight = hasData ? (55 * normalizedValue).clamp(6.0, 55.0) : 4.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasData)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${screenTimeHours.toStringAsFixed(1)}h',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: isToday ? Colors.white : Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        Container(
          width: 30,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: hasData
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isToday
                        ? [softLavender, softLavender.withOpacity(0.7)]
                        : [mintGreen, mintGreen.withOpacity(0.6)],
                  )
                : null,
            color: hasData ? null : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            boxShadow: hasData
                ? [
                    BoxShadow(
                      color: (isToday ? softLavender : mintGreen).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  // ===================== ANIMATION HELPER =====================
  Widget _buildAnimatedWidget({required double delay, required Widget child}) {
    // After entry animation completes, skip animation wrappers for scroll performance
    if (_pageController.isCompleted) return child;

    final curve = Interval(delay, math.min(delay + 0.3, 1.0), curve: Curves.easeOut);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _pageController, curve: curve),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _pageController, curve: curve)),
        child: child,
      ),
    );
  }
}

// ===================== CUSTOM PAINTERS =====================
class BrainIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.cubicTo(size.width * 0.25, size.height * 0.1, size.width * 0.08, size.height * 0.35, size.width * 0.12, size.height * 0.55);
    path.cubicTo(size.width * 0.08, size.height * 0.75, size.width * 0.25, size.height * 0.9, size.width * 0.5, size.height * 0.85);
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.cubicTo(size.width * 0.75, size.height * 0.1, size.width * 0.92, size.height * 0.35, size.width * 0.88, size.height * 0.55);
    path.cubicTo(size.width * 0.92, size.height * 0.75, size.width * 0.75, size.height * 0.9, size.width * 0.5, size.height * 0.85);
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.lineTo(size.width * 0.5, size.height * 0.85);
    path.moveTo(size.width * 0.2, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.35, size.height * 0.4, size.width * 0.3, size.height * 0.55);
    path.moveTo(size.width * 0.22, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.38, size.height * 0.62, size.width * 0.35, size.height * 0.75);
    path.moveTo(size.width * 0.8, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.65, size.height * 0.4, size.width * 0.7, size.height * 0.55);
    path.moveTo(size.width * 0.78, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.62, size.height * 0.62, size.width * 0.65, size.height * 0.75);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrendChartPainter extends CustomPainter {
  final List<double> points;
  final List<String> labels;
  final double maxValue;

  _TrendChartPainter({
    required this.points,
    required this.labels,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chartHeight = size.height - 24;
    final spacing = points.length > 1 ? size.width / (points.length - 1) : size.width / 2;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Build point positions
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = points.length > 1 ? i * spacing : size.width / 2;
      final y = chartHeight - (points[i] / maxValue) * chartHeight;
      offsets.add(Offset(x, y));
    }

    // Gradient fill under curve
    if (offsets.length >= 2) {
      final fillPath = Path()..moveTo(offsets.first.dx, chartHeight);
      for (final o in offsets) {
        fillPath.lineTo(o.dx, o.dy);
      }
      fillPath.lineTo(offsets.last.dx, chartHeight);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x407C6AEF), Color(0x057C6AEF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
      canvas.drawPath(fillPath, fillPaint);

      // Line
      final linePaint = Paint()
        ..color = const Color(0xFF7C6AEF)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        final prev = offsets[i - 1];
        final curr = offsets[i];
        final midX = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // Dots and labels
    for (int i = 0; i < offsets.length; i++) {
      // Outer dot
      canvas.drawCircle(
        offsets[i],
        5,
        Paint()..color = Colors.white,
      );
      // Inner dot
      canvas.drawCircle(
        offsets[i],
        3.5,
        Paint()..color = const Color(0xFF7C6AEF),
      );

      // Label below
      final textPainter = TextPainter(
        text: TextSpan(
          text: i < labels.length ? labels[i] : '',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(offsets[i].dx - textPainter.width / 2, chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2 - 4;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) => oldDelegate.progress != progress;
}
