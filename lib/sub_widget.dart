//sub_widget
import 'package:flutter/material.dart';
import 'my_chess_piece.dart';
import 'my_move_rule.dart';
import 'my_board.dart';

class KingStatusDisplay extends StatelessWidget {
  final ChessBoard chessBoard;
  final bool isWhite;

  const KingStatusDisplay({
    Key? key,
    required this.chessBoard,
    required this.isWhite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isTurn = (chessBoard.whiteTurn == isWhite);
    final double totalValue = chessBoard.getTeamValue(isWhite);
    final int roundedValue = totalValue.ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    isTurn
                        ? const Color.fromARGB(200, 255, 255, 0)
                        : const Color.fromARGB(50, 255, 50, 0),
                shape: BoxShape.circle,
              ),
            ),
            if (chessBoard.whiteWin != null &&
                ((chessBoard.whiteWin! && isWhite) ||
                    (!chessBoard.whiteWin! && !isWhite)))
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.7),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            Image.asset(
              isWhite
                  ? 'assets/images/pieces/w_king.png'
                  : 'assets/images/pieces/b_king.png',
              width: 40,
              height: 40,
            ),
            if (chessBoard.whiteWin != null &&
                ((chessBoard.whiteWin! && isWhite) ||
                    (!chessBoard.whiteWin! && !isWhite)))
              const Positioned(
                top: 0,
                child: Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          roundedValue.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class MoveHistoryList extends StatelessWidget {
  final ChessBoard chessBoard;

  const MoveHistoryList({Key? key, required this.chessBoard}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final reversedHistory = chessBoard.moveHistory.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reversedHistory.length + 1,
      itemBuilder: (_, index) {
        if (index == reversedHistory.length) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 211, 233, 255),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'lịch sử bắt đầu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center, // Canh giữa văn bản
            ),
          );
        }

        // Các mục lịch sử nước đi thông thường
        final log = reversedHistory[index];
        final fromPos =
            '${String.fromCharCode(log.fromCol + 97)}${chessBoard.maxRow - log.fromRow}';
        final toPos =
            '${String.fromCharCode(log.toCol + 97)}${chessBoard.maxRow - log.toRow}';
        final isLatestMove = index == 0;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: log.isWhite ? Colors.white : Colors.black12,
            borderRadius: BorderRadius.circular(8),
            border:
                isLatestMove
                    ? Border.all(color: Colors.amber, width: 2.0)
                    : Border.all(color: Colors.transparent, width: 2.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(log.from.imagePath, width: 32),
                  const SizedBox(width: 8),
                  Text('$fromPos → $toPos'),
                  if (log.captured.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'X',
                      style: TextStyle(color: Color.fromARGB(255, 255, 0, 0)),
                    ),
                    const SizedBox(width: 4),
                    ...log.captured.expand(
                      (cap) => [
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            '(${String.fromCharCode(cap.col + 97)}${chessBoard.maxRow - cap.row})',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 255, 0, 0),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.0),
                          child: Image.asset(
                            cap.piece.imagePath,
                            width: 32,
                            height: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (log.transform.isNotEmpty) ...[
                for (final t in log.transform)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Text(
                          '(${String.fromCharCode(t.col + 97)}${chessBoard.maxRow - t.row})',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 0, 191, 0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Image.asset(t.from.imagePath, width: 28),
                        const Text('→'),
                        Image.asset(t.to.imagePath, width: 28),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum BoardRotation { up, right, down, left }

enum ZoneDisplayMode { hidden, zoneOnly, borderOnly, zoneAndBorder }

class BoardRotationPainter extends CustomPainter {
  final BoardRotation currentRotation;

  BoardRotationPainter(this.currentRotation);

  @override
  void paint(Canvas canvas, Size size) {
    final whitePaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;

    final RRect rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8.0),
    );
    canvas.clipRRect(rRect);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height / 2),
      blackPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      whitePaint,
    );
  }

  @override
  bool shouldRepaint(covariant BoardRotationPainter oldDelegate) =>
      oldDelegate.currentRotation != currentRotation;
}

class GameSettingsMenu extends StatefulWidget {
  final ZoneDisplayMode initialZoneDisplayMode;
  final BoardRotation initialBoardRotation;
  final BoardRotation initialWhitePieceRotation;
  final BoardRotation initialBlackPieceRotation;

