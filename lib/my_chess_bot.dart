//my_chess_bot
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'my_board.dart';
import 'my_chess_piece.dart';
import 'my_move_rule.dart';

/// Lớp chứa thông tin về nước đi của bot.
class BotMove {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final MyChessPiece? transform;

  BotMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.transform,
  });
}

/// Dữ liệu được truyền vào isolate để tính toán.
class _MinimaxPayload {
  final ChessBoard board;
  final int depth;
  final bool isBotWhite;

  _MinimaxPayload(this.board, this.depth, this.isBotWhite);
}

/// Lớp chính điều khiển bot.
class MyChessBot {
  bool _isCancelled = false;
  void cancelThinking() {
    _isCancelled = true;
  }

  void resetCancellation() {
    _isCancelled = false;
  }

  /// Tìm nước đi tốt nhất bằng cách sử dụng một isolate riêng.
  Future<BotMove?> findBestMove(ChessBoard board, int depth) async {
    _isCancelled = false;
    if (_isCancelled) return null;
    board.clearHistory();
    final payload = _MinimaxPayload(board.copy(), depth, board.whiteTurn);
    try {
      final bestMove = await compute(_findBestMoveIsolate, payload);
      return bestMove;
    } catch (e) {
      debugPrint("Lỗi trong isolate của bot cờ vua: $e");
      return null;
    }
  }

  /// Hàm tĩnh được chạy trong isolate để tìm nước đi tốt nhất.
  static BotMove? _findBestMoveIsolate(_MinimaxPayload payload) {
    final minimax = _Minimax(
      board: payload.board,
      isBotWhite: payload.isBotWhite,
    );
    return minimax.findBestMove(payload.depth);
  }

  // Thêm một hàm để xóa bảng chuyển vị từ bên ngoài,
  // cần thiết khi bắt đầu một ván cờ mới.
  static void clearTranspositionTable() {
    _Minimax.clearTable();
  }
}

/// Lớp triển khai thuật toán Minimax với cắt tỉa Alpha-Beta.
class _Minimax {
  // Thêm bảng chuyển vị (Transposition Table)
  // Đã đổi kiểu khóa từ String sang int để sử dụng hashCode
  // Đã thêm từ khóa `static` để bảng chuyển vị được chia sẻ và tồn tại lâu hơn
  static final Map<int, double> _transpositionTable = {};

  // Hàm để xóa bảng chuyển vị (được gọi từ MyChessBot)
  static void clearTable() {
    _transpositionTable.clear();
  }

  final ChessBoard board;
  final bool isBotWhite;

  // Độ sâu tối đa cho tìm kiếm tĩnh (quiescence search).
  // Thường là rất nhỏ, ví dụ: 2 hoặc 3 nước đi.
  final int _maxQuiescenceDepth = 2;

  // Ngưỡng cho việc chọn nước đi ngẫu nhiên nếu điểm không chênh lệch quá nhiều.
  // Ví dụ: 1.0 nghĩa là nếu các nước đi có điểm trong khoảng [bestValue - 1.0, bestValue],
  // chúng sẽ được coi là "ngang nhau" và được chọn ngẫu nhiên.
  final double _randomMoveThreshold = 1.0; // Có thể điều chỉnh giá trị này

  _Minimax({required this.board, required this.isBotWhite});

  /// Đánh giá giá trị của bàn cờ từ góc nhìn của bot.
  /// Giá trị dương là tốt cho bot, giá trị âm là xấu.
  double _evaluateBoard(ChessBoard board) {
    final botValue = board.getTeamValue(isBotWhite);
    final opponentValue = board.getTeamValue(!isBotWhite);
    return botValue - opponentValue;
  }

