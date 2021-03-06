import '../../../xml.dart' show XmlNodeType;
import '../event.dart';
import '../utils/named.dart';
import '../visitor.dart';

/// Event of an closing XML element node.
class XmlEndElementEvent extends XmlEvent with XmlNamed {
  const XmlEndElementEvent(this.name, [this.namespaceUri]);

  @override
  final String name;

  @override
  final String namespaceUri;

  @override
  XmlNodeType get nodeType => XmlNodeType.ELEMENT;

  @override
  void accept(XmlEventVisitor visitor) => visitor.visitEndElementEvent(this);

  @override
  int get hashCode => nodeType.hashCode ^ name.hashCode;

  @override
  bool operator ==(Object other) =>
      other is XmlEndElementEvent && other.name == name;
}
