// play_chess.dart

import 'package:flutter/material.dart';
import 'my_chess_piece.dart';
import 'my_board.dart';
import 'sub_widget.dart';
import 'my_chess_bot.dart';

class ChessBoardPage extends StatefulWidget {
  final String? useBoard;
  final ChessBoard? boardData;
  final bool whiteIsBot;
  final bool blackIsBot;

  const ChessBoardPage({
    super.key,
    this.useBoard,
    this.boardData,
    this.whiteIsBot = false,
    this.blackIsBot = false,
  });
  @override
  State<ChessBoardPage> createState() => _ChessBoardPageState();
}

class _ChessBoardPageState extends State<ChessBoardPage> {
  ChessBoard chessBoard = ChessBoard(8, 8);
  BoardRotation boardRotation = BoardRotation.up;
  BoardRotation whitePieceRotation = BoardRotation.up;
  BoardRotation blackPieceRotation = BoardRotation.down;
  late int displayRows;
  late int displayCols;
  ZoneDisplayMode _zoneDisplayMode = ZoneDisplayMode.hidden;
  bool _isBotThinking = false;
  bool _isUndoMode = false;
  bool _stopBotThinking = false; // BIẾN MỚI: Dừng bot thực hiện lượt tiếp theo

  final MyChessBot _chessBot = MyChessBot();
  @override
  void initState() {
    super.initState();
    if (widget.boardData != null) {
      chessBoard = widget.boardData!;
    } else {
      chessBoard.useBoard(widget.useBoard ?? 'default');
    }

    chessBoard.getBoardValueSummary(true);
    _updateDisplayDimensions();
    if (!widget.whiteIsBot && !widget.blackIsBot) {
      boardRotation = BoardRotation.up;
      whitePieceRotation = BoardRotation.up;
      blackPieceRotation = BoardRotation.down;
    } else {
      if (widget.whiteIsBot && !widget.blackIsBot) {
        boardRotation = BoardRotation.down;
        whitePieceRotation = BoardRotation.up;
        blackPieceRotation = BoardRotation.up;
      } else {
        boardRotation = BoardRotation.up;
        whitePieceRotation = BoardRotation.up;
        blackPieceRotation = BoardRotation.up;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPlayBotMove();
    });
    MyChessBot.clearTranspositionTable();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _updateDisplayDimensions() {
    if (boardRotation == BoardRotation.up ||
        boardRotation == BoardRotation.down) {
      displayRows = chessBoard.maxRow;
      displayCols = chessBoard.maxCol;
    } else {
      displayRows = chessBoard.maxCol;
      displayCols = chessBoard.maxRow;
    }
  }

  void _showGameOverDialog({required bool winnerIsWhite}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder:
          (_) => AlertDialog(
            title: const Text('Trò chơi kết thúc', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
                const SizedBox(height: 16),
                Text(
                  '${winnerIsWhite ? "Trắng" : "Đen"} đã chiến thắng!',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    chessBoard.whiteWin = winnerIsWhite;
                  });
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<MyChessPiece?> _showPromotionChoice(List<MyChessPiece> options) async {
    return await showDialog<MyChessPiece>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder:
          (_) => AlertDialog(
            title: const Text('Chọn quân biến hình'),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    options.map((piece) {
                      return GestureDetector(
                        onTap: () => Navigator.of(context).pop(piece),
                        child: Container(
                          width: 60,
                          height: 60,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.asset(
                            piece.imagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }

  void _checkAndPlayBotMove() {
    if (chessBoard.whiteWin != null) return;
    if (_isUndoMode) return;
    if (_stopBotThinking) return; // MỚI: Không gọi hàm bot nếu cờ dừng đang bật

    bool isWhiteBotTurn = widget.whiteIsBot && chessBoard.whiteTurn;
    bool isBlackBotTurn = widget.blackIsBot && !chessBoard.whiteTurn;

    if (isWhiteBotTurn || isBlackBotTurn) {
      _playBotMove();
    }
  }

  Future<void> _playBotMove() async {
    setState(() {
      _isBotThinking = true;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    final int botDepth = 3;
    final BotMove? bestMove = await _chessBot.findBestMove(
      chessBoard.copy(),
      botDepth,
    );

    // MỚI: Kiểm tra _stopBotThinking sau khi bot tính toán xong
    if (_stopBotThinking) {
      setState(() {
        _isBotThinking = false; // Reset cờ _isBotThinking
      });
      return; // Bỏ qua nước đi của bot nếu người chơi đã yêu cầu dừng
    }

    if (bestMove != null) {
      setState(() {
        chessBoard.select(
          bestMove.fromRow,
          bestMove.fromCol,
          chessBoard.board[bestMove.fromRow][bestMove.fromCol]!,
        );
        chessBoard.calculateHintMoves(
          chessBoard.selectRow!,
          chessBoard.selectCol!,
        );
      });
      await Future.delayed(const Duration(milliseconds: 100));
      _performBotMoveStepsInternal(bestMove);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Đã gộp và điều chỉnh logic kiểm tra kết thúc game và gọi nước đi bot tiếp theo
    if (chessBoard.whiteWin != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameOverDialog(winnerIsWhite: chessBoard.whiteWin!);
      });
    } else if (!_stopBotThinking) {
      // MỚI: Chỉ gọi bot lượt tiếp theo nếu không yêu cầu dừng
      _checkAndPlayBotMove();
    }
    // ĐÃ XÓA: await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      _isBotThinking = false;
    });
  }

  void _performBotMoveStepsInternal(BotMove botMove) {
    final matchedMove = chessBoard.validMoves.firstWhere(
      (m) => m.r == botMove.toRow && m.c == botMove.toCol,
    );
    chessBoard.moveAction(
      botMove.toRow,
      botMove.toCol,
      matchedMove,
      botMove.transform,
    );
  }

  Future<void> _performMoveStep(int row, int col) async {
    final matchedMove = chessBoard.validMoves.firstWhere(
      (m) => m.r == row && m.c == col,
    );
    final moveBonus = (matchedMove.capture == null) ? 1 : 0;
    final captureBonus =
        (matchedMove.capture != null) ? matchedMove.capture!.length : 0;
    List<MyChessPiece> transformations = chessBoard.getAllTransforms(
      chessBoard.selectRow!,
      chessBoard.selectCol!,
      moveBonus,
      captureBonus,
      row,
      col,
    );
    MyChessPiece? transformedPiece;
    if (transformations.isNotEmpty) {
      transformedPiece =
          transformations.length == 1
              ? transformations.first
              : await _showPromotionChoice(transformations);
    }
    chessBoard.moveAction(row, col, matchedMove, transformedPiece);
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _handleMove(int row, int col) async {
    await _performMoveStep(row, col);

    if (chessBoard.whiteWin != null) {
      _showGameOverDialog(winnerIsWhite: chessBoard.whiteWin!);
    }

    _checkAndPlayBotMove();
  }

  Future<void> _onTap(int row, int col) async {
    // REVERTED: _isBotThinking || được giữ lại để cấm chạm vào bảng khi bot đang nghĩ
    if (_isBotThinking ||
        chessBoard.whiteTurn == true && widget.whiteIsBot ||
        chessBoard.whiteTurn == false && widget.blackIsBot ||
        chessBoard.whiteWin != null ||
        _isUndoMode)
      return;

    MyChessPiece? tapped = chessBoard.board[row][col];
    bool isSameSquare =
        chessBoard.selectRow == row && chessBoard.selectCol == col;
    bool hasSelected =
        chessBoard.selectRow != null && chessBoard.selectCol != null;
    if (isSameSquare) {
      setState(() {
        chessBoard.clearSelect();
      });
      return;
    }
    if (!hasSelected &&
        tapped != null &&
        tapped.isWhite == chessBoard.whiteTurn &&
        (!chessBoard.hasPriority() || tapped.isPriority)) {
      setState(() {
        chessBoard.select(row, col, tapped);
        chessBoard.calculateHintMoves(
          chessBoard.selectRow!,
          chessBoard.selectCol!,
        );
      });
      return;
    }
    if (hasSelected) {
      bool isValidMove = chessBoard.validMoves.any(
        (m) => m.r == row && m.c == col,
      );
      if (isValidMove) {
        await _handleMove(row, col);
        return;
      } else if (tapped != null &&
          tapped.isWhite == chessBoard.whiteTurn &&
          (!chessBoard.hasPriority() || tapped.isPriority)) {
        setState(() {
          chessBoard.select(row, col, tapped);
          chessBoard.calculateHintMoves(
            chessBoard.selectRow!,
            chessBoard.selectCol!,
          );
        });
      } else {
        setState(() {
          chessBoard.clearSelect();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // MỚI: Xử lý nút quay lại của hệ thống/mũi tên trên AppBar
      onWillPop: () async {
        // Chờ bot hoàn thành nếu đang nghĩ trước khi cho phép thoát
        while (_isBotThinking) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        MyChessBot.clearTranspositionTable();
        return true; // Cho phép hành động quay lại tiếp tục
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Aura Chess')),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      KingStatusDisplay(chessBoard: chessBoard, isWhite: true),
                      KingStatusDisplay(chessBoard: chessBoard, isWhite: false),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: displayCols / displayRows,
                  child: Stack(
                    children: [
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayRows * displayCols,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: displayCols,
                        ),
                        itemBuilder: (context, index) {
                          int displayRow = index ~/ displayCols;
                          int displayCol = index % displayCols;
                          int actualRow, actualCol;

                          switch (boardRotation) {
                            case BoardRotation.up:
                              actualRow = displayRow;
                              actualCol = displayCol;
                              break;
                            case BoardRotation.down:
                              actualRow = chessBoard.maxRow - 1 - displayRow;
                              actualCol = chessBoard.maxCol - 1 - displayCol;
                              break;
                            case BoardRotation.left:
                              actualRow = displayCol;
                              actualCol = chessBoard.maxCol - 1 - displayRow;
                              break;
                            case BoardRotation.right:
                              actualCol = displayRow;
                              actualRow = chessBoard.maxRow - 1 - displayCol;

                              break;
                          }

                          if (actualRow < 0 ||
                              actualRow >= chessBoard.maxRow ||
                              actualCol < 0 ||
                              actualCol >= chessBoard.maxCol) {
                            return Container(
                              color: Colors.red.withOpacity(0.5),
                            );
                          }

                          bool isWhiteSquare = (actualRow + actualCol) % 2 == 0;
                          bool isSelected =
                              chessBoard.selectRow == actualRow &&
                              chessBoard.selectCol == actualCol;
                          Color baseColor =
                              isWhiteSquare
                                  ? const Color.fromARGB(255, 191, 191, 223)
                                  : const Color.fromARGB(255, 79, 79, 111);
                          Color? overlayColor;

                          int zoneValue = chessBoard.zone[actualRow][actualCol];
                          Color? zoneOverlayColor;
                          bool showZone =
                              _zoneDisplayMode == ZoneDisplayMode.zoneOnly ||
                              _zoneDisplayMode == ZoneDisplayMode.zoneAndBorder;
                          if (showZone) {
                            if (zoneValue != 0) {
                              double opacity = 0.15 * zoneValue.abs();
                              zoneOverlayColor = (zoneValue > 0
                                      ? Colors.white
                                      : Colors.black)
                                  .withOpacity(opacity);
                            }
                          }

                          if (isSelected) {
                            overlayColor = Color.fromARGB(191, 127, 255, 127);
                          } else if (chessBoard.isCaptureMove(
                            actualRow,
                            actualCol,
                          )) {
                            overlayColor = Color.fromARGB(191, 255, 127, 127);
                          } else if (chessBoard.isMoveTarget(
                            actualRow,
                            actualCol,
                          )) {
                            overlayColor = Color.fromARGB(191, 127, 127, 255);
                          } else if (chessBoard.isHintMove(
                            actualRow,
                            actualCol,
                          )) {
                            overlayColor = Color.fromARGB(191, 191, 127, 255);
                          }

                          Border? zoneBorder;
                          bool showBorder =
                              _zoneDisplayMode == ZoneDisplayMode.borderOnly ||
                              _zoneDisplayMode == ZoneDisplayMode.zoneAndBorder;
                          if (showBorder) {
                            const zoneBorderSide = BorderSide(
                              color: Color.fromARGB(255, 255, 0, 0),
                              width: 1.0,
                            );
                            final currentZoneValue =
                                chessBoard.zone[actualRow][actualCol];
                            final bool hasTopBorder =
                                actualRow > 0 &&
                                chessBoard.zone[actualRow - 1][actualCol] !=
                                    currentZoneValue;
                            final bool hasBottomBorder =
                                actualRow + 1 < chessBoard.maxRow &&
                                chessBoard.zone[actualRow + 1][actualCol] !=
                                    currentZoneValue;
                            final bool hasLeftBorder =
                                actualCol > 0 &&
                                chessBoard.zone[actualRow][actualCol - 1] !=
                                    currentZoneValue;
                            final bool hasRightBorder =
                                actualCol + 1 < chessBoard.maxCol &&
                                chessBoard.zone[actualRow][actualCol + 1] !=
                                    currentZoneValue;
                            switch (boardRotation) {
                              case BoardRotation.up:
                                zoneBorder = Border(
                                  top:
                                      hasTopBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  bottom:
                                      hasBottomBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  left:
                                      hasLeftBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  right:
                                      hasRightBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                );
                                break;
                              case BoardRotation.down:
                                zoneBorder = Border(
                                  top:
                                      hasBottomBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  bottom:
                                      hasTopBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  left:
                                      hasRightBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  right:
                                      hasLeftBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                );
                                break;
                              case BoardRotation.right:
                                zoneBorder = Border(
                                  top:
                                      hasLeftBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  bottom:
                                      hasRightBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  left:
                                      hasBottomBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  right:
                                      hasTopBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                );
                                break;
                              case BoardRotation.left:
                                zoneBorder = Border(
                                  top:
                                      hasRightBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  bottom:
                                      hasLeftBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  left:
                                      hasTopBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                  right:
                                      hasBottomBorder
                                          ? zoneBorderSide
                                          : BorderSide.none,
                                );
                                break;
                            }
                          }
                          return GestureDetector(
                            onTap:
                                // _isBotThinking || được giữ lại
                                (chessBoard.whiteWin != null ||
                                        _isUndoMode ||
                                        _isBotThinking)
                                    ? null
                                    : () => _onTap(actualRow, actualCol),
                            onLongPress: () {
                              final piece =
                                  chessBoard.board[actualRow][actualCol];
                              if (piece != null) {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.black.withOpacity(
                                    0.7,
                                  ),
                                  builder: (BuildContext context) {
                                    return PieceInfoModal(
                                      piece: piece,
                                      chessBoard: chessBoard,
                                    );
                                  },
                                );
                              }
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: baseColor),
                                if (zoneOverlayColor != null)
                                  Container(color: zoneOverlayColor),
                                if (overlayColor != null)
                                  Container(color: overlayColor),
                                if (showBorder && zoneBorder != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: zoneBorder,
                                    ),
                                  ),
                                Center(
                                  child:
                                      chessBoard.board[actualRow][actualCol] !=
                                              null
                                          ? Transform.rotate(
                                            angle: () {
                                              switch (chessBoard
                                                      .board[actualRow][actualCol]!
                                                      .isWhite
                                                  ? whitePieceRotation
                                                  : blackPieceRotation) {
                                                case BoardRotation.up:
                                                  return 0.0;
                                                case BoardRotation.down:
                                                  return 3.14159;
                                                case BoardRotation.left:
                                                  return -3.14159 / 2;
                                                case BoardRotation.right:
                                                  return 3.14159 / 2;
                                              }
                                            }(),
                                            child: Image.asset(
                                              chessBoard
                                                  .board[actualRow][actualCol]!
                                                  .imagePath,
                                              fit: BoxFit.contain,
                                            ),
                                          )
                                          : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_isBotThinking)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.4),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_isUndoMode && chessBoard.whiteWin == null)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      spreadRadius: 3,
                                      blurRadius: 7,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.play_arrow),
                                  iconSize: 60,
                                  color: Colors.white.withOpacity(0.3),
                                  onPressed: () {
                                    // Đã bỏ điều kiện _isBotThinking ? null :
                                    setState(() {
                                      _isUndoMode = false;
                                      _stopBotThinking =
                                          false; // MỚI: Tắt cờ dừng khi tiếp tục
                                    });
                                    _checkAndPlayBotMove();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.undo),
                        onPressed:
                            chessBoard.moveHistory.isNotEmpty
                                ? () async {
                                  // Đã bỏ điều kiện !_isBotThinking và thêm async
                                  // Chờ bot hoàn thành nếu đang nghĩ
                                  while (_isBotThinking) {
                                    await Future.delayed(
                                      const Duration(milliseconds: 50),
                                    );
                                  }
                                  setState(() {
                                    chessBoard.undoMove();
                                    chessBoard.getBoardValueSummary(false);
                                    _isUndoMode = true;
                                    _stopBotThinking =
                                        true; // MỚI: Bật cờ dừng khi bấm Undo
                                  });
                                }
                                : null,
                      ),
                      IconButton(
                        icon: Icon(Icons.history),
                        onPressed: () {
                          // Đã bỏ điều kiện _isBotThinking ? null :
                          showModalBottomSheet(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.7),
                            builder:
                                (_) => MoveHistoryList(chessBoard: chessBoard),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.settings),
                        onPressed: () {
                          // REVERTED: Đã khôi phục cài đặt nút Settings
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            barrierColor: Colors.black.withOpacity(0.7),
                            builder: (context) {
                              return GameSettingsMenu(
                                initialZoneDisplayMode: _zoneDisplayMode,
                                initialBoardRotation: boardRotation,
                                initialWhitePieceRotation: whitePieceRotation,
                                initialBlackPieceRotation: blackPieceRotation,
                                onZoneDisplayModeChanged: (newMode) {
                                  setState(() {
                                    _zoneDisplayMode = newMode;
                                  });
                                },
                                onBoardRotationChanged: (newRotation) {
                                  setState(() {
                                    boardRotation = newRotation;
                                    _updateDisplayDimensions();
                                  });
                                },
                                onWhitePieceRotationChanged: (newRotation) {
                                  setState(() {
                                    whitePieceRotation = newRotation;
                                  });
                                },
                                onBlackPieceRotationChanged: (newRotation) {
                                  setState(() {
                                    blackPieceRotation = newRotation;
                                  });
                                },
                                onUpdateDisplayDimensions:
                                    _updateDisplayDimensions,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
