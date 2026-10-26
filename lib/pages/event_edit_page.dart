import 'package:flutter/material.dart';
import '../models/event.dart';
import '../db/database_helper.dart';

/// 新建 / 编辑事件：填名称 + 选颜色
class EventEditPage extends StatefulWidget {
  final Event? event;
  const EventEditPage({super.key, this.event});

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  final db = DatabaseHelper();
  final _nameCtl = TextEditingController();
  final _palette = const [
    '#07C160', '#1989FA', '#FF9F0A', '#FA5151',
    '#9C27B0', '#00BCD4', '#795548', '#607D8B',
  ];
  late String _color;

  @override
  void initState() {
    super.initState();
    _color = widget.event?.color ?? _palette[0];
    _nameCtl.text = widget.event?.name ?? '';
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入名称')));
      return;
    }
    if (widget.event != null) {
      await db.updateEvent(Event(
        id: widget.event!.id,
        name: name,
        color: _color,
        sort: widget.event!.sort,
        archived: widget.event!.archived,
      ));
    } else {
      final count = (await db.getEvents()).length;
      await db.insertEvent(Event(name: name, color: _color, sort: count));
    }
    if (mounted) Navigator.pop(context);
  }

  Color _cc(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.event != null ? '编辑事件' : '新建事件')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: '事件名称',
              hintText: '如：写代码',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('选择颜色', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _palette
                .map(
                  (c) => GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _cc(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == c ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
