import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';

class SalesDataPage extends StatelessWidget {
  const SalesDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 34),
        ),
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '销售数据',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '2023-2024',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/sales-data-range'),
            icon: const Icon(Icons.access_time),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: const [
          _SalesOverviewCard(),
          _SalesProgressCard(
            title: '销售金额统计',
            rows: [
              _SalesProgressItem(name: '小酥肉', value: '1820元', percent: .70),
              _SalesProgressItem(name: '特惠双人餐', value: '820元', percent: .30),
            ],
          ),
          _SalesProgressCard(
            title: '销售数量统计',
            rows: [
              _SalesProgressItem(name: '小酥肉', value: '181份', percent: .70),
              _SalesProgressItem(name: '特惠双人餐', value: '10份', percent: .30),
            ],
          ),
          _SalesTableCard(),
        ],
      ),
    );
  }
}

class SalesDataRangePage extends StatefulWidget {
  const SalesDataRangePage({super.key});

  @override
  State<SalesDataRangePage> createState() => _SalesDataRangePageState();
}

class _SalesDataRangePageState extends State<SalesDataRangePage> {
  int _choose = 4;
  DateTime? _start;
  DateTime? _end;

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? (_start ?? now) : (_end ?? now),
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppTheme.brand),
          ),
          child: child!,
        );
      },
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBg,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, size: 34),
        ),
        title: const Text(
          '统计范围',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        children: [
          _RangeCard(
            children: [
              _RangeOption(
                title: '最近7天',
                selected: _choose == 1,
                onTap: () => setState(() => _choose = 1),
              ),
              _RangeOption(
                title: '最近1月',
                selected: _choose == 2,
                onTap: () => setState(() => _choose = 2),
              ),
              _RangeOption(
                title: '最近1年',
                selected: _choose == 3,
                onTap: () => setState(() => _choose = 3),
              ),
            ],
          ),
          _RangeCard(
            children: [
              _RangeOption(
                title: '自定义日期',
                selected: _choose == 4,
                onTap: () => setState(() => _choose = 4),
              ),
              if (_choose == 4) ...[
                const Divider(height: 1, color: Color(0xFFEAEAEA)),
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          text: _formatRangeDate(_start) ?? '开始日期',
                          onTap: () => _pickDate(start: true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: _DateButton(
                          text: _formatRangeDate(_end) ?? '结束日期',
                          onTap: () => _pickDate(start: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesOverviewCard extends StatelessWidget {
  const _SalesOverviewCard();

  @override
  Widget build(BuildContext context) {
    return _SalesCard(
      title: '销售数据总览',
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.85,
        ),
        children: const [
          _OverviewItem(label: '总销售金额(元)', value: '3200.96'),
          _OverviewItem(label: '团购券已售(份)', value: '99'),
          _OverviewItem(label: '今日销售金额(元)', value: '386'),
          _OverviewItem(label: '今日团购券已售(份)', value: '320'),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEEEEEE), width: .5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesProgressCard extends StatelessWidget {
  const _SalesProgressCard({required this.title, required this.rows});

  final String title;
  final List<_SalesProgressItem> rows;

  @override
  Widget build(BuildContext context) {
    return _SalesCard(
      title: title,
      child: Column(
        children: [
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(child: Text(row.name)),
                Text(row.value),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: row.percent,
                color: AppTheme.brand,
                backgroundColor: const Color(0xFFF0F0F0),
              ),
            ),
            if (row != rows.last) const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _SalesProgressItem {
  const _SalesProgressItem({
    required this.name,
    required this.value,
    required this.percent,
  });

  final String name;
  final String value;
  final double percent;
}

class _SalesTableCard extends StatelessWidget {
  const _SalesTableCard();

  static const rows = [
    ('9/8', '27', '2235'),
    ('9/7', '26', '2000'),
    ('9/7', '26', '2000'),
    ('9/7', '26', '2000'),
    ('9/7', '26', '2000'),
    ('9/7', '26', '2000'),
    ('9/7', '26', '2000'),
    ('9/7', '26', '2000'),
    ('9/7', '26', '2000'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SalesCard(
      title: '日报表',
      child: Table(
        border: TableBorder.all(color: const Color(0xFFF4F4F4)),
        columnWidths: const {
          0: FlexColumnWidth(.8),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(1.4),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFEEEEEE)),
            children: [
              _TableCell('日期', header: true),
              _TableCell('销售数量(份)', header: true),
              _TableCell('销售金额(元)', header: true),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                _TableCell(row.$1),
                _TableCell(row.$2),
                _TableCell(row.$3),
              ],
            ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text, {this.header = false});

  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: header ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF4F4F4))),
            ),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _RangeOption extends StatelessWidget {
  const _RangeOption({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: selected ? AppTheme.brand : AppTheme.textPrimary,
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.brand : const Color(0xFF999999),
                ),
              ),
              child: selected
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.brand,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text),
      ),
    );
  }
}

String? _formatRangeDate(DateTime? value) {
  if (value == null) return null;
  return '${value.year}/${value.month}/${value.day}';
}
