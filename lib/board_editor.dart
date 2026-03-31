import 'package:flutter/material.dart';
import 'my_board.dart';
import 'my_chess_piece.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum EditMode { zone, piece, promotion, limit }

enum TagState { normal, include, exclude }

Color getZoneColor(int zone) {
  if (zone == 0) return Color.fromARGB(45, 191, 191, 191);
  int a = 30 * zone.abs();
  return zone > 0
      ? Color.fromARGB(a, 0, 128, 255)
      : Color.fromARGB(a, 255, 0, 0);
}

class BoardEditor extends StatefulWidget {
  const BoardEditor({super.key});

  @override
  State<BoardEditor> createState() => _BoardEditorState();
}

class _BoardEditorState extends State<BoardEditor> {
  late ChessBoard board;
  EditMode currentMode = EditMode.zone;

  int selectedZone = 0;
  MyChessPiece? selectedPiece; // null để xóa
  // bool isPiecePaletteWhite = true; // Đã được thay thế bằng pieceFilterStates
  Map<String, TagState> pieceFilterStates = {};

  @override
  void initState() {
    super.initState();
    board = ChessBoard(8, 8);
    board.useBoard('custom'); // load mặc định
    _initializeFilters();
  }

  void _initializeFilters() async {
    pieceFilterStates = await _loadPieceFilterState();
    if (mounted) setState(() {}); // Rebuild with loaded filters
  }

