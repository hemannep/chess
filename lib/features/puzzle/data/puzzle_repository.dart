import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_master/features/game/domain/chess_engine_service.dart';

enum PuzzleDifficulty { beginner, intermediate, advanced, expert }
enum PuzzleTheme {
  fork,
  pin,
  skewer,
  discoveredAttack,
  backRank,
  mateIn1,
  mateIn2,
  mateIn3,
  endgame
}

class PuzzleEntity {
  final String id;
  final String fen;
  final List<String> solution;
  final PuzzleDifficulty difficulty;
  final List<PuzzleTheme> themes;
  final int rating;
  final bool isDaily;

  const PuzzleEntity({
    required this.id,
    required this.fen,
    required this.solution,
    required this.difficulty,
    required this.themes,
    required this.rating,
    this.isDaily = false,
  });

  factory PuzzleEntity.fromMap(Map<String, dynamic> map) {
    final themeNames = List<String>.from(map['themes'] as List? ?? []);
    return PuzzleEntity(
      id: map['id'] as String? ?? '',
      fen: map['fen'] as String? ?? ChessEngineService.startingFen,
      solution: List<String>.from(map['solution'] as List? ?? []),
      difficulty: PuzzleDifficulty.values.firstWhere(
        (d) => d.name == (map['difficulty'] as String? ?? 'intermediate'),
        orElse: () => PuzzleDifficulty.intermediate,
      ),
      themes: themeNames
          .map((t) => PuzzleTheme.values.firstWhere((pt) => pt.name == t,
              orElse: () => PuzzleTheme.fork))
          .toList(),
      rating: map['rating'] as int? ?? 1500,
      isDaily: map['isDaily'] as bool? ?? false,
    );
  }
}

class PuzzleRepository {
  final FirebaseFirestore _db;
  PuzzleRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<PuzzleEntity?> getDailyPuzzle() async {
    try {
      final snap = await _db
          .collection('puzzles')
          .where('isDaily', isEqualTo: true)
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first;
      return PuzzleEntity.fromMap({...d.data(), 'id': d.id});
    } catch (_) {
      return null;
    }
  }

