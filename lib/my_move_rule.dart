import 'package:flutter/foundation.dart'; // Import this for listEquals
import 'my_board.dart';
import 'my_chess_piece.dart';

//Transform
class TransformPiece {
  String type;
  String name;
  int count;
  TransformPiece(this.type, this.count, this.name);
}

//Direction
const Map<int, List<int>> directionMap = {
  1: [-1, 0], // Up
  2: [-1, 1], // Up Right
  3: [0, 1], // Right
  4: [1, 1], // Down Right
  5: [1, 0], // Down
  6: [1, -1], // Down Left
  7: [0, -1], // Left
  8: [-1, -1], // Up Left
};
int adjustDirection(int dir, bool isWhite) {
  return isWhite ? dir : ((dir + 3) % 8) + 1;
}

double valueDirection(int dir) {
  return (1 + (1 + dir % 2) * 2) / 2.5;
}

class StepEffect {
  int r;
  int c;
  StepEffect({required this.r, required this.c});

  Map<String, dynamic> toJson() => {'r': r, 'c': c};

  static StepEffect fromJson(Map<String, dynamic> json) =>
      StepEffect(r: json['r'], c: json['c']);
}

class StepMove {
  int r;
  int c;
  List<StepEffect>? capture;
  StepMove({required this.r, required this.c, this.capture});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepMove &&
          runtimeType == other.runtimeType &&
          r == other.r &&
          c == other.c &&
          listEquals(capture, other.capture); // Sử dụng listEquals để so sánh danh sách

  @override
  int get hashCode => Object.hash(r, c, capture);

  // Note: listEquals yêu cầu import 'package:flutter/foundation.dart'.

  Map<String, dynamic> toJson() => {
    'r': r,
    'c': c,
    'capture': capture?.map((e) => e.toJson()).toList(),
  };

  static StepMove fromJson(Map<String, dynamic> json) => StepMove(
    r: json['r'],
    c: json['c'],
    capture:
        (json['capture'] as List?)?.map((e) => StepEffect.fromJson(e)).toList(),
  );
}

//Move
class Move {
  List<int> directions;
  int maxStep;
  bool mustCapture;
  bool captureAllies;
  bool captureEnemies;
  bool onlyCaptureImportant;
  bool cantCaptureImportant;
  bool overLimit;

  int stepping;
  int spacing;
  bool startSpacing;
  bool blockSpacing;

  int minJump;
  int maxJump;
  bool jumpOverAllies;
  bool jumpOverEnemies;
  bool captureJump;
  bool canCaptureDirectly;

  Move({
    required this.directions,
    this.maxStep = 1,
    this.mustCapture = false,
    this.captureAllies = false,
    this.captureEnemies = true,
    this.onlyCaptureImportant = false,
    this.cantCaptureImportant = false,
    this.overLimit = false,
    this.stepping = 1,
    this.spacing = 0,
    this.startSpacing = true,
    this.blockSpacing = false,
    this.minJump = 0,
    this.maxJump = 0,
    this.jumpOverAllies = true,
    this.jumpOverEnemies = true,
    this.captureJump = false,
    this.canCaptureDirectly = true,
  });

  bool inBounds(int row, int col, int maxRow, int maxCol) =>
      row >= 0 && row < maxRow && col >= 0 && col < maxCol;

  bool shouldStep(int i) {
    if (spacing == 0) return true;
    return startSpacing
        ? (i % (stepping + spacing) >= spacing)
        : (i % (spacing + stepping) >= stepping);
  }

  bool canLand(int i, int j) {
    return (maxJump - minJump >= j);
  }

  bool canJump(bool isWhite, bool targetIsWhite) {
    return ((targetIsWhite == isWhite && jumpOverAllies) ||
        (targetIsWhite != isWhite && jumpOverEnemies));
  }

  bool canCapture(bool isWhite, bool targetIsWhite, bool targetIsImportant) {
    if (onlyCaptureImportant && !targetIsImportant) return false;
    if (cantCaptureImportant && targetIsImportant) return false;
    return ((targetIsWhite == isWhite && captureAllies) ||
        (targetIsWhite != isWhite && captureEnemies));
  }

  // trả về các nước đi khả thi
  List<StepMove> generateMoves(
    ChessBoard chessBoard,
    int row,
    int col,
    MyChessPiece movingPiece,
  ) {
    List<StepMove> moves = [];
    int r = row;
    int c = col;
    int j = maxJump;
    List<StepEffect> listJumpCapture = [];
    for (int step = 0; step < maxStep; step++) {
      int dir = adjustDirection(
        directions[step % directions.length],
        movingPiece.isWhite,
      );
      List<int> offset = directionMap[dir]!;
      int newR = r + offset[0];
      int newC = c + offset[1];
      if (!inBounds(newR, newC, chessBoard.maxRow, chessBoard.maxCol)) break;
      var target = chessBoard.board[newR][newC];
      if (!shouldStep(step)) {
        if (blockSpacing && target != null) break;
        r = newR;
        c = newC;
        continue;
      } else if (target == null) {
        if (canLand(step, j) &&
            !mustCapture &&
            (overLimit ||
                chessBoard.isMoveAllowedByLimit(movingPiece, newR, newC))) {
          moves.add(
            StepMove(
              r: newR,
              c: newC,
              capture:
                  listJumpCapture.isNotEmpty
                      ? List.from(listJumpCapture)
                      : null,
            ),
          );
        }
      } else {
        bool canCaptureTarget = canCapture(
          movingPiece.isWhite,
          target.isWhite,
          target.isImportant,
        );
        List<StepEffect> captureList = List.from(listJumpCapture);
        if (canCaptureDirectly &&
            canCaptureTarget &&
            canLand(step, j) &&
            (overLimit ||
                chessBoard.isMoveAllowedByLimit(movingPiece, newR, newC))) {
          captureList.add(StepEffect(r: newR, c: newC));
          moves.add(StepMove(r: newR, c: newC, capture: captureList));
        }
        if (j > 0 && canJump(movingPiece.isWhite, target.isWhite)) {
          if (captureJump && canCaptureTarget) {
            listJumpCapture.add(StepEffect(r: newR, c: newC));
          }
          j--;
          r = newR;
          c = newC;
          continue;
        } else {
          break;
        }
      }
      r = newR;
      c = newC;
    }
    return moves;
  }