  /// Lấy tất cả các nước đi hợp lệ cho một người chơi trên bàn cờ hiện tại.
  /// Thêm một cờ để chỉ lấy nước đi buộc (forcing moves)
  List<BotMove> _getAllPossibleMoves(
    ChessBoard currentBoard,
    bool isWhiteTurn, {
    bool forcingOnly = false, // Mặc định là không chỉ lấy nước buộc
  }) {
    final List<BotMove> moves = [];
    final bool priorityOnly = currentBoard.hasPriority();

    for (int r = 0; r < currentBoard.maxRow; r++) {
      for (int c = 0; c < currentBoard.maxCol; c++) {
        final piece = currentBoard.board[r][c];
        // Bỏ qua nếu: quân cờ null, không phải lượt của bot,
        // hoặc không phải quân ưu tiên khi đang có quân ưu tiên trên bàn.
        if (piece == null ||
            piece.isWhite != isWhiteTurn ||
            (priorityOnly && !piece.isPriority)) {
          continue;
        }

        final validStepMoves = piece.getValidMoves(currentBoard, r, c);
        for (final stepMove in validStepMoves) {
          // Tính toán bonus cho việc kiểm tra biến hình, dựa trên logic của play_chess.dart
          final captureBonus = stepMove.capture?.length ?? 0;
          final moveBonus = (captureBonus == 0) ? 1 : 0;

          // Kiểm tra xem đây có phải là nước đi buộc không
          final bool isCapture =
              currentBoard.board[stepMove.r][stepMove.c] != null;
          final bool isPromotion =
              piece.name == 'pawn' &&
              ((piece.isWhite && stepMove.r == 0) ||
                  (!piece.isWhite && stepMove.r == currentBoard.maxRow - 1));

          if (forcingOnly && !isCapture && !isPromotion) {
            continue; // Bỏ qua nếu chỉ muốn nước buộc mà đây không phải
          }

          // Kiểm tra các khả năng biến hình cho nước đi cụ thể này
          final transforms = currentBoard.getAllTransforms(
            r,
            c,
            moveBonus,
            captureBonus,
            stepMove.r,
            stepMove.c,
          );
          if (transforms.isEmpty) {
            moves.add(
              BotMove(
                fromRow: r,
                fromCol: c,
                toRow: stepMove.r,
                toCol: stepMove.c,
              ),
            );
          } else {
            for (final transform in transforms) {
              // Nếu là tìm kiếm tĩnh và đây là nước phong cấp, thì thêm vào
              if (forcingOnly && !isPromotion) {
                continue; // Bỏ qua nếu không phải nước buộc khi đang tìm kiếm buộc
              }
              moves.add(
                BotMove(
                  fromRow: r,
                  fromCol: c,
                  toRow: stepMove.r,
                  toCol: stepMove.c,
                  transform: transform,
                ),
              );
            }
          }
        }
      }
    }

    // Sắp xếp nước đi: Ưu tiên nước bắt quân (capture moves)
    // Việc này giúp cắt tỉa Alpha-Beta hiệu quả hơn, làm bot nhanh hơn
    moves.sort((a, b) {
      // Kiểm tra xem nước đi có phải là nước bắt quân không
      // (Bằng cách kiểm tra xem có quân cờ ở ô đích trước khi thực hiện nước đi)
      final bool aIsCapture = currentBoard.board[a.toRow][a.toCol] != null;
      final bool bIsCapture = currentBoard.board[b.toRow][b.toCol] != null;

      if (aIsCapture && !bIsCapture) {
        return -1; // 'a' là bắt quân, 'b' không phải -> 'a' ưu tiên hơn
      }
      if (!aIsCapture && bIsCapture) {
        return 1; // 'b' là bắt quân, 'a' không phải -> 'b' ưu tiên hơn
      }
      return 0; // Cả hai đều bắt quân hoặc cả hai đều không, giữ nguyên thứ tự
    });

    return moves;
  }

  /// Tìm nước đi tốt nhất cho bot.
  BotMove? findBestMove(int depth) {
    double bestValue = double.negativeInfinity;
    List<BotMove> bestMovesCandidates = []; // Danh sách các nước đi ứng cử viên

    final possibleMoves = _getAllPossibleMoves(board, isBotWhite)..shuffle();
    // Xáo trộn ban đầu để đảm bảo tính ngẫu nhiên nếu tất cả nước đi đều có điểm bằng nhau
    // (trước khi lọc theo ngưỡng)

    if (possibleMoves.isEmpty) {
      return null;
    }

    for (final move in possibleMoves) {
      final tempBoard = board.copy();
      _performMove(tempBoard, move);
      final bool turnSwitched = tempBoard.whiteTurn != isBotWhite;
      final boardValue = _minimax(
        tempBoard,
        turnSwitched
            ? depth - 1
            : depth, // Chỉ giảm độ sâu khi lượt đi kết thúc
        double.negativeInfinity,
        double.infinity,
        !turnSwitched,
      );

      // Cập nhật bestValue và danh sách ứng cử viên
      if (boardValue > bestValue) {
        bestValue = boardValue;
        bestMovesCandidates = [
          move,
        ]; // Reset danh sách nếu tìm thấy nước đi tốt hơn
      } else if ((bestValue - boardValue).abs() <= _randomMoveThreshold) {
        // Nếu giá trị nước đi hiện tại gần bằng bestValue trong ngưỡng cho phép
        bestMovesCandidates.add(move);
      }
    }

    // Chọn ngẫu nhiên từ các nước đi ứng cử viên tốt nhất (nếu có nhiều hơn một)
    if (bestMovesCandidates.isNotEmpty) {
      final random = Random();
      return bestMovesCandidates[random.nextInt(bestMovesCandidates.length)];
    }

    // Trường hợp dự phòng nếu không tìm thấy ứng cử viên nào (không nên xảy ra nếu possibleMoves không rỗng)
    if (possibleMoves.isNotEmpty) {
      return possibleMoves[Random().nextInt(possibleMoves.length)];
    }

    return null;
  }