  Future<void> _savePieceFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    // Chuyển Map<String, TagState> thành Map<String, int> để lưu trữ
    final storableMap = pieceFilterStates.map(
      (key, value) => MapEntry(key, value.index),
    );
    await prefs.setString('piece_filter_state', jsonEncode(storableMap));
  }

  Future<Map<String, TagState>> _loadPieceFilterState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('piece_filter_state');
    final allTags = MyChessPiece.getAllTag();

    if (jsonString == null) {
      // Trả về map mặc định nếu chưa có gì được lưu
      // Mặc định, bộ lọc màu trắng được bật
      final defaultStates = {for (var tag in allTags) tag: TagState.normal};
      defaultStates['#white'] = TagState.include;
      return defaultStates;
    }

    final loadedMap = jsonDecode(jsonString) as Map<String, dynamic>;
    // Chuyển Map<String, dynamic> (thực chất là Map<String, int>) trở lại Map<String, TagState>
    final finalMap = loadedMap.map(
      (key, value) => MapEntry(key, TagState.values[value as int]),
    );
    // Đảm bảo tag màu không bao giờ ở trạng thái 'normal'
    if (finalMap['#white'] == TagState.normal) {
      finalMap['#white'] = TagState.include;
    }
    return finalMap;
  }

  Future<void> saveToSlot(String slot) async {
    final prefs = await SharedPreferences.getInstance();
    final data = board.toJson(); // bạn cần đảm bảo board.toJson() trả về Map
    await prefs.setString('slot_$slot', jsonEncode(data));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã lưu vào slot $slot')));
  }

  Future<void> loadFromSlot(String slot) async {
    if (slot == 'slot0') {
      setState(() {
        board = ChessBoard(8, 8)..useBoard('default');
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã tải bàn cờ mặc định')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('slot_$slot');

    if (jsonString == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Slot $slot chưa có dữ liệu')));
      return;
    }

    final data = jsonDecode(jsonString);
    setState(() {
      board = ChessBoard.fromJson(data); // đảm bảo bạn có fromJson đúng
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã tải từ slot $slot')));
  }

  Future<String?> askForBoardName(BuildContext context, String? oldName) async {
    final controller = TextEditingController(text: oldName ?? '');
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nhập tên bản cờ'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '<No name>',
              hintStyle: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  Future<void> showBoardSizeDialog(BuildContext context) async {
    final rowController = TextEditingController();
    final colController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Thay đổi kích thước bàn cờ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: colController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số cột',
                  hintText: '2 <= X <= 32',
                  hintStyle: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              TextField(
                controller: rowController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số hàng',
                  hintText: '4 <= Y <= 32',
                  hintStyle: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final rows = int.tryParse(rowController.text);
      final cols = int.tryParse(colController.text);
      if (rows != null && cols != null && rows >= 4 && cols >= 2) {
        confirmAction(
          context,
          'Dữ liệu hiện tại sẽ mất. Bạn có chắc không?',
          () {
            setState(() {
              board = ChessBoard(rows, cols);
              board.useBoard('custom');
            });
          },
        );
      }
    }
  }

  void handleTap(int row, int col) {
    setState(() {
      if (currentMode == EditMode.zone) {
        board.zone[row][col] = selectedZone;
      } else if (currentMode == EditMode.piece) {
        final MyChessPiece? pieceOnSquare = board.board[row][col];

        // Nếu công cụ đang chọn là "xóa" (selectedPiece == null), thì luôn xóa.
        if (selectedPiece == null) {
          board.board[row][col] = null;
          return;
        }

        // Kiểm tra xem quân cờ trên ô có giống với quân cờ đang chọn không.
        final bool isSamePiece =
            pieceOnSquare != null &&
            pieceOnSquare.name == selectedPiece!.name &&
            pieceOnSquare.isWhite == selectedPiece!.isWhite;

        if (isSamePiece) {
          // Nếu giống nhau, xóa quân cờ đi (toggle off).
          board.board[row][col] = null;
        } else {
          // Nếu khác, đặt quân cờ mới vào.
          board.board[row][col] = MyChessPiece(
            selectedPiece!.isWhite,
            selectedPiece!.name,
          );
        }
      }
    });
  }

  void confirmAction(
    BuildContext context,
    String message,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Xác nhận'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  void showSaveSlotDialog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('slot0_name', 'Bàn Cờ Mặc Định');
    Map<String, String?> slotNames = {
      'slot0': prefs.getString('slot0_name'),
      'slot1': prefs.getString('slot1_name'),
      'slot2': prefs.getString('slot2_name'),
      'slot3': prefs.getString('slot3_name'),
      'slot4': prefs.getString('slot4_name'),
      'slot5': prefs.getString('slot5_name'),
      'slot6': prefs.getString('slot6_name'),
      'slot7': prefs.getString('slot7_name'),
      'slot8': prefs.getString('slot8_name'),
      'slot9': prefs.getString('slot9_name'),
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('💾 File Save'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  [
                    'slot0',
                    'slot1',
                    'slot2',
                    'slot3',
                    'slot4',
                    'slot5',
                    'slot6',
                    'slot7',
                    'slot8',
                    'slot9',
                  ].map((slot) {
                    final hasData =
                        slot == 'slot0' || prefs.containsKey('slot_$slot');
                    final displayName =
                        hasData
                            ? (slotNames[slot]?.isNotEmpty == true
                                ? slotNames[slot]!
                                : '<No Name>')
                            : '<Empty>';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 🧾 Tên bàn cờ ở trên bên trái
                            Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: hasData ? Colors.black : Colors.grey,
                              ),
                            ),

                            SizedBox(height: 8),

                            /// 🔘 Các nút ở dưới bên phải
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (slot !=
                                      'slot0') // Không cho save với slot0
                                    IconButton(
                                      icon: Icon(Icons.save),
                                      tooltip: 'Lưu',
                                      onPressed:
                                          () => confirmAction(
                                            context,
                                            'Ghi đè dữ liệu lên "${slotNames[slot]?.isNotEmpty == true ? slotNames[slot] : slot}"?',
                                            () async {
                                              final name =
                                                  await askForBoardName(
                                                    context,
                                                    slotNames[slot],
                                                  );
                                              if (name != null) {
                                                await prefs.setString(
                                                  '${slot}_name',
                                                  name,
                                                );
                                                await saveToSlot(slot);
                                                Navigator.pop(context);
                                              }
                                            },
                                          ),
                                    ),
                                  if (hasData)
                                    IconButton(
                                      icon: Icon(Icons.folder_open),
                                      tooltip: 'Tải',
                                      onPressed:
                                          () => confirmAction(
                                            context,
                                            'Tải dữ liệu từ "${slotNames[slot]?.isNotEmpty == true ? slotNames[slot] : slot}"? Dữ liệu hiện tại sẽ bị ghi đè.',
                                            () async {
                                              await loadFromSlot(slot);
                                              Navigator.pop(context);
                                            },
                                          ),
                                    ),
                                  if (slot != 'slot0' && hasData)
                                    IconButton(
                                      icon: Icon(Icons.delete),
                                      tooltip: 'Xoá',
                                      onPressed:
                                          () => confirmAction(
                                            context,
                                            'Xoá dữ liệu của "${slotNames[slot]?.isNotEmpty == true ? slotNames[slot] : slot}"?',
                                            () async {
                                              await prefs.remove('slot_$slot');
                                              await prefs.remove(
                                                '${slot}_name',
                                              );
                                              Navigator.pop(context);
                                            },
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  /// Widget palette chọn zone
  Widget buildZonePalette() {
    int lastTapTime = 0;

    return StatefulBuilder(
      builder: (context, setInner) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nút giảm
            IconButton(
              icon: Icon(Icons.remove),
              onPressed:
                  selectedZone > -3
                      ? () => setInner(() => selectedZone--)
                      : null,
            ),

            // Nút zone hiện tại với nhấn 2 lần để reset
            GestureDetector(
              onTap: () {
                int now = DateTime.now().millisecondsSinceEpoch;
                if (now - lastTapTime < 500) {
                  // double tap
                  setInner(() => selectedZone = 0);
                }
                lastTapTime = now;
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: getZoneColor(selectedZone),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                ),
                child: Text(
                  '$selectedZone',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Nút tăng
            IconButton(
              icon: Icon(Icons.add),
              onPressed:
                  selectedZone < 3
                      ? () => setInner(() => selectedZone++)
                      : null,
            ),
          ],
        );
      },
    );
  }

  void _showPiecePickerDialog(
    BuildContext context,
    List<MyChessPiece> allPieces,
    Function(MyChessPiece?) onSelected,
  ) {
    Set<String> getTagsForPiece(MyChessPiece piece) {
      // Lấy tag từ trường description (ví dụ: "#base #normal #pawn")
      final descriptionTags =
          piece.description
              .split(' ') // Tách chuỗi thành các phần
              .where(
                (s) => s.startsWith('#'),
              ) // Chỉ lấy các phần bắt đầu bằng '#'
              .toSet(); // Chuyển thành Set để loại bỏ trùng lặp

      // Thêm tag màu sắc
      if (piece.isWhite) {
        descriptionTags.add('#white');
      }
      return descriptionTags;
    }

    // Lấy tất cả các tag duy nhất từ tất cả các quân cờ
    // Lấy tag theo thứ tự đã định nghĩa trong MyChessPiece
    final allAvailableTags = MyChessPiece.getAllTag();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Lọc danh sách quân cờ dựa trên các tag đã chọn từ state chính
              final displayedPieces =
                  allPieces.where((piece) {
                    final pieceTags = getTagsForPiece(piece);
                    bool passesFilter = true;
                    pieceFilterStates.forEach((tag, state) {
                      if (state != TagState.normal) {
                        if (state == TagState.include &&
                            !pieceTags.contains(tag)) {
                          passesFilter = false;
                        }
                        if (state == TagState.exclude &&
                            pieceTags.contains(tag)) {
                          passesFilter = false;
                        }
                      }
                    });
                    return passesFilter;
                  }).toList();

              return Dialog(
                child: Container(
                  padding: EdgeInsets.all(12),
                  width: 350, // Tăng chiều rộng một chút
                  height: 500, // Tăng chiều cao để có chỗ cho filter
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn Quân',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      // Vùng chứa các chip filter
                      // Các nút điều khiển bộ lọc
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bộ lọc:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextButton(
                            onPressed: () {
                              // Cập nhật state chính và state của dialog
                              setDialogState(() {
                                setState(() {
                                  // Reset tất cả các tag ngoại trừ tag màu
                                  pieceFilterStates.updateAll(
                                    (key, value) =>
                                        key == '#white'
                                            ? pieceFilterStates[key]!
                                            : TagState.normal,
                                  );
                                  _savePieceFilterState();
                                });
                              });
                            },
                            child: Text('Reset'),
                          ),
                        ],
                      ),
                      // Giới hạn chiều cao và thêm cuộn cho vùng filter
                      Container(
                        constraints: BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6.0,
                            runSpacing: 0.0,
                            children:
                                allAvailableTags.map((tag) {
                                  final state =
                                      pieceFilterStates[tag] ?? TagState.normal;
                                  return FilterChip(
                                    label: Text(tag),
                                    selected: state != TagState.normal,
                                    selectedColor:
                                        state == TagState.include
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                    avatar: null, // Bỏ avatar
                                    showCheckmark: false,
                                    onSelected: (isSelected) {
                                      // Cập nhật state chính và state của dialog
                                      setDialogState(() {
                                        setState(() {
                                          // Cập nhật state của BoardEditor
                                          if (tag == '#white') {
                                            // Tag màu chỉ có 2 trạng thái: include/exclude
                                            pieceFilterStates[tag] =
                                                state == TagState.include
                                                    ? TagState.exclude
                                                    : TagState.include;
                                          } else {
                                            // Các tag khác có 3 trạng thái
                                            if (state == TagState.normal) {
                                              pieceFilterStates[tag] =
                                                  TagState.include;
                                            } else if (state ==
                                                TagState.include) {
                                              pieceFilterStates[tag] =
                                                  TagState.exclude;
                                            } else {
                                              pieceFilterStates[tag] =
                                                  TagState.normal;
                                            }
                                          }
                                          _savePieceFilterState();
                                        });
                                      });
                                    },
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                      Divider(),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 4,
                          children: [
                            // Nút xóa
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                                onSelected(null);
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/pieces/delete.png',
                                    width: 32,
                                    height: 32,
                                    errorBuilder: (_, __, ___) => Text('X'),
                                  ),
                                  SizedBox(height: 4),
                                ],
                              ),
                            ),
                            // Danh sách quân cờ đã lọc
                            ...displayedPieces.map(
                              (p) => GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onSelected(p);
                                },
                                child: Tooltip(
                                  message: p.name,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        p.imagePath,
                                        width: 32,
                                        height: 32,
                                        errorBuilder:
                                            (_, __, ___) => Text(p.name),
                                      ),
                                      SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  /// Widget palette chọn quân
  Widget buildPiecePalette() {
    final allPieces = MyChessPiece.getAllTemplates();
    // Lấy trạng thái màu từ bộ lọc, mặc định là trắng nếu chưa có
    final isWhite =
        (pieceFilterStates['#white'] ?? TagState.include) == TagState.include;

    MyChessPiece? getMatchingPiece(String name, bool color) {
      try {
        return allPieces.firstWhere(
          (p) => p.name == name && p.isWhite == color,
        );
      } catch (e) {
        return null; // Trả về null nếu không tìm thấy quân cờ tương ứng
      }
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // Công tắc chuyển màu quân cờ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/pieces/w_round_pawn.png',
                width: 28,
                height: 28,
              ),
              Switch(
                value: isWhite,
                onChanged: (newValue) {
                  setState(() {
                    pieceFilterStates['#white'] =
                        newValue ? TagState.include : TagState.exclude;
                    if (selectedPiece != null) {
                      selectedPiece = getMatchingPiece(
                        selectedPiece!.name,
                        newValue,
                      );
                    }
                  });
                  _savePieceFilterState();
                },
                activeTrackColor: Colors.blue.shade200,
                inactiveTrackColor: Colors.grey.shade500,
                inactiveThumbColor: Colors.black,
              ),
              Image.asset(
                'assets/images/pieces/b_round_pawn.png',
                width: 28,
                height: 28,
              ),
            ],
          ),
        ),

        // Nút chọn quân hoặc xóa
        GestureDetector(
          onTap: () {
            // Mở dialog chọn quân
            _showPiecePickerDialog(context, allPieces, (value) {
              debugPrint("Selected: ${value?.name ?? 'null'}");
              setState(() {
                selectedPiece = value;
                // Nếu người dùng chọn 1 quân, cập nhật bộ lọc màu cho phù hợp
                if (value != null) {
                  pieceFilterStates['#white'] =
                      value.isWhite ? TagState.include : TagState.exclude;
                  _savePieceFilterState();
                }
              });
            });
          },
          child: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 204, 240, 255),
              border: Border.all(
                color: Color.fromARGB(255, 0, 128, 255),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                selectedPiece != null
                    ? Image.asset(
                      selectedPiece!.imagePath,
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => Text(selectedPiece!.name),
                    )
                    : Image.asset(
                      'assets/images/pieces/delete.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => Text('Xóa'),
                    ),
          ),
        ),
      ],
    );
  }

  Widget buildPromotionEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < board.chessPromoted.length; i++) ...[
          Row(
            children: [
              // Quân cờ sẽ được phong
              Image.asset(
                board.chessPromoted[i].piece.imagePath,
                width: 32,
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    board.chessPromoted[i].piece.name,
                  ); // fallback nếu không tìm thấy ảnh
                },
              ),

              // Vùng phong cấp
              Text(
                'Zone: ${board.chessPromoted[i].fromZone} → ${board.chessPromoted[i].toZone}',
              ),

              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => showEditPromotionDialog(i),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed:
                    () => setState(() {
                      board.chessPromoted.removeAt(i);
                    }),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children:
                board.chessPromoted[i].listChess
                    .map(
                      (e) => Chip(
                        label: Image.asset(
                          e.imagePath,
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              e.name,
                            ); // fallback nếu không tìm thấy ảnh
                          },
                        ),
                      ),
                    )
                    .toList(),
          ),
          Divider(),
        ],
        ElevatedButton.icon(
          onPressed: () => showEditPromotionDialog(null),
          icon: Icon(Icons.add),
          label: Text('Thêm luật phong cấp'),
        ),
      ],
    );
  }

  void showEditPromotionDialog(int? index) {
    final isEdit = index != null;
    final ChessPromoted? oldRule = isEdit ? board.chessPromoted[index] : null;

    MyChessPiece? selectedPiece =
        oldRule != null
            ? MyChessPiece.getAllTemplates().firstWhere(
              (p) =>
                  p.name == oldRule.piece.name &&
                  p.isWhite == oldRule.piece.isWhite,
              orElse: () => MyChessPiece.getAllTemplates().first,
            )
            : null;
    int fromZone = oldRule?.fromZone ?? 0;
    int toZone = oldRule?.toZone ?? 0;
    List<MyChessPiece> selectedList = [...(oldRule?.listChess ?? [])];
    bool isDeleteMode = false;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            width: double.maxFinite,
            height:
                MediaQuery.of(context).size.height * 0.8, // điều chỉnh tùy bạn
            child: StatefulBuilder(
              builder: (context, setInner) {
                return Column(
                  children: [
                    Text(
                      isEdit ? 'Sửa phong cấp' : 'Tạo phong cấp',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quân cờ gốc:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                _showPiecePickerDialog(
                                  context,
                                  MyChessPiece.getAllTemplates(),
                                  (newPiece) {
                                    setInner(() => selectedPiece = newPiece);
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    selectedPiece != null
                                        ? Image.asset(
                                          selectedPiece!.imagePath,
                                          width: 40,
                                          height: 40,
                                          errorBuilder:
                                              (_, __, ___) =>
                                                  Text(selectedPiece!.name),
                                        )
                                        : const Tooltip(
                                          message: "Chọn quân cờ",
                                          child: Icon(
                                            Icons.add_box_outlined,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                        ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text('Từ zone:'),
                                SizedBox(width: 10),
                                DropdownButton<int>(
                                  value: fromZone,
                                  items:
                                      List.generate(7, (i) => i - 3)
                                          .map(
                                            (z) => DropdownMenuItem(
                                              value: z,
                                              child: Text('$z'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setInner(() {
                                        fromZone = v!;
                                        if (toZone < fromZone) {
                                          toZone = fromZone;
                                        }
                                      }),
                                ),
                                Text('→'),
                                DropdownButton<int>(
                                  value: toZone,
                                  items:
                                      List.generate(7, (i) => i - 3)
                                          .where((z) => z >= fromZone)
                                          .map(
                                            (z) => DropdownMenuItem(
                                              value: z,
                                              child: Text('$z'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) => setInner(() => toZone = v!),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Phong thành quân:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.add_circle_outline),
                                      tooltip: 'Thêm quân',
                                      onPressed: () async {
                                        _showPiecePickerDialog(
                                          context,
                                          MyChessPiece.getAllTemplates(),
                                          (newPiece) {
                                            if (newPiece != null &&
                                                !selectedList.contains(
                                                  newPiece,
                                                )) {
                                              setInner(
                                                () =>
                                                    selectedList.add(newPiece),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline),
                                      tooltip: 'Chế độ xóa',
                                      color: isDeleteMode ? Colors.red : null,
                                      onPressed:
                                          () => setInner(
                                            () => isDeleteMode = !isDeleteMode,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              width: double.infinity,
                              constraints: BoxConstraints(minHeight: 70),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    selectedList.map((p) {
                                      return GestureDetector(
                                        onTap: () {
                                          if (isDeleteMode) {
                                            setInner(
                                              () => selectedList.remove(p),
                                            );
                                          }
                                        },
                                        child: Chip(
                                          label: Image.asset(
                                            p.imagePath,
                                            width: 32,
                                            height: 32,
                                          ),
                                          backgroundColor:
                                              isDeleteMode
                                                  ? Colors.red.shade100
                                                  : null,
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (selectedPiece == null) return;
                            final newRule = ChessPromoted(
                              piece: selectedPiece!,
                              fromZone: fromZone,
                              toZone: toZone,
                              listChess: selectedList,
                            );
                            setState(() {
                              if (isEdit) {
                                board.chessPromoted[index] = newRule;
                              } else {
                                board.chessPromoted.add(newRule);
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: Text('Lưu'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget buildLimitEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < board.chessLimit.length; i++) ...[
          Row(
            children: [
              Image.asset(
                board.chessLimit[i].piece.imagePath,
                width: 32,
                height: 32,
                errorBuilder: (context, error, stackTrace) {
                  return Text(board.chessLimit[i].piece.name);
                },
              ),
              SizedBox(width: 8),
              Text(
                'Zone: ${board.chessLimit[i].fromZone} → ${board.chessLimit[i].toZone}',
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () => showEditLimitDialog(i),
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed:
                    () => setState(() {
                      board.chessLimit.removeAt(i);
                    }),
              ),
            ],
          ),
          Divider(),
        ],
        ElevatedButton.icon(
          onPressed: () => showEditLimitDialog(null),
          icon: Icon(Icons.add),
          label: Text('Thêm luật giới hạn'),
        ),
      ],
    );
  }

  void showEditLimitDialog(int? index) {
    final isEdit = index != null;
    final ChessLimit? oldRule = isEdit ? board.chessLimit[index] : null;

    MyChessPiece? selectedPiece =
        oldRule != null
            ? MyChessPiece.getAllTemplates().firstWhere(
              (p) =>
                  p.name == oldRule.piece.name &&
                  p.isWhite == oldRule.piece.isWhite,
              orElse: () => MyChessPiece.getAllTemplates().first,
            )
            : null;
    int fromZone = oldRule?.fromZone ?? 0;
    int toZone = oldRule?.toZone ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16),
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: StatefulBuilder(
              builder: (context, setInner) {
                return Column(
                  children: [
                    Text(
                      isEdit ? 'Sửa giới hạn' : 'Tạo giới hạn',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quân cờ bị giới hạn:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                _showPiecePickerDialog(
                                  context,
                                  MyChessPiece.getAllTemplates(),
                                  (newPiece) {
                                    setInner(() => selectedPiece = newPiece);
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child:
                                    selectedPiece != null
                                        ? Image.asset(
                                          selectedPiece!.imagePath,
                                          width: 40,
                                          height: 40,
                                          errorBuilder:
                                              (_, __, ___) =>
                                                  Text(selectedPiece!.name),
                                        )
                                        : const Tooltip(
                                          message: "Chọn quân cờ",
                                          child: Icon(
                                            Icons.add_box_outlined,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                        ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text('Chỉ đi trong zone:'),
                                SizedBox(width: 10),
                                DropdownButton<int>(
                                  value: fromZone,
                                  items:
                                      List.generate(7, (i) => i - 3)
                                          .map(
                                            (z) => DropdownMenuItem(
                                              value: z,
                                              child: Text('$z'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setInner(() {
                                        fromZone = v!;
                                        if (toZone < fromZone) {
                                          toZone = fromZone;
                                        }
                                      }),
                                ),
                                Text('→'),
                                DropdownButton<int>(
                                  value: toZone,
                                  items:
                                      List.generate(7, (i) => i - 3)
                                          .where((z) => z >= fromZone)
                                          .map(
                                            (z) => DropdownMenuItem(
                                              value: z,
                                              child: Text('$z'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) => setInner(() => toZone = v!),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (selectedPiece == null) return;
                            final newRule = ChessLimit(
                              piece: selectedPiece!,
                              fromZone: fromZone,
                              toZone: toZone,
                            );
                            setState(() {
                              if (isEdit) {
                                board.chessLimit[index] = newRule;
                              } else {
                                board.chessLimit.add(newRule);
                              }
                            });
                            Navigator.pop(context);
                          },
                          child: Text('Lưu'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Editor'),
        actions: [
          IconButton(
            icon: Icon(Icons.grid_on),
            tooltip: 'Thay đổi kích thước bàn cờ',
            onPressed: () => showBoardSizeDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.save),
            tooltip: '💾',
            onPressed: showSaveSlotDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Controls: Mode Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToggleButtons(
                  isSelected: [
                    currentMode == EditMode.zone,
                    currentMode == EditMode.piece,
                    currentMode == EditMode.promotion,
                    currentMode == EditMode.limit,
                  ],
                  onPressed: (index) {
                    setState(() {
                      currentMode = EditMode.values[index];
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(Icons.select_all),
                          SizedBox(width: 4),
                          Text('Zone'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(Icons.people_alt_outlined),
                          SizedBox(width: 4),
                          Text('Piece'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(Icons.star_half_outlined),
                          SizedBox(width: 4),
                          Text('Promote'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(Icons.block),
                          SizedBox(width: 4),
                          Text('Limit'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Selection palette
            if (currentMode == EditMode.zone) buildZonePalette(),
            if (currentMode == EditMode.piece) buildPiecePalette(),
            SizedBox(height: 10),
            if (currentMode == EditMode.promotion)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: buildPromotionEditor(),
              )
            else if (currentMode == EditMode.limit)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: buildLimitEditor(),
              )
            else
              // Board Grid
              SizedBox(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final maxHeight = constraints.maxHeight;

                    final maxSide =
                        board.maxRow > board.maxCol
                            ? board.maxRow
                            : board.maxCol;
                    final cellSize =
                        (maxWidth < maxHeight ? maxWidth : maxHeight) / maxSide;
                    final maxsc = maxSide / 4;
                    return InteractiveViewer(
                      minScale: 0.25,
                      maxScale: maxsc,
                      child: SizedBox(
                        width: cellSize * board.maxCol,
                        height: cellSize * board.maxRow,
                        child: GridView.builder(
                          physics:
                              const NeverScrollableScrollPhysics(), // tránh scroll bên trong
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: board.maxCol,
                                childAspectRatio: 1.0,
                              ),
                          itemCount: board.maxRow * board.maxCol,
                          itemBuilder: (context, index) {
                            final row = index ~/ board.maxCol;
                            final col = index % board.maxCol;
                            final zone = board.zone[row][col];
                            final piece = board.board[row][col];

                            return GestureDetector(
                              onTap: () => handleTap(row, col),
                              child: Container(
                                width: cellSize,
                                height: cellSize,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  color: getZoneColor(zone),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      zone.toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    if (piece != null)
                                      Image.asset(
                                        piece.imagePath,
                                        width: cellSize * 0.8,
                                        height: cellSize * 0.8,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Text(piece.name);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