  // trả về giá trị chiến lượt của nước đi trên bàn cờ hiện tại
  double valueStrategicMoves(
    ChessBoard chessBoard,
    int row,
    int col,
    MyChessPiece movingPiece,
  ) {
    double strategicValue = 0;
    int r = row;
    int c = col;
    int j = maxJump;
    List<StepEffect> listJumpCapture = [];
    bool modCaptureAllies = false;
    if (captureEnemies && !captureAllies) {
      captureAllies = true;
      modCaptureAllies = true;
    }
    for (int step = 0; step < maxStep; step++) {
      int dir = adjustDirection(
        directions[step % directions.length],
        movingPiece.isWhite,
      );
      List<int> offset = directionMap[dir]!;
      int newR = r + offset[0];
      int newC = c + offset[1];
      if (!inBounds(newR, newC, chessBoard.maxRow, chessBoard.maxCol)) break;
      var target = chessBoard.board[newR][newC];
      if (!shouldStep(step)) {
        if (blockSpacing && target != null) break;
        r = newR;
        c = newC;
        continue;
      } else if (target == null) {
        if (canLand(step, j) &&
            !mustCapture &&
            (overLimit ||
                chessBoard.isMoveAllowedByLimit(movingPiece, newR, newC))) {
          strategicValue += 5;
        }
      } else {
        bool canCaptureTarget = canCapture(
          movingPiece.isWhite,
          target.isWhite,
          target.isImportant,
        );
        List<StepEffect> captureList = List.from(listJumpCapture);
        if (canCaptureDirectly &&
            canCaptureTarget &&
            canLand(step, j) &&
            (overLimit ||
                chessBoard.isMoveAllowedByLimit(movingPiece, newR, newC))) {
          captureList.add(StepEffect(r: newR, c: newC));
          final movingValue = chessBoard.getPieceValue(movingPiece);
          for (var capture in captureList) {
            final capturePiece = chessBoard.board[capture.r][capture.c]!;
            final captureValue = chessBoard.getPieceValue(capturePiece);

            if (capturePiece.isWhite == movingPiece.isWhite) {
              if (!movingPiece.isImportant && !capturePiece.isImportant) {
                strategicValue += movingValue / 2;
              } else {
                strategicValue += 10;
              }
            } else {
              if (!capturePiece.isImportant) {
                if (movingPiece.canMoveAgain) {
                  strategicValue += 10 + captureValue;
                } else {
                  strategicValue += 10 + captureValue * 2;
                }
              } else if (!movingPiece.isImportant) {
                strategicValue += 10 + captureValue;
              } else {
                strategicValue += captureValue;
              }
            }
          }
        }
        if (j > 0 && canJump(movingPiece.isWhite, target.isWhite)) {
          if (captureJump && canCaptureTarget) {
            listJumpCapture.add(StepEffect(r: newR, c: newC));
          }
          j--;
          r = newR;
          c = newC;
          continue;
        } else {
          break;
        }
      }
      r = newR;
      c = newC;
    }
    if (modCaptureAllies) {
      captureAllies = false;
    }
    return strategicValue / 10;
  }

  //trả về giá trị tổng quát của nước đi trên bàn cờ rộng
  double valueTrueMoves(int row, int col) {
    int maxRow = row * 2 - 1;
    int maxCol = col * 2 - 1;
    int maxRowCol = maxRow > maxCol ? maxRow : maxCol;
    int trueStep = 0;
    double subStep = 1.0;
    double multi = 1;
    double value = 0;
    int r = row;
    int c = col;
    if (captureEnemies) multi++;
    if (captureAllies) multi++;
    if (mustCapture) multi--;
    for (int step = 0; step < maxStep; step++) {
      int dir = directions[step % directions.length];
      List<int> offset = directionMap[dir]!;
      int newR = r + offset[0];
      int newC = c + offset[1];
      if (!inBounds(newR, newC, maxRow, maxCol)) break;
      if (spacing > 0) {
        if (!shouldStep(step)) {
          if (!blockSpacing) {
            subStep += valueDirection(dir) * 3 / 4;
          } else {
            subStep += valueDirection(dir) / 2;
          }
        } else {
          value +=
              multi * (maxRowCol - trueStep) * (valueDirection(dir) + subStep);
          trueStep++;
          subStep = 0;
        }
      } else {
        value +=
            multi * (maxRowCol - trueStep) * (valueDirection(dir) + subStep);
        trueStep++;
        subStep = 0;
      }
      r = newR;
      c = newC;
    }
    value *=
        (1 + ((jumpOverAllies ? 1 : 0) + (jumpOverEnemies ? 1 : 0)) * maxJump) /
        (1 + minJump * 4);
    value /= maxRowCol;
    return value;
  }
}
