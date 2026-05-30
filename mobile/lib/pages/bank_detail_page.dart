import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'qa_detail_page.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

class BankDetailPage extends StatefulWidget {
  final KbBank bank;

  const BankDetailPage({super.key, required this.bank});

  @override
  State<BankDetailPage> createState() => _BankDetailPageState();
}

class _BankDetailPageState extends State<BankDetailPage> {
  List<KbQa> _qas = [];
  int _total = 0;
  int _currentPage = 1;
  bool _busy = true;
  bool _loadingMore = false;
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _sc.addListener(_more);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _more() {
    if (_sc.position.pixels > _sc.position.maxScrollExtent - 150 &&
        !_busy &&
        !_loadingMore &&
        _qas.length < _total) {
      _currentPage++;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() => _busy = true);
    try {
      final data = await ApiService.pageQas(
        currentPage: _currentPage,
        categoryId: widget.bank.id,
      );
      if (mounted) {
        setState(() {
          _total = data['total'] as int;
          if (_currentPage == 1) {
            _qas = (data['items'] as List).map((e) => KbQa.fromJson(e)).toList();
          } else {
            _qas.addAll((data['items'] as List).map((e) => KbQa.fromJson(e)));
          }
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _accColor(double a) {
    if (a >= 0.8) return AppTheme.success;
    if (a >= 0.5) return AppTheme.accent;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.bank.name)),
      body: _busy && _qas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _qas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz_outlined, size: 56, color: AppTheme.textHint.withAlpha(128)),
                      SizedBox(height: 12.h),
                      const Text('暂无题目', style: TextStyle(color: AppTheme.textSoft, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _sc,
                  padding: EdgeInsets.only(top: 2.h, bottom: 80.h),
                  itemCount: _qas.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= _qas.length) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                      );
                    }
                    return _card(_qas[i]);
                  },
                ),
    );
  }

  Widget _card(KbQa qa) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QaDetailPage(
                qa: qa,
                banks: [widget.bank],
                tags: const [],
                onRefresh: () {
                  _currentPage = 1;
                  _fetch();
                },
              ),
            ),
          );
          _currentPage = 1;
          _fetch();
        },
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QuestionRichText(text: qa.question, fontSize: 14),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Text(widget.bank.name,
                            style: TextStyle(fontSize: 11.sp, color: AppTheme.textSoft)),
                        const Spacer(),
                        Text(
                          '${(qa.accuracy * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: _accColor(qa.accuracy),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