  Future<PuzzleEntity?> getRandomPuzzle({PuzzleDifficulty? difficulty}) async {
    try {
      Query<Map<String, dynamic>> query =
          _db.collection('puzzles').where('isDaily', isEqualTo: false);
      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty.name);
      }
      final snap = await query.limit(20).get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs[DateTime.now().millisecond % snap.docs.length];
      return PuzzleEntity.fromMap({...d.data(), 'id': d.id});
    } catch (_) {
      return null;
    }
  }

  Future<void> markPuzzleComplete(
      String uid, String puzzleId, bool solved, int thinkTimeMs) async {
    try {
      await _db
          .collection('puzzleCompletions')
          .doc(uid)
          .collection('completions')
          .doc(puzzleId)
          .set({
        'puzzleId': puzzleId,
        'solved': solved,
        'thinkTimeMs': thinkTimeMs,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

enum PuzzlePhase { loading, playing, correct, incorrect, reviewing }

class PuzzleState {
  final PuzzleEntity? puzzle;
  final PuzzlePhase phase;
  final String currentFen;
  final int solutionStep;
  final List<String> legalMoves;
  final String? selectedSquare;
  final int elapsedMs;

  const PuzzleState({
    this.puzzle,
    this.phase = PuzzlePhase.loading,
    this.currentFen = ChessEngineService.startingFen,
    this.solutionStep = 0,
    this.legalMoves = const [],
    this.selectedSquare,
    this.elapsedMs = 0,
  });

  PuzzleState copyWith({
    PuzzleEntity? puzzle,
    PuzzlePhase? phase,
    String? currentFen,
    int? solutionStep,
    List<String>? legalMoves,
    String? selectedSquare,
    int? elapsedMs,
    bool clearSelection = false,
  }) =>
      PuzzleState(
        puzzle: puzzle ?? this.puzzle,
        phase: phase ?? this.phase,
        currentFen: currentFen ?? this.currentFen,
        solutionStep: solutionStep ?? this.solutionStep,
        legalMoves: clearSelection ? const [] : legalMoves ?? this.legalMoves,
        selectedSquare:
            clearSelection ? null : selectedSquare ?? this.selectedSquare,
        elapsedMs: elapsedMs ?? this.elapsedMs,
      );
}

class PuzzleNotifier extends StateNotifier<PuzzleState> {
  final PuzzleRepository _repo;
  final ChessEngineService _engine;
  final String uid;

  PuzzleNotifier({
    required PuzzleRepository repo,
    required ChessEngineService engine,
    required this.uid,
  })  : _repo = repo,
        _engine = engine,
        super(const PuzzleState());

  Future<void> loadDailyPuzzle() async {
    state = const PuzzleState(phase: PuzzlePhase.loading);
    final puzzle = await _repo.getDailyPuzzle();
    if (puzzle == null) {
      await loadRandomPuzzle();
      return;
    }
    state = PuzzleState(
      puzzle: puzzle,
      phase: PuzzlePhase.playing,
      currentFen: puzzle.fen,
    );
  }

  Future<void> loadRandomPuzzle({PuzzleDifficulty? difficulty}) async {
    state = const PuzzleState(phase: PuzzlePhase.loading);
    final puzzle = await _repo.getRandomPuzzle(difficulty: difficulty);
    if (puzzle == null) {
      state = const PuzzleState(phase: PuzzlePhase.playing);
      return;
    }
    state = PuzzleState(
      puzzle: puzzle,
      phase: PuzzlePhase.playing,
      currentFen: puzzle.fen,
    );
  }

  void onSquareTapped(String square) {
    if (state.phase != PuzzlePhase.playing) return;
    final puzzle = state.puzzle;
    if (puzzle == null) return;

    if (state.selectedSquare != null && state.legalMoves.contains(square)) {
      _tryPuzzleMove(state.selectedSquare!, square);
      return;
    }
    final legal = _engine.getLegalMovesForSquare(state.currentFen, square);
    if (legal.isNotEmpty) {
      state = state.copyWith(selectedSquare: square, legalMoves: legal);
    } else {
      state = state.copyWith(clearSelection: true);
    }
  }

  void _tryPuzzleMove(String from, String to) {
    final puzzle = state.puzzle!;
    final step = state.solutionStep;
    if (step >= puzzle.solution.length) return;

    final expected = puzzle.solution[step];
    if (expected.length < 4) return;
    final expFrom = expected.substring(0, 2);
    final expTo = expected.substring(2, 4);

    final newFen = _engine.applyMove(state.currentFen, from, to);
    if (newFen == null) {
      state = state.copyWith(clearSelection: true);
      return;
    }

    if (from == expFrom && to == expTo) {
      final nextStep = step + 1;
      final isSolved = nextStep >= puzzle.solution.length;
      state = state.copyWith(
        currentFen: newFen,
        solutionStep: nextStep,
        phase: isSolved ? PuzzlePhase.correct : PuzzlePhase.playing,
        clearSelection: true,
      );
      if (isSolved) {
        _repo.markPuzzleComplete(uid, puzzle.id, true, state.elapsedMs);
      } else {
        Future.delayed(const Duration(milliseconds: 500), _playOpponentMove);
      }
    } else {
      state =
          state.copyWith(phase: PuzzlePhase.incorrect, clearSelection: true);
      Future.delayed(const Duration(milliseconds: 800), () {
        state = state.copyWith(phase: PuzzlePhase.playing);
      });
      _repo.markPuzzleComplete(uid, puzzle.id, false, state.elapsedMs);
    }
  }

  void _playOpponentMove() {
    final puzzle = state.puzzle!;
    final step = state.solutionStep;
    if (step >= puzzle.solution.length) return;
    final move = puzzle.solution[step];
    if (move.length < 4) return;
    final from = move.substring(0, 2);
    final to = move.substring(2, 4);
    final newFen = _engine.applyMove(state.currentFen, from, to);
    if (newFen != null) {
      state =
          state.copyWith(currentFen: newFen, solutionStep: step + 1);
    }
  }

  void showSolution() {
    final puzzle = state.puzzle;
    if (puzzle == null || state.solutionStep >= puzzle.solution.length) return;
    state = state.copyWith(phase: PuzzlePhase.reviewing);
  }
}
