import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_logs/core/theme/app_colors.dart';
import 'package:my_logs/core/theme/app_typography.dart';
import 'package:my_logs/core/widgets/app_confirmation_dialog.dart';
import 'package:my_logs/features/ai_assistant/application/ai_assistant_provider.dart';
import 'package:my_logs/features/ai_assistant/domain/models/ai_message.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasInputText = false;

  // ── LogsPad App Theme Colors ────────────────────────────────────────────────
  static const Color _chatBg = AppColors.background;
  static const Color _chatHeaderBg = AppColors.surface;
  static const Color _userBubble = AppColors.primaryContainer; // #4F46E5
  static const Color _userBubbleText = AppColors.onPrimary; // #FFFFFF
  static const Color _userBubbleSubtext = Color(0xFFDAD7FF);
  static const Color _aiBubble = AppColors.surfaceContainerLowest; // #FFFFFF
  static const Color _aiBubbleBorder = Color(0xFFE2E8F0);
  static const Color _chatText = AppColors.obsidian; // #0F172A
  static const Color _chatSubtext = AppColors.outline; // #777587
  static const Color _brandAccent = AppColors.primary; // #3525CD / #4F46E5
  static const Color _datePillBg = AppColors.surfaceContainer; // #ECEEF0
  static const Color _datePillText = AppColors.onSurfaceVariant; // #464555
  static const Color _infoPillBg = Color(0xFFEEF2FF); // soft brand indigo tint
  static const Color _infoPillBorder = Color(0xFFC7D2FE);
  static const Color _infoPillText = Color(0xFF3730A3);

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scrollToBottom();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottom();
    });
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasInputText) {
      setState(() => _hasInputText = hasText);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? predefinedText]) {
    final text = predefinedText ?? _textController.text;
    if (text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    _textController.clear();
    ref.read(aiAssistantProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _confirmClearChat() async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Clear Chat?',
      message: 'This will delete all messages in this conversation.',
      confirmLabel: 'Clear',
      icon: Icons.delete_outline_rounded,
      confirmColor: AppColors.error,
      isDestructive: true,
    );
    if (confirmed == true && mounted) {
      ref.read(aiAssistantProvider.notifier).clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(aiAssistantProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || prev?.isLoading != next.isLoading) {
        _scrollToBottom();
      }
    });

    final aiState = ref.watch(aiAssistantProvider);
    final messages = aiState.messages;
    final activeWs = ref.watch(activeWorkspaceProvider);
    final wsName = activeWs?.name ?? 'Personal';

    return Scaffold(
      backgroundColor: _chatBg,
      appBar: AppBar(
        backgroundColor: _chatHeaderBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _chatText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            // App Avatar with Online Indicator
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: _brandAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LogsPad AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _chatText,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Active • $wsName',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _brandAccent,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (messages.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: _chatText),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'clear') _confirmClearChat();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Clear chat', style: TextStyle(color: AppColors.error, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Divider under app bar
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Conversation Stream or Empty State
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: messages.length + (aiState.isLoading ? 1 : 0) + 1,
                      itemBuilder: (context, index) {
                        // First item is always the floating Date Pill
                        if (index == 0) {
                          return _buildDateHeader();
                        }

                        final msgIndex = index - 1;
                        if (msgIndex == messages.length && aiState.isLoading) {
                          return _buildThinkingBubble();
                        }
                        return _buildMessageBubble(context, messages[msgIndex]);
                      },
                    ),
            ),

            // Floating Bottom Input Bar
            _buildChatInputBar(context, aiState.isLoading),
          ],
        ),
      ),
    );
  }

  // Floating Date Pill
  Widget _buildDateHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _datePillBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'TODAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _datePillText,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // Empty State with Privacy Notice & Quick Prompt Chips
  Widget _buildEmptyState(BuildContext context) {
    final activeWs = ref.watch(activeWorkspaceProvider);
    final enabled = activeWs?.enabledFeatures ?? const ['notes', 'tasks', 'reminders'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildDateHeader(),

          const SizedBox(height: 12),

          // LogsPad Context & Privacy Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _infoPillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _infoPillBorder, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: _infoPillText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'LogsPad AI is scoped to your active workspace "${activeWs?.name ?? 'Personal'}". All created tasks, notes, books, and media are automatically organized and saved.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _infoPillText,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Suggestions Header
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 18, color: _chatSubtext),
              const SizedBox(width: 6),
              Text(
                'SUGGESTED ACTIONS',
                style: AppTypography.labelEyebrow.copyWith(color: _chatSubtext),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Contextual Prompt Chips based on enabled workspace features
          if (enabled.contains('tasks')) ...[
            _buildPromptChip(
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF10B981),
              text: 'Add a high priority task: Review sprint goals tomorrow at 4 PM',
            ),
            const SizedBox(height: 8),
          ],
          if (enabled.contains('notes')) ...[
            _buildPromptChip(
              icon: Icons.edit_note_rounded,
              iconColor: const Color(0xFF4F46E5),
              text: 'Write a note: Meeting key takeaways and action items',
            ),
            const SizedBox(height: 8),
          ],
          if (enabled.contains('reminders')) ...[
            _buildPromptChip(
              icon: Icons.notifications_active_outlined,
              iconColor: const Color(0xFFF59E0B),
              text: 'Remind me tomorrow at 9 AM to pay electricity bill',
            ),
            const SizedBox(height: 8),
          ],
          if (enabled.contains('read')) ...[
            _buildPromptChip(
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF8B5CF6),
              text: 'Add "Atomic Habits" by James Clear to my reading list',
            ),
            const SizedBox(height: 8),
          ],
          if (enabled.contains('watch')) ...[
            _buildPromptChip(
              icon: Icons.movie_outlined,
              iconColor: const Color(0xFFEC4899),
              text: 'Add "Spirited Away" to my anime watch list',
            ),
            const SizedBox(height: 8),
          ],
          if (enabled.contains('learning_paths')) ...[
            _buildPromptChip(
              icon: Icons.alt_route_rounded,
              iconColor: const Color(0xFF0284C7),
              text: 'Create a learning path for "Flutter Clean Architecture"',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPromptChip({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _sendMessage(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _aiBubbleBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _chatText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: _chatSubtext),
            ],
          ),
        ),
      ),
    );
  }

  // Message Bubble (LogsPad Indigo for User, Clean White with Border for AI)
  Widget _buildMessageBubble(BuildContext context, AiChatMessage message) {
    final isUser = message.role == AiMessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: isUser
                  ? _userBubble
                  : message.isError
                      ? const Color(0xFFFDE8E8)
                      : _aiBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isUser ? 14 : 3),
                bottomRight: Radius.circular(isUser ? 3 : 14),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: message.isError ? const Color(0xFFF87171) : _aiBubbleBorder,
                      width: 1,
                    ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: isUser ? 0.08 : 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Message Body Text
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isUser
                        ? _userBubbleText
                        : (message.isError ? AppColors.error : _chatText),
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),

                // Action/Attachment Cards (if AI executed actions)
                if (message.actions.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 2),
                    child: Divider(color: Color(0xFFE2E8F0), height: 1),
                  ),
                  ...message.actions.map((action) => _buildActionAttachment(context, action)),
                ],

                const SizedBox(height: 4),

                // Timestamp & Status Indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Spacer(),
                    Text(
                      DateFormat('h:mm a').format(message.timestamp).toLowerCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isUser ? _userBubbleSubtext : _chatSubtext,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 15,
                        color: _userBubbleSubtext,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Action executed by AI rendered as a rich, prominent document card
  Widget _buildActionAttachment(BuildContext context, AiActionItem action) {
    IconData icon;
    String entityType;
    String route;
    Color themeColor;
    Color cardBg;
    Color cardBorder;
    Color textThemeColor;

    switch (action.type) {
      case AiActionType.createTask:
        icon = Icons.check_circle_rounded;
        entityType = 'Task';
        route = '/tasks';
        themeColor = const Color(0xFF059669);
        cardBg = const Color(0xFFECFDF5);
        cardBorder = const Color(0xFFA7F3D0);
        textThemeColor = const Color(0xFF065F46);
        break;
      case AiActionType.createNote:
        icon = Icons.description_rounded;
        entityType = 'Note';
        route = '/notes';
        themeColor = const Color(0xFF4F46E5);
        cardBg = const Color(0xFFEEF2FF);
        cardBorder = const Color(0xFFC7D2FE);
        textThemeColor = const Color(0xFF312E81);
        break;
      case AiActionType.createReminder:
        icon = Icons.alarm_rounded;
        entityType = 'Reminder';
        route = '/reminders';
        themeColor = const Color(0xFFD97706);
        cardBg = const Color(0xFFFFFBEB);
        cardBorder = const Color(0xFFFDE68A);
        textThemeColor = const Color(0xFF78350F);
        break;
      case AiActionType.addBook:
        icon = Icons.menu_book_rounded;
        entityType = 'Book';
        route = '/read';
        themeColor = const Color(0xFF7C3AED);
        cardBg = const Color(0xFFFAF5FF);
        cardBorder = const Color(0xFFE9D5FF);
        textThemeColor = const Color(0xFF581C87);
        break;
      case AiActionType.addMedia:
        icon = Icons.movie_rounded;
        entityType = 'Media';
        route = '/watch';
        themeColor = const Color(0xFFDB2777);
        cardBg = const Color(0xFFFDF2F8);
        cardBorder = const Color(0xFFFBCFE8);
        textThemeColor = const Color(0xFF831843);
        break;
      case AiActionType.createLearningPath:
        icon = Icons.alt_route_rounded;
        entityType = 'Learning Path';
        route = '/learning-paths';
        themeColor = const Color(0xFF0284C7);
        cardBg = const Color(0xFFF0F9FF);
        cardBorder = const Color(0xFFBAE6FD);
        textThemeColor = const Color(0xFF075985);
        break;
      default:
        icon = Icons.bolt_rounded;
        entityType = 'Action';
        route = '/';
        themeColor = const Color(0xFF0284C7);
        cardBg = const Color(0xFFF0F9FF);
        cardBorder = const Color(0xFFBAE6FD);
        textThemeColor = const Color(0xFF075985);
    }

    final isOk = action.isExecuted;
    if (!isOk) {
      cardBg = const Color(0xFFFEF2F2);
      cardBorder = const Color(0xFFFECACA);
      textThemeColor = const Color(0xFF991B1B);
    }

    final label = action.resultMessage ?? '$entityType Created';
    final imageUrl = (action.data['coverUrl'] ?? action.data['posterUrl']) as String?;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(9),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 36,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Icon(icon, size: 18, color: themeColor),
                ),
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cardBorder),
              ),
              child: Icon(icon, size: 18, color: themeColor),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textThemeColor,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      isOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 12,
                      color: isOk ? themeColor : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isOk ? 'Saved in active workspace' : (action.errorMessage ?? 'Execution failed'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isOk ? textThemeColor.withValues(alpha: 0.8) : AppColors.error,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isOk) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.go(route);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: themeColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Typing indicator
  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _aiBubble,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(3),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: _aiBubbleBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChatTypingDots(),
              SizedBox(width: 8),
              Text(
                'LogsPad AI is thinking...',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _chatSubtext,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Floating Bottom Input Bar matching LogsPad theme
  Widget _buildChatInputBar(BuildContext context, bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // White Rounded Capsule for TextField
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sparkle Prompt Icon
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.auto_awesome_rounded, color: _brandAccent, size: 20),
                  ),

                  // Multiline Input Field
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: _chatText,
                      ),
                      cursorColor: _brandAccent,
                      decoration: const InputDecoration(
                        hintText: 'Ask LogsPad AI anything...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: _chatSubtext,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),

                  // Attachment Icon
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.onSurfaceVariant, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      _showAttachmentOptions(context);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Circular Brand Send Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: (isLoading || !_hasInputText) ? null : () => _sendMessage(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: (isLoading || !_hasInputText)
                      ? AppColors.surfaceContainerHigh
                      : _brandAccent,
                  shape: BoxShape.circle,
                  boxShadow: (isLoading || !_hasInputText)
                      ? null
                      : [
                          BoxShadow(
                            color: _brandAccent.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          _hasInputText ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
                          color: (isLoading || !_hasInputText)
                              ? AppColors.outline
                              : Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Quick Attachment Options Bottom Sheet
  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _chatText),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attachmentItem(
                    icon: Icons.check_box_rounded,
                    label: 'Task',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _sendMessage('Add high-priority task: ');
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.description_rounded,
                    label: 'Note',
                    color: const Color(0xFF4F46E5),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _sendMessage('Draft a note: ');
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.alarm_rounded,
                    label: 'Reminder',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _sendMessage('Remind me tomorrow at 9 AM: ');
                    },
                  ),
                  _attachmentItem(
                    icon: Icons.menu_book_rounded,
                    label: 'Book',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _sendMessage('Add book to read tracker: ');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _chatText)),
        ],
      ),
    );
  }
}

// ── Typing Dots Animation in Brand Indigo ──────────────────────────────────
class _ChatTypingDots extends StatefulWidget {
  const _ChatTypingDots();

  @override
  State<_ChatTypingDots> createState() => _ChatTypingDotsState();
}

class _ChatTypingDotsState extends State<_ChatTypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final val = math.sin((_controller.value * 2 * math.pi) + delay);
            final scale = (val + 1) / 2; // 0.0 to 1.0

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                color: Color.lerp(AppColors.outlineVariant, AppColors.primary, scale),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
