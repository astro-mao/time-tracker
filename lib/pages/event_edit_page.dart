import 'package:flutter/material.dart';
import '../app_state.dart';
import '../db/database_helper.dart';
import '../models/event.dart';
import '../utils/ui.dart';

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
    '#2563EB', '#10B981', '#F59E0B', '#EF4444',
    '#8B5CF6', '#06B6D4', '#EC4899', '#84CC16',
  ];
  late String _color;
  bool _saving = false;

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
    if (_saving) return;
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入名称')));
      return;
    }
    setState(() => _saving = true);
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
    // 关键：事件变了必须广播，否则计时页/记录页/统计页还拿着旧列表
    AppState().notify();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '编辑事件' : '新建事件')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: softCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('事件名称',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('给这段时间起个名字，比如「写代码」「开会」',
                    style: TextStyle(fontSize: 12, color: AppColors.faint)),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameCtl,
                  autofocus: !isEdit,
                  textInputAction: TextInputAction.done,
                  maxLength: 12,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    hintText: '如：写代码',
                    counterText: '',
                    prefixIcon: Icon(Icons.edit_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: softCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('标记颜色',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('颜色会用在列表、环形图和统计里',
                    style: TextStyle(fontSize: 12, color: AppColors.faint)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: _palette.map((c) {
                    final selected = _color == c;
                    return GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hexColor(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: hexColor(c).withOpacity(.35),
                              blurRadius: selected ? 12 : 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: selected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(isEdit ? '保存修改' : '创建事件'),
            ),
          ),
        ],
      ),
    );
  }
}
