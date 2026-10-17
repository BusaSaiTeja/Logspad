import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_logs/features/read/data/google_books_service.dart';
import 'package:my_logs/features/watch/data/anilist_anime_service.dart';
import 'package:my_logs/features/watch/data/tmdb_service.dart';
import 'package:my_logs/features/ai_assistant/data/ai_agent_service.dart';
import 'package:my_logs/features/ai_assistant/domain/models/ai_message.dart';
import 'package:my_logs/features/learning_paths/application/learning_path_providers.dart';
import 'package:my_logs/features/learning_paths/domain/models/learning_path.dart';
import 'package:my_logs/features/notes/application/note_providers.dart';
import 'package:my_logs/features/notes/domain/models/note_item.dart';
import 'package:my_logs/features/read/application/book_providers.dart';
import 'package:my_logs/features/read/domain/models/book_item.dart';
import 'package:my_logs/features/reminders/application/reminder_providers.dart';
import 'package:my_logs/features/reminders/domain/models/reminder_item.dart';
import 'package:my_logs/features/tasks/application/task_providers.dart';
import 'package:my_logs/features/tasks/domain/models/task_item.dart';
import 'package:my_logs/features/watch/application/media_providers.dart';
import 'package:my_logs/features/watch/domain/models/media_item.dart';
import 'package:my_logs/features/workspaces/application/workspace_providers.dart';
import 'package:uuid/uuid.dart';

class AiAssistantState {
  const AiAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.baseUrl = '',
    this.selectedProvider = 'groq',
  });

  final List<AiChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final String baseUrl;
  final String selectedProvider;

  AiAssistantState copyWith({
    List<AiChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? baseUrl,
    String? selectedProvider,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      baseUrl: baseUrl ?? this.baseUrl,
      selectedProvider: selectedProvider ?? this.selectedProvider,
    );
  }
}

class AiAssistantNotifier extends StateNotifier<AiAssistantState> {
  AiAssistantNotifier({
    required this.ref,
    required this.service,
  }) : super(const AiAssistantState()) {
    _loadBaseUrl();
  }

  final Ref ref;
  final AiAgentService service;
  static const _uuid = Uuid();

  Future<void> _loadBaseUrl() async {
    final url = await service.getBaseUrl();
    state = state.copyWith(baseUrl: url);
  }

  Future<void> updateBaseUrl(String newUrl) async {
    await service.setCustomEndpoint(newUrl);
    state = state.copyWith(baseUrl: newUrl.trim());
  }

  void setProvider(String provider) {
    state = state.copyWith(selectedProvider: provider);
  }

