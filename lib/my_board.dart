// my_board
import 'my_chess_piece.dart';
import 'my_move_rule.dart';

// Log logic
class CaptureLog {
  final int row;
  final int col;
  final MyChessPiece piece;
  CaptureLog({required this.row, required this.col, required this.piece});

  // Thêm toJson và fromJson để có thể truyền qua isolate nếu cần (ví dụ trong MoveLog)
  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'piece': piece.toJson(),
  };

  static CaptureLog fromJson(Map<String, dynamic> json) => CaptureLog(
    row: json['row'],
    col: json['col'],
    piece: MyChessPiece.fromJson(json['piece']),
  );
}

class TransformLog {
  final int row;
  final int col;
  final MyChessPiece from;
  final MyChessPiece to;
  TransformLog({
    required this.row,
    required this.col,
    required this.from,
    required this.to,
  });

  // Thêm toJson và fromJson để có thể truyền qua isolate nếu cần (ví dụ trong MoveLog)
  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'from': from.toJson(),
    'to': to.toJson(),
  };
  static TransformLog fromJson(Map<String, dynamic> json) => TransformLog(
    row: json['row'],
    col: json['col'],
    from: MyChessPiece.fromJson(json['from']),
    to: MyChessPiece.fromJson(json['to']),
  );
}

class MoveLog {
  final bool isWhite;
  final MyChessPiece from;
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final List<CaptureLog> captured;
  final List<TransformLog> transform;
  MoveLog({
    required this.isWhite,
    required this.from,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.captured = const [],
    this.transform = const [],
  });

  Map<String, dynamic> toJson() => {
    'isWhite': isWhite,
    'from': from.toJson(),
    'fromRow': fromRow,
    'fromCol': fromCol,
    'toRow': toRow,
    'toCol': toCol,
    'captured': captured.map((e) => e.toJson()).toList(),
    'transform': transform.map((e) => e.toJson()).toList(),
  };

  static MoveLog fromJson(Map<String, dynamic> json) => MoveLog(
    isWhite: json['isWhite'],
    from: MyChessPiece.fromJson(json['from']),
    fromRow: json['fromRow'],
    fromCol: json['fromCol'],
    toRow: json['toRow'],
    toCol: json['toCol'],
    captured:
        (json['captured'] as List).map((e) => CaptureLog.fromJson(e)).toList(),
    transform:
        (json['transform'] as List)
            .map((e) => TransformLog.fromJson(e))
            .toList(),
  );
}

// Special Rule
class ChessPromoted {
  MyChessPiece piece;
  int fromZone;
  int toZone;
  List<MyChessPiece> listChess;
  ChessPromoted({
    required this.piece,
    this.fromZone = 0,
    this.toZone = 0,
    this.listChess = const [],
  });

  Map<String, dynamic> toJson() => {
    'chessPiece': piece.toJson(),
    'fromZone': fromZone,
    'toZone': toZone,
    'listChess': listChess.map((e) => e.toJson()).toList(),
  };
  static ChessPromoted fromJson(Map<String, dynamic> json) => ChessPromoted(
    piece: MyChessPiece.fromJson(json['chessPiece']),
    fromZone: json['fromZone'],
    toZone: json['toZone'],
    listChess:
        (json['listChess'] as List)
            .map((e) => MyChessPiece.fromJson(e))
            .toList(),
  );
}

class ChessLimit {
  MyChessPiece piece;
  String type;
  int fromZone;
  int toZone;
  ChessLimit({
    required this.piece,
    this.type = "",
    this.fromZone = 0,
    this.toZone = 0,
  });
  Map<String, dynamic> toJson() => {
    'piece': piece.toJson(),
    'type': type,
    'fromZone': fromZone,
    'toZone': toZone,
  };

  static ChessLimit fromJson(Map<String, dynamic> json) => ChessLimit(
    piece: MyChessPiece.fromJson(json['piece']),
    type: json['type'] ?? "",
    fromZone: json['fromZone'],
    toZone: json['toZone'],
  );
}

