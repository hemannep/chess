// Pure Dart domain types. No Flutter/Firebase imports.
// These are the single source of truth for all domain objects.

enum GameMode { local, online, bot }
enum GameStatus { waiting, inProgress, paused, completed, abandoned }
enum GameResult { whiteWins, blackWins, draw, ongoing }
enum ResultReason {
  checkmate,
  timeout,
  resign,
  agreement,
  stalemate,
  insufficientMaterial,
  fiftyMoveRule,
  repetition,
  abandoned,
}
enum TimeControlPreset { bullet1, blitz3, blitz5, rapid10, rapid15, custom }
enum BotDifficulty { easy, medium, hard, expert }
enum PlayerColor { white, black }
enum AchievementCategory { gameplay, social, streak, milestone, special }

// ─── Firestore string <-> enum helpers ───────────────────────────────────────
// Cloud Functions and Firestore store snake_case strings ('in_progress',
// 'white_wins'), while Dart enums use camelCase. These bridge the gap.

extension GameStatusX on GameStatus {
  static GameStatus fromString(String? s) => switch (s) {
        'waiting' => GameStatus.waiting,
        'in_progress' => GameStatus.inProgress,
        'paused' => GameStatus.paused,
        'completed' => GameStatus.completed,
        'abandoned' => GameStatus.abandoned,
        _ => GameStatus.inProgress,
      };
  String get toFirestore => switch (this) {
        GameStatus.waiting => 'waiting',
        GameStatus.inProgress => 'in_progress',
        GameStatus.paused => 'paused',
        GameStatus.completed => 'completed',
        GameStatus.abandoned => 'abandoned',
      };
}

extension GameResultX on GameResult {
  static GameResult fromString(String? s) => switch (s) {
        'white_wins' => GameResult.whiteWins,
        'black_wins' => GameResult.blackWins,
        'draw' => GameResult.draw,
        _ => GameResult.ongoing,
      };
  String get toFirestore => switch (this) {
        GameResult.whiteWins => 'white_wins',
        GameResult.blackWins => 'black_wins',
        GameResult.draw => 'draw',
        GameResult.ongoing => 'ongoing',
      };
}

extension ResultReasonX on ResultReason {
  static ResultReason? fromString(String? s) => switch (s) {
        'checkmate' => ResultReason.checkmate,
        'timeout' => ResultReason.timeout,
        'resign' => ResultReason.resign,
        'agreement' => ResultReason.agreement,
        'stalemate' => ResultReason.stalemate,
        'insufficient_material' => ResultReason.insufficientMaterial,
        'fifty_move_rule' => ResultReason.fiftyMoveRule,
        'repetition' => ResultReason.repetition,
        'abandoned' => ResultReason.abandoned,
        _ => null,
      };
  String get toFirestore => switch (this) {
        ResultReason.checkmate => 'checkmate',
        ResultReason.timeout => 'timeout',
        ResultReason.resign => 'resign',
        ResultReason.agreement => 'agreement',
        ResultReason.stalemate => 'stalemate',
        ResultReason.insufficientMaterial => 'insufficient_material',
        ResultReason.fiftyMoveRule => 'fifty_move_rule',
        ResultReason.repetition => 'repetition',
        ResultReason.abandoned => 'abandoned',
      };
}

// ─── Time control ────────────────────────────────────────────────────────────

class TimeControl {
  final int initialSeconds;
  final int incrementSeconds;

  const TimeControl({
    required this.initialSeconds,
    required this.incrementSeconds,
  });

  factory TimeControl.fromPreset(TimeControlPreset preset) {
    return switch (preset) {
      TimeControlPreset.bullet1 =>
        const TimeControl(initialSeconds: 60, incrementSeconds: 0),
      TimeControlPreset.blitz3 =>
        const TimeControl(initialSeconds: 180, incrementSeconds: 0),
      TimeControlPreset.blitz5 =>
        const TimeControl(initialSeconds: 300, incrementSeconds: 0),
      TimeControlPreset.rapid10 =>
        const TimeControl(initialSeconds: 600, incrementSeconds: 5),
      TimeControlPreset.rapid15 =>
        const TimeControl(initialSeconds: 900, incrementSeconds: 10),
      TimeControlPreset.custom =>
        const TimeControl(initialSeconds: 600, incrementSeconds: 0),
    };
  }

