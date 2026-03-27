import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/models/user/danmaku_block.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/foundation.dart';

class RuleFilter {
  static final _regExp = RegExp(r'^/(.*)/$');
  static const String _debugTag = 'TestDanmakuFilter';

  List<String> dmFilterString = [];
  List<RegExp> dmRegExp = [];
  Set<String> dmUid = {};

  int count = 0;

  RuleFilter(this.dmFilterString, this.dmRegExp, this.dmUid, [int? count]) {
    this.count =
        count ?? dmFilterString.length + dmRegExp.length + dmUid.length;
  }

  RuleFilter.fromRuleTypeEntries(List<List<SimpleRule>> rules) {
    logDebug(
      'RuleFilter.fromRuleTypeEntries start\n'
      '${formatRulesSnapshot('rawRules', rules)}',
    );

    dmFilterString = rules[0].map((e) => e.filter).toList();
    logDebug(_formatItems('rawKeywords', dmFilterString));

    final regexLogs = StringBuffer('rawRegex.total=${rules[1].length}');
    dmRegExp = <RegExp>[];
    for (int i = 0; i < rules[1].length; i++) {
      final SimpleRule rule = rules[1][i];
      final String normalized =
          _regExp.matchAsPrefix(rule.filter)?.group(1) ?? rule.filter;
      regexLogs
        ..writeln()
        ..write(
          'rawRegex[$i]: id=${rule.id}, type=${rule.type}, '
          'raw=${_trimText(rule.filter)}',
        )
        ..writeln()
        ..write('rawRegex[$i].normalized=${_trimText(normalized)}');
      try {
        final regExp = RegExp(normalized, caseSensitive: false);
        dmRegExp.add(regExp);
        regexLogs
          ..writeln()
          ..write(
            'rawRegex[$i].compiled=${_trimText(regExp.pattern)}',
          );
      } catch (error, stackTrace) {
        regexLogs
          ..writeln()
          ..write('rawRegex[$i].compileError=$error');
        logError(
          'RuleFilter.fromRuleTypeEntries regex compile failed\n$regexLogs',
          error,
          stackTrace,
        );
        rethrow;
      }
    }
    logDebug(regexLogs.toString());

    dmUid = rules[2].map((e) => e.filter).toSet();
    logDebug(_formatItems('rawUid', dmUid));

    count = dmFilterString.length + dmRegExp.length + dmUid.length;
    logDebug(
      'RuleFilter.fromRuleTypeEntries complete\n${debugSummary('builtRuleFilter')}',
    );
  }

  RuleFilter.empty();

  bool remove(DanmakuElem elem) {
    return dmUid.contains(elem.midHash) ||
        dmFilterString.any((i) => elem.content.contains(i)) ||
        dmRegExp.any((i) => i.hasMatch(elem.content));
  }

  String debugSummary([String label = 'ruleFilter']) {
    final buffer = StringBuffer(
      '$label.count=$count, '
      '$label.keywordCount=${dmFilterString.length}, '
      '$label.regexCount=${dmRegExp.length}, '
      '$label.uidCount=${dmUid.length}',
    );
    buffer
      ..writeln()
      ..write(_formatItems('$label.keyword', dmFilterString))
      ..writeln()
      ..write(_formatItems('$label.regex', dmRegExp.map((i) => i.pattern)))
      ..writeln()
      ..write(_formatItems('$label.uid', dmUid));
    return buffer.toString();
  }

  static String formatRulesSnapshot(
    String label,
    List<List<SimpleRule>> rules,
  ) {
    final keywordRules = rules.isNotEmpty ? rules[0] : <SimpleRule>[];
    final regexRules = rules.length > 1 ? rules[1] : <SimpleRule>[];
    final uidRules = rules.length > 2 ? rules[2] : <SimpleRule>[];
    return [
      _formatSimpleRules('$label.keyword', keywordRules),
      _formatSimpleRules('$label.regex', regexRules),
      _formatSimpleRules('$label.uid', uidRules),
    ].join('\n');
  }

  static void logDebug(String msg) {
    if (!kDebugMode && !Pref.enableLog) {
      return;
    }
    final message = '[$_debugTag] $msg';
    logger.i(message);
    if (Pref.enableLog) {
      Utils.reportError(message);
    }
  }

  static void logError(String msg, Object error, StackTrace stackTrace) {
    if (!kDebugMode && !Pref.enableLog) {
      return;
    }
    final message = '[$_debugTag] $msg\nerror=$error';
    logger.i(message);
    if (Pref.enableLog) {
      Utils.reportError(message, stackTrace);
    }
  }

  static String _formatSimpleRules(String label, List<SimpleRule> rules) {
    final buffer = StringBuffer('$label.total=${rules.length}');
    for (int i = 0; i < rules.length; i++) {
      final SimpleRule rule = rules[i];
      buffer
        ..writeln()
        ..write(
          '$label[$i]: id=${rule.id}, type=${rule.type}, '
          'filter=${_trimText(rule.filter)}',
        );
    }
    return buffer.toString();
  }

  static String _formatItems(String label, Iterable<String> items) {
    final list = items.toList(growable: false);
    final buffer = StringBuffer('$label.total=${list.length}');
    for (int i = 0; i < list.length; i++) {
      buffer
        ..writeln()
        ..write('$label[$i]=${_trimText(list[i])}');
    }
    return buffer.toString();
  }

  static String _trimText(String value, [int maxLength = 800]) {
    final normalized = value.replaceAll('\n', r'\n');
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}...<trimmed>';
  }
}