// Chess Board Logic
class ChessBoard {
  int maxRow;
  int maxCol;
  int? selectRow;
  int? selectCol;
  int? toRow;
  int? toCol;
  bool whiteTurn = true;
  bool? whiteWin;
  MyChessPiece? movingPiece;
  List<CaptureLog> capturedList = [];
  List<TransformLog> transformList = [];
  List<StepMove> validMoves = [];
  List<StepMove> hintMoves = [];
  List<MoveLog> moveHistory = [];
  double whiteValue = 0;
  double whiteBonusValue = 1;
  double whiteStrategicValue = 0;
  double blackValue = 0;
  double blackBonusValue = 1;
  double blackStrategicValue = 0;
  late List<List<MyChessPiece?>> board;
  late List<List<int>> zone;
  List<ChessPromoted> chessPromoted = [];
  List<ChessLimit> chessLimit = [];

  ChessBoard(this.maxRow, this.maxCol) {
    board = List.generate(maxRow, (_) => List.filled(maxCol, null));
    zone = List.generate(maxRow, (_) => List.filled(maxCol, 0));
  }

  ///
  List<MyChessPiece> getAllTransforms(
    int row,
    int col, [
    int moveBonus = 0,
    int captureBonus = 0,
    int? toRow,
    int? toCol,
  ]) {
    final piece = board[row][col];
    if (piece == null) return [];
    List<MyChessPiece> result = [];
    for (final transform in piece.listTransform.whereType<TransformPiece>()) {
      int total = 0;
      final type = transform.type;

      if (type.contains('move')) total += piece.moveCount + moveBonus;
      if (type.contains('capture')) total += piece.captureCount + captureBonus;
      if (type.contains('turn')) total += piece.turnCount;

      if (total >= transform.count) {
        result.add(piece.createTransformed(transform.name, false));
      }
    }
    final newLocation = (toRow != null && toCol != null);
    for (final promoted in chessPromoted) {
      if (piece.name == promoted.piece.name &&
          piece.isWhite == promoted.piece.isWhite &&
          zone[newLocation ? toRow : row][newLocation ? toCol : col] >=
              promoted.fromZone &&
          zone[newLocation ? toRow : row][newLocation ? toCol : col] <=
              promoted.toZone) {
        for (final promotedTo in promoted.listChess) {
          result.add(piece.createTransformed(promotedTo.name, false));
        }
      }
    }
    return result;
  }

  bool isMoveAllowedByLimit(MyChessPiece piece, int toRow, int toCol) {
    final applicableLimits = chessLimit.where(
      (limit) =>
          limit.piece.name == piece.name &&
          limit.piece.isWhite == piece.isWhite,
    );

    if (applicableLimits.isEmpty) {
      return true;
    }

    final toZoneValue = zone[toRow][toCol];
    return applicableLimits.any(
      (limit) => toZoneValue >= limit.fromZone && toZoneValue <= limit.toZone,
    );
  }

  //tính giá trị quân
  void calculatePieceValue(MyChessPiece pieceCalculate) {
    MyChessPiece piece = pieceCalculate;
    if (pieceCalculate.trueForm.isNotEmpty) {
      piece = pieceCalculate.createTransformed(pieceCalculate.trueForm, false);
    }
    Set<String> visited = {};
    List<MyChessPiece> queue = [piece];
    double value = 5 + piece.getTrueValueMoves(maxRow, maxCol);
    piece.bonusValue = 0;
    if (!piece.canMoveAgain) value *= 2;
    double totalValue = value;
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final key = '${current.isWhite}_${current.name}';
      if (visited.contains(key)) continue;
      visited.add(key);
      for (final transform
          in current.listTransform.whereType<TransformPiece>()) {
        int totalCond = 0;
        final type = transform.type;
        if (type.contains('move')) totalCond++;
        if (type.contains('capture')) totalCond++;
        if (type.contains('turn')) totalCond++;
        if (totalCond > 0) {
          final transformed = current.createTransformed(transform.name, false);
          double tValue = transformed.getTrueValueMoves(maxRow, maxCol);
          if (!transformed.canMoveAgain) {
            tValue /= 2;
          }
          totalValue += tValue * (totalCond / (transform.count + 1));
          queue.add(transformed);
          piece.bonusValue +=
              (transformed.canMoveAgain && !transformed.isPriority) ? 0.1 : 0.0;
        }
      }
      for (final promoted in chessPromoted) {
        if (current.name == promoted.piece.name &&
            current.isWhite == promoted.piece.isWhite) {
          // Tạo danh sách các lựa chọn phong cấp và giá trị của chúng
          List<Map<String, dynamic>> promotionOptions = [];
          for (final promotedTo in promoted.listChess) {
            final promotedPiece = MyChessPiece(
              promotedTo.isWhite,
              promotedTo.name,
            );
            double pValue = promotedPiece.getTrueValueMoves(maxRow, maxCol);
            promotionOptions.add({'piece': promotedPiece, 'value': pValue});
          }
          // Sắp xếp các lựa chọn theo giá trị giảm dần
          promotionOptions.sort(
            (a, b) => (b['value'] as double).compareTo(a['value'] as double),
          );
          final int numOptions = promotionOptions.length;
          final double zoneFactor =
              4 * (8 - (promoted.toZone - promoted.fromZone + 1));
          // Cộng dồn giá trị với trọng số giảm dần
          for (int i = 0; i < numOptions; i++) {
            final option = promotionOptions[i];
            final MyChessPiece promotedPiece = option['piece'];
            final double pValue = option['value'];
            final double weight = (numOptions - i) / numOptions;
            totalValue += ((value + pValue) / 2 / zoneFactor) * weight;
            queue.add(promotedPiece);
          }
        }
      }
    }
    pieceCalculate.value = totalValue;
    pieceCalculate.bonusValue = piece.bonusValue;
  }

  void plusPieceValue(MyChessPiece piece) {
    if (piece.isWhite) {
      whiteValue += piece.value;
      whiteBonusValue += piece.bonusValue;
    } else {
      blackValue += piece.value;
      blackBonusValue += piece.bonusValue;
    }
  }

  //khởi tạo giá trị quân lúc đầu
  //tính giá trị bàn cờ
  void getBoardValueSummary(bool firstTime) {
    if (firstTime) {
      for (final promoted in chessPromoted) {
        for (final promotedTo in promoted.listChess) {
          calculatePieceValue(promotedTo);
        }
      }
    }
    whiteValue = 0;
    whiteBonusValue = 1;
    whiteStrategicValue = 0;
    blackValue = 0;
    blackBonusValue = 1;
    blackStrategicValue = 0;
    for (int r = 0; r < maxRow; r++) {
      for (int c = 0; c < maxCol; c++) {
        final piece = board[r][c];
        if (piece == null) continue;
        if (firstTime) {
          calculatePieceValue(piece);
        }
        if (piece.isWhite) {
          whiteValue += piece.value;
          whiteBonusValue += piece.bonusValue;
        } else {
          blackValue += piece.value;
          blackBonusValue += piece.bonusValue;
        }
      }
    }
    for (int r = 0; r < maxRow; r++) {
      for (int c = 0; c < maxCol; c++) {
        final piece = board[r][c];
        if (piece == null) continue;
        piece.setStrategicValueMoves(r, c, this);
        if (piece.isWhite) {
          whiteStrategicValue += piece.strategicValue;
        } else {
          blackStrategicValue += piece.strategicValue;
        }
      }
    }
  }

  // lấy giá trị quân cờ(chủ yếu để so sánh)
  double getPieceValue(MyChessPiece piece, [bool useStrategicValue = false]) {
    double pieceValue;
    double pieceBonusValue;
    if (piece.isWhite) {
      if (useStrategicValue) {
        pieceValue = piece.value + piece.strategicValue;
        pieceBonusValue = (whiteValue + whiteStrategicValue) * piece.bonusValue;
      } else {
        pieceValue = piece.value;
        pieceBonusValue = whiteValue * piece.bonusValue;
      }
    } else {
      if (useStrategicValue) {
        pieceValue = piece.value + piece.strategicValue;
        pieceBonusValue = (blackValue + blackStrategicValue) * piece.bonusValue;
      } else {
        pieceValue = piece.value;
        pieceBonusValue = blackValue * piece.bonusValue;
      }
    }
    return pieceValue + pieceBonusValue;
  }

  // lấy giá trị bàn cờ(chủ yếu để so sánh)
  double getTeamValue(bool isWhite, [useStrategicValue = true]) {
    double wValue = whiteValue;
    double bValue = blackValue;
    double returnValue;
    if (useStrategicValue) {
      wValue += whiteStrategicValue;
      bValue += blackStrategicValue;
    }
    if (whiteWin != null) {
      returnValue =
          isWhite == whiteWin!
              ? isWhite
                  ? (wValue * whiteBonusValue) + 1000000
                  : (bValue * blackBonusValue) + 1000000
              : isWhite
              ? (wValue * whiteBonusValue) - 1000000
              : (bValue * blackBonusValue) - 1000000;
    } else {
      returnValue =
          isWhite ? wValue * whiteBonusValue : bValue * blackBonusValue;
    }
    return returnValue;
  }

  ///
  bool hasPriority() {
    for (var row in board) {
      for (var piece in row) {
        if (piece != null && piece.isWhite == whiteTurn && piece.isPriority) {
          return true;
        }
      }
    }
    return false;
  }

  /// Kiểm tra xem còn nước đi hợp lệ nào không cho người chơi hiện tại.

  bool hasValidMoves() {
    bool priority = hasPriority();
    for (int r = 0; r < maxRow; r++) {
      for (int c = 0; c < maxCol; c++) {
        final piece = board[r][c];
        // Kiểm tra xem có quân cờ nào của người chơi hiện tại không
        if (piece != null &&
            piece.isWhite == whiteTurn &&
            piece.isPriority == priority) {
          // Lấy tất cả các nước đi hợp lệ của quân cờ đó
          List<StepMove> moves = piece.getValidMoves(this, r, c);
          // Nếu tìm thấy một nước đi hợp lệ, trả về true ngay lập tức
          if (moves.isNotEmpty) {
            return true;
          }
        }
      }
    }
    // Nếu lặp qua hết bàn cờ mà không tìm thấy nước đi nào, trả về false
    return false;
  }

  bool isMoveTarget(int row, int col) {
    return validMoves.any((move) => move.r == row && move.c == col);
  }

  bool isCaptureMove(int row, int col) {
    // Rewritten with a block body to be more explicit for the static analyzer,
    // which was incorrectly flagging an issue here. The logic is unchanged.
    return validMoves.any((move) {
      if (move.r == row && move.c == col) {
        return move.capture != null;
      }
      return false;
    });
  }

  bool isHintMove(int row, int col) {
    return hintMoves.any((move) => move.r == row && move.c == col);
  }

  void select(int row, int col, MyChessPiece piece) {
    validMoves = piece.getValidMoves(this, row, col);
    if (piece.listMove.isEmpty) {
      clearSelect();
      return;
    }
    selectRow = row;
    selectCol = col;
  }

  void clearSelect() {
    selectRow = null;
    selectCol = null;
    toRow = null;
    toCol = null;
    validMoves.clear();
    hintMoves.clear();
  }

  void clearHistory() {
    moveHistory.clear();
    transformList.clear();
    capturedList.clear();
  }

  void moveAction(
    int row,
    int col,
    StepMove matchedMove,
    MyChessPiece? transform, [
    bool quickBot = false,
  ]) {
    if (selectRow == null || selectCol == null) return;
    movingPiece = board[selectRow!][selectCol!];
    if (movingPiece == null) return;
    toRow = row;
    toCol = col;

    if (matchedMove.capture == null) {
      movingPiece!.moveCount++;
    } else {
      for (var capture in matchedMove.capture ?? []) {
        final capturedPiece = board[capture.r][capture.c];
        if (capturedPiece != null) {
          if (!quickBot) {
            capturedList.add(
              CaptureLog(row: capture.r, col: capture.c, piece: capturedPiece),
            );
          }
          if (whiteWin == null && capturedPiece.isImportant) {
            whiteWin = !capturedPiece.isWhite;
          }
          board[capture.r][capture.c] = null;
          movingPiece!.captureCount++;
        }
      }
    }
    //biến hình nếu có
    if (transform != null) {
      if (!quickBot) {
        transformList.add(
          TransformLog(
            row: toRow!,
            col: toCol!,
            from: movingPiece!,
            to: transform,
          ),
        );
      }
      if (transform.trueForm != "") calculatePieceValue(transform);
      if (transform.description == "") {
        transform.description = movingPiece!.description;
      }
      board[toRow!][toCol!] = transform;
    } else {
      board[toRow!][toCol!] = movingPiece;
    }
    board[selectRow!][selectCol!] = null;

    //nếu không biến hình, dạng biến hình không đi tiếp thì turnPlus và chuyển lược
    if (transform == null || !transform.canMoveAgain) {
      turnPlus(quickBot);
      if (!quickBot) updateHistory();
      whiteTurn = !whiteTurn;
      getBoardValueSummary(false);
    } else {
      if (!quickBot) updateHistory();
      getBoardValueSummary(false);
      select(row, col, transform);
    }
    if (whiteWin == null) {
      if (!hasValidMoves()) whiteWin = !whiteTurn;
      if (getTeamValue(true) <= 0) whiteWin = false;
      if (getTeamValue(false) <= 0) whiteWin = true;
    }
  }

  void updateHistory() {
    moveHistory.add(
      MoveLog(
        isWhite: whiteTurn,
        from: movingPiece!,
        fromRow: selectRow!,
        fromCol: selectCol!,
        toRow: toRow!,
        toCol: toCol!,
        captured: List<CaptureLog>.from(capturedList),
        transform: List<TransformLog>.from(transformList),
      ),
    );
    movingPiece = null;
    capturedList.clear();
    transformList.clear();
    validMoves.clear();
    clearSelect();
  }

  // cộng giá trị turn cho các quân cờ. đủ thì biến hình
  void turnPlus([noHistory = false]) {
    for (int r = 0; r < maxRow; r++) {
      for (int c = 0; c < maxCol; c++) {
        MyChessPiece? piece = board[r][c];
        if (piece != null) {
          piece.turnCount++;
          final turnTransforms =
              piece.listTransform
                  .whereType<TransformPiece>()
                  .where(
                    (t) =>
                        t.type.contains('turn') && piece.turnCount >= t.count,
                  )
                  .toList();
          if (turnTransforms.isNotEmpty) {
            final oldPiece = piece;
            final newPiece = piece.createTransformed(
              turnTransforms.first.name,
              false,
            );
            if (!noHistory) {
              transformList.add(
                TransformLog(row: r, col: c, from: oldPiece, to: newPiece),
              );
            }
            board[r][c] = newPiece;
          }
        }
      }
    }
  }

  void undoMove() {
    if (moveHistory.isEmpty) return;
    whiteWin = null;
    MoveLog lastMove = moveHistory.removeLast();
    for (var t in lastMove.transform.reversed) {
      board[t.row][t.col] = t.from;
    }
    if (lastMove.captured.isEmpty) {
      lastMove.from.moveCount--;
    }
    for (int r = 0; r < maxRow; r++) {
      for (int c = 0; c < maxCol; c++) {
        MyChessPiece? piece = board[r][c];
        if (piece != null && piece.turnCount > 0) {
          piece.turnCount--;
        }
      }
    }
    board[lastMove.fromRow][lastMove.fromCol] = lastMove.from;
    board[lastMove.toRow][lastMove.toCol] = null;
    for (var capture in lastMove.captured) {
      board[lastMove.fromRow][lastMove.fromCol]!.captureCount--;
      board[capture.row][capture.col] = capture.piece;
    }
    if (whiteTurn != lastMove.isWhite) {
      whiteTurn = lastMove.isWhite;
    }
    clearSelect();
    getBoardValueSummary(false);
  }

  ChessBoard copy() {
    return ChessBoard.fromJson(toJson());
  }

  /////////////
  void useBoard(String name) {
    switch (name) {
      /// Normal Chess Piece ///
      case 'custom':
        // zone
        for (int i = 0; i < maxCol; i++) {
          zone[0][i] = -2;
          zone[maxRow - 1][i] = 2;
          if (maxRow >= 4) {
            zone[1][i] = -1;
            zone[maxRow - 2][i] = 1;
          }
        }
        int midCol1 = ((maxCol - 1) / 2).floor();
        int midCol2 = ((maxCol - 1) / 2).ceil();
        zone[0][midCol1] = -3;
        zone[0][midCol2] = -3;
        zone[maxRow - 1][midCol1] = 3;
        zone[maxRow - 1][midCol2] = 3;
        break;
      default:
        // size
        maxCol = 8;
        maxRow = 8;
        // zone
        for (int i = 0; i < 8; i++) {
          zone[0][i] = -2;
          zone[1][i] = -1;
          zone[6][i] = 1;
          zone[7][i] = 2;
        }
        zone[0][3] = zone[0][4] = -3;
        zone[7][3] = zone[7][4] = 3;
        // chess promoted
        chessPromoted = [
          ChessPromoted(
            piece: MyChessPiece(true, 'round_pawn'),
            fromZone: -3,
            toZone: -2,
            listChess: [
              MyChessPiece(true, 'rook'),
              MyChessPiece(true, 'knight'),
              MyChessPiece(true, 'bishop'),
              MyChessPiece(true, 'queen'),
            ],
          ),
          ChessPromoted(
            piece: MyChessPiece(false, 'round_pawn'),
            fromZone: 2,
            toZone: 3,
            listChess: [
              MyChessPiece(false, 'rook'),
              MyChessPiece(false, 'knight'),
              MyChessPiece(false, 'bishop'),
              MyChessPiece(false, 'queen'),
            ],
          ),
        ];
        // board
        board[0][0] = MyChessPiece(false, 'rook');
        board[0][1] = MyChessPiece(false, 'knight');
        board[0][2] = MyChessPiece(false, 'bishop');
        board[0][3] = MyChessPiece(false, 'queen');
        board[0][4] = MyChessPiece(false, 'king');
        board[0][5] = MyChessPiece(false, 'bishop');
        board[0][6] = MyChessPiece(false, 'knight');
        board[0][7] = MyChessPiece(false, 'rook');
        for (int i = 0; i < 8; i++) {
          board[1][i] = MyChessPiece(false, 'quick_round_pawn');
        }
        board[7][0] = MyChessPiece(true, 'rook');
        board[7][1] = MyChessPiece(true, 'knight');
        board[7][2] = MyChessPiece(true, 'bishop');
        board[7][3] = MyChessPiece(true, 'queen');
        board[7][4] = MyChessPiece(true, 'king');
        board[7][5] = MyChessPiece(true, 'bishop');
        board[7][6] = MyChessPiece(true, 'knight');
        board[7][7] = MyChessPiece(true, 'rook');
        for (int i = 0; i < 8; i++) {
          board[6][i] = MyChessPiece(true, 'quick_round_pawn');
        }
    }
  }

  String toQuickCompare() {
    String QC = "";
    QC += whiteTurn ? "6" : "9";
    for (int r = 0; r < maxRow; r++) {
      for (int c = 0; c < maxCol; c++) {
        MyChessPiece? piece = board[r][c];
        if (piece != null) {
          QC += "1${piece.name}";
          QC += piece.isWhite ? "6" : "9";
          QC += piece.moveTransform ? "${piece.moveCount}" : "0";
          QC += piece.captureTransform ? "${piece.captureCount}" : "0";
          QC += piece.turnTransform ? "${piece.turnCount}1" : "01";
        } else {
          QC += "0";
        }
      }
    }
    return QC;
  }

  Map<String, dynamic> toJson() => {
    'rows': maxRow,
    'cols': maxCol,
    'whiteTurn': whiteTurn,
    'whiteWin': whiteWin,
    'zone': zone,
    'board': board.map((r) => r.map((p) => p?.toJson()).toList()).toList(),
    'chessPromoted': chessPromoted.map((e) => e.toJson()).toList(),
    'chessLimit': chessLimit.map((e) => e.toJson()).toList(),
    'moveHistory': moveHistory.map((e) => e.toJson()).toList(),
  };

  static ChessBoard fromJson(Map<String, dynamic> json) {
    final board = ChessBoard(json['rows'], json['cols']);
    board.whiteTurn = json['whiteTurn'] ?? true;
    // whiteWin có thể là null, nên gán trực tiếp
    board.whiteWin = json['whiteWin'];
    board.zone = List<List<int>>.from(
      (json['zone'] as List).map((r) => List<int>.from(r)),
    );
    board.board =
        (json['board'] as List)
            .map<List<MyChessPiece?>>(
              (row) =>
                  (row as List)
                      .map<MyChessPiece?>(
                        (p) => p == null ? null : MyChessPiece.fromJson(p),
                      )
                      .toList(),
            )
            .toList();
    board.chessPromoted =
        (json['chessPromoted'] as List)
            .map((e) => ChessPromoted.fromJson(e))
            .toList();
    if (json['chessLimit'] != null) {
      board.chessLimit =
          (json['chessLimit'] as List)
              .map((e) => ChessLimit.fromJson(e))
              .toList();
    }
    if (json['moveHistory'] != null) {
      board.moveHistory =
          (json['moveHistory'] as List)
              .map((e) => MoveLog.fromJson(e))
              .toList();
    }
    return board;
  }

  void _getChainedMoves(
    int currentRow,
    int currentCol,
    MyChessPiece currentPiece,
    Set<String> visitedStates,
    List<StepMove> currentChain,
    int depth,
  ) {
    // Giới hạn độ sâu để tránh vòng lặp vô hạn hoặc tính toán quá lâu
    if (depth > 3) return; // Ví dụ: giới hạn 3 bước biến hình liên tiếp

    // Tạo bản sao của bàn cờ để thử nước đi mà không ảnh hưởng đến trạng thái hiện tại
    ChessBoard tempBoard = this.copy();
    tempBoard.board[currentRow][currentCol] =
        currentPiece; // Đặt quân cờ hiện tại vào vị trí
    tempBoard.selectRow = currentRow;
    tempBoard.selectCol = currentCol;

    List<StepMove> possibleMoves = currentPiece.getValidMoves(
      tempBoard,
      currentRow,
      currentCol,
    );

    for (var move in possibleMoves) {
      // Đánh dấu ô đích như là một nước đi gợi ý
      hintMoves.add(move);

      // Tạo bản sao bàn cờ mới cho mỗi nước đi để đảm bảo độc lập
      ChessBoard nextBoard = tempBoard.copy();

      // Giả lập việc di chuyển quân cờ
      nextBoard.selectRow = currentRow;
      nextBoard.selectCol = currentCol;
      nextBoard.movingPiece =
          nextBoard.board[currentRow][currentCol]; // Lấy quân cờ từ tempBoard

      // Xử lý việc bắt quân nếu có
      if (move.capture != null) {
        for (var capture in move.capture!) {
          if (nextBoard.board[capture.r][capture.c] != null) {
            nextBoard.board[capture.r][capture.c] = null;
          }
        }
      }

      // Lấy các dạng biến hình có thể xảy ra tại ô đích
      final moveBonus = (move.capture == null) ? 1 : 0;
      final captureBonus = (move.capture != null) ? move.capture!.length : 0;
      List<MyChessPiece> transformations = nextBoard.getAllTransforms(
        currentRow,
        currentCol, // Vị trí ban đầu của quân cờ để tính toán transform dựa trên trạng thái của nó
        moveBonus,
        captureBonus,
        move.r, // Vị trí đích của nước đi
        move.c, // Vị trí đích của nước đi
      );

      // Di chuyển quân cờ đến ô đích
      nextBoard.board[move.r][move.c] = nextBoard.movingPiece;
      nextBoard.board[currentRow][currentCol] = null;

      // Duyệt qua tất cả các dạng biến hình có thể xảy ra
      for (var transformedPiece in transformations) {
        if (transformedPiece.canMoveAgain) {
          // Nếu quân cờ biến hình có thể đi tiếp, thì khám phá các nước đi của nó
          nextBoard.board[move.r][move.c] =
              transformedPiece; // Đặt quân cờ đã biến hình vào vị trí đích

          // Tạo một trạng thái duy nhất để tránh lặp lại cùng một chuỗi nước đi/biến hình
          String stateKey =
              '${move.r}_${move.c}_${transformedPiece.name}_${transformedPiece.isWhite}_${depth}';
          if (!visitedStates.contains(stateKey)) {
            visitedStates.add(stateKey);
            _getChainedMoves(
              move.r,
              move.c,
              transformedPiece,
              visitedStates,
              currentChain,
              depth + 1,
            );
          }
        }
      }
    }
  }

  void calculateHintMoves(int startRow, int startCol) {
    hintMoves.clear();
    final piece = board[startRow][startCol];
    if (piece == null) return;

    // Set để theo dõi các trạng thái đã ghé thăm, tránh lặp vô hạn
    Set<String> visitedStates = {};
    _getChainedMoves(startRow, startCol, piece, visitedStates, [], 0);

    // Đảm bảo chỉ có các nước đi duy nhất trong hintMoves
    // (nếu một ô có thể được đến bằng nhiều chuỗi, nó vẫn chỉ là một hint)
    final uniqueHintMoves = <String, StepMove>{};
    for (var move in hintMoves) {
      uniqueHintMoves['${move.r}_${move.c}'] = move;
    }
    hintMoves = uniqueHintMoves.values.toList();
  }
}