  String get displayString {
    final min = initialSeconds ~/ 60;
    if (incrementSeconds == 0) return '${min}m';
    return '${min}m+${incrementSeconds}s';
  }

  Map<String, dynamic> toMap() => {
        'initialSeconds': initialSeconds,
        'incrementSeconds': incrementSeconds,
      };

  factory TimeControl.fromMap(Map<String, dynamic> map) => TimeControl(
        initialSeconds: map['initialSeconds'] as int? ?? 600,
        incrementSeconds: map['incrementSeconds'] as int? ?? 0,
      );
}

// ─── Timer state ─────────────────────────────────────────────────────────────

class TimerState {
  final int remainingMs;
  final bool running;
  final int? lastStartedAt;

  const TimerState({
    required this.remainingMs,
    required this.running,
    this.lastStartedAt,
  });

  /// Client-side display time (accounts for elapsed since lastStartedAt).
  /// This means zero reads/writes for display — it's pure math.
  int get displayMs {
    if (!running || lastStartedAt == null) return remainingMs;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastStartedAt!;
    return (remainingMs - elapsed).clamp(0, remainingMs);
  }

  bool get isExpired => displayMs <= 0;

  Map<String, dynamic> toMap() => {
        'remainingMs': remainingMs,
        'running': running,
        'lastStartedAt': lastStartedAt,
      };

  factory TimerState.fromMap(Map<String, dynamic> map) => TimerState(
        remainingMs: map['remainingMs'] as int? ?? 600000,
        running: map['running'] as bool? ?? false,
        lastStartedAt: map['lastStartedAt'] as int?,
      );

  TimerState copyWith({int? remainingMs, bool? running, int? lastStartedAt}) =>
      TimerState(
        remainingMs: remainingMs ?? this.remainingMs,
        running: running ?? this.running,
        lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      );
}

// ─── Player info ─────────────────────────────────────────────────────────────

class PlayerInfo {
  final String uid;
  final String username;
  final String? avatarUrl;
  final int rating;
  final String? country;

  const PlayerInfo({
    required this.uid,
    required this.username,
    this.avatarUrl,
    required this.rating,
    this.country,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'avatarUrl': avatarUrl,
        'rating': rating,
        'country': country,
      };

  factory PlayerInfo.fromMap(Map<String, dynamic> map) => PlayerInfo(
        uid: map['uid'] as String,
        username: map['username'] as String? ?? 'Player',
        avatarUrl: map['avatarUrl'] as String?,
        rating: map['rating'] as int? ?? 1200,
        country: map['country'] as String?,
      );
}

// ─── Move record ─────────────────────────────────────────────────────────────

class MoveRecord {
  final int moveNumber;
  final String from;
  final String to;
  final String san;
  final String fen;
  final String? promotion;
  final int timestamp;
  final int? thinkTimeMs;

  const MoveRecord({
    required this.moveNumber,
    required this.from,
    required this.to,
    required this.san,
    required this.fen,
    this.promotion,
    required this.timestamp,
    this.thinkTimeMs,
  });

  Map<String, dynamic> toMap() => {
        'moveNumber': moveNumber,
        'from': from,
        'to': to,
        'san': san,
        'fen': fen,
        'promotion': promotion,
        'timestamp': timestamp,
        'thinkTimeMs': thinkTimeMs,
      };

  factory MoveRecord.fromMap(Map<String, dynamic> map) => MoveRecord(
        moveNumber: map['moveNumber'] as int? ?? 0,
        from: map['from'] as String,
        to: map['to'] as String,
        san: map['san'] as String? ?? '',
        fen: map['fen'] as String? ?? '',
        promotion: map['promotion'] as String?,
        timestamp: map['timestamp'] as int? ?? 0,
        thinkTimeMs: map['thinkTimeMs'] as int?,
      );
}

// ─── Game entity (top-level) ─────────────────────────────────────────────────

class GameEntity {
  final String id;
  final GameMode mode;
  final GameStatus status;
  final GameResult result;
  final ResultReason? resultReason;

