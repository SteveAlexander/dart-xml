import '../../../xml.dart' show XmlNodeType;
import '../event.dart';
import '../visitor.dart';

/// Event of an XML comment node.
class XmlCommentEvent extends XmlEvent {
  const XmlCommentEvent(this.text);

  final String text;

  @override
  XmlNodeType get nodeType => XmlNodeType.COMMENT;

  @override
  void accept(XmlEventVisitor visitor) => visitor.visitCommentEvent(this);

  @override
  int get hashCode => nodeType.hashCode ^ text.hashCode;

  @override
  bool operator ==(Object other) =>
      other is XmlCommentEvent && other.text == text;
}
