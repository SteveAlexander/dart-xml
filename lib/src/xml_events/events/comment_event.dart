library xml_events.events.comment_event;

import 'package:xml/xml.dart';

import '../event.dart';

class XmlCommentEvent extends XmlEvent {
  XmlCommentEvent(this.text);

  final String text;

  @override
  XmlNodeType get nodeType => XmlNodeType.COMMENT;

  @override
  String toString() => '$runtimeType($text)';
}