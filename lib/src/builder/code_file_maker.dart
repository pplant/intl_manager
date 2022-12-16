part of './builder.dart';

RegExp regExp = new RegExp(
  r'\{[a-zA-Z]+_arg_\d+\}',
  caseSensitive: false,
  multiLine: true,
);

RegExp intRegex = RegExp(r'\{int_arg_\d+\}');
RegExp stringRegex = RegExp(r'\{string_arg_\d+\}');

RegExp one = new RegExp(
  r"=1{(.*?)} other{",
  caseSensitive: false,
  multiLine: true,
);

RegExp other = new RegExp(
  r"} other{(.*?)}}",
  caseSensitive: false,
  multiLine: true,
);

String _makeClassCodeString(String className,String supportedLocaleCode, String getterCode) {
  return '''
// DO NOT EDIT. This is code generated via package:intl_manager

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class $className {
$supportedLocaleCode
$getterCode}
''';
}

String _makeGetterCode(String message, String key) {
  message = _filterMessage(message);
  key = _filterKey(key);
  return '''
  String get $key => Intl.message('$message', name: '$key');\n''';
}

String _makeGetterCodeWithArgs(String message, String key, List<String> args) {
  message = _filterMessage(message);
  key = _filterKey(key);
  final arguments = args.map((e) => e.replaceAll('int ', '').replaceAll('String ', '')).toList();
  return '''
  String $key(${args.join(',')}) => Intl.message('$message', name: '$key', args: $arguments);\n''';
}

String _makePluralCode(String one, String other, String key) {
  one = _filterMessage(one);
  other = _filterMessage(other);
  key = _filterKey(key);
  return '''
  String $key(num count) => Intl.plural(count, one: '${one.replaceAll('{count}', '\$count')}', other: '${other.replaceAll('{count}', '\$count')}', name: '$key', args: [count]);\n''';
}

String _makeSupportedLocaleCode(List<I18nEntity> supportedLocale) {
  String _supportedLanguageCode='';
  int size = supportedLocale.length;
  for(int i=0;i<size;i++){
    var l = supportedLocale[i].locale;
    _supportedLanguageCode+="'${l.languageCode}',";
  }
  if(_supportedLanguageCode.endsWith(',')){
    _supportedLanguageCode=_supportedLanguageCode.substring(0,_supportedLanguageCode.length-1);
  }
  //
  String _supportedLocaleMap='';
  for(int i=0;i<size;i++){
    var l = supportedLocale[i].locale;
    _supportedLocaleMap+="['${l.languageCode}','${l.countryCode??''}'],";
  }
  if(_supportedLocaleMap.endsWith(',')){
    _supportedLocaleMap=_supportedLocaleMap.substring(0,_supportedLocaleMap.length-1);
  }
  return '''
  static const List<String> _supportedLanguageCode = [${_supportedLanguageCode??''}];
  static const List<List<String>> _supportedLocaleMap = [${_supportedLocaleMap??''}];

  static List<String> getSupportedLanguageCodes(){
    return _supportedLanguageCode;
  }

  static List<Locale> createSupportedLocale(bool appendCountryCode){
    List<Locale> result = [];
    for (List<String> c in _supportedLocaleMap) {
      result.add(Locale(c[0], appendCountryCode ? c[1] : ''));
    }
    return result;
  }\n''';
}

String _filterMessage(String msg){
  msg = msg.replaceAll('\n', '\\n');
  msg = msg.replaceAll('\r', '\\r');
  msg = msg.replaceAll('\t', '\\r');
  msg = msg.replaceAll("'", "\\'");
  return msg;
}

String _filterKey(String? key){
  if(key==null){
    return '';
  }
  return key.trim();
}

bool makeDefinesDartCodeFile(
    File outFile, String className, Map<String, dynamic> arbJson,List<I18nEntity> supportedLocale) {
  List<String> getters = [];
  arbJson.forEach((key, value) {
    if (key.startsWith('@')) {
      return;
    }
    final String finalValue = value;
    // check if we have a formatArgs, if so replace with flutter-compatible one
    if (one.hasMatch(finalValue) && other.hasMatch(finalValue)) {
      getters.add(_makePluralCode(one.firstMatch(finalValue)!.group(1)!, other.firstMatch(finalValue)!.group(1)!, key));
    } else if (regExp.hasMatch(value)) {
      List<String> args = [];
      int iterCounter = 1;
      final newValue = value.replaceAllMapped(regExp, (match) {
        final arg = "arg_$iterCounter";
        iterCounter+= 1;
        args.add('${intRegex.hasMatch(match.group(0)) ? 'int' : 'String'} $arg');
        return '\$$arg';
      });
      getters.add(_makeGetterCodeWithArgs(newValue, key, args));
    } else {
      getters.add(_makeGetterCode(value, key));
    }
  });
  if (!outFile.existsSync()) {
    print('creating new File ${outFile.path}');
    outFile.createSync(recursive: true);
  }
  String supportedLocaleCode = _makeSupportedLocaleCode(supportedLocale);
  String contentStr = _makeClassCodeString(className,supportedLocaleCode, getters.join());
  outFile.writeAsStringSync(contentStr);
  return true;
}