  /// Thuật toán Minimax với cắt tỉa Alpha-Beta.
  double _minimax(
    ChessBoard currentBoard,
    int depth,
    double alpha,
    double beta,
    bool isMaximizingPlayer,
  ) {
    // Tạo khóa cho bảng chuyển vị bằng cách sử dụng hashCode của chuỗi toQuickCompare()
    final int boardKey = currentBoard.toQuickCompare().hashCode;

    // Kiểm tra trong bảng chuyển vị
    if (_transpositionTable.containsKey(boardKey)) {
      return _transpositionTable[boardKey]!;
    }

    // Điều kiện dừng: Khi hết độ sâu của tìm kiếm chính
    // thì chuyển sang tìm kiếm tĩnh (quiescence search)
    if (depth <= 0) {
      // Gọi tìm kiếm tĩnh để đánh giá trạng thái "tĩnh lặng"
      return _quiescenceSearch(
        currentBoard,
        alpha,
        beta,
        isMaximizingPlayer,
        0,
      );
    }

    // Nếu trò chơi đã kết thúc (chiếu hết/hòa)
    if (currentBoard.whiteWin != null) {
      final evaluation = _evaluateBoard(currentBoard);
      _transpositionTable[boardKey] = evaluation;
      return evaluation;
    }

    // Xác định người chơi hiện tại dựa trên vai trò tối đa/tối thiểu hóa.
    final bool currentPlayerIsWhite =
        isMaximizingPlayer ? isBotWhite : !isBotWhite;
    final possibleMoves = _getAllPossibleMoves(
      currentBoard,
      currentPlayerIsWhite,
    );

    // Nếu không còn nước đi nào (bị chiếu hết hoặc cờ hòa), trả về giá trị bàn cờ.
    if (possibleMoves.isEmpty) {
      final evaluation = _evaluateBoard(currentBoard);
      _transpositionTable[boardKey] = evaluation;
      return evaluation;
    }

    if (isMaximizingPlayer) {
      double maxEval = double.negativeInfinity;
      for (final move in possibleMoves) {
        final tempBoard = currentBoard.copy();
        _performMove(tempBoard, move);
        final bool turnSwitched = tempBoard.whiteTurn != currentPlayerIsWhite;
        final eval = _minimax(
          tempBoard,
          turnSwitched ? depth - 1 : depth - 1,
          alpha,
          beta,
          !turnSwitched,
        );
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) {
          break; // Cắt tỉa Beta
        }
      }
      _transpositionTable[boardKey] = maxEval; // Lưu kết quả vào bảng chuyển vị
      return maxEval;
    } else {
      // Người chơi tối thiểu hóa (đối thủ)
      double minEval = double.infinity;
      for (final move in possibleMoves) {
        final tempBoard = currentBoard.copy();
        _performMove(tempBoard, move);
        final bool turnSwitched = tempBoard.whiteTurn != currentPlayerIsWhite;
        final eval = _minimax(
          tempBoard,
          turnSwitched ? depth - 1 : depth - 1,
          alpha,
          beta,
          turnSwitched,
        );
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) {
          break; // Cắt tỉa Alpha
        }
      }
      _transpositionTable[boardKey] = minEval; // Lưu kết quả vào bảng chuyển vị
      return minEval;
    }
  }

  /// Thuật toán Quiescence Search (Tìm kiếm tĩnh).
  /// Chỉ xem xét các nước đi "buộc" (bắt quân, phong cấp) để đạt đến trạng thái tĩnh.
  double _quiescenceSearch(
    ChessBoard currentBoard,
    double alpha,
    double beta,
    bool isMaximizingPlayer,
    int qDepth, // Độ sâu hiện tại của tìm kiếm tĩnh
  ) {
    // Nếu trò chơi đã kết thúc (chiếu hết/hòa) hoặc đạt đến độ sâu tĩnh tối đa
    if (currentBoard.whiteWin != null || qDepth >= _maxQuiescenceDepth) {
      return _evaluateBoard(currentBoard);
    }

    // Đánh giá tĩnh hiện tại là sàn cho alpha (nếu là người chơi tối đa hóa)
    // hoặc trần cho beta (nếu là người chơi tối thiểu hóa)
    double eval = _evaluateBoard(currentBoard);
    if (isMaximizingPlayer) {
      alpha = max(alpha, eval);
    } else {
      beta = min(beta, eval);
    }

    // Nếu khoảng Alpha-Beta đã bị cắt tỉa ngay từ đầu, trả về giá trị
    if (alpha >= beta) {
      return eval;
    }

    final bool currentPlayerIsWhite =
        isMaximizingPlayer ? isBotWhite : !isBotWhite;

    // Lấy chỉ các nước đi buộc (captures và promotions)
    final possibleForcingMoves = _getAllPossibleMoves(
      currentBoard,
      currentPlayerIsWhite,
      forcingOnly: true, // Chỉ lấy nước đi buộc
    );

    // Nếu không có nước đi buộc nào, đây là trạng thái tĩnh, trả về đánh giá tĩnh hiện tại
    if (possibleForcingMoves.isEmpty) {
      return eval;
    }

    // Sắp xếp nước đi buộc để tăng hiệu quả cắt tỉa (captures trước)
    possibleForcingMoves.sort((a, b) {
      final bool aIsCapture = currentBoard.board[a.toRow][a.toCol] != null;
      final bool bIsCapture = currentBoard.board[b.toRow][b.toCol] != null;
      if (aIsCapture && !bIsCapture) return -1;
      if (!aIsCapture && bIsCapture) return 1;
      return 0;
    });

    if (isMaximizingPlayer) {
      double maxEval = eval; // Khởi tạo với đánh giá tĩnh hiện tại
      for (final move in possibleForcingMoves) {
        final tempBoard = currentBoard.copy();
        _performMove(tempBoard, move);
        final bool turnSwitched = tempBoard.whiteTurn != currentPlayerIsWhite;
        final score = _quiescenceSearch(
          tempBoard,
          alpha,
          beta,
          !turnSwitched, // Lật người chơi
          qDepth + 1,
        );
        maxEval = max(maxEval, score);
        alpha = max(alpha, score);
        if (beta <= alpha) {
          break; // Cắt tỉa Beta
        }
      }
      return maxEval;
    } else {
      // Người chơi tối thiểu hóa
      double minEval = eval; // Khởi tạo với đánh giá tĩnh hiện tại
      for (final move in possibleForcingMoves) {
        final tempBoard = currentBoard.copy();
        _performMove(tempBoard, move);
        final bool turnSwitched = tempBoard.whiteTurn != currentPlayerIsWhite;
        final score = _quiescenceSearch(
          tempBoard,
          alpha,
          beta,
          turnSwitched, // Không lật người chơi nếu lượt không đổi (vì chỉ tìm kiếm forcing moves)
          qDepth + 1,
        );
        minEval = min(minEval, score);
        beta = min(beta, eval);
        if (beta <= alpha) {
          break; // Cắt tỉa Alpha
        }
      }
      return minEval;
    }
  }

  /// Thực hiện một nước đi trên bàn cờ tạm thời để tính toán.
  /// Hàm này mô phỏng lại logic di chuyển quân cờ trong play_chess.dart.
  void _performMove(ChessBoard board, BotMove move) {
    final piece = board.board[move.fromRow][move.fromCol];
    if (piece == null) return;
    // 1. Chọn quân cờ để lấy danh sách các nước đi hợp lệ
    board.select(move.fromRow, move.fromCol, piece);
    // 2. Tìm StepMove tương ứng với nước đi của bot
    final matchedStepMove = board.validMoves.firstWhere(
      (step) => step.r == move.toRow && step.c == move.toCol,
      orElse: () => StepMove(r: move.toRow, c: move.toCol),
    );
    // 3. Thực hiện hành động di chuyển. Hàm này sẽ cập nhật board.transformList nếu có biến hình.
    board.moveAction(
      move.toRow,
      move.toCol,
      matchedStepMove,
      move.transform,
      true,
    );
  }
}
