import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/models/user/danmaku_block.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class RuleFilter {
  static final _regExp = RegExp(r'^/(.*)/$');

  final List<String> _dmFilterString;
  final List<RegExp> _dmRegExp;
  final Set<String> _dmUid;
  // Merged candidates keep their content and sender; cache by object identity.
  Expando<bool> _matchCache = Expando<bool>();

  Iterable<String> get dmFilterString => _dmFilterString;
  Iterable<RegExp> get dmRegExp => _dmRegExp;
  late final Iterable<String> dmUid = UnmodifiableSetView(_dmUid);

  int get count => _dmFilterString.length + _dmRegExp.length + _dmUid.length;
  bool get isEmpty =>
      _dmFilterString.isEmpty && _dmRegExp.isEmpty && _dmUid.isEmpty;

  RuleFilter(
    Iterable<String> dmFilterString,
    Iterable<RegExp> dmRegExp,
    Iterable<String> dmUid,
  ) : _dmFilterString = List.unmodifiable(dmFilterString),
      _dmRegExp = List.unmodifiable(dmRegExp),
      _dmUid = dmUid.toSet();

  factory RuleFilter.fromRuleTypeEntries(List<List<SimpleRule>> rules) {
    final dmRegExp = <RegExp>[];
    for (final e in rules[1]) {
      final raw = e.filter;
      final normalized = _regExp.matchAsPrefix(raw)?.group(1) ?? raw;
      try {
        dmRegExp.add(RegExp(normalized, caseSensitive: false));
      } catch (error, stackTrace) {
        final displayFilter = _shortText(raw);
        SmartDialog.showToast('"$displayFilter"无法处理，已跳过');

        final message =
            '[DanmakuFilter] skip invalid regex: '
            'id=${e.id}, type=${e.type}, raw=$raw, normalized=$normalized, '
            'error=$error';
        logger.i(message);
        Utils.reportError(message, stackTrace);
      }
    }

    return RuleFilter(
      rules[0].map((e) => e.filter),
      dmRegExp,
      rules[2].map((e) => e.filter),
    );
  }

  RuleFilter.empty() : this(const [], const [], const []);

  bool addUid(String uid) {
    if (!_dmUid.add(uid)) return false;
    _matchCache = Expando<bool>();
    return true;
  }

  bool hasSameRules(RuleFilter other) {
    const strings = UnorderedIterableEquality<String>();
    const regexps = UnorderedIterableEquality<(String, bool, bool, bool, bool)>();
    (String, bool, bool, bool, bool) signature(RegExp rule) => (
      rule.pattern,
      rule.isCaseSensitive,
      rule.isMultiLine,
      rule.isUnicode,
      rule.isDotAll,
    );
    return strings.equals(_dmFilterString, other._dmFilterString) &&
        const SetEquality<String>().equals(_dmUid, other._dmUid) &&
        regexps.equals(_dmRegExp.map(signature), other._dmRegExp.map(signature));
  }

  bool remove(DanmakuElem elem) {
    if (isEmpty) return false;
    final cached = _matchCache[elem];
    if (cached != null) return cached;
    final blocked = _dmUid.contains(elem.midHash) ||
        _dmFilterString.any((i) => elem.content.contains(i)) ||
        _dmRegExp.any((i) => i.hasMatch(elem.content));
    _matchCache[elem] = blocked;
    return blocked;
  }

  static String _shortText(String text, [int maxLength = 40]) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }
}
