import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'question_rich_text.dart';
import '../theme/desktop_theme.dart';

enum PracticeModeType { random, bank, wrong }

enum SubMode { sequential, random, wrong }

class PracticePage extends StatefulWidget {
  final ValueChanged<bool>? onStartedChanged;
  const PracticePage({super.key, this.onStartedChanged});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  PracticeModeType _modeType = PracticeModeType.random;
  String? _categoryId;
  SubMode _subMode = SubMode.random;
  int _minScore = 0;
  List<KbBank> _banks = [];
  Map<String, KbBank> _categoryMap = {};
  bool _loading = false;

  List<KbQa> _questions = [];
  int _currentIndex = 0;
  List<bool> _revealed = [];
  List<List<TextEditingController>> _userAnswerCtrls = [];
  bool _started = false;
  int _rightCount = 0;
  int _wrongCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final data = await ApiService.pageBanks(pageSize: 100);
      final banks = (data['items'] as List).map((e) => KbBank.fromJson(e)).toList();
      setState(() {
        _banks = banks;
        _categoryMap = {for (var b in banks) b.id: b};
      });
    } catch (_) {}
  }

  Future<void> _startPractice() async {
    setState(() => _loading = true);
    try {
      List<dynamic> data;
      switch (_modeType) {
        case PracticeModeType.random:
          data = await ApiService.randomQas(limit: 10);
          break;
        case PracticeModeType.bank:
          switch (_subMode) {
            case SubMode.sequential:
              data = await ApiService.sequentialQas(limit: 10, categoryId: _categoryId);
              break;
            case SubMode.random:
              data = await ApiService.randomQas(limit: 10, categoryId: _categoryId);
              break;
            case SubMode.wrong:
              data = await ApiService.wrongQas(limit: 10, categoryId: _categoryId, minScore: _minScore);
              break;
          }
          break;
        case PracticeModeType.wrong:
          data = await ApiService.wrongQas(limit: 10, minScore: _minScore);
          break;
      }

      final qas = data.map((e) => KbQa.fromJson(e)).toList();

      if (qas.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有找到符合条件的题目')));
        }
        return;
      }

      setState(() {
        _questions = qas;
        _revealed = List.filled(qas.length, false);
        _userAnswerCtrls = List.generate(
          qas.length,
          (i) => List.generate(qas[i].answer.length, (_) => TextEditingController()),
        );
        _currentIndex = 0;
        _started = true;
        _loading = false;
        _rightCount = 0;
        _wrongCount = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onStartedChanged?.call(true);
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  void _reset() {
    for (final ctrlList in _userAnswerCtrls) {
      for (final c in ctrlList) c.dispose();
    }
    widget.onStartedChanged?.call(false);
    setState(() {
      _started = false;
      _questions = [];
      _revealed = [];
      _userAnswerCtrls = [];
      _rightCount = 0;
      _wrongCount = 0;
    });
  }

  bool _checkAnswer(KbQa qa) {
    final userAnswers = _userAnswerCtrls[_currentIndex].map((c) => c.text.trim()).toList();
    if (userAnswers.length != qa.answer.length) return false;
    for (int i = 0; i < qa.answer.length; i++) {
      if (userAnswers[i] != qa.answer[i]) return false;
    }
    return true;
  }

  void _submitAnswer() async {
    final qa = _questions[_currentIndex];
    final isCorrect = _checkAnswer(qa);

    final newTotal = qa.total + 1;
    final newRight = qa.right + (isCorrect ? 1 : 0);
    final newWrong = qa.wrong + (isCorrect ? 0 : 1);

    try {
      await ApiService.updateQa(qa.id, {'total': newTotal, 'right': newRight, 'wrong': newWrong});
    } catch (e) {
      debugPrint('统计更新失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('统计更新失败: $e'), backgroundColor: Colors.orange),
      );
    }

    setState(() {
      if (isCorrect) {
        _rightCount++;
      } else {
        _wrongCount++;
      }
      _revealed[_currentIndex] = true;
      _questions[_currentIndex] = KbQa(
        id: qa.id,
        createTime: qa.createTime,
        updateTime: qa.updateTime,
        question: qa.question,
        answer: qa.answer,
        imageUrl: qa.imageUrl,
        total: newTotal,
        right: newRight,
        wrong: newWrong,
        randomInt: qa.randomInt,
        categoryId: qa.categoryId,
        tagId: qa.tagId,
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCorrect ? '回答正确！' : '回答错误，正确答案：${qa.answer.join("、")}'),
          backgroundColor: isCorrect ? DesktopTheme.green : DesktopTheme.red,
          duration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) setState(() => _currentIndex++);
  }

  void _prevQuestion() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  @override
  void dispose() {
    if (_started) {
      for (final ctrlList in _userAnswerCtrls) {
        for (final c in ctrlList) c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return _buildSetupPage();
    if (_questions.isEmpty) return _buildEmptyPracticePage();
    return _buildPracticePage();
  }

  Widget _buildEmptyPracticePage() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: DesktopTheme.textTertiary),
            const SizedBox(height: 16),
            const Text('暂无题目', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _reset, child: const Text('返回')),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupPage() {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Center(
                  child: Icon(Icons.school_outlined, size: 48, color: DesktopTheme.primary),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text('选择练习模式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('选择你喜欢的练习方式', style: TextStyle(fontSize: 13, color: DesktopTheme.textTertiary)),
                ),
                const SizedBox(height: 28),

                // Mode selector
                _buildModeSelector(),
                const SizedBox(height: 20),

                // Mode-specific controls
                _buildModeControls(),
                const SizedBox(height: 32),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _startPractice,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow, color: Colors.white),
                    label: Text(_loading ? '加载中...' : '开始练习', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DesktopTheme.bgSection,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _modeTab(PracticeModeType.random, '随机', Icons.shuffle_outlined),
          _modeTab(PracticeModeType.bank, '题库', Icons.folder_outlined),
          _modeTab(PracticeModeType.wrong, '错题', Icons.error_outline),
        ].expand((w) => [Expanded(child: w)]).toList(),
      ),
    );
  }

  Widget _modeTab(PracticeModeType type, String label, IconData icon) {
    final selected = _modeType == type;
    return GestureDetector(
      onTap: () => setState(() => _modeType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? DesktopTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : DesktopTheme.textTertiary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : DesktopTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeControls() {
    switch (_modeType) {
      case PracticeModeType.random:
        return _buildRandomControls();
      case PracticeModeType.bank:
        return _buildBankControls();
      case PracticeModeType.wrong:
        return _buildWrongControls();
    }
  }

  Widget _buildRandomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesktopTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesktopTheme.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shuffle_outlined, size: 18, color: DesktopTheme.primary),
              SizedBox(width: 6),
              Text('随机模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          SizedBox(height: 8),
          Text('从全部题库中随机抽取10道题目', style: TextStyle(color: DesktopTheme.textTertiary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBankControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesktopTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesktopTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: DesktopTheme.primary),
              SizedBox(width: 6),
              Text('题库模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoryId,
            decoration: InputDecoration(
              labelText: '选择题库',
              hintText: '全部题库',
              filled: true,
              fillColor: DesktopTheme.bgSection,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.primary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('全部题库')),
              ..._banks.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
            ],
            dropdownColor: DesktopTheme.bgCard,
            style: const TextStyle(fontSize: 13),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 12),
          const Text('练习方式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: SubMode.values.map((mode) {
              final selected = _subMode == mode;
              return _SubModeChip(label: _subModeLabel(mode), selected: selected, onTap: () => setState(() => _subMode = mode));
            }).toList(),
          ),
          if (_subMode == SubMode.wrong) ...[
            const SizedBox(height: 12),
            _buildWrongThresholdControl(),
          ],
        ],
      ),
    );
  }

  Widget _buildWrongControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesktopTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DesktopTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: DesktopTheme.primary),
              SizedBox(width: 6),
              Text('错题模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _buildWrongThresholdControl(),
        ],
      ),
    );
  }

  Widget _buildWrongThresholdControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('最小错误次数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DesktopTheme.indigo50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '>= $_minScore',
                style: const TextStyle(color: DesktopTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        Slider(
          value: _minScore.toDouble(),
          min: -1,
          max: 1,
          divisions: 2,
          label: '>= $_minScore',
          onChanged: (v) => setState(() => _minScore = v.toInt()),
        ),
        Text('筛选掌握程度 <= $_minScore 的题目 (-1=不会, 0=模糊, 1=掌握)', style: const TextStyle(color: DesktopTheme.textTertiary, fontSize: 12)),
      ],
    );
  }

  String _subModeLabel(SubMode mode) {
    switch (mode) {
      case SubMode.sequential: return '顺序练习';
      case SubMode.random: return '随机练习';
      case SubMode.wrong: return '错题练习';
    }
  }

  Widget _buildPracticePage() {
    final qa = _questions[_currentIndex];
    final revealed = _revealed[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final userAnswerCtrls = _userAnswerCtrls[_currentIndex];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: DesktopTheme.bgCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DesktopTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('第 ${_currentIndex + 1} 题', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                ),
                                if (qa.categoryId != null)
                                  Chip(
                                    label: Text(_categoryMap[qa.categoryId]?.name ?? '', style: const TextStyle(fontSize: 11)),
                                    backgroundColor: DesktopTheme.bgSection,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  color: DesktopTheme.textTertiary,
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('退出练习'),
                                      content: const Text('确定要退出当前练习吗？'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                                        TextButton(
                                          onPressed: () { Navigator.pop(ctx); _reset(); },
                                          child: const Text('确定', style: TextStyle(color: DesktopTheme.red)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  tooltip: '退出练习',
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: DesktopTheme.bgSection,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: QuestionRichText(
                                text: qa.question,
                                revealed: revealed,
                                answers: qa.answer,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!revealed) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: DesktopTheme.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DesktopTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('请填空作答', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 12),
                              ...List.generate(qa.answer.length, (i) => Padding(
                                padding: EdgeInsets.only(bottom: i < qa.answer.length - 1 ? 12 : 0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: DesktopTheme.indigo50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DesktopTheme.primary)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: userAnswerCtrls[i],
                                        decoration: InputDecoration(
                                          hintText: '空${i + 1} 的答案',
                                          filled: true,
                                          fillColor: DesktopTheme.bgSection,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: DesktopTheme.primary, width: 2)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _submitAnswer,
                                  icon: const Icon(Icons.check, color: Colors.white),
                                  label: const Text('提交答案', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: DesktopTheme.green, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('正确答案', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...qa.answer.asMap().entries.map((e) => Padding(
                                padding: EdgeInsets.only(bottom: e.key < qa.answer.length - 1 ? 6 : 0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF86EFAC),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(e.value, style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: DesktopTheme.bgCard,
              border: Border(top: BorderSide(color: DesktopTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentIndex > 0 ? _prevQuestion : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('上一题'),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: DesktopTheme.indigo50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_questions.length}',
                    style: const TextStyle(color: DesktopTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _revealed[_currentIndex] ? (!isLast ? _nextQuestion : _reset) : null,
                    icon: isLast ? const SizedBox.shrink() : const Icon(Icons.chevron_right, color: Colors.white),
                    iconAlignment: IconAlignment.end,
                    label: Text(isLast ? '返回' : '下一题', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? DesktopTheme.indigo50 : DesktopTheme.bgSection,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? DesktopTheme.indigo100 : DesktopTheme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? DesktopTheme.primary : DesktopTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
