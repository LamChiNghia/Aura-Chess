import 'my_board.dart';
import 'my_move_rule.dart';

// Chess Piece
class MyChessPiece {
  String name;
  String trueForm = '';
  String description = "";
  bool isWhite;
  double value = 0;
  double bonusValue = 0;
  double strategicValue = 0;
  bool isImportant = false;
  bool isPriority = false;
  bool canMoveAgain = false;
  int moveCount = 0;
  int captureCount = 0;
  int turnCount = 0;
  bool moveTransform = false;
  bool captureTransform = false;
  bool turnTransform = false;
  String get imagePath =>
      'assets/images/pieces/${isWhite ? "w" : "b"}_$name.png';
  String get showName => name
      .split('_')
      .map(
        (word) =>
            word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1)}'
                : '',
      )
      .join(' ');
  List<Move?> listMove = [];
  List<TransformPiece?> listTransform = [];

  // lấy các nước đi khả thi
  List<StepMove> getValidMoves(ChessBoard chessBoard, int row, int col) {
    return listMove
        .whereType<Move>()
        .expand((r) => r.generateMoves(chessBoard, row, col, this))
        .toList();
  }

  // lấy giá trị tổng quát các nước đi nước đi (giả dụ bàn cờ trống và rộng)
  double getTrueValueMoves(int row, int col) {
    double v = 0;
    listMove.whereType<Move>().forEach((r) {
      v += r.valueTrueMoves(row, col);
    });
    return v;
  }

  // lấy giá trị chiến lược các nước đi nước đi (trong thế cờ hiện tại)
  void setStrategicValueMoves(int row, int col, ChessBoard chessBoard) {
    strategicValue = 0;
    listMove.whereType<Move>().forEach((r) {
      strategicValue += r.valueStrategicMoves(chessBoard, row, col, this);
    });
    List<Map<String, dynamic>> forms = [];
    final double position =
        isWhite
            ? (chessBoard.maxRow - row) / chessBoard.maxRow
            : (row + 1) / chessBoard.maxRow;
    for (final promoted in chessBoard.chessPromoted) {
      if (name == promoted.piece.name && isWhite == promoted.piece.isWhite) {
        for (final promotedTo in promoted.listChess) {
          forms.add({
            'piece': promotedTo,
            'value': chessBoard.getPieceValue(promotedTo),
            'zoneFactor':
                position + 1 / (8 - (promoted.toZone - promoted.fromZone + 1)),
          });
        }
      }
    }
    forms.sort(
      (a, b) => (b['value'] as double).compareTo(a['value'] as double),
    );
    final int numOptions = forms.length;
    double transformValue = 0;
    for (int i = 0; i < numOptions; i++) {
      final option = forms[i];
      final double pValue = option['value'];
      final double weight = (numOptions - i) / numOptions;
      final double zoneFactor = option['zoneFactor'];
      transformValue += (pValue * zoneFactor * weight) / 50;
    }
    strategicValue = strategicValue + transformValue;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'isWhite': isWhite,
    'value': value,
    'bonusValue': bonusValue,
    'strategicValue': strategicValue,
    'isImportant': isImportant,
    'isPriority': isPriority,
    'canMoveAgain': canMoveAgain,
    'moveCount': moveCount,
    'captureCount': captureCount,
    'turnCount': turnCount,
  };

  static MyChessPiece fromJson(Map<String, dynamic> json) {
    final piece = MyChessPiece(json['isWhite'], json['name']);
    piece.value = json['value'] as double? ?? 0.0;
    piece.bonusValue = json['bonusValue'] as double? ?? 0.0;
    piece.strategicValue = json['strategicValue'] as double? ?? 0.0;
    piece.isImportant = json['isImportant'] as bool? ?? false;
    piece.isPriority = json['isPriority'] as bool? ?? false;
    piece.canMoveAgain = json['canMoveAgain'] as bool? ?? false;
    piece.moveCount = json['moveCount'] as int? ?? 0;
    piece.captureCount = json['captureCount'] as int? ?? 0;
    piece.turnCount = json['turnCount'] as int? ?? 0;
    return piece;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MyChessPiece && name == other.name && isWhite == other.isWhite;

  @override
  int get hashCode => name.hashCode ^ isWhite.hashCode;

  static List<String> getAllTag() {
    return [
      '#white',
      '#base', // quân cờ trong cờ vua cơ bản
      '#subForm', // form phụ của các quân cờ
      '#near', // quân cờ đi gần
      '#away', // quân cờ đi xa
      '#space', // quân cờ đi có khoảng ngắc
      '#jump', // quân cờ có thể nhảy qua đầu quân cờ khác
      '#pierce', // quân cờ có thể ăn bằng cách đi xuyên qua quân cờ khác
      '#counter', // quân cờ có khả năng ăn lại quân ăn nó
      '#area', // quân cờ có khả năng ăn lan
      '#aura', // quân cờ có hiệu ứng
      '#red', // quân cờ aura có thể ăn nhiều quân cùng lúc
      '#purple', // quân cờ aura có thể đi nhiều lần
      '#blue', // quân cờ aura có thể hỗ trợ team di chuyển
      '#green', // quân cờ aura có thể tạo ra quân cờ khác(chưa có)
      '#gold', // quân cờ aura có thể cản, quân khác di chuyển(kiểu không thể bị ăn không thể nhảy quan...)(chưa có)
    ];
  }

  static const Map<String, String> _pieceDefinitions = {
    // Normal Chess Piece
    'quick_round_pawn': /*   */ "#base #subForm #near",
    'round_pawn': /*         */ "#base #near",
    'knight': /*             */ "#base #space #jump",
    'rook': /*               */ "#base #away",
    'bishop': /*             */ "#base #away",
    'queen': /*              */ "#base #away",
    'king': /*               */ "#base #near #important",
    'china_general': /*      */ "#base #near #important",
    // Normal Type
    'quick_occult_pawn': /*  */ "#subForm #near",
    'occult_pawn': /*        */ "#near",
    'quick_pillar_pawn': /*  */ "#subForm #near",
    'pillar_pawn': /*        */ "#near",
    'quick_square_pawn': /*  */ "#subForm #near",
    'square_pawn': /*        */ "#near",
    'quick_pyramid_pawn': /* */ "#subForm #near",
    'pyramid_pawn': /*       */ "#near",
    'quick_cup_pawn': /*     */ "#subForm #near",
    'cup_pawn': /*           */ "#near",
    'quick_diamond_pawn': /* */ "#subForm #near",
    'diamond_pawn': /*       */ "#near",
    'catapult': /*           */ "#away #jump",
    'archer': /*             */ "#away #jump",
    'cannon': /*             */ "#away #jump",
    'soldier': /*            */ "#near",
    'high_soldier': /*       */ "#space #jump",
    'blind_high_soldier': /* */ "#space",
    'general': /*            */ "#away #near",
    'chancellor': /*         */ "#away #space #jump",
    'marshal': /*            */ "#away #near #space #jump",
    'priest': /*             */ "#near",
    'high_priest': /*        */ "#space #jump",
    'blind_high_priest': /*  */ "#space",
    'archbishop': /*         */ "#away #near",
    'cardinal': /*           */ "#away #space #jump",
    'pope': /*               */ "#away #near #space #jump",
    'blind_knight': /*       */ "#space",
    'pegasus': /*            */ "#away #space #jump",
    'blind_pegasus': /*      */ "#away #space",
    // Red Type
    'rhino': /*              */ "#aura #red #jump #away",
    'bull': /*               */ "#aura #red #jump #away",
    'triceratops': /*        */ "#aura #red #jump #away",
    'red_lion': /*           */ "#aura #red #purple #near",
    'red_t_rex': /*          */ "#aura #red #purple #space",
    'red_long': /*           */ "#aura #red #purple #space",
    'red_dragon': /*         */ "#aura #red #purple #away #space",
    // Violet Type
    'lion': /*               */ "#aura #purple #near",
    't_rex': /*              */ "#aura #purple #space",
    'long': /*               */ "#aura #purple #space",
    'dragon': /*             */ "#aura #purple #away #space",
    'tower': /*              */ "#aura #purple #near",
    'castle': /*             */ "#aura #purple #away",
    'sage': /*               */ "#aura #purple #near",
    'saint': /*              */ "#aura #purple #away",
    // Blue Type
    'mage': /*               */ "#aura #blue #away",
    'witch': /*              */ "#aura #blue #away",
    'unicorn': /*            */ "#aura #blue #space #jump",
  };

  static List<MyChessPiece> getAllTemplates() {
    return _pieceDefinitions.keys
        .expand((name) => [MyChessPiece(true, name), MyChessPiece(false, name)])
        .toList();
  }

  MyChessPiece(this.isWhite, this.name) {
    description = _pieceDefinitions[name] ?? '';
    switch (name) {
      /// Normal Chess Piece ///
      case 'quick_round_pawn':
        trueForm = 'round_pawn';
        listMove = [
          Move(directions: [1], maxStep: 2, captureEnemies: false),
          Move(directions: [2], maxStep: 1, mustCapture: true),
          Move(directions: [8], maxStep: 1, mustCapture: true),
        ];
        listTransform = [TransformPiece('move or capture', 1, 'round_pawn')];
        break;
      case 'round_pawn':
        listMove = [
          Move(directions: [1], maxStep: 1, captureEnemies: false),
          Move(directions: [2], maxStep: 1, mustCapture: true),
          Move(directions: [8], maxStep: 1, mustCapture: true),
        ];
        break;
      case 'knight':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1),
        ];
        break;
      case 'rook':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 99),
        ];
        break;
      case 'bishop':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 99),
        ];
        break;
      case 'queen':
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8])
            Move(directions: [dirs], maxStep: 99),
        ];
        break;
      case 'king':
        isImportant = true;
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8])
            Move(directions: [dirs], maxStep: 1),
        ];
        break;
      case 'china_general':
        isImportant = true;
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 1),
          Move(
            directions: [1],
            maxStep: 9,
            mustCapture: true,
            onlyCaptureImportant: true,
            overLimit: true,
          ),
        ];
        break;

      /// Mod Chess Piece ///

      /// /// Normal Type ///
      case 'quick_occult_pawn':
        trueForm = 'occult_pawn';
        listMove = [
          Move(directions: [1], maxStep: 1, mustCapture: true),
          Move(directions: [2], maxStep: 2, captureEnemies: false),
          Move(directions: [8], maxStep: 2, captureEnemies: false),
        ];
        listTransform = [TransformPiece('move or capture', 1, 'occult_pawn')];
        break;
      case 'occult_pawn':
        listMove = [
          Move(directions: [1], maxStep: 1, mustCapture: true),
          Move(directions: [2], maxStep: 1, captureEnemies: false),
          Move(directions: [8], maxStep: 1, captureEnemies: false),
        ];
        break;
      case 'quick_pillar_pawn':
        trueForm = 'pillar_pawn';
        listMove = [
          Move(directions: [1], maxStep: 2, captureEnemies: false),
          Move(directions: [3], maxStep: 2, captureEnemies: false),
          Move(directions: [7], maxStep: 2, captureEnemies: false),
          Move(directions: [2], maxStep: 1, mustCapture: true),
          Move(directions: [8], maxStep: 1, mustCapture: true),
        ];
        listTransform = [TransformPiece('move or capture', 1, 'pillar_pawn')];
        break;
      case 'pillar_pawn':
        listMove = [
          Move(directions: [1], maxStep: 1, captureEnemies: false),
          Move(directions: [3], maxStep: 1, captureEnemies: false),
          Move(directions: [7], maxStep: 1, captureEnemies: false),
          Move(directions: [2], maxStep: 1, mustCapture: true),
          Move(directions: [8], maxStep: 1, mustCapture: true),
        ];
        break;
      case 'quick_square_pawn':
        trueForm = 'square_pawn';
        listMove = [
          Move(directions: [1], maxStep: 2, mustCapture: true),
          Move(directions: [3], maxStep: 2, mustCapture: true),
          Move(directions: [7], maxStep: 2, mustCapture: true),
          Move(directions: [2], maxStep: 1, captureEnemies: false),
          Move(directions: [8], maxStep: 1, captureEnemies: false),
        ];
        listTransform = [TransformPiece('move or capture', 1, 'square_pawn')];
        break;
      case 'square_pawn':
        listMove = [
          Move(directions: [1], maxStep: 1, mustCapture: true),
          Move(directions: [3], maxStep: 1, mustCapture: true),
          Move(directions: [7], maxStep: 1, mustCapture: true),
          Move(directions: [2], maxStep: 1, captureEnemies: false),
          Move(directions: [8], maxStep: 1, captureEnemies: false),
        ];
        break;
      case 'quick_pyramid_pawn':
        trueForm = 'pyramid_pawn';
        listMove = [
          Move(directions: [1], maxStep: 2, captureEnemies: false),
          Move(directions: [1], maxStep: 1, mustCapture: true),
        ];
        listTransform = [TransformPiece('move or capture', 1, 'pyramid_pawn')];
        break;
      case 'pyramid_pawn':
        listMove = [
          Move(directions: [1], maxStep: 1),
        ];
        break;
      case 'quick_cup_pawn':
        trueForm = 'cup_pawn';
        listMove = [
          Move(directions: [2], maxStep: 2, captureEnemies: false),
          Move(directions: [8], maxStep: 2, captureEnemies: false),
          Move(directions: [2], maxStep: 1, mustCapture: true),
          Move(directions: [8], maxStep: 1, mustCapture: true),
        ];
        listTransform = [TransformPiece('move or capture', 1, 'cup_pawn')];
        break;
      case 'cup_pawn':
        listMove = [
          Move(directions: [2], maxStep: 1),
          Move(directions: [8], maxStep: 1),
        ];
        break;
      case 'quick_diamond_pawn':
        trueForm = 'diamond_pawn';
        listMove = [
          Move(directions: [1], maxStep: 2, captureEnemies: false),
          Move(directions: [3], maxStep: 2, captureEnemies: false),
          Move(directions: [7], maxStep: 2, captureEnemies: false),
          Move(directions: [1], maxStep: 1, mustCapture: true),
          Move(directions: [3], maxStep: 1, mustCapture: true),
          Move(directions: [7], maxStep: 1, mustCapture: true),
        ];
        listTransform = [TransformPiece('move or capture', 1, 'diamond_pawn')];
        break;
      case 'diamond_pawn':
        listMove = [
          Move(directions: [1], maxStep: 1),
          Move(directions: [3], maxStep: 1),
          Move(directions: [7], maxStep: 1),
        ];
        break;
      case 'catapult':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) ...[
            Move(directions: [dirs], maxStep: 99, captureEnemies: false),
            Move(
              directions: [dirs],
              maxStep: 99,
              mustCapture: true,
              minJump: 1,
              maxJump: 1,
            ),
          ],
        ];
        break;
      case 'archer':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) ...[
            Move(directions: [dirs], maxStep: 99, captureEnemies: false),
            Move(
              directions: [dirs],
              maxStep: 99,
              mustCapture: true,
              minJump: 1,
              maxJump: 1,
            ),
          ],
        ];
        break;
      case 'cannon':
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8]) ...[
            Move(directions: [dirs], maxStep: 99, captureEnemies: false),
            Move(
              directions: [dirs],
              maxStep: 99,
              mustCapture: true,
              minJump: 1,
              maxJump: 1,
            ),
          ],
        ];
        break;
      case 'soldier':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 1),
        ];
        break;
      case 'high_soldier':
        listMove = [
          for (int dirs in [1, 3, 5, 7])
            Move(directions: [dirs], maxStep: 2, spacing: 1),
        ];
        break;
      case 'blind_high_soldier':
        listMove = [
          for (int dirs in [1, 3, 5, 7])
            Move(
              directions: [dirs],
              maxStep: 2,
              spacing: 1,
              blockSpacing: true,
            ),
        ];
        break;
      case 'general':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 99),
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 1),
        ];
        break;
      case 'chancellor':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 99),
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1),
        ];
        break;
      case 'marshal':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 99),
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 1),
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1),
        ];
        break;
      case 'priest':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 1),
        ];
        break;
      case 'high_priest':
        listMove = [
          for (int dirs in [2, 4, 6, 8])
            Move(directions: [dirs], maxStep: 2, spacing: 1),
        ];
        break;
      case 'blind_high_priest':
        listMove = [
          for (int dirs in [2, 4, 6, 8])
            Move(
              directions: [dirs],
              maxStep: 2,
              spacing: 1,
              blockSpacing: true,
            ),
        ];
        break;
      case 'archbishop':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 99),
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 1),
        ];
        break;
      case 'cardinal':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 99),
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1),
        ];
        break;
      case 'pope':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 99),
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 1),
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1),
        ];
        break;
      case 'blind_knight':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        break;
      case 'pegasus':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 99, spacing: 1),
        ];
        break;
      case 'blind_pegasus':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 99, spacing: 1, blockSpacing: true),
        ];
        break;

      /// /// Red Type ///

      case 'rhino':
        listMove = [
          for (int dirs in [1, 3, 5, 7])
            Move(
              directions: [dirs],
              maxStep: 99,
              maxJump: 1,
              captureJump: true,
              jumpOverAllies: false,
            ),
        ];
        break;
      case 'bull':
        listMove = [
          for (int dirs in [2, 4, 6, 8])
            Move(
              directions: [dirs],
              maxStep: 99,
              maxJump: 1,
              captureJump: true,
              jumpOverAllies: false,
            ),
        ];
        break;
      case 'triceratops':
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8])
            Move(
              directions: [dirs],
              maxStep: 99,
              maxJump: 1,
              captureJump: true,
              jumpOverAllies: false,
            ),
        ];
        break;
      case 'red_lion':
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8])
            Move(directions: [dirs], maxStep: 1),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'red_lion_aura')];
        break;
      case 'red_lion_aura':
        trueForm = 'red_lion';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8])
            Move(directions: [dirs], maxStep: 1),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'red_lion')];
        break;
      case 'red_t_rex':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [
          TransformPiece('move or capture', 1, 'red_t_rex_aura'),
        ];
        break;
      case 'red_t_rex_aura':
        trueForm = 'red_t_rex';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'red_t_rex')];
        break;
      case 'red_long':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'red_long_aura')];
        break;
      case 'red_long_aura':
        trueForm = 'red_long';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [
          TransformPiece('move or capture', 1, 'red_long_aura_boost'),
        ];
        break;
      case 'red_long_aura_boost':
        trueForm = 'red_long';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'red_long')];
        break;
      case 'red_dragon':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 4, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [
          TransformPiece('move or capture', 1, 'red_dragon_aura'),
        ];
        break;
      case 'red_dragon_aura':
        trueForm = 'red_dragon';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 4, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'red_dragon')];
        break;

      /// /// Purple Type ///

      case 'lion':
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8])
            Move(directions: [dirs], maxStep: 1),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 'lion_aura')];
        break;
      case 'lion_aura':
        trueForm = 'lion';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (int dirs in [1, 2, 3, 4, 5, 6, 7, 8])
            Move(directions: [dirs], maxStep: 1),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'lion')];
        break;
      case 't_rex':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 't_rex_aura')];
        break;
      case 't_rex_aura':
        trueForm = 't_rex';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 't_rex')];
        break;
      case 'long':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 'long_aura')];
        break;
      case 'long_aura':
        trueForm = 'long';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [
          TransformPiece('move', 1, 'long_aura_boost'),
          TransformPiece('capture', 1, 'long'),
        ];
        break;
      case 'long_aura_boost':
        trueForm = 'long';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'long')];
        break;
      case 'dragon':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 4, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 'dragon_aura')];
        break;
      case 'dragon_aura':
        trueForm = 'dragon';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 4, spacing: 1, blockSpacing: true),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'dragon')];
        break;
      case 'tower':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 1),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 'tower_aura')];
        break;
      case 'tower_aura':
        trueForm = 'tower';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 99),
        ];
        turnTransform = true;
        listTransform = [TransformPiece('turn', 1, 'tower')];
        break;

      case 'castle':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 99),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 'castle_aura')];
        break;
      case 'castle_aura':
        trueForm = 'castle';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 1),
        ];
        turnTransform = true;
        listTransform = [TransformPiece('turn', 1, 'castle')];
        break;

      case 'sage':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 1),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 'sage_aura')];
        break;
      case 'sage_aura':
        trueForm = 'sage';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 99),
        ];
        turnTransform = true;
        listTransform = [TransformPiece('turn', 1, 'sage')];
        break;

      case 'saint':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 99),
        ];
        moveTransform = true;
        listTransform = [TransformPiece('move', 1, 'saint_aura')];
        break;
      case 'saint_aura':
        trueForm = 'saint';
        canMoveAgain = true;
        isPriority = true;
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 1),
        ];
        turnTransform = true;
        listTransform = [TransformPiece('turn', 1, 'saint')];
        break;

      /// /// Blue Type ///

      case 'mage':
        listMove = [
          for (int dirs in [1, 3, 5, 7]) Move(directions: [dirs], maxStep: 99),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move capture', 1, 'mage_aura')];
        break;
      case 'mage_aura':
        trueForm = 'mage';
        canMoveAgain = true;
        turnTransform = true;
        listTransform = [TransformPiece('turn', 1, 'mage')];
        break;

      case 'witch':
        listMove = [
          for (int dirs in [2, 4, 6, 8]) Move(directions: [dirs], maxStep: 99),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'witch_aura')];
        break;
      case 'witch_aura':
        trueForm = 'witch';
        canMoveAgain = true;
        turnTransform = true;
        listTransform = [TransformPiece('turn', 1, 'witch')];
        break;

      case 'unicorn':
        listMove = [
          for (var dirs in [
            [1, 8],
            [1, 2],
            [3, 2],
            [3, 4],
            [5, 4],
            [5, 6],
            [7, 6],
            [7, 8],
          ])
            Move(directions: dirs, maxStep: 2, spacing: 1),
        ];
        moveTransform = true;
        captureTransform = true;
        listTransform = [TransformPiece('move or capture', 1, 'unicorn_aura')];
        break;
      case 'unicorn_aura':
        trueForm = 'unicorn';
        canMoveAgain = true;
        turnTransform = true;
        listTransform = [TransformPiece('turn', 1, 'unicorn')];
        break;

      /// End ///
      default:
        return;
    }
  }

  MyChessPiece createTransformed(String newName, bool holdCount) {
    final newPiece = MyChessPiece(isWhite, newName);
    newPiece.value = value;
    newPiece.bonusValue = bonusValue;
    newPiece.moveCount = holdCount ? moveCount : 0;
    newPiece.captureCount = holdCount ? captureCount : 0;
    newPiece.turnCount = holdCount ? turnCount : 0;
    return newPiece;
  }

  MyChessPiece copy() {
    var copied = MyChessPiece(isWhite, name);
    copied.description = description;
    copied.value = value;
    copied.bonusValue = bonusValue;
    copied.isImportant = isImportant;
    copied.isPriority = isPriority;
    copied.canMoveAgain = canMoveAgain;
    copied.moveCount = moveCount;
    copied.captureCount = captureCount;
    copied.turnCount = turnCount;
    copied.listMove =
        listMove
            .map(
              (m) =>
                  m == null
                      ? null
                      : Move(
                        directions: List.from(m.directions),
                        maxStep: m.maxStep,
                        mustCapture: m.mustCapture,
                        captureAllies: m.captureAllies,
                        captureEnemies: m.captureEnemies,
                        stepping: m.stepping,
                        spacing: m.spacing,
                        startSpacing: m.startSpacing,
                        blockSpacing: m.blockSpacing,
                        minJump: m.minJump,
                        maxJump: m.maxJump,
                        jumpOverAllies: m.jumpOverAllies,
                        jumpOverEnemies: m.jumpOverEnemies,
                      ),
            )
            .toList();

    copied.listTransform =
        listTransform
            .map(
              (t) => t == null ? null : TransformPiece(t.type, t.count, t.name),
            )
            .toList();

    return copied;
  }
}
