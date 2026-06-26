import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/locator.dart';
import '../../../core/providers.dart' show notesRepositoryProvider;
import '../../../data/models/annotation.dart';
import '../../../data/models/book_note.dart';
import '../../../data/repositories/notes_repository.dart';

class NotesState {
  final BookNote? bookNote;
  final List<Annotation> annotations;
  final bool isLoading;
  final String? error;

  const NotesState({
    this.bookNote,
    this.annotations = const [],
    this.isLoading = false,
    this.error,
  });

  NotesState copyWith({
    BookNote? bookNote,
    List<Annotation>? annotations,
    bool? isLoading,
    String? error,
  }) =>
      NotesState(
        bookNote: bookNote ?? this.bookNote,
        annotations: annotations ?? this.annotations,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// 当前打开的书 ID。在 ReaderPage 装配时通过 override 注入。
final currentBookIdProvider = Provider<String?>((_) => null);

final notesControllerProvider =
    StateNotifierProvider.autoDispose<NotesController, AsyncValue<NotesState>>(
  (ref) {
    final bookId = ref.watch(currentBookIdProvider);
    final repo = ref.watch(notesRepositoryProvider);
    return NotesController(bookId: bookId, repository: repo);
  },
);

class NotesController extends StateNotifier<AsyncValue<NotesState>> {
  final String? bookId;
  final NotesRepository repository;
  StreamSubscription<List<Annotation>>? _sub;
  static const _uuid = Uuid();

  NotesController({required this.bookId, required this.repository})
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    if (bookId == null) {
      state = const AsyncValue.data(NotesState());
      return;
    }
    try {
      // Subscribe synchronously so we don't miss emissions between the initial
      // getNoteByBook await and listen() registration.
      _sub = repository.watchAnnotations(bookId!).listen((annotations) async {
        final note = await repository.getNoteByBook(bookId!);
        if (!mounted) return;
        final current = state.value ?? const NotesState();
        state = AsyncValue.data(current.copyWith(
          bookNote: note,
          annotations: annotations,
          isLoading: false,
        ));
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addHighlight(
      EpubRangeLocator locator, HighlightColor color, String quote) async {
    final note = await _ensureBookNote();
    final now = DateTime.now();
    await repository.addAnnotation(Annotation(
      id: _uuid.v4(),
      bookNoteId: note.id,
      locator: locator,
      quote: quote,
      note: null,
      color: color,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> updateAnnotation(Annotation annotation) async {
    await repository.updateAnnotation(
        annotation.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> deleteAnnotation(String id) async {
    await repository.deleteAnnotation(id);
  }

  Future<BookNote> _ensureBookNote() async {
    final existing = await repository.getNoteByBook(bookId!);
    if (existing != null) return existing;
    return repository.createEmptyNote(
      id: _uuid.v4(),
      bookId: bookId!,
      bookTitle: '',
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
