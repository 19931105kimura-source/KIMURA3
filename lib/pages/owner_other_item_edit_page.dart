import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/other_item_data.dart';
import '../utils/price_format.dart';

class OwnerOtherItemEditPage extends StatefulWidget {
  const OwnerOtherItemEditPage({super.key});

  @override
  State<OwnerOtherItemEditPage> createState() =>
      _OwnerOtherItemEditPageState();
}

class _OwnerOtherItemEditPageState
    extends State<OwnerOtherItemEditPage> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final otherData = context.watch<OtherItemData>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('その他 編集'),
      ),
      body: Row(
        children: [
          // =====================
          // 左：カテゴリ一覧
          // =====================
          SizedBox(
            width: 240,
            child: Column(
              children: [
                Expanded(
                  child: ReorderableListView(
                    onReorder: otherData.reorderCategories,
                    children: otherData.categories.map((cat) {
                      final selected = cat == _selectedCategory;
                      return ListTile(
                        key: ValueKey(cat),
                        selected: selected,
                        title: Text(cat),
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ✏️ カテゴリ名編集
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final name = await _inputText(
                                  context,
                                  'カテゴリ名編集',
                                  initial: cat,
                                );
                                if (name != null) {
                                  otherData.renameCategory(cat, name);
                                  setState(() =>
                                      _selectedCategory = name);
                                }
                              },
                            ),
                            // 🗑 削除
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () {
                                otherData.removeCategory(cat);
                                if (_selectedCategory == cat) {
                                  setState(() => _selectedCategory = null);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('カテゴリ追加'),
                  onTap: () async {
                    final name =
                        await _inputText(context, 'カテゴリ名');
                    if (name != null) {
                      otherData.addCategory(name);
                      setState(() => _selectedCategory = name);
                    }
                  },
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // =====================
          // 右：商品編集
          // =====================
          Expanded(
            child: _selectedCategory == null
                ? const Center(child: Text('カテゴリを選択してください'))
                : _itemArea(context),
          ),
        ],
      ),
    );
  }

  // =========================
  // 商品一覧エリア
  // =========================
  Widget _itemArea(BuildContext context) {
    final otherData = context.read<OtherItemData>();
    final items = otherData.items
        .where((i) => i['category'] == _selectedCategory)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ReorderableListView(
              onReorder: (o, n) {
                otherData.reorderItemsInCategory(
                  _selectedCategory!,
                  o,
                  n,
                );
              },
              children: items.map((item) {
                return ListTile(
                  key: ValueKey(item),
                  title: Text(item['name']),
                  subtitle: Text(formatYen(item['price']))
,
                  onTap: () =>
                      _editItemDialog(context, item),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('項目追加'),
            onPressed: () async {
              final name =
                  await _inputText(context, '項目名');
              if (name == null) return;

              final priceStr =
                  await _inputText(context, '金額');
              final price = int.tryParse(priceStr ?? '');
              if (price == null) return;

              otherData.addItem(
                _selectedCategory!,
                name,
                price,
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================
  // 商品 編集ダイアログ
  // =========================
  Future<void> _editItemDialog(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final nameCtrl =
        TextEditingController(text: item['name']);
    final priceCtrl =
        TextEditingController(text: '${item['price']}');

    final otherData = context.read<OtherItemData>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('項目編集'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: '表示名'),
            ),
            TextField(
              controller: priceCtrl,
              decoration:
                  const InputDecoration(labelText: '金額'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              otherData.removeItem(item);
              Navigator.pop(context);
            },
            child: const Text('削除',
                style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              otherData.renameItem(item, nameCtrl.text);
              final price = int.tryParse(priceCtrl.text);
              if (price != null) {
                otherData.updatePrice(item, price);
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // =========================
  // 共通：テキスト入力
  // =========================
  Future<String?> _inputText(
    BuildContext context,
    String title, {
    String initial = '',
  }) async {
    final controller =
        TextEditingController(text: initial);

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