  final ValueChanged<ZoneDisplayMode> onZoneDisplayModeChanged;
  final ValueChanged<BoardRotation> onBoardRotationChanged;
  final ValueChanged<BoardRotation> onWhitePieceRotationChanged;
  final ValueChanged<BoardRotation> onBlackPieceRotationChanged;
  final VoidCallback onUpdateDisplayDimensions;

  const GameSettingsMenu({
    Key? key,
    required this.initialZoneDisplayMode,
    required this.initialBoardRotation,
    required this.initialWhitePieceRotation,
    required this.initialBlackPieceRotation,
    required this.onZoneDisplayModeChanged,
    required this.onBoardRotationChanged,
    required this.onWhitePieceRotationChanged,
    required this.onBlackPieceRotationChanged,
    required this.onUpdateDisplayDimensions,
  }) : super(key: key);

  @override
  State<GameSettingsMenu> createState() => _GameSettingsMenuState();
}

class _GameSettingsMenuState extends State<GameSettingsMenu> {
  late ZoneDisplayMode _zoneDisplayMode;
  late BoardRotation _boardRotation;
  late BoardRotation _whitePieceRotation;
  late BoardRotation _blackPieceRotation;

  @override
  void initState() {
    super.initState();
    _zoneDisplayMode = widget.initialZoneDisplayMode;
    _boardRotation = widget.initialBoardRotation;
    _whitePieceRotation = widget.initialWhitePieceRotation;
    _blackPieceRotation = widget.initialBlackPieceRotation;
  }

  int _rotationToInt(BoardRotation rotation) {
    switch (rotation) {
      case BoardRotation.up:
        return 0;
      case BoardRotation.right:
        return 1;
      case BoardRotation.down:
        return 2;
      case BoardRotation.left:
        return 3;
    }
  }

  BoardRotation _intToRotation(int value) {
    switch (value % 4) {
      case 0:
        return BoardRotation.up;
      case 1:
        return BoardRotation.right;
      case 2:
        return BoardRotation.down;
      case 3:
        return BoardRotation.left;
      default:
        return BoardRotation.up;
    }
  }