  void clearHistory() {
    state = state.copyWith(messages: const [], clearError: true);
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final userMsg = AiChatMessage(
      id: _uuid.v4(),
      role: AiMessageRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [...state.messages, userMsg];
    state = state.copyWith(
      messages: updatedMessages,
      isLoading: true,
      clearError: true,
    );

    try {
      final activeWs = ref.read(activeWorkspaceProvider);
      final activeWsId = activeWs?.id ?? '';
      final enabledFeatures = activeWs?.enabledFeatures ?? const ['notes', 'tasks', 'reminders'];

      final result = await service.sendPrompt(
        history: updatedMessages,
        activeWorkspaceId: activeWsId,
        enabledFeatures: enabledFeatures,
        provider: state.selectedProvider,
      );

      // Execute actions triggered by the AI agent
      final executedActions = <AiActionItem>[];
      final now = DateTime.now();

      for (final action in result.actions) {
        try {
          switch (action.type) {
            case AiActionType.createTask:
              final title = action.data['title'] as String? ?? 'Untitled Task';
              final dueDateRaw = action.data['dueDate'] as String?;
              DateTime? dueDate;
              if (dueDateRaw != null) {
                dueDate = DateTime.tryParse(dueDateRaw);
              }

              final priorityStr = (action.data['priority'] as String? ?? 'medium').toLowerCase();
              final priority = priorityStr == 'high'
                  ? TaskPriority.high
                  : priorityStr == 'low'
                      ? TaskPriority.low
                      : TaskPriority.medium;

              final taskItem = TaskItem(
                id: _uuid.v4(),
                title: title,
                description: action.data['description'] as String?,
                priority: priority,
                dueDate: dueDate,
                workspaceId: activeWsId,
                createdAt: now,
                updatedAt: now,
              );

              await ref.read(taskListProvider.notifier).add(taskItem);
              executedActions.add(
                action.copyWith(
                  isExecuted: true,
                  resultMessage: 'Created task: "$title"',
                ),
              );
              break;

            case AiActionType.createNote:
              final title = action.data['title'] as String? ?? 'Quick Note';
              final content = action.data['content'] as String? ?? '';
              final rawTags = action.data['tags'] as List<dynamic>? ?? [];
              final tags = rawTags.map((e) => e.toString()).toList();

              final noteItem = NoteItem(
                id: _uuid.v4(),
                title: title,
                content: content,
                tags: tags,
                workspaceId: activeWsId,
                createdAt: now,
                updatedAt: now,
              );

              await ref.read(noteListProvider.notifier).add(noteItem);
              executedActions.add(
                action.copyWith(
                  isExecuted: true,
                  resultMessage: 'Saved note: "$title"',
                ),
              );
              break;

            case AiActionType.createReminder:
              final title = action.data['title'] as String? ?? 'Reminder';
              final timeRaw = action.data['dateTime'] as String? ?? action.data['scheduledTime'] as String?;
              final scheduledTime = (timeRaw != null ? DateTime.tryParse(timeRaw) : null) ??
                  now.add(const Duration(hours: 1));

              final reminderItem = ReminderItem(
                id: _uuid.v4(),
                title: title,
                scheduledTime: scheduledTime,
                recurrence: ReminderRecurrence.none,
                createdAt: now,
                updatedAt: now,
              );

              await ref.read(reminderListProvider.notifier).add(reminderItem);
              executedActions.add(
                action.copyWith(
                  isExecuted: true,
                  resultMessage: 'Set reminder for ${DateFormat('MMM d, h:mm a').format(scheduledTime)}',
                ),
              );
              break;

            case AiActionType.addBook:
              var title = action.data['title'] as String? ?? 'Untitled Book';
              var author = action.data['author'] as String? ?? 'Unknown Author';
              final statusRaw = (action.data['status'] as String? ?? 'toRead').toLowerCase();
              BookStatus status = BookStatus.toRead;
              if (statusRaw.contains('reading')) {
                status = BookStatus.reading;
              } else if (statusRaw.contains('read') && !statusRaw.contains('toread')) {
                status = BookStatus.read;
              } else if (statusRaw.contains('hold')) {
                status = BookStatus.onHold;
              } else if (statusRaw.contains('drop')) {
                status = BookStatus.dropped;
              }

              var totalPages = action.data['totalPages'] is int
                  ? action.data['totalPages'] as int
                  : int.tryParse(action.data['totalPages']?.toString() ?? '');
              final rating = action.data['rating'] is num
                  ? (action.data['rating'] as num).toDouble()
                  : double.tryParse(action.data['rating']?.toString() ?? '');

              String? coverUrl = action.data['coverUrl'] as String?;
              String? synopsis = action.data['synopsis'] as String?;
              List<String> genres = (action.data['genres'] as List<dynamic>?)?.cast<String>() ?? [];

              // Automatically fetch rich book metadata from OpenLibrary / Google Books API
              try {
                final booksService = GoogleBooksService();
                final suggestions = await booksService.searchBooks(
                  title,
                  author: (author != 'Unknown Author' && author.isNotEmpty) ? author : null,
                );
                if (suggestions.isNotEmpty) {
                  final best = suggestions.first;
                  if (best.title.isNotEmpty) title = best.title;
                  if (author == 'Unknown Author' || author.isEmpty) {
                    author = best.author;
                  }
                  coverUrl ??= best.coverUrl;
                  totalPages ??= best.pageCount;
                  if (genres.isEmpty && best.categories.isNotEmpty) {
                    genres = best.categories;
                  }
                  synopsis ??= best.description;
                }
              } catch (e) {
                if (kDebugMode) print('[AiAssistant] Book metadata API fetch failed: $e');
              }

              final bookItem = BookItem(
                id: _uuid.v4(),
                title: title,
                author: author,
                status: status,
                coverUrl: coverUrl,
                synopsis: synopsis,
                genres: genres,
                totalPages: totalPages,
                rating: rating,
                notes: action.data['notes'] as String?,
                workspaceId: activeWsId,
                createdAt: now,
                updatedAt: now,
              );

              await ref.read(bookListProvider.notifier).add(bookItem);

              final updatedBookData = Map<String, dynamic>.from(action.data)
                ..['title'] = title
                ..['author'] = author
                ..['coverUrl'] = coverUrl
                ..['totalPages'] = totalPages
                ..['genres'] = genres
                ..['synopsis'] = synopsis;

              executedActions.add(
                action.copyWith(
                  data: updatedBookData,
                  isExecuted: true,
                  resultMessage: 'Added book: "$title" by $author${totalPages != null ? ' ($totalPages pages)' : ''}${coverUrl != null ? ' • Cover added' : ''}',
                ),
              );
              break;

            case AiActionType.addMedia:
              var title = action.data['title'] as String? ?? 'Untitled Media';
              final catRaw = (action.data['category'] as String? ?? 'movie').toLowerCase();
              MediaCategory category = MediaCategory.movie;
              if (catRaw.contains('anime')) {
                category = MediaCategory.anime;
              } else if (catRaw.contains('animat')) {
                category = MediaCategory.animatedMovie;
              }

              final statusRaw = (action.data['status'] as String? ?? 'planToWatch').toLowerCase();
              MediaStatus status = MediaStatus.planToWatch;
              if (statusRaw.contains('watching')) {
                status = MediaStatus.watching;
              } else if (statusRaw.contains('complete')) {
                status = MediaStatus.completed;
              } else if (statusRaw.contains('hold')) {
                status = MediaStatus.onHold;
              } else if (statusRaw.contains('drop')) {
                status = MediaStatus.dropped;
              }

              final rating = action.data['rating'] is num
                  ? (action.data['rating'] as num).toDouble()
                  : double.tryParse(action.data['rating']?.toString() ?? '');

              String? posterUrl = action.data['posterUrl'] as String?;
              int? year = action.data['year'] is int
                  ? action.data['year'] as int
                  : int.tryParse(action.data['year']?.toString() ?? '');
              String? synopsis = action.data['synopsis'] as String?;
              List<String> genres = (action.data['genres'] as List<dynamic>?)?.cast<String>() ?? [];
              String? language = action.data['language'] as String?;
              int? totalEpisodes = action.data['totalEpisodes'] is int
                  ? action.data['totalEpisodes'] as int
                  : int.tryParse(action.data['totalEpisodes']?.toString() ?? '');

              // Automatically fetch rich media metadata from TMDB / AniList APIs
              try {
                if (category == MediaCategory.anime) {
                  final animeService = AniListAnimeService();
                  final aniResults = await animeService.searchAnime(title);
                  if (aniResults.isNotEmpty) {
                    final best = aniResults.first;
                    title = best.title;
                    posterUrl ??= best.posterUrl;
                    year ??= best.year;
                    synopsis ??= best.synopsis;
                    if (genres.isEmpty && best.genres.isNotEmpty) {
                      genres = best.genres;
                    }
                    totalEpisodes ??= best.totalEpisodes;
                    language ??= 'Japanese';
                  } else {
                    final tmdbService = TmdbService();
                    final tvResults = await tmdbService.searchTv(title);
                    if (tvResults.isNotEmpty) {
                      final best = tvResults.first;
                      title = best.title;
                      posterUrl ??= best.posterUrl;
                      year ??= best.year;
                      synopsis ??= best.synopsis;
                      if (genres.isEmpty && best.genres.isNotEmpty) {
                        genres = best.genres;
                      }
                      language ??= best.language ?? 'Japanese';
                    }
                  }
                } else {
                  final tmdbService = TmdbService();
                  final movieResults = await tmdbService.searchMovies(title);
                  if (movieResults.isNotEmpty) {
                    final best = movieResults.first;
                    title = best.title;
                    posterUrl ??= best.posterUrl;
                    year ??= best.year;
                    synopsis ??= best.synopsis;
                    if (genres.isEmpty && best.genres.isNotEmpty) {
                      genres = best.genres;
                    }
                    language ??= best.language;
                  }
                }
              } catch (e) {
                if (kDebugMode) print('[AiAssistant] Media metadata API fetch failed: $e');
              }

              final mediaItem = MediaItem(
                id: _uuid.v4(),
                title: title,
                category: category,
                status: status,
                year: year,
                synopsis: synopsis,
                posterUrl: posterUrl,
                genres: genres,
                rating: rating,
                totalEpisodes: totalEpisodes,
                language: language,
                notes: action.data['notes'] as String?,
                workspaceId: activeWsId,
                createdAt: now,
                updatedAt: now,
              );

              await ref.read(mediaListProvider.notifier).add(mediaItem);

              final updatedMediaData = Map<String, dynamic>.from(action.data)
                ..['title'] = title
                ..['posterUrl'] = posterUrl
                ..['year'] = year
                ..['genres'] = genres
                ..['synopsis'] = synopsis
                ..['totalEpisodes'] = totalEpisodes
                ..['language'] = language;

              executedActions.add(
                action.copyWith(
                  data: updatedMediaData,
                  isExecuted: true,
                  resultMessage: 'Added ${category.label.toLowerCase()}: "$title"${year != null ? ' ($year)' : ''}${posterUrl != null ? ' • Poster added' : ''}',
                ),
              );
              break;

            case AiActionType.createLearningPath:
              final title = action.data['title'] as String? ?? 'New Learning Path';
              final desc = action.data['description'] as String?;
              final rawSteps = action.data['steps'] as List<dynamic>? ?? [];
              final steps = <PathStep>[];
              for (var i = 0; i < rawSteps.length; i++) {
                steps.add(
                  PathStep(
                    id: _uuid.v4(),
                    title: rawSteps[i].toString(),
                    order: i + 1,
                  ),
                );
              }

              final path = LearningPath(
                id: _uuid.v4(),
                title: title,
                description: desc,
                steps: steps,
                workspaceId: activeWsId,
                createdAt: now,
                updatedAt: now,
              );

              await ref.read(learningPathListProvider.notifier).add(path);
              executedActions.add(
                action.copyWith(
                  isExecuted: true,
                  resultMessage: 'Created learning path: "$title" (${steps.length} milestones)',
                ),
              );
              break;

            case AiActionType.unknown:
              executedActions.add(action);
              break;
          }
        } catch (actionErr) {
          executedActions.add(
            action.copyWith(
              isExecuted: false,
              errorMessage: actionErr.toString(),
            ),
          );
        }
      }

      final assistantMsg = AiChatMessage(
        id: _uuid.v4(),
        role: AiMessageRole.assistant,
        content: result.reply,
        actions: executedActions,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
      );
    } catch (e) {
      final errorMsg = AiChatMessage(
        id: _uuid.v4(),
        role: AiMessageRole.assistant,
        content: e.toString().contains('endpoint is not configured')
            ? 'The AI agent endpoint is not configured yet. Tap the Settings icon above to provide your Vercel API URL.'
            : 'Unable to connect to AI agent: ${e.toString().replaceAll('Exception:', '').trim()}',
        timestamp: DateTime.now(),
        isError: true,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final aiAssistantProvider =
    StateNotifierProvider<AiAssistantNotifier, AiAssistantState>((ref) {
  final service = ref.watch(aiAgentServiceProvider);
  return AiAssistantNotifier(ref: ref, service: service);
});
