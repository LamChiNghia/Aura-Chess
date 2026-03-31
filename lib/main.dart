import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'play_chess.dart';
import 'my_board.dart';
import 'board_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MenuPage(),
    );
  }
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  // Hộp thoại thiết lập trận đấu tất cả trong một
  void _showGameSetupDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, String?> slotNames = {
      for (var i = 0; i <= 9; i++) 'slot$i': prefs.getString('slot${i}_name'),
    };
    // Đảm bảo slot0 luôn có tên
    prefs.setString('slot0_name', 'Mặc Định');
    // Sử dụng StatefulBuilder để cập nhật UI bên trong AlertDialog
    bool whiteIsBot = false; // Mặc định là PvP
    bool blackIsBot = true; // Mặc định người chơi là Trắng

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Thiết lập trận đấu',
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hàng ngang chính hiển thị Người/Máy cho quân Trắng và Đen
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Lựa chọn cho Quân Trắng (Người hoặc Máy)
                        Expanded(
                          child: Card(
                            color:
                                whiteIsBot
                                    ? Colors.red.shade100
                                    : Colors.blue.shade100,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  whiteIsBot =
                                      !whiteIsBot; // Đảo ngược trạng thái Bot cho quân Trắng
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/pieces/w_king.png', // Luôn là quân Vua Trắng
                                      width: 40,
                                      height: 40,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      whiteIsBot
                                          ? Icons.smart_toy
                                          : Icons.person,
                                      color:
                                          whiteIsBot
                                              ? Colors.redAccent
                                              : Colors.blueAccent,
                                      size: 30,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 16,
                        ), // Khoảng cách giữa hai lựa chọn
                        // Lựa chọn cho Quân Đen (Người hoặc Máy)
                        Expanded(
                          child: Card(
                            color:
                                blackIsBot
                                    ? Colors.red.shade100
                                    : Colors.blue.shade100,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  blackIsBot =
                                      !blackIsBot; // Đảo ngược trạng thái Bot cho quân Đen
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/pieces/b_king.png', // Luôn là quân Vua Đen
                                      width: 40,
                                      height: 40,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      blackIsBot
                                          ? Icons.smart_toy_sharp
                                          : Icons.person,
                                      color:
                                          blackIsBot
                                              ? Colors.redAccent
                                              : Colors.blueAccent,
                                      size: 30,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      "Chọn bàn cờ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: 10,
                        itemBuilder: (context, i) {
                          final slot = 'slot$i';
                          final hasData =
                              (slot == 'slot0') ||
                              prefs.containsKey('slot_$slot');
                          final displayName =
                              (slot == 'slot0')
                                  ? 'Mặc Định'
                                  : (hasData
                                      ? (slotNames[slot]?.isNotEmpty == true
                                          ? slotNames[slot]!
                                          : '<Không tên>')
                                      : '<Trống>');

                          return Card(
                            color: hasData ? Colors.white : Colors.grey[200],
                            child: ListTile(
                              title: Text(
                                displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: hasData ? Colors.black : Colors.grey,
                                ),
                              ),
                              onTap:
                                  hasData
                                      ? () async {
                                        ChessBoard board;
                                        if (slot == 'slot0') {
                                          board = ChessBoard(8, 8)
                                            ..useBoard("default");
                                        } else {
                                          final jsonString = prefs.getString(
                                            'slot_$slot',
                                          );
                                          if (jsonString == null) return;
                                          final data = jsonDecode(jsonString);
                                          board = ChessBoard.fromJson(data);
                                        }

                                        Navigator.pop(context); // Đóng dialog
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => ChessBoardPage(
                                                  boardData: board,
                                                  whiteIsBot:
                                                      whiteIsBot, // Truyền trực tiếp trạng thái
                                                  blackIsBot:
                                                      blackIsBot, // Truyền trực tiếp trạng thái
                                                ),
                                          ),
                                        );
                                      }
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play Chess Menu')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('Chơi cờ'),
              onPressed: () => _showGameSetupDialog(context),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Tạo bàn cờ'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BoardEditor()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