  double _getRotationAngle(BoardRotation rotation) {
    switch (rotation) {
      case BoardRotation.up:
        return 0.0;
      case BoardRotation.right:
        return 3.14159 / 2;
      case BoardRotation.down:
        return 3.14159;
      case BoardRotation.left:
        return -3.14159 / 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cài đặt',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_zoneDisplayMode == ZoneDisplayMode.hidden) {
                        _zoneDisplayMode = ZoneDisplayMode.zoneOnly;
                      } else if (_zoneDisplayMode == ZoneDisplayMode.zoneOnly) {
                        _zoneDisplayMode = ZoneDisplayMode.hidden;
                      } else if (_zoneDisplayMode ==
                          ZoneDisplayMode.borderOnly) {
                        _zoneDisplayMode = ZoneDisplayMode.zoneAndBorder;
                      } else if (_zoneDisplayMode ==
                          ZoneDisplayMode.zoneAndBorder) {
                        _zoneDisplayMode = ZoneDisplayMode.borderOnly;
                      }
                      widget.onZoneDisplayModeChanged(_zoneDisplayMode);
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            (_zoneDisplayMode == ZoneDisplayMode.zoneOnly ||
                                    _zoneDisplayMode ==
                                        ZoneDisplayMode.zoneAndBorder)
                                ? Colors.amber
                                : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      Icons.select_all,
                      color:
                          (_zoneDisplayMode == ZoneDisplayMode.zoneOnly ||
                                  _zoneDisplayMode ==
                                      ZoneDisplayMode.zoneAndBorder)
                              ? Colors.amber
                              : Colors.grey,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_zoneDisplayMode == ZoneDisplayMode.hidden) {
                        _zoneDisplayMode = ZoneDisplayMode.borderOnly;
                      } else if (_zoneDisplayMode ==
                          ZoneDisplayMode.borderOnly) {
                        _zoneDisplayMode = ZoneDisplayMode.hidden;
                      } else if (_zoneDisplayMode == ZoneDisplayMode.zoneOnly) {
                        _zoneDisplayMode = ZoneDisplayMode.zoneAndBorder;
                      } else if (_zoneDisplayMode ==
                          ZoneDisplayMode.zoneAndBorder) {
                        _zoneDisplayMode = ZoneDisplayMode.zoneOnly;
                      }
                      widget.onZoneDisplayModeChanged(_zoneDisplayMode);
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            (_zoneDisplayMode == ZoneDisplayMode.borderOnly ||
                                    _zoneDisplayMode ==
                                        ZoneDisplayMode.zoneAndBorder)
                                ? Colors.amber
                                : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(
                      Icons.grid_4x4,
                      color:
                          (_zoneDisplayMode == ZoneDisplayMode.borderOnly ||
                                  _zoneDisplayMode ==
                                      ZoneDisplayMode.zoneAndBorder)
                              ? Colors.amber
                              : Colors.grey,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            const Text(
              'Xoay ảnh',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onDoubleTap: () {
                        setState(() {
                          _boardRotation = BoardRotation.up;
                        });
                        widget.onBoardRotationChanged(BoardRotation.up);
                        widget.onUpdateDisplayDimensions();
                      },
                      child: Transform.rotate(
                        angle: _getRotationAngle(_boardRotation),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: CustomPaint(
                            painter: BoardRotationPainter(_boardRotation),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.rotate_right,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        final newIndex =
                            (_rotationToInt(_boardRotation) + 1) % 4;
                        final newRotation = _intToRotation(newIndex);
                        setState(() {
                          _boardRotation = newRotation;
                        });
                        widget.onBoardRotationChanged(newRotation);
                        widget.onUpdateDisplayDimensions();
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onDoubleTap: () {
                        setState(() {
                          _whitePieceRotation = BoardRotation.up;
                        });
                        widget.onWhitePieceRotationChanged(BoardRotation.up);
                      },
                      child: Transform.rotate(
                        angle: _getRotationAngle(_whitePieceRotation),
                        child: Image.asset(
                          'assets/images/pieces/w_king.png',
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.rotate_right,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        final newIndex =
                            (_rotationToInt(_whitePieceRotation) + 1) % 4;
                        final newRotation = _intToRotation(newIndex);
                        setState(() => _whitePieceRotation = newRotation);
                        widget.onWhitePieceRotationChanged(newRotation);
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onDoubleTap: () {
                        setState(() {
                          _blackPieceRotation = BoardRotation.up;
                        });
                        widget.onBlackPieceRotationChanged(BoardRotation.up);
                      },
                      child: Transform.rotate(
                        angle: _getRotationAngle(_blackPieceRotation),
                        child: Image.asset(
                          'assets/images/pieces/b_king.png',
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.rotate_right,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        final newIndex =
                            (_rotationToInt(_blackPieceRotation) + 1) % 4;
                        final newRotation = _intToRotation(newIndex);
                        setState(() => _blackPieceRotation = newRotation);
                        widget.onBlackPieceRotationChanged(newRotation);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PieceInfoModal extends StatelessWidget {
  final MyChessPiece piece;
  final ChessBoard chessBoard;

  const PieceInfoModal({
    Key? key,
    required this.piece,
    required this.chessBoard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(piece.imagePath, width: 60),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${piece.name} ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: '(${piece.value.toStringAsFixed(1)})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (piece.strategicValue > 0) ...[
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: '(+${(piece.strategicValue).toStringAsFixed(1)})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  if (piece.bonusValue > 0) ...[
                    const TextSpan(text: ' '),
                    TextSpan(
                      text:
                          '(+${(piece.bonusValue * 100).toStringAsFixed(1)} % team)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                  if (piece.isImportant) ...[
                    const TextSpan(text: ' '),
                    const TextSpan(
                      text: '(+∞)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              piece.description,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            if (piece.listTransform.isNotEmpty) ...[
              const Text(
                'Các dạng biến hình:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children:
                    piece.listTransform.whereType<TransformPiece>().map((
                      promo,
                    ) {
                      return Row(
                        children: [
                          Image.asset(
                            MyChessPiece(piece.isWhite, promo.name).imagePath,
                            width: 40,
                            height: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${promo.type} (${promo.count} lần)',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            if (chessBoard.chessPromoted.any(
              (p) =>
                  p.piece.name == piece.name &&
                  p.piece.isWhite == piece.isWhite,
            )) ...[
              const Text(
                'Có thể phong cấp thành:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children:
                    chessBoard.chessPromoted
                        .where(
                          (p) =>
                              p.piece.name == piece.name &&
                              p.piece.isWhite == piece.isWhite,
                        )
                        .expand(
                          (p) => p.listChess.map((promoPiece) {
                            return Row(
                              children: [
                                Image.asset(
                                  MyChessPiece(
                                    promoPiece.isWhite,
                                    promoPiece.name,
                                  ).imagePath,
                                  width: 40,
                                  height: 40,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${promoPiece.name} (zone: ${p.fromZone} → ${p.toZone})',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        )
                        .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