  final PlayerInfo? white;
  final PlayerInfo? black;
  final List<String> playerUids;

  final TimeControl timeControl;
  final TimerState whiteTimer;
  final TimerState blackTimer;

  final String fen;
  final List<MoveRecord> moves;
  final String? pgn;

  final BotDifficulty? botDifficulty;
  final String? roomCode;

  final int createdAt;
  final int? startedAt;
  final int? endedAt;

  final String? drawOfferBy;

  const GameEntity({
    required this.id,
    required this.mode,
    required this.status,
    this.result = GameResult.ongoing,
    this.resultReason,
    this.white,
    this.black,
    required this.playerUids,
    required this.timeControl,
    required this.whiteTimer,
    required this.blackTimer,
    required this.fen,
    this.moves = const [],
    this.pgn,
    this.botDifficulty,
    this.roomCode,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.drawOfferBy,
  });

  PlayerColor get currentTurn {
    final parts = fen.split(' ');
    return parts.length > 1 && parts[1] == 'b'
        ? PlayerColor.black
        : PlayerColor.white;
  }

  bool get isOngoing =>
      status == GameStatus.inProgress || status == GameStatus.waiting;

  String get currentTurnUid => currentTurn == PlayerColor.white
      ? (white?.uid ?? '')
      : (black?.uid ?? '');

  GameEntity copyWith({
    GameStatus? status,
    GameResult? result,
    ResultReason? resultReason,
    TimerState? whiteTimer,
    TimerState? blackTimer,
    String? fen,
    List<MoveRecord>? moves,
    String? pgn,
    int? endedAt,
    String? drawOfferBy,
  }) {
    return GameEntity(
      id: id,
      mode: mode,
      status: status ?? this.status,
      result: result ?? this.result,
      resultReason: resultReason ?? this.resultReason,
      white: white,
      black: black,
      playerUids: playerUids,
      timeControl: timeControl,
      whiteTimer: whiteTimer ?? this.whiteTimer,
      blackTimer: blackTimer ?? this.blackTimer,
      fen: fen ?? this.fen,
      moves: moves ?? this.moves,
      pgn: pgn ?? this.pgn,
      botDifficulty: botDifficulty,
      roomCode: roomCode,
      createdAt: createdAt,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      drawOfferBy: drawOfferBy ?? this.drawOfferBy,
    );
  }
}

// ─── User / Profile ──────────────────────────────────────────────────────────

class UserSettings {
  final String boardTheme;
  final String pieceSet;
  final bool soundEnabled;
  final bool hapticEnabled;
  final bool showLegalMoves;
  final bool showCoordinates;
  final bool autoPromoteToQueen;
  final bool darkMode;

  const UserSettings({
    this.boardTheme = 'classic',
    this.pieceSet = 'cburnett',
    this.soundEnabled = true,
    this.hapticEnabled = true,
    this.showLegalMoves = true,
    this.showCoordinates = true,
    this.autoPromoteToQueen = false,
    this.darkMode = false,
  });

  Map<String, dynamic> toMap() => {
        'boardTheme': boardTheme,
        'pieceSet': pieceSet,
        'soundEnabled': soundEnabled,
        'hapticEnabled': hapticEnabled,
        'showLegalMoves': showLegalMoves,
        'showCoordinates': showCoordinates,
        'autoPromoteToQueen': autoPromoteToQueen,
        'darkMode': darkMode,
      };

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        boardTheme: map['boardTheme'] as String? ?? 'classic',
        pieceSet: map['pieceSet'] as String? ?? 'cburnett',
        soundEnabled: map['soundEnabled'] as bool? ?? true,
        hapticEnabled: map['hapticEnabled'] as bool? ?? true,
        showLegalMoves: map['showLegalMoves'] as bool? ?? true,
        showCoordinates: map['showCoordinates'] as bool? ?? true,
        autoPromoteToQueen: map['autoPromoteToQueen'] as bool? ?? false,
        darkMode: map['darkMode'] as bool? ?? false,
      );

