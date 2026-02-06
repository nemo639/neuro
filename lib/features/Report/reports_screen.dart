import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:url_launcher/url_launcher.dart';  // For opening PDF
import 'package:share_plus/share_plus.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pageController;
  int _selectedNavIndex = 2; // Reports is selected

  // Design colors matching home screen
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color mintGreen = Color(0xFFB8E8D1);
  static const Color softLavender = Color(0xFFE8DFF0);
  static const Color creamBeige = Color(0xFFF5EBE0);
  static const Color softYellow = Color(0xFFFFF3CD);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color navBg = Color(0xFFFAFAFA);
  static const Color blueAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color greenAccent = Color(0xFF10B981);

  // State variables
  List<ReportItem> reports = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _loadReports();
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
    super.dispose();
  }

  Future<void> _loadReports() async {
    try {
      final result = await ApiService.listReports();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success']) {
            final items = result['data']['items'] as List? ?? [];
            reports = items.map((r) => ReportItem.fromJson(r)).toList();
            // Sort by date (newest first)
            reports.sort((a, b) => b.id.compareTo(a.id));
          } else {
            // Handle error
            print('Error loading reports: ${result['error']}');
          }
        });
      }
    } catch (e) {
      print('Exception loading reports: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showGenerateReportDialog() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _GenerateReportSheet(
      onGenerate: (String title, List<int> sessionIds, String? category) async {
        Navigator.pop(context);
        await _generateReport(title, sessionIds, category);
      },
    ),
  );
}

  Future<void> _generateReport(String title, List<int> sessionIds, String? category) async {
  setState(() => _isGenerating = true);
  
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Generating report...'),
        ],
      ),
      duration: Duration(seconds: 30),
    ),
  );
  
  try {
    final result = await ApiService.createReport(
      title: title,
      sessionIds: sessionIds.isEmpty ? null : sessionIds,
      category: category,
    );
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report generated successfully!'),
          backgroundColor: greenAccent,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _viewReport(result['data']['id']),
          ),
        ),
      );
      // Refresh reports list to show the new report
      await _loadReports();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to generate report'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _isGenerating = false);
    }
  }
}

  Future<void> _viewReport(int reportId) async {
    // Navigate to report detail screen
    Navigator.pushNamed(context, '/report-detail', arguments: {'reportId': reportId});
  }

  Future<void> _downloadReport(int reportId) async {
    final url = '${ApiService.baseUrl}/api/v1/reports/$reportId/download';
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open PDF')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  Future<void> _deleteReport(int reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final result = await ApiService.deleteReport(reportId: reportId);
      if (result['success']) {
        _loadReports();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _onNavItemTapped(int index) {
    HapticFeedback.selectionClick();
    
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/tests');
        break;
      case 2:
        setState(() => _selectedNavIndex = index);
        break;
      case 3:
        Navigator.pushNamed(context, '/XAI');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatsCard(),
                    const SizedBox(height: 24),
                    if (reports.isEmpty)
                      _buildEmptyState()
                    else
                      _buildReportsList(),
                    const SizedBox(height: 20),
                    _buildGenerateButton(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return _buildAnimatedWidget(
      delay: 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment Reports',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Downloadable PDF reports with AI insights',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    // Calculate dynamic stats
    final totalReports = reports.length;
    
    // Count reports from this month
    final now = DateTime.now();
    int thisMonthReports = 0;
    for (var report in reports) {
      // Parse the formatted date like "Dec 11, 2025"
      try {
        final dateParts = report.date.split(' ');
        if (dateParts.length >= 3) {
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final monthIndex = months.indexOf(dateParts[0]) + 1;
          final year = int.tryParse(dateParts[2].replaceAll(',', '')) ?? 0;
          
          if (monthIndex == now.month && year == now.year) {
            thisMonthReports++;
          }
        }
      } catch (e) {
        // Skip if date parsing fails
      }
    }
    
    // Count reports with PDF URL (assuming available/shared)
    final availableReports = reports.where((r) => r.pdfUrl != null && r.pdfUrl!.isNotEmpty).length;
    
    return _buildAnimatedWidget(
      delay: 0.1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: darkCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: darkCard.withOpacity(0.3),
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
                  Text(
                    'Total Reports Generated',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: mintGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.insert_chart_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$totalReports',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildMiniStat('This Month', '$thisMonthReports', mintGreen),
                  const SizedBox(width: 16),
                  _buildMiniStat('Available', '$availableReports', softLavender),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 80,
              color: Colors.black.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No Reports Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate your first assessment report',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    return Column(
      children: reports.asMap().entries.map((entry) {
        int index = entry.key;
        ReportItem report = entry.value;
        return _buildAnimatedWidget(
          delay: 0.15 + (index * 0.05),
          child: _buildReportCard(report),
        );
      }).toList(),
    );
  }

  Widget _buildReportCard(ReportItem report) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: report.iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: report.iconColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.black.withOpacity(0.4),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            report.date,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Badges row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: report.isReady 
                        ? greenAccent.withOpacity(0.15) 
                        : Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.isReady ? 'Ready' : 'Processing',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: report.isReady ? greenAccent : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${report.testsCount} tests',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Risk scores row
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildRiskScore('AD Risk', report.adRisk),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.black.withOpacity(0.08),
                  ),
                  Expanded(
                    child: _buildRiskScore('PD Risk', report.pdRisk),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: report.isReady ? () {
                      HapticFeedback.lightImpact();
                      _downloadReport(report.id);
                    } : null,
                    child: Opacity(
                      opacity: report.isReady ? 1.0 : 0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: blueAccent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: report.isReady ? [
                            BoxShadow(
                              color: blueAccent.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ] : [],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Download',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: report.isReady && report.pdfUrl != null ? () {
                      HapticFeedback.lightImpact();
                      Share.share('Check out my report: ${report.pdfUrl}');
                    } : null,
                    child: Opacity(
                      opacity: report.isReady && report.pdfUrl != null ? 1.0 : 0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              color: Colors.black.withOpacity(0.7),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Share',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildRiskScore(String label, int score) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$score',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: '/100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return _buildAnimatedWidget(
      delay: 0.35,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: _isGenerating ? null : () {
            HapticFeedback.mediumImpact();
            _showGenerateReportDialog();
          },
          child: Opacity(
            opacity: _isGenerating ? 0.6 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: darkCard.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isGenerating)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: mintGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.black87,
                        size: 18,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _isGenerating ? 'Generating...' : 'Generate New Report',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.assignment_outlined, 'Tests'),
              _buildNavItem(2, Icons.analytics_outlined, 'Reports'),
              _buildNavItem(3, Icons.auto_awesome_rounded, 'XAI'),
              _buildNavItem(4, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? darkCard : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.black38,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedWidget({required double delay, required Widget child}) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _pageController,
        curve: Interval(delay, math.min(delay + 0.3, 1.0), curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _pageController,
          curve: Interval(delay, math.min(delay + 0.3, 1.0), curve: Curves.easeOut),
        )),
        child: child,
      ),
    );
  }
}

// Data model
class ReportItem {
  final int id;
  final String title;
  final String date;
  final int testsCount;
  final int sessionsCount;
  final int adRisk;
  final int pdRisk;
  final String status;
  final String? pdfUrl;
  final Color iconColor;
  final Color iconBgColor;
  final List<Map<String, dynamic>> sessionDetails;

  ReportItem({
    required this.id,
    required this.title,
    required this.date,
    required this.testsCount,
    required this.sessionsCount,
    required this.adRisk,
    required this.pdRisk,
    required this.status,
    this.pdfUrl,
    this.iconColor = const Color(0xFF8B5CF6),
    this.iconBgColor = const Color(0xFFF3E8FF),
    this.sessionDetails = const [],
  });

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    return ReportItem(
      id: json['id'],
      title: json['title'] ?? 'Report',
      date: _formatDate(json['created_at']),
      testsCount: json['total_tests'] ?? 0,
      sessionsCount: json['sessions_count'] ?? 0,
      adRisk: (json['ad_risk_score'] ?? 0).toInt(),
      pdRisk: (json['pd_risk_score'] ?? 0).toInt(),
      status: json['status'] ?? 'completed',
      pdfUrl: json['pdf_url'],
      iconColor: const Color(0xFF8B5CF6),
      iconBgColor: const Color(0xFFF3E8FF),
      sessionDetails: List<Map<String, dynamic>>.from(json['sessions'] ?? []),
    );
  }
  
  static String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  bool get isReady => status == 'completed';
}

// Replace the _GenerateReportSheet class with this improved version

class _GenerateReportSheet extends StatefulWidget {
  final Function(String title, List<int> sessionIds, String? category) onGenerate;
  
  const _GenerateReportSheet({required this.onGenerate});
  
  @override
  State<_GenerateReportSheet> createState() => _GenerateReportSheetState();
}

class _GenerateReportSheetState extends State<_GenerateReportSheet> {
  final _titleController = TextEditingController(text: 'Comprehensive Assessment Report');
  List<Map<String, dynamic>> _sessions = [];
  Set<int> _selectedSessionIds = {};
  bool _isLoading = true;
  bool _selectAll = true;
  String? _errorMessage;
  
  // Category filter
  String? _selectedCategory;
  final List<String> _categories = ['All', 'speech', 'motor', 'cognitive'];
  
  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({String? category}) async {
    try {
      print('Loading test sessions... Category: $category');
      
      // Load sessions with optional category filter
      final result = await ApiService.listTestSessions(
        status: 'completed',
        category: category == 'All' ? null : category,
      );
      
      print('Sessions API result: $result');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          
          if (result['success']) {
            print('API Success: ${result['data']}');
            
            // Handle different response structures
            dynamic items;
            if (result['data'] is Map && result['data']['items'] != null) {
              items = result['data']['items'];
            } else if (result['data'] is List) {
              items = result['data'];
            } else {
              items = null;
            }
            
            if (items != null && items is List && items.isNotEmpty) {
              _sessions = List<Map<String, dynamic>>.from(items);
              print('✅ Loaded ${_sessions.length} sessions');
              
              // Select all by default
              _selectedSessionIds = _sessions.map((s) => s['id'] as int).toSet();
              _errorMessage = null;
            } else {
              _sessions = [];
              _errorMessage = null; // Don't show error for empty results
              print('⚠️ No sessions found');
            }
          } else {
            _errorMessage = result['error'] ?? 'Failed to load sessions';
            print('❌ Error loading sessions: $_errorMessage');
          }
        });
      }
    } catch (e, stackTrace) {
      print('❌ Exception loading sessions: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Connection error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Generate Report',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Report Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Report Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Category Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter by Category:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category || 
                                      (category == 'All' && _selectedCategory == null);
                    return FilterChip(
                      label: Text(_formatCategory(category)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category == 'All' ? null : category;
                          _isLoading = true;
                          _sessions = [];
                          _selectedSessionIds = {};
                        });
                        _loadSessions(category: _selectedCategory);
                      },
                      backgroundColor: Colors.grey[100],
                      selectedColor: const Color(0xFF3B82F6).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF3B82F6),
                      labelStyle: TextStyle(
                        color: isSelected ? const Color(0xFF3B82F6) : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Select All Toggle
          if (_sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Include Sessions (${_selectedSessionIds.length}/${_sessions.length}):',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectAll = !_selectAll;
                        if (_selectAll) {
                          _selectedSessionIds = _sessions.map((s) => s['id'] as int).toSet();
                        } else {
                          _selectedSessionIds.clear();
                        }
                      });
                    },
                    child: Text(_selectAll ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),
            ),
          
          // Sessions List
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _loadSessions(category: _selectedCategory);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
              : _sessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No Sessions Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCategory != null
                                ? 'No completed ${_formatCategory(_selectedCategory!)} sessions found.\nTry selecting a different category.'
                                : 'Complete some tests first to generate reports.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/tests');
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start Tests'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A1A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final isSelected = _selectedSessionIds.contains(session['id']);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedSessionIds.remove(session['id']);
                              } else {
                                _selectedSessionIds.add(session['id']);
                              }
                              _selectAll = _selectedSessionIds.length == _sessions.length;
                            });
                          },
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedSessionIds.add(session['id']);
                                } else {
                                  _selectedSessionIds.remove(session['id']);
                                }
                                _selectAll = _selectedSessionIds.length == _sessions.length;
                              });
                            },
                          ),
                          title: Text(
                            _formatCategory(session['category']),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${session['items_count'] ?? 0} tests • ${_formatDate(session['completed_at'])}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Score: ${session['score'] ?? 'N/A'}',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Generate Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_sessions.isNotEmpty && _selectedSessionIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please select at least one session',
                              style: TextStyle(color: Colors.orange[900], fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedSessionIds.isEmpty ? null : () {
                      if (_titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a report title')),
                        );
                        return;
                      }
                      widget.onGenerate(
                        _titleController.text.trim(),
                        _selectedSessionIds.toList(),
                        _selectedCategory,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _sessions.isEmpty 
                          ? 'No Sessions Available'
                          : 'Generate Report (${_selectedSessionIds.length} ${_selectedSessionIds.length == 1 ? 'session' : 'sessions'})',
                      style: TextStyle(
                        color: _selectedSessionIds.isEmpty ? Colors.grey[600] : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatCategory(String? category) {
    if (category == null || category == 'All') return 'All Categories';
    final formatted = category[0].toUpperCase() + category.substring(1);
    final categoryMap = {
      'Speech': 'Speech',
      'Motor': 'Motor',
      'Cognitive': 'Cognitive',
      'Gait': 'Gait'
    };
    return categoryMap[formatted] ?? formatted;
  }
  
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return '${date.day}/${date.month}/${date.year}';
  }
}