import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'question_rich_text.dart';
import '../theme/app_theme.dart';

enum PracticeMode { random, sequential, wrong }

class PracticePage extends StatefulWidget {
  const PracticePage({super.key});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  // Setup state
  KbBank? _selectedBank;
  PracticeMode _mode = PracticeMode.random;
  int _minWrongCount = 1;
  final TextEditingController _wrongCtrl = TextEditingController(text: '1');
  String? _wrongError;
  bool _loading = false;
  int _bankTotal = 0; // 选中题库的后代总题数（0=未选/全库）

  // 强制练习配置状态
  String? _forcedBankId;
  String? _forcedBankName;
  List<String>? _forcedCategoryIds;

  // Bank drill-down state
  List<Map<String, dynamic>> _bankTreeRaw = []; // tree from API
  Map<String, Map<String, dynamic>> _bankNodeMap = {}; // id → node
  Map<String, int> _descendantCounts = {};
  List<_NavStep> _drillPath = [];
  bool _treeLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBankTree();
    _loadForcedConfig();
  }

  @override
  void dispose() {
    _wrongCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBankTree() async {
    setState(() => _treeLoading = true);

    // 独立请求，一个失败不影响另一个
    try {
      final tree = await ApiService.getBankTree();
      final nodeMap = <String, Map<String, dynamic>>{};
      _buildNodeMap((tree as List<dynamic>).cast<Map<String, dynamic>>(), nodeMap);
      if (mounted) {
        setState(() {
          _bankTreeRaw = tree.cast<Map<String, dynamic>>();
          _bankNodeMap = nodeMap;
        });
      }
    } catch (_) {
      // 树加载失败，保持空列表
    }

    try {
      final counts = await ApiService.getDescendantCounts();
      if (mounted) setState(() => _descendantCounts = counts);
    } catch (_) {
      // 计数加载失败不影响主流程
    }

    if (mounted) setState(() => _treeLoading = false);
  }

  void _buildNodeMap(List<Map<String, dynamic>> nodes, Map<String, Map<String, dynamic>> map) {
    for (final node in nodes) {
      map[node['id'] as String] = node;
      final children = node['children'] as List<dynamic>?;
      if (children != null) _buildNodeMap(children.cast<Map<String, dynamic>>(), map);
    }
  }

  /// 当前展示的题库列表（根或某层的 children）
  List<Map<String, dynamic>> get _currentBanks {
    if (_drillPath.isEmpty) return _bankTreeRaw;
    final node = _bankNodeMap[_drillPath.last.id];
    if (node == null) return [];
    final children = node['children'] as List<dynamic>?;
    return children?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 下钻到子题库
  void _drillInto(String bankId) {
    final node = _bankNodeMap[bankId];
    if (node == null) return;
    setState(() {
      _drillPath.add(_NavStep(id: bankId, name: node['name'] as String));
    });
  }

  /// 面包屑回退到某个位置
  void _drillBackTo(int index) {
    setState(() {
      _drillPath = _drillPath.sublist(0, index + 1);
    });
  }

  /// 回退到根
  void _drillBackToRoot() {
    setState(() {
      _drillPath.clear();
    });
  }

  /// 选中当前层级题库作为练习目标
  void _selectCurrentLevelBank() {
    if (_drillPath.isEmpty) return;
    final node = _bankNodeMap[_drillPath.last.id];
    if (node == null) return;
    _selectBankById(_drillPath.last.id, node['name'] as String);
  }

  void _selectBankById(String bankId, String bankName) {
    setState(() {
      _selectedBank = KbBank(
        id: bankId,
        createTime: '',
        updateTime: '',
        name: bankName,
      );
    });
    _bankTotal = _descendantCounts[bankId] ?? 0;
  }

  void _clearSelection() {
    setState(() {
      _selectedBank = null;
      _bankTotal = 0;
    });
  }

  /// 加载已保存的强制练习配置
  Future<void> _loadForcedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('forced_quiz_bank_id');
    final name = prefs.getString('forced_quiz_bank_name');
    final idsStr = prefs.getString('forced_quiz_category_ids');
    if (id != null && idsStr != null && idsStr.isNotEmpty) {
      if (mounted) {
        setState(() {
          _forcedBankId = id;
          _forcedBankName = name;
          _forcedCategoryIds = idsStr.split(',');
        });
      }
    }
  }

  /// 配置当前选中题库为APP入口强制练习题库
  Future<void> _configureForcedQuiz() async {
    if (_selectedBank == null) return;
    final node = _bankNodeMap[_selectedBank!.id];
    final categoryIds = node != null
        ? _collectDescendantIds(node)
        : <String>[_selectedBank!.id];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('forced_quiz_bank_id', _selectedBank!.id);
    await prefs.setString('forced_quiz_bank_name', _selectedBank!.name);
    await prefs.setString('forced_quiz_category_ids', categoryIds.join(','));
    if (mounted) {
      setState(() {
        _forcedBankId = _selectedBank!.id;
        _forcedBankName = _selectedBank!.name;
        _forcedCategoryIds = categoryIds;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已配置强制练习：${_selectedBank!.name}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 清除强制练习配置，恢复全库随机
  Future<void> _clearForcedQuiz() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('forced_quiz_bank_id');
    await prefs.remove('forced_quiz_bank_name');
    await prefs.remove('forced_quiz_category_ids');
    if (mounted) {
      setState(() {
        _forcedBankId = null;
        _forcedBankName = null;
        _forcedCategoryIds = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已清除强制练习配置，恢复全库随机'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 收集节点自身及所有后代ID
  List<String> _collectDescendantIds(Map<String, dynamic> node) {
    final ids = <String>[node['id'] as String];
    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        ids.addAll(_collectDescendantIds(child as Map<String, dynamic>));
      }
    }
    return ids;
  }

  Future<void> _startPractice() async {
    setState(() => _loading = true);
    try {
      List<KbQa> qas;

      if (_selectedBank != null) {
        // 选中题库 → 获取该题库及其后代的所有题目
        final node = _bankNodeMap[_selectedBank!.id];
        final categoryIds = node != null ? _collectDescendantIds(node) : <String>[_selectedBank!.id];
        final allData = await ApiService.getAllQasForBank();
        qas = allData
            .map((e) => KbQa.fromJson(e))
            .where((q) => categoryIds.contains(q.categoryId))
            .toList();
      } else {
        // 未选题库 → 全库所有题目
        final allData = await ApiService.getAllQasForBank();
        qas = allData.map((e) => KbQa.fromJson(e)).toList();
      }

      // 根据模式处理
      switch (_mode) {
        case PracticeMode.random:
          qas.shuffle(Random());
          break;
        case PracticeMode.sequential:
          // 保持原顺序
          break;
        case PracticeMode.wrong:
          // 错题模式：筛选错误次数 >= _minWrongCount 的题目
          qas = qas.where((q) => q.wrong >= _minWrongCount).toList();
          break;
      }

      if (qas.isEmpty) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有找到符合条件的题目')));
        }
        return;
      }

      setState(() => _loading = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PracticeQuizPage(
              questions: qas,
              bank: _selectedBank,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppTheme.indigo50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_outlined, size: 40.sp, color: AppTheme.primary),
                  ),
                ),
                SizedBox(height: 16.h),
                Center(
                  child: Text('开始练习', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                ),
                SizedBox(height: 8.h),
                Center(
                  child: Text('逐层选择题库', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
                ),
                SizedBox(height: 28.h),

                Text('选择题库', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                SizedBox(height: 8.h),
                _buildBankDrilldown(),
                SizedBox(height: 24.h),

                // ── 强制练习配置 ──
                if (_selectedBank != null) ...[
                  _buildForcedQuizConfig(),
                  SizedBox(height: 24.h),
                ],

                Text('练习模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
                SizedBox(height: 8.h),
                _buildModeSelector(),
                if (_mode == PracticeMode.wrong) ...[
                  SizedBox(height: 16.h),
                  _buildWrongThresholdControl(),
                ],
                SizedBox(height: 32.h),

                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton.icon(
                    onPressed: (_loading || (_mode == PracticeMode.wrong && _wrongError != null)) ? null : _startPractice,
                    icon: _loading
                        ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow, color: Colors.white),
                    label: Text(
                      _loading
                          ? '加载中...'
                          : _selectedBank != null
                              ? '开始练习 ($_bankTotal 题)'
                              : '开始练习（全部题库）',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }

  // ═══════════════════════════════════════════
  // 强制练习配置 UI
  // ═══════════════════════════════════════════

  Widget _buildForcedQuizConfig() {
    final isCurrentForced = _forcedBankId == _selectedBank!.id;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isCurrentForced ? AppTheme.indigo50 : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isCurrentForced ? AppTheme.primary.withAlpha(100) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCurrentForced ? Icons.check_circle : Icons.touch_app_outlined,
                size: 18.sp,
                color: isCurrentForced ? AppTheme.primary : AppTheme.textTertiary,
              ),
              SizedBox(width: 8.w),
              Text(
                'APP入口强制练习',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (isCurrentForced) ...[
            // 已配置当前题库
            Text(
              '当前题库「$_forcedBankName」已设为APP启动时的强制练习来源',
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              height: 36.h,
              child: OutlinedButton.icon(
                onPressed: _clearForcedQuiz,
                icon: Icon(Icons.close, size: 16.sp),
                label: Text('清除配置，恢复全库随机', style: TextStyle(fontSize: 12.sp)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                ),
              ),
            ),
          ] else ...[
            // 未配置或配置了其他题库
            if (_forcedBankId != null) ...[
              Text(
                '当前强制练习来源是「$_forcedBankName」，选择下方按钮可更换',
                style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary),
              ),
              SizedBox(height: 8.h),
            ],
            SizedBox(
              width: double.infinity,
              height: 36.h,
              child: OutlinedButton.icon(
                onPressed: _configureForcedQuiz,
                icon: Icon(Icons.lock_outline, size: 16.sp, color: AppTheme.primary),
                label: Text(
                  '配置「${_selectedBank!.name}」为强制练习',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankDrilldown() {
    if (_treeLoading) {
      return Container(
        padding: EdgeInsets.all(24.h),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentBanks = _currentBanks;
    final hasSelected = _selectedBank != null;
    final isRoot = _drillPath.isEmpty;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: hasSelected ? AppTheme.primary : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 面包屑导航
          _buildBreadcrumb(),
          if (_drillPath.isNotEmpty) SizedBox(height: 10.h),

          // 银行列表（竖排全宽）
          if (currentBanks.isNotEmpty) ...[
            ...currentBanks.map((bank) => _buildBankRow(bank)),
          ] else if (isRoot && _bankTreeRaw.isEmpty)
            // 根层级且无题库
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Center(
                child: Text('暂无题库，请先创建', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
              ),
            )
          else if (!isRoot)
            // 非根层级且无子题库
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Center(
                child: Column(children: [
                  Icon(Icons.folder_outlined, size: 36.sp, color: AppTheme.textTertiary.withAlpha(100)),
                  SizedBox(height: 6.h),
                  Text('此层级下无子题库', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13.sp)),
                ]),
              ),
            ),

          // 选中当前层级题库的提示
          if (_drillPath.isNotEmpty && (_selectedBank == null || _selectedBank!.id != _drillPath.last.id)) ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: _selectCurrentLevelBank,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.indigo50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppTheme.indigo100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16.sp, color: AppTheme.primary),
                    SizedBox(width: 6.w),
                    Text(
                      '选择「${_drillPath.last.name}」',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.primary, fontFamily: 'Inter'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 已选中的题库信息
          if (hasSelected) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppTheme.indigo50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.indigo100),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder, size: 16.sp, color: AppTheme.primary),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      _selectedBank!.name,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Inter'),
                    ),
                  ),
                  if (_bankTotal > 0)
                    Text('$_bankTotal 题', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
                  SizedBox(width: 4.w),
                  GestureDetector(
                    onTap: _clearSelection,
                    child: Icon(Icons.close, size: 16.sp, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 单个题库行（全宽卡片）
  Widget _buildBankRow(Map<String, dynamic> bank) {
    final id = bank['id'] as String;
    final name = bank['name'] as String;
    final hasChildren = (bank['children'] as List<dynamic>?)?.isNotEmpty ?? false;
    final count = _descendantCounts[id] ?? 0;
    final isSelected = _selectedBank?.id == id;

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: InkWell(
        onTap: () {
          if (hasChildren) {
            _drillInto(id);
          } else {
            _selectBankById(id, name);
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          height: 64.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withAlpha(15) : AppTheme.bgSection,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border.withAlpha(120),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // 左侧图标
              Container(
                width: 40.w, height: 40.w,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  hasChildren ? Icons.folder_rounded : Icons.menu_book_rounded,
                  color: AppTheme.primary,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              // 名称 + 题数
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      hasChildren ? (count > 0 ? '$count 题（含子题库）' : '暂无题目') : (count > 0 ? '$count 题' : '暂无题目'),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: count > 0 ? AppTheme.primary : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // 右侧操作图标
              if (hasChildren)
                Icon(Icons.chevron_right, size: 20.sp, color: AppTheme.textTertiary)
              else
                Icon(Icons.play_circle_outline, size: 22.sp, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  /// 面包屑
  Widget _buildBreadcrumb() {
    if (_drillPath.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4.w,
      runSpacing: 4.h,
      children: [
        _breadcrumbChip('全部', onTap: _drillBackToRoot),
        for (int i = 0; i < _drillPath.length; i++) ...[
          Icon(Icons.chevron_right, size: 16.sp, color: AppTheme.textTertiary),
          _breadcrumbChip(
            _drillPath[i].name,
            isLast: i == _drillPath.length - 1,
            onTap: () => _drillBackTo(i),
          ),
        ],
      ],
    );
  }

  Widget _breadcrumbChip(String label, {bool isLast = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isLast ? AppTheme.primary : AppTheme.bgSection,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isLast ? Colors.white : AppTheme.textSecondary,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: AppTheme.bgSection,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          _modeTab(PracticeMode.random, '随机', Icons.shuffle_outlined),
          _modeTab(PracticeMode.sequential, '顺序', Icons.format_list_numbered_outlined),
          _modeTab(PracticeMode.wrong, '错题', Icons.error_outline),
        ].expand((w) => [Expanded(child: w)]).toList(),
      ),
    );
  }

  Widget _modeTab(PracticeMode mode, String label, IconData icon) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _mode = mode;
        if (mode == PracticeMode.wrong) {
          _wrongCtrl.text = '1';
          _minWrongCount = 1;
          _wrongError = null;
        }
      }),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20.sp, color: selected ? Colors.white : AppTheme.textTertiary),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : AppTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateWrongInput() {
    final text = _wrongCtrl.text.trim();
    if (text.isEmpty) {
      _wrongError = '请输入错误次数';
      return;
    }
    final v = int.tryParse(text);
    if (v == null) {
      _wrongError = '请输入有效数字';
      return;
    }
    if (v < 1) {
      _wrongError = '错误次数必须 ≥ 1';
      return;
    }
    _wrongError = null;
    _minWrongCount = v;
  }

  Widget _buildWrongThresholdControl() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最小错误次数', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp, color: AppTheme.textPrimary)),
          SizedBox(height: 8.h),
          TextField(
            controller: _wrongCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '默认 1',
              filled: true,
              fillColor: AppTheme.bgSection,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: _wrongError != null ? AppTheme.red : AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: _wrongError != null ? AppTheme.red : AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide(color: _wrongError != null ? AppTheme.red : AppTheme.primary, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              suffixIcon: IconButton(
                icon: Icon(Icons.check_circle_outline, size: 20.sp, color: _wrongError != null ? AppTheme.textTertiary : AppTheme.primary),
                onPressed: () {
                  setState(() => _validateWrongInput());
                },
              ),
            ),
            onSubmitted: (_) => setState(() => _validateWrongInput()),
            onChanged: (_) {
              if (_wrongError != null) setState(() => _validateWrongInput());
            },
          ),
          if (_wrongError != null) ...[
            SizedBox(height: 6.h),
            Text(_wrongError!, style: TextStyle(color: AppTheme.red, fontSize: 12.sp)),
          ],
          SizedBox(height: 8.h),
          Text(
            '筛选错误次数 ≥ $_minWrongCount 的题目',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

class PracticeQuizPage extends StatefulWidget {
  final List<KbQa> questions;
  final KbBank? bank;
  const PracticeQuizPage({super.key, required this.questions, this.bank});

  @override
  State<PracticeQuizPage> createState() => _PracticeQuizPageState();
}

class _PracticeQuizPageState extends State<PracticeQuizPage> {
  List<KbQa> _questions = [];
  int _currentIndex = 0;
  late PageController _pageController;
  List<bool> _revealed = [];
  List<List<TextEditingController>> _userAnswerCtrls = [];
  bool _showExitConfirm = false;

  Map<String, KbBank> _categoryMap = {};

  @override
  void initState() {
    super.initState();
    _questions = widget.questions;
    _pageController = PageController();
    _revealed = List.filled(_questions.length, false);
    _userAnswerCtrls = List.generate(
      _questions.length,
      (i) => List.generate(_questions[i].answer.length, (_) => TextEditingController()),
    );
    if (widget.bank != null) {
      _categoryMap = {widget.bank!.id: widget.bank!};
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final ctrlList in _userAnswerCtrls) {
      for (final c in ctrlList) c.dispose();
    }
    super.dispose();
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

    // API 静默更新统计（后端暂未支持则忽略）
    ApiService.updateQa(qa.id, {'total': newTotal, 'right': newRight, 'wrong': newWrong}).catchError((_) {});

    setState(() {
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
        score: qa.score,
        sortOrder: qa.sortOrder,
        categoryId: qa.categoryId,
        tagId: qa.tagId,
      );
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _exitPractice() {
    setState(() => _showExitConfirm = true);
  }

  void _cancelExit() {
    setState(() => _showExitConfirm = false);
  }

  void _confirmExit() {
    void attempt(int tries) {
      if (!mounted || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.mounted) return;
        Navigator.of(context, rootNavigator: true).maybePop().then((didPop) {
          if (!didPop && tries < 20) {
            attempt(tries + 1);
          }
        });
      });
    }
    attempt(0);
  }

  @override
  Widget build(BuildContext context) {
    final qa = _questions[_currentIndex];
    final progress = (_currentIndex + (_revealed[_currentIndex] ? 1 : 0)) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: '退出练习',
          onPressed: _exitPractice,
        ),
        title: Text(
          '第 ${_currentIndex + 1} / ${_questions.length} 题',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
        ),
        centerTitle: true,
        actions: [
          if (widget.bank != null)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Chip(
                label: Text(widget.bank!.name, style: TextStyle(fontSize: 11.sp)),
                backgroundColor: AppTheme.indigo50,
                labelStyle: TextStyle(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(6.h),
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2.r),
              child: LinearProgressIndicator(
                value: progress, minHeight: 3.h,
                backgroundColor: AppTheme.border.withAlpha(80),
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
            SizedBox(height: 3.h),
          ]),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: _questions.length,
        itemBuilder: (ctx, i) {
          final qi = _questions[i];
          final revealed = _revealed[i];
          final ctrls = _userAnswerCtrls[i];
          final isLast = i == _questions.length - 1;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 题目卡片
                _buildQuestionCard(qi, i, revealed),
                SizedBox(height: 20.h),
                // 答题区 / 结果区
                if (!revealed)
                  _buildAnswerArea(qi, ctrls, i)
                else ...[
                  _buildResultArea(qi, ctrls),
                  SizedBox(height: 16.h),
                  _buildStatsCard(qi),
                  // 最后一题答完后提示
                  if (isLast)
                    Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Center(
                        child: Text('已完成全部题目，左滑回顾',
                          style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _showExitConfirm
          ? Container(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelExit,
                    child: const Text('继续练习'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmExit,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
                    child: const Text('退出', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ]),
            )
          : Container(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_questions.length, (i) {
                  final isCurrent = i == _currentIndex;
                  final isAnswered = _revealed[i];
                  return Container(
                    width: isCurrent ? 20.w : 8.w,
                    height: 8.w,
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.primary
                          : isAnswered
                              ? AppTheme.primary.withAlpha(80)
                              : AppTheme.border,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  );
                }),
              ),
            ),
    );
  }

  Widget _buildQuestionCard(KbQa qa, int index, bool revealed) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28.w, height: 28.w,
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8.r)),
              child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: Colors.white))),
            ),
            SizedBox(width: 10.w),
            Text('填空题', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
          ]),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity, padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(color: AppTheme.bgSection, borderRadius: BorderRadius.circular(12.r)),
            child: QuestionRichText(text: qa.question, revealed: revealed, answers: qa.answer, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(KbQa qa, List<TextEditingController> ctrls, int pageIndex) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('请填空作答', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
        SizedBox(height: 12.h),
        ...List.generate(qa.answer.length, (i) => Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(children: [
            Container(
              width: 24.w, height: 24.w,
              decoration: BoxDecoration(color: AppTheme.indigo50, borderRadius: BorderRadius.circular(6.r)),
              child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: AppTheme.primary, fontFamily: 'Inter'))),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: ctrls[i],
                autofocus: i == 0,
                decoration: InputDecoration(
                  hintText: '空${i + 1} 的答案',
                  filled: true, fillColor: AppTheme.bgSection,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
              ),
            ),
          ]),
        )),
        SizedBox(height: 8.h),
        SizedBox(
          width: double.infinity, height: 48.h,
          child: ElevatedButton.icon(
            onPressed: _submitAnswer,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('提交答案', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter')),
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
          ),
        ),
      ]),
    );
  }

  Widget _buildResultArea(KbQa qa, List<TextEditingController> ctrls) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('答题结果', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
        SizedBox(height: 12.h),
        ...List.generate(qa.answer.length, (i) {
          final isCorrect = ctrls[i].text.trim() == qa.answer[i];
          final borderColor = isCorrect ? AppTheme.green : AppTheme.red;
          return Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 24.w, height: 24.w,
                  decoration: BoxDecoration(
                    color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Center(child: Icon(isCorrect ? Icons.check : Icons.close, size: 14, color: borderColor)),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(color: AppTheme.bgSection, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: borderColor, width: 1.5)),
                    child: Text(ctrls[i].text, style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: isCorrect ? AppTheme.green : AppTheme.red, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              SizedBox(height: 6.h),
              Padding(
                padding: EdgeInsets.only(left: 32.w),
                child: Row(children: [
                  Text('正确答案：', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary, fontFamily: 'Inter')),
                  Flexible(child: Text(qa.answer[i], style: TextStyle(fontSize: 13.sp, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'Inter'))),
                ]),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildStatsCard(KbQa qa) {
    final accuracy = qa.total > 0 ? (qa.right / qa.total * 100).round() : 0;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, size: 18.sp, color: AppTheme.primary),
          SizedBox(width: 6.w),
          Text('练习统计', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.sp, fontFamily: 'Inter', color: AppTheme.textPrimary)),
        ]),
        SizedBox(height: 12.h),
        Row(children: [
          _statItem(label: '总次数', value: qa.total, color: AppTheme.textPrimary),
          _statItem(label: '答对', value: qa.right, color: AppTheme.green),
          _statItem(label: '答错', value: qa.wrong, color: AppTheme.red),
        ]),
        SizedBox(height: 10.h),
        Row(children: [
          Text('正确率 ', style: TextStyle(fontSize: 12.sp, color: AppTheme.textTertiary)),
          Text('$accuracy%',
            style: TextStyle(
              fontSize: 14.sp, fontWeight: FontWeight.bold,
              color: accuracy >= 60 ? AppTheme.green : AppTheme.red,
              fontFamily: 'Inter',
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _statItem({required String label, required int value, required Color color}) {
    return Expanded(
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
        SizedBox(height: 2.h),
        Text(label, style: TextStyle(fontSize: 11.sp, color: AppTheme.textTertiary)),
      ]),
    );
  }
}

/// 面包屑导航步骤
class _NavStep {
  final String id;
  final String name;
  const _NavStep({required this.id, required this.name});
}