  UserSettings copyWith({
    String? boardTheme,
    String? pieceSet,
    bool? soundEnabled,
    bool? hapticEnabled,
    bool? showLegalMoves,
    bool? showCoordinates,
    bool? autoPromoteToQueen,
    bool? darkMode,
  }) =>
      UserSettings(
        boardTheme: boardTheme ?? this.boardTheme,
        pieceSet: pieceSet ?? this.pieceSet,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
        showLegalMoves: showLegalMoves ?? this.showLegalMoves,
        showCoordinates: showCoordinates ?? this.showCoordinates,
        autoPromoteToQueen: autoPromoteToQueen ?? this.autoPromoteToQueen,
        darkMode: darkMode ?? this.darkMode,
      );
}

class UserEntity {
  final String uid;
  final String username;
  final String? email;
  final String? avatarUrl;
  final int rating;
  final int ratingPeak;
  final String? country;
  final int xp;
  final int level;
  final int streak;
  final DateTime? lastActiveDate;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final List<String> unlockedThemes;
  final List<String> earnedAchievements;
  final UserSettings settings;
  final bool isGuest;

  const UserEntity({
    required this.uid,
    required this.username,
    this.email,
    this.avatarUrl,
    this.rating = 1200,
    this.ratingPeak = 1200,
    this.country,
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.lastActiveDate,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.unlockedThemes = const ['classic'],
    this.earnedAchievements = const [],
    this.settings = const UserSettings(),
    this.isGuest = false,
  });

  double get winRate => gamesPlayed == 0 ? 0 : wins / gamesPlayed;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'username': username,
        'email': email,
        'avatarUrl': avatarUrl,
        'rating': rating,
        'ratingPeak': ratingPeak,
        'country': country,
        'xp': xp,
        'level': level,
        'streak': streak,
        'lastActiveDate': lastActiveDate?.toIso8601String(),
        'gamesPlayed': gamesPlayed,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'unlockedThemes': unlockedThemes,
        'earnedAchievements': earnedAchievements,
        'settings': settings.toMap(),
        'isGuest': isGuest,
      };

  factory UserEntity.fromMap(Map<String, dynamic> map) => UserEntity(
        uid: map['uid'] as String,
        username: map['username'] as String? ?? 'Player',
        email: map['email'] as String?,
        avatarUrl: map['avatarUrl'] as String?,
        rating: map['rating'] as int? ?? 1200,
        ratingPeak: map['ratingPeak'] as int? ?? 1200,
        country: map['country'] as String?,
        xp: map['xp'] as int? ?? 0,
        level: map['level'] as int? ?? 1,
        streak: map['streak'] as int? ?? 0,
        lastActiveDate: map['lastActiveDate'] != null
            ? DateTime.tryParse(map['lastActiveDate'] as String)
            : null,
        gamesPlayed: map['gamesPlayed'] as int? ?? 0,
        wins: map['wins'] as int? ?? 0,
        losses: map['losses'] as int? ?? 0,
        draws: map['draws'] as int? ?? 0,
        unlockedThemes:
            List<String>.from(map['unlockedThemes'] as List? ?? ['classic']),
        earnedAchievements:
            List<String>.from(map['earnedAchievements'] as List? ?? []),
        settings: UserSettings.fromMap(
            map['settings'] as Map<String, dynamic>? ?? {}),
        isGuest: map['isGuest'] as bool? ?? false,
      );

  UserEntity copyWith({
    String? username,
    String? avatarUrl,
    int? rating,
    int? ratingPeak,
    int? xp,
    int? level,
    int? streak,
    DateTime? lastActiveDate,
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? draws,
    List<String>? unlockedThemes,
    List<String>? earnedAchievements,
    UserSettings? settings,
  }) =>
      UserEntity(
        uid: uid,
        username: username ?? this.username,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        rating: rating ?? this.rating,
        ratingPeak: ratingPeak ?? this.ratingPeak,
        country: country,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        streak: streak ?? this.streak,
        lastActiveDate: lastActiveDate ?? this.lastActiveDate,
        gamesPlayed: gamesPlayed ?? this.gamesPlayed,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        draws: draws ?? this.draws,
        unlockedThemes: unlockedThemes ?? this.unlockedThemes,
        earnedAchievements: earnedAchievements ?? this.earnedAchievements,
        settings: settings ?? this.settings,
        isGuest: isGuest,
      );
}

