import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neuroverse/core/api_service.dart';

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
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Clear All Conversations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            const Text('This will permanently delete all conversations.\nThis action cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('Clear All', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
    Future.delayed(const Duration(milliseconds: 150), () {
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
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Main chat content
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32, height: 32,
                              child: CircularProgressIndicator(
                                color: darkCard,
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Loading conversation...',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : _messages.isEmpty
                        ? _buildEmptyState()
                        : _buildMessageList(),
              ),
              _buildInputBar(),
              if (!keyboardOpen) _buildBottomNav(),
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
            _buildConversationDrawer(),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════

  Widget _buildHeader() {
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
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_rounded, color: Colors.white.withValues(alpha: 0.8), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              // Neuro avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: mintGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFF1A1A1A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conversationTitle ?? 'Neuro',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            color: mintGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: mintGreen.withValues(alpha: 0.5), blurRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI Health Companion',
                          style: TextStyle(
                            fontSize: 11,
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
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_square, color: Colors.white.withValues(alpha: 0.8), size: 20),
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

  Widget _buildConversationDrawer() {
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: SafeArea(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.78,
          margin: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(4, 0),
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
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: darkCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.stars_rounded, color: Color(0xFFB8E8D1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Conversations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _isDrawerOpen = false),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
              // New chat button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: GestureDetector(
                  onTap: _startNewChat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: darkCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('New Chat',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Conversation list
              Expanded(
                child: _conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No conversations yet',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text('Start a new chat to begin',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: _conversations.length,
                        itemBuilder: (context, index) {
                          final conv = _conversations[index];
                          final isActive = conv['id'] == _conversationId;
                          return _buildConversationTile(conv, isActive);
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          SizedBox(width: 8),
                          Text('Clear All Conversations',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
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

  Widget _buildConversationTile(Map<String, dynamic> conv, bool isActive) {
    final title = conv['title'] ?? 'Chat';
    final time = _timeAgo(conv['updated_at'] ?? conv['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () => _loadConversation(conv['id'], title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? darkCard : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 18,
                color: isActive ? mintGreen : Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
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
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
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

  Widget _buildEmptyState() {
    return FadeTransition(
      opacity: _animController,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Hero illustration
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: darkCard.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.stars_rounded, color: mintGreen, size: 40),
                  Positioned(
                    right: 12, top: 12,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: mintGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: mintGreen.withValues(alpha: 0.6), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hi! I\'m Neuro',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your personal AI health companion.\nAsk about your results, brain health, or wellness tips.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mintGreen.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: mintGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Neuro uses your test data for personalized responses. Your conversations are private.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Suggestions
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SUGGESTED QUESTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(_suggestions.length, (i) {
              final s = _suggestions[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSuggestionTile(
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

  Widget _buildSuggestionTile(String text, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF374151)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // MESSAGES
  // ═══════════════════════════════════════════

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isSending) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 34, height: 34,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.stars_rounded, color: Color(0xFFB8E8D1), size: 17),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Neuro',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: isUser ? Colors.white : const Color(0xFF1F2937),
                      height: 1.55,
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.stars_rounded, color: Color(0xFFB8E8D1), size: 17),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  blurRadius: 12,
                  offset: const Offset(0, 3),
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

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
                decoration: InputDecoration(
                  hintText: 'Ask Neuro anything...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(_messageController.text),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(_messageController.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey.shade300 : darkCard,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _isSending ? Icons.more_horiz_rounded : Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
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

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
              _buildNavItem(2, Icons.auto_awesome_rounded, 'XAI'),
              _buildNavItem(3, Icons.stars_rounded, 'Neuro'),
              _buildNavItem(4, Icons.description_outlined, 'Reports'),
              _buildNavItem(5, Icons.person_outline_rounded, 'Profile'),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? darkCard : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.black38, size: 22),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
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
          margin: const EdgeInsets.symmetric(horizontal: 3),
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
