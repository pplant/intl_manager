import 'dart:io';
import 'package:xml/xml.dart' as xml;
import 'package:string_unescape/string_unescape.dart';

final RegExp stringPlaceHolders = RegExp(r'\%\d\$s');
final RegExp numberPlaceHolders = RegExp(r'\%\d\$d');

class Xml2Arb {
  static Map<String, dynamic> convertFromFile(String filePath, String locale) {
    Map<String, dynamic> converted;
    File file = File(filePath);
    String content = "<xml></xml>";
    try {
      content = file.readAsStringSync();
    } catch (e) {
      print(e);
    }
    converted = convert(content, locale);
    // try and check if we have plurals
    File pluralsFile = File(filePath.replaceFirst('strings-$locale', 'plurals-$locale'));
    if (pluralsFile.existsSync()) {
      try {
        final pluralsContent = pluralsFile.readAsStringSync();
        final plurals = convertPlural(pluralsContent, locale);
        converted.addAll(plurals);
      } catch (e, stackTrace) {
        print('$e\n$stackTrace');
      }
    }
    return converted;
  }

  static Map<String, dynamic> convert(String stringsXml, String locale) {
    xml.XmlDocument result = xml.XmlDocument.parse(stringsXml);
    var stringsList = result.rootElement.children;
    Map<String, dynamic> arbJson = {};
    arbJson['@@locale'] = locale;
    for (var se in stringsList) {
      String? key = getNodeStringKey(se);
      String? arbKey = normalizeKeyName(key);
      if (arbKey != null && arbKey.isNotEmpty) {
        String newValue = unescape(se.text);
        Map<String, dynamic> placeholders = {};
        int iterCounter = 1;
        if(stringPlaceHolders.hasMatch(newValue)) {
          newValue = newValue.replaceAllMapped(stringPlaceHolders, (match) {
            final arg = "string_arg_$iterCounter";
            iterCounter+= 1;
            placeholders.putIfAbsent(arg, () => {'type': 'String'});
            return '{$arg}';
          });
        }
        iterCounter = 1;
        if(numberPlaceHolders.hasMatch(newValue)) {
          newValue = newValue.replaceAllMapped(numberPlaceHolders, (match) {
            final arg = "int_arg_$iterCounter";
            iterCounter+= 1;
            placeholders.putIfAbsent(arg, () => {'type': 'int'});
            return '{$arg}';
          });
        }
        arbJson[arbKey] = newValue;
        arbJson['@$arbKey'] = {'type': 'text', ...placeholders.isNotEmpty ? { "placeholders": placeholders} : {}};
      }
    }
    return arbJson;
  }

  static Map<String, dynamic> convertPlural(String stringsXml, String locale) {
    xml.XmlDocument result = xml.XmlDocument.parse(stringsXml);
    var stringsList = result.rootElement.children;
    Map<String, dynamic> arbJson = {};
    for (var se in stringsList) {
      String? key = getNodeStringKey(se);
      String? arbKey = normalizeKeyName(key);
      if (arbKey != null && arbKey.isNotEmpty) {
        arbJson[arbKey] = decodePluralToArb(se);
        arbJson['@$arbKey'] = {
          "description": "A plural message",
          "placeholders": {
            "count": {}
          }
        };
      }
    }
    return arbJson;
  }

  static String? decodePluralToArb(xml.XmlNode node) {
    return "{count, plural, =1{${convertToDartPlaceHolder(node, 'one')}} other{${convertToDartPlaceHolder(node, 'other')}}}";
  }
  
  static String? convertToDartPlaceHolder(xml.XmlNode node, String nodeName) {
    return node.childElements
        .firstWhere(
            (element) => element.name.qualified == 'item' && element.attributes.indexWhere((attr) => attr.name.qualified == 'quantity' && attr.value == nodeName) > -1,
        orElse: () => xml.XmlElement(xml.XmlName('item'))).text.replaceAll('%d', "{count}");
  }

  static String? getNodeStringKey(xml.XmlNode node) {
    if (node.attributes.isNotEmpty) {
      for (xml.XmlAttribute attr in node.attributes) {
        //print('\t attr: $attr');
        if (attr.name.qualified == "name") {
          return attr.value;
        }
      }
    }
    return null;
  }

  static String? normalizeKeyName(String? key) {
    if (key == null || key.length == 0) {
      return key;
    }
    List<String> parts = key.split("_");
    if (parts.length == 1) {
      return key;
    }
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      String p = parts[i];
      if (p.length > 0) {
        if (i == 0) {
          sb.write(p.substring(0, 1).toLowerCase());
        } else {
          sb.write(p.substring(0, 1).toUpperCase());
        }
        sb.write(p.substring(1, p.length));
      }
    }
    return sb.toString();
  }
}