// ─── Achievements ────────────────────────────────────────────────────────────

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int xpReward;
  final AchievementCategory category;
  final bool isSecret;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpReward,
    required this.category,
    this.isSecret = false,
  });
}

class Achievements {
  static const List<Achievement> all = [
    Achievement(
        id: 'first_win',
        title: 'First Blood',
        description: 'Win your first game',
        icon: '🩸',
        xpReward: 50,
        category: AchievementCategory.milestone),
    Achievement(
        id: 'ten_wins',
        title: 'Getting Serious',
        description: 'Win 10 games',
        icon: '🏅',
        xpReward: 100,
        category: AchievementCategory.milestone),
    Achievement(
        id: 'streak_3',
        title: 'On Fire',
        description: 'Play 3 days in a row',
        icon: '🔥',
        xpReward: 75,
        category: AchievementCategory.streak),
    Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Play 7 days in a row',
        icon: '⚡',
        xpReward: 200,
        category: AchievementCategory.streak),
    Achievement(
        id: 'puzzle_10',
        title: 'Puzzle Addict',
        description: 'Solve 10 daily puzzles',
        icon: '🧩',
        xpReward: 100,
        category: AchievementCategory.gameplay),
    Achievement(
        id: 'online_first',
        title: 'Connected',
        description: 'Play your first online game',
        icon: '🌐',
        xpReward: 50,
        category: AchievementCategory.social),
    Achievement(
        id: 'vs_hard_bot',
        title: 'Bot Slayer',
        description: 'Beat the Hard bot',
        icon: '🤖',
        xpReward: 200,
        category: AchievementCategory.gameplay),
    Achievement(
        id: 'rating_1400',
        title: 'Club Player',
        description: 'Reach 1400 rating',
        icon: '📈',
        xpReward: 300,
        category: AchievementCategory.milestone),
    Achievement(
        id: 'en_passant',
        title: 'En Passant!',
        description: 'Win a game using en passant',
        icon: '👻',
        xpReward: 100,
        category: AchievementCategory.gameplay,
        isSecret: true),
  ];

  static Achievement? findById(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}

// ─── XP System ───────────────────────────────────────────────────────────────

class XpSystem {
  static const List<int> levelThresholds = [
    0, 100, 250, 500, 900, 1400, 2000, 2800, 3700, 5000,
    6500, 8200, 10000, 12000, 14500, 17000, 20000, 23500, 27000, 31000,
  ];

  static int levelForXp(int xp) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  static int xpToNextLevel(int xp) {
    final level = levelForXp(xp);
    if (level >= levelThresholds.length) return 0;
    return levelThresholds[level] - xp;
  }

  static double progressToNextLevel(int xp) {
    final level = levelForXp(xp);
    if (level >= levelThresholds.length) return 1.0;
    final current = levelThresholds[level - 1];
    final next = levelThresholds[level];
    return (xp - current) / (next - current);
  }

  static int xpForWin(GameMode mode, BotDifficulty? bot) {
    return switch (mode) {
      GameMode.online => 50,
      GameMode.bot => switch (bot) {
          BotDifficulty.easy => 10,
          BotDifficulty.medium => 20,
          BotDifficulty.hard => 40,
          BotDifficulty.expert => 80,
          null => 10,
        },
      GameMode.local => 5,
    };
  }
}
