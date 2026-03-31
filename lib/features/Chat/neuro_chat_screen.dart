import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';
import 'package:neuroverse/core/loading_bars.dart';
import '../../core/responsive.dart';

class NeuroChatScreen extends StatefulWidget {
  const NeuroChatScreen({super.key});

  @override
  State<NeuroChatScreen> createState() => _NeuroChatScreenState();
}

class _NeuroChatScreenState extends State<NeuroChatScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 3;

  // Design colors matching app theme
  static const Color bgColor = Color(0xFFF7F7F7);
  static const Color darkCard = Color(0xFF1A1A1A);
  static const Color navBg = Color(0xFFFAFAFA);
  static const Color mintGreen = Color(0xFFB8E8D1);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animController;

  List<ChatMessage> _messages = [];
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isDrawerOpen = false;
  String? _conversationId;
  String? _conversationTitle;

  final List<Map<String, dynamic>> _suggestions = [
    {'text': 'What do my test results mean?', 'icon': Icons.analytics_outlined, 'color': Color(0xFFB8E8D1)},
    {'text': 'Tips for brain health', 'icon': Icons.favorite_outline_rounded, 'color': Color(0xFFF5EBE0)},
    {'text': 'Explain my risk scores', 'icon': Icons.show_chart_rounded, 'color': Color(0xFFE8DFF0)},
    {'text': 'Best foods for brain health?', 'icon': Icons.restaurant_rounded, 'color': Color(0xFFFFF3CD)},
    {'text': "What is Parkinson's disease?", 'icon': Icons.help_outline_rounded, 'color': Color(0xFFD1E8F0)},
    {'text': 'How to sleep better at night?', 'icon': Icons.bedtime_rounded, 'color': Color(0xFFE8D1D1)},
    {'text': 'Exercises for motor function', 'icon': Icons.directions_run_rounded, 'color': Color(0xFFD1E8E8)},
    {'text': 'How to manage health anxiety?', 'icon': Icons.self_improvement_rounded, 'color': Color(0xFFE0D1E8)},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadConversations();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════
  // DATA METHODS
  // ═══════════════════════════════════════════
 
  Future<void> _loadConversations() async {
    try {
      final result = await ApiService.getConversations();
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true && result['data'] != null) {
            final data = result['data'];
            _conversations = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
            // Auto-load the most recent conversation
            if (_conversations.isNotEmpty) {
              _loadConversation(_conversations.first['id'], _conversations.first['title'] ?? 'Chat');
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Load conversations error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConversation(String convId, String title) async {
    setState(() {
      _conversationId = convId;
      _conversationTitle = title;
      _messages = [];
      _isLoading = true;
      _isDrawerOpen = false;
    });

    try {
      final result = await ApiService.getChatHistory(conversationId: convId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true && result['data'] != null) {
            final data = result['data'];
            final msgs = data['messages'] as List? ?? [];
            _messages = msgs.map((m) => ChatMessage.fromJson(m)).toList();
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Load conversation error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startNewChat() {
    setState(() {
      _conversationId = null;
      _conversationTitle = null;
      _messages = [];
      _isDrawerOpen = false;
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isSending = true;
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final result = await ApiService.sendChatMessage(
        message: text.trim(),
        conversationId: _conversationId,
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          if (result['success'] == true && result['data'] != null) {
            final data = result['data'];
            final newConvId = data['conversation_id'];
            // If this was a new conversation, update state & refresh list
            if (_conversationId == null && newConvId != null) {
              _conversationId = newConvId;
              _conversationTitle = data['title'] ?? text.trim();
              _refreshConversationList();
            }
            _messages.add(ChatMessage(
              role: 'assistant',
              content: data['reply'] ?? 'Sorry, I could not process that.',
              timestamp: DateTime.now(),
            ));
          } else {
            _messages.add(ChatMessage(
              role: 'assistant',
              content: 'I\'m having trouble connecting right now. Please try again.',
              timestamp: DateTime.now(),
            ));
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Chat send exception: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Connection error. Please check your internet.',
            timestamp: DateTime.now(),
          ));
        });
      }
    }
  }

  Future<void> _refreshConversationList() async {
    try {
      final result = await ApiService.getConversations();
      if (mounted && result['success'] == true && result['data'] != null) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(result['data']['conversations'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteConversation(String convId) async {
    await ApiService.deleteConversation(conversationId: convId);
    if (mounted) {
      setState(() {
        _conversations.removeWhere((c) => c['id'] == convId);
        if (_conversationId == convId) {
          _conversationId = null;
          _conversationTitle = null;
          _messages = [];
        }
      });
    }
  }

  Future<void> _clearAllChats() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 28),
            ),
            SizedBox(height: 16),
            Text('Clear All Conversations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
            ),
            SizedBox(height: 8),
            Text('This will permanently delete all conversations.\nThis action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text('Clear All', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ApiService.clearAllChats();
      if (mounted) {
        setState(() {
          _conversations.clear();
          _messages.clear();
          _conversationId = null;
          _conversationTitle = null;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }

  // ═══════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Main chat content
          Column(
            children: [
              _buildHeader(r),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingDots(color: darkCard, size: 10),
                            SizedBox(height: 12),
                            Text('Loading conversation...',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? _buildEmptyState(r)
                        : _buildMessageList(r),
              ),
              _buildInputBar(r),
              if (!keyboardOpen) _buildBottomNav(r),
            ],
          ),
          // Conversation drawer overlay
          if (_isDrawerOpen) ...[
            GestureDetector(
              onTap: () => setState(() => _isDrawerOpen = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
            _buildConversationDrawer(r),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════

  Widget _buildHeader(Responsive r) {
    return Container(
      decoration: const BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          child: Row(
            children: [
              // Menu button — opens conversation drawer
              GestureDetector(
                onTap: () => setState(() => _isDrawerOpen = !_isDrawerOpen),
                child: Container(
                  width: r.w(40), height: r.h(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.dp(12)),
                  ),
                  child: Icon(Icons.menu_rounded, color: Colors.white.withValues(alpha: 0.8), size: r.dp(22)),
                ),
              ),
              SizedBox(width: r.w(12)),
              // Neuro avatar
              Container(
                width: r.w(40),
                height: r.h(40),
                decoration: BoxDecoration(
                  color: mintGreen,
                  borderRadius: BorderRadius.circular(r.dp(13)),
                ),
                child: Icon(Icons.stars_rounded, color: Color(0xFF1A1A1A), size: r.dp(22)),
              ),
              SizedBox(width: r.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conversationTitle ?? 'Neuro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.sp(17),
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: r.h(2)),
                    Row(
                      children: [
                        Container(
                          width: r.w(6), height: r.h(6),
                          decoration: BoxDecoration(
                            color: mintGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: mintGreen.withValues(alpha: 0.5), blurRadius: r.dp(6)),
                            ],
                          ),
                        ),
                        SizedBox(width: r.w(6)),
                        Text(
                          'AI Health Companion',
                          style: TextStyle(
                            fontSize: r.sp(11),
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // New chat button
              GestureDetector(
                onTap: _startNewChat,
                child: Container(
                  width: r.w(40), height: r.h(40),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.dp(12)),
                  ),
                  child: Icon(Icons.edit_square, color: Colors.white.withValues(alpha: 0.8), size: r.dp(20)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CONVERSATION DRAWER (like ChatGPT sidebar)
  // ═══════════════════════════════════════════

  Widget _buildConversationDrawer(Responsive r) {
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.78,
          margin: EdgeInsets.only(left: r.w(8), top: r.h(8), bottom: r.h(8)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r.dp(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: r.dp(30),
                offset: Offset(r.w(4), r.h(0)),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drawer header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: r.w(38), height: r.h(38),
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(r.dp(12)),
                      ),
                      child: Icon(Icons.stars_rounded, color: Color(0xFFB8E8D1), size: r.dp(20)),
                    ),
                    SizedBox(width: r.w(12)),
                    Expanded(
                      child: Text('Conversations',
                        style: TextStyle(fontSize: r.sp(18), fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isDrawerOpen = false),
                      child: Container(
                        width: r.w(34), height: r.h(34),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(r.dp(10)),
                        ),
                        child: Icon(Icons.close_rounded, size: r.dp(18), color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
              // New chat button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(4)),
                child: GestureDetector(
                  onTap: _startNewChat,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: r.h(13)),
                    decoration: BoxDecoration(
                      color: darkCard,
                      borderRadius: BorderRadius.circular(r.dp(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: r.dp(20)),
                        SizedBox(width: r.w(8)),
                        Text('New Chat',
                          style: TextStyle(fontSize: r.sp(14), fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.h(8)),
              // Conversation list
              Expanded(
                child: _conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: r.dp(40), color: Colors.grey.shade300),
                            SizedBox(height: r.h(12)),
                            Text('No conversations yet',
                              style: TextStyle(fontSize: r.sp(14), color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: r.h(4)),
                            Text('Start a new chat to begin',
                              style: TextStyle(fontSize: r.sp(12), color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(4)),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conv = _conversations[index];
                          final isActive = conv['id'] == _conversationId;
                          return _buildConversationTile(r, conv, isActive);
                        },
                      ),
              ),
              // Clear all button at bottom
              if (_conversations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _isDrawerOpen = false);
                      _clearAllChats();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: r.h(12)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(r.dp(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: r.dp(18)),
                          SizedBox(width: r.w(8)),
                          Text('Clear All Conversations',
                            style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationTile(Responsive r, Map<String, dynamic> conv, bool isActive) {
    final title = conv['title'] ?? 'Chat';
    final time = _timeAgo(conv['updated_at'] ?? conv['created_at']);

    return Padding(
      padding: EdgeInsets.only(bottom: r.h(4)),
      child: GestureDetector(
        onTap: () => _loadConversation(conv['id'], title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: r.w(14), vertical: r.h(12)),
          decoration: BoxDecoration(
            color: isActive ? darkCard : Colors.transparent,
            borderRadius: BorderRadius.circular(r.dp(14)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: r.dp(18),
                color: isActive ? mintGreen : Colors.grey.shade400,
              ),
              SizedBox(width: r.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.sp(13.5),
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                    SizedBox(height: r.h(2)),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: r.sp(11),
                        color: isActive ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              // Delete single conversation
              GestureDetector(
                onTap: () => _deleteConversation(conv['id']),
                child: Padding(
                  padding: EdgeInsets.all(r.dp(4)),
                  child: Icon(
                    Icons.close_rounded,
                    size: r.dp(16),
                    color: isActive ? Colors.white.withValues(alpha: 0.4) : Colors.grey.shade300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════

  Widget _buildEmptyState(Responsive r) {
    return FadeTransition(
      opacity: _animController,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(r.dp(24)),
        child: Column(
          children: [
            SizedBox(height: r.h(32)),
            // Hero illustration
            Container(
              width: r.w(88),
              height: r.h(88),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(r.dp(28)),
                boxShadow: [
                  BoxShadow(
                    color: darkCard.withValues(alpha: 0.3),
                    blurRadius: r.dp(24),
                    offset: Offset(r.w(0), r.h(10)),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.stars_rounded, color: mintGreen, size: r.dp(40)),
                  Positioned(
                    right: 12, top: 12,
                    child: Container(
                      width: r.w(12), height: r.h(12),
                      decoration: BoxDecoration(
                        color: mintGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: mintGreen.withValues(alpha: 0.6), blurRadius: r.dp(8)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.h(24)),
            Text(
              'Hi! I\'m Neuro',
              style: TextStyle(
                fontSize: r.sp(26),
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: r.h(8)),
            Text(
              'Your personal AI health companion.\nAsk about your results, brain health, or wellness tips.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.sp(14.5),
                color: Colors.grey.shade600,
                height: r.h(1.5),
              ),
            ),
            SizedBox(height: r.h(32)),

            // Info card
            Container(
              padding: EdgeInsets.all(r.dp(16)),
              decoration: BoxDecoration(
                color: mintGreen.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(r.dp(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: r.w(36), height: r.h(36),
                    decoration: BoxDecoration(
                      color: mintGreen,
                      borderRadius: BorderRadius.circular(r.dp(10)),
                    ),
                    child: Icon(Icons.shield_outlined, size: r.dp(18), color: Color(0xFF1A1A1A)),
                  ),
                  SizedBox(width: r.w(12)),
                  Expanded(
                    child: Text(
                      'Neuro uses your test data for personalized responses. Your conversations are private.',
                      style: TextStyle(fontSize: r.sp(12.5), color: Colors.grey.shade700, height: r.h(1.4)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.h(28)),

            // Suggestions
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SUGGESTED QUESTIONS',
                style: TextStyle(
                  fontSize: r.sp(11),
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: r.h(14)),
            ...List.generate(_suggestions.length, (i) {
              final s = _suggestions[i];
              return Padding(
                padding: EdgeInsets.only(bottom: r.h(10)),
                child: _buildSuggestionTile(r, 
                  s['text'] as String,
                  s['icon'] as IconData,
                  s['color'] as Color,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(Responsive r, String text, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(r.dp(16)),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: r.dp(10),
              offset: Offset(r.w(0), r.h(2)),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: r.w(36), height: r.h(36),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(r.dp(10)),
              ),
              child: Icon(icon, size: r.dp(18), color: Color(0xFF374151)),
            ),
            SizedBox(width: r.w(14)),
            Expanded(
              child: Text(text,
                style: TextStyle(fontSize: r.sp(14), fontWeight: FontWeight.w500, color: Color(0xFF374151)),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: r.dp(14), color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════

  Widget _buildMessageList(Responsive r) {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isSending) {
          return _buildTypingIndicator(r);
        }
        return _buildMessageBubble(r, _messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(Responsive r, ChatMessage message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: EdgeInsets.only(bottom: r.h(14)),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: r.w(34), height: r.h(34),
              margin: EdgeInsets.only(top: r.h(2)),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(r.dp(11)),
              ),
              child: Icon(Icons.stars_rounded, color: Color(0xFFB8E8D1), size: r.dp(17)),
            ),
            SizedBox(width: r.w(10)),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.h(13)),
              decoration: BoxDecoration(
                color: isUser ? darkCard : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isUser ? 0.12 : 0.05),
                    blurRadius: r.dp(12),
                    offset: Offset(r.w(0), r.h(3)),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: EdgeInsets.only(bottom: r.h(4)),
                      child: Text('Neuro',
                        style: TextStyle(
                          fontSize: r.sp(11),
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      fontSize: r.sp(14.5),
                      color: isUser ? Colors.white : const Color(0xFF1F2937),
                      height: r.h(1.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(Responsive r) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.h(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: r.w(34), height: r.h(34),
            margin: EdgeInsets.only(top: r.h(2)),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(r.dp(11)),
            ),
            child: Icon(Icons.stars_rounded, color: Color(0xFFB8E8D1), size: r.dp(17)),
          ),
          SizedBox(width: r.w(10)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: r.dp(12),
                  offset: Offset(r.w(0), r.h(3)),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => _BouncingDot(delay: i * 0.2)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // INPUT BAR
  // ═══════════════════════════════════════════

  Widget _buildInputBar(Responsive r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: r.dp(10),
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(r.dp(22)),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(fontSize: r.sp(15), color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'Ask Neuro anything...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: r.sp(14.5)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: r.w(20), vertical: r.h(12)),
                ),
                onSubmitted: (_) => _sendMessage(_messageController.text),
              ),
            ),
          ),
          SizedBox(width: r.w(10)),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(_messageController.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: r.w(46),
              height: r.h(46),
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey.shade300 : darkCard,
                borderRadius: BorderRadius.circular(r.dp(15)),
              ),
              child: Icon(
                _isSending ? Icons.more_horiz_rounded : Icons.arrow_upward_rounded,
                color: Colors.white,
                size: r.dp(22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // BOTTOM NAV
  // ═══════════════════════════════════════════

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
        Navigator.pushNamed(context, '/XAI');
        break;
      case 3:
        setState(() => _selectedNavIndex = index);
        break;
      case 4:
        Navigator.pushNamed(context, '/reports');
        break;
      case 5:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  Widget _buildBottomNav(Responsive r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(r.dp(24)),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: r.dp(20),
            offset: Offset(r.w(0), r.h(4)),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.h(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(r, 0, Icons.home_rounded, 'Home'),
              _buildNavItem(r, 1, Icons.assignment_outlined, 'Tests'),
              _buildNavItem(r, 2, Icons.auto_awesome_rounded, 'XAI'),
              _buildNavItem(r, 3, Icons.stars_rounded, 'Neuro'),
              _buildNavItem(r, 4, Icons.description_outlined, 'Reports'),
              _buildNavItem(r, 5, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(Responsive r, int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () => _onNavItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.h(10)),
        decoration: BoxDecoration(
          color: isSelected ? darkCard : Colors.transparent,
          borderRadius: BorderRadius.circular(r.dp(16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black38, size: r.dp(22)),
            if (isSelected) ...[
              SizedBox(width: r.w(8)),
              Text(label,
                style: TextStyle(fontSize: r.sp(13), fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Bouncing Dot Animation
// ═══════════════════════════════════════════

class _BouncingDot extends StatefulWidget {
  final double delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final bounce = math.sin(_ctrl.value * math.pi * 2) * 4;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 3),
          child: Transform.translate(
            offset: Offset(0, -bounce.abs()),
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFFD1D5DB),
                  const Color(0xFF6B7280),
                  (_ctrl.value * 2).clamp(0.0, 1.0),
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// Chat Message Model
// ═══════════════════════════════════════════

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
