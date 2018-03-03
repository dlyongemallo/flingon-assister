import 'package:xml/xml.dart' as xml;
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'klingontext.dart';
import 'dart:math';

class WordDatabase {
  static Future<Map<String, WordDatabaseEntry>> getDatabase() async {
    Map<String, WordDatabaseEntry> ret = new Map();

    final List<String> memSegments = [
      '00-header', '01-b', '02-ch', '03-D', '04-gh', '05-H', '06-j', '07-l',
      '08-m', '09-n', '10-ng', '11-p', '12-q', '13-Q', '14-r', '15-S', '16-t',
      '17-tlh', '18-v', '19-w', '20-y', '21-a', '22-e', '23-I', '24-o',
      '25-u', '26-suffixes', '27-extra', '28-footer'
    ];
    final memBase = 'klingon-assistant/KlingonAssistant/data/mem-';
    final memSuffix = '.xml';
    String concat = '';

    for (String memSegment in memSegments) {
      concat += await rootBundle.loadString(memBase + memSegment + memSuffix);
    }

    final doc = xml.parse(concat);

    for (var entry in doc
        .findAllElements('database')
        .first
        .findElements('table')) {
      var elem = new WordDatabaseEntry.fromXmlNode(entry);
      ret[elem.searchName] = elem;
    }

    return ret;
  }

  // Measures similarity between haystack and needle. If haystack contains
  // needle, returns the number of extra characters in haystack that aren't
  // also in needle. Otherwise, returns a large number for sorting purposes.
  static int _extraChars(String needle, String haystack) {
    if (haystack.contains(needle)) {
      return haystack.length - needle.length;
    }

    return 999999999;
  }

  static List<WordDatabaseEntry> match({Map<String, WordDatabaseEntry> db,
    String query}) {
    List<WordDatabaseEntry> ret = [];

    if (db != null) {
      for (var entry in db.values) {
        if (query.isNotEmpty && ((
            entry.entryName.contains(query) ||
            entry.definition.contains(query) ||
            entry.searchTags.contains(query)
        ))) {
          ret.add(entry);
        }
      }
    }

    // Sort based on which entry contained a hit that most closely resembled
    // the search query.
    ret.sort((WordDatabaseEntry a, WordDatabaseEntry b) {
      return min(_extraChars(query, a.entryName),
          min(_extraChars(query, a.definition),
              _extraChars(query, a.searchTags))) -
          min(_extraChars(query, b.entryName),
              min(_extraChars(query, b.definition),
                  _extraChars(query, b.searchTags)));
    });

    return ret;
  }
}

class WordDatabaseEntry {
  WordDatabaseEntry.fromXmlNode(xml.XmlNode node) {
    try {
      id = int.parse(innerText(ofNode: node, withName: 'id'));
    } catch (InvalidNumberException) {
      // XXX figure out what ID isn't parsing
      id = 0;
    }
    entryName = innerText(ofNode: node, withName: 'entry_name');
    partOfSpeech = innerText(ofNode: node, withName: 'part_of_speech');
    definition = innerText(ofNode: node, withName: 'definition');
    definitionDE = innerText(ofNode: node, withName: 'definition_de');
    synonyms = innerText(ofNode: node, withName: 'synonyms');
    antonyms = innerText(ofNode: node, withName: 'antonyms');
    seeAlso = innerText(ofNode: node, withName: 'see_also');
    notes = innerText(ofNode: node, withName: 'notes');
    notesDe = innerText(ofNode: node, withName: 'notes_de');
    hiddenNotes = innerText(ofNode: node, withName: 'hidden_notes');
    components = innerText(ofNode: node, withName: 'components');
    examples = innerText(ofNode: node, withName: 'examples');
    examplesDe = innerText(ofNode: node, withName: 'examples_de');
    searchTags = innerText(ofNode: node, withName: 'search_tags');
    searchTagsDe = innerText(ofNode: node, withName: 'search_tags_de');
    source = innerText(ofNode: node, withName: 'source');

    searchName = normalizeSearchName('$entryName:$partOfSpeech');
  }

  int id;
  String entryName;
  String partOfSpeech;
  String definition;
  String definitionDE;
  String synonyms;
  String antonyms;
  String seeAlso;
  String notes;
  String notesDe;
  String hiddenNotes;
  String components;
  String examples;
  String examplesDe;
  String searchTags;
  String searchTagsDe;
  String source;
  String searchName;

  static String innerText({xml.XmlNode ofNode, String withName}) {
    Iterable<xml.XmlNode> matching = ofNode.children.where((child) {
      return child.attributes.where((attrib) {
        return attrib.name.toString() == 'name' &&
            attrib.value.toString() == withName;
      }).isNotEmpty;
    });
    if (matching.isNotEmpty) {
      return matching.first.text;
    }
    return '';
  }

  Widget toWidget(TextStyle style, {Function onTap(String)}) {
    final double listPadding = 8.0;
    final double hMargins = 8.0;

    final Widget emptyWidget = const Text('');

    return new Expanded(child: new Padding(
      padding: new EdgeInsets.symmetric(horizontal: hMargins),
      child: new ListView(
        children: [
          new Padding(
            padding: new EdgeInsets.only(bottom: listPadding),
            child: new Text(
              '$entryName',
              style: new TextStyle(
                fontSize: style.fontSize * 2.5,
                fontFamily: 'RobotoSlab',
              ),
          )),
          new Padding(
              padding: new EdgeInsets.only(bottom: listPadding),
              child: new RichText(text: new TextSpan(
                style: style,
                children: [
                  new TextSpan(text: '('),
                  new TextSpan(
                    text: '$partOfSpeech',
                    style: new TextStyle(fontStyle: FontStyle.italic)
                  ),
                  new TextSpan(text: ') $definition'),
                ],
              )),
            ),
          notes.isNotEmpty ? new Padding(
            padding: new EdgeInsets.only(bottom: listPadding),
            child: new KlingonText(
                fromString: '$notes',
                style: style,
                onTap: onTap
            ),
          ) : emptyWidget,
          examples.isNotEmpty ? new Padding(
            padding: new EdgeInsets.only(bottom: listPadding),
            child: new KlingonText(
            fromString: 'Examples: $examples',
            style: style,
            onTap: onTap
            ),
          ) : emptyWidget,
          seeAlso.isNotEmpty ? new Padding(
            padding: new EdgeInsets.only(bottom: listPadding),
            child: new KlingonText(
                fromString: 'See also: $seeAlso',
                style: style,
                onTap: onTap
            ),
          ) : emptyWidget,
          source.isNotEmpty ? new Padding(
            padding: new EdgeInsets.only(bottom: listPadding),
            child: new KlingonText(
                fromString: 'Source(s): $source',
                style: style,
                onTap: onTap
            ),
          ) : emptyWidget,
        ],
    )));
  }

  ListTile toListTile({Function onTap}) {
    return new ListTile(
      title: new Text(
          entryName,
          style: new TextStyle(fontFamily: 'RobotoSlab'),
      ),
      subtitle: new Text(definition),
      onTap: onTap,
    );
  }

  static String normalizeSearchName(String namepos) {
    List<String> split = namepos.split(':');

    if (split.first == '*') {
      return namepos;
    }

    String homophone = '';

    if (split.length > 2) {
      for (String attrib in split[2].split(',')) {
        try {
          int homophoneNum = int.parse(attrib.split('h').first);
          homophone = ':$homophoneNum';
          break;
        } catch (FormatException) {}
      }
    }

    return '${split[0]}:${split[1]}$homophone';
  }
}