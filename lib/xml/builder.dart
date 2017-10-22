library xml.builder;

import 'package:xml/xml/nodes/attribute.dart' show XmlAttribute;
import 'package:xml/xml/nodes/cdata.dart' show XmlCDATA;
import 'package:xml/xml/nodes/comment.dart' show XmlComment;
import 'package:xml/xml/nodes/data.dart' show XmlData;
import 'package:xml/xml/nodes/document.dart' show XmlDocument;
import 'package:xml/xml/nodes/document_fragment.dart' show XmlDocumentFragment;
import 'package:xml/xml/nodes/element.dart' show XmlElement;
import 'package:xml/xml/nodes/node.dart' show XmlNode;
import 'package:xml/xml/nodes/processing.dart' show XmlProcessing;
import 'package:xml/xml/nodes/text.dart' show XmlText;
import 'package:xml/xml/utils/attribute_type.dart' show XmlAttributeType;
import 'package:xml/xml/utils/name.dart' show XmlName, xml, xmlns, xmlData, xmlUri;
import 'package:xml/xml/visitors/transformer.dart' show XmlTransformer;

/// A builder to create XML trees with code.
class XmlBuilder {
  /// If [optimizeNamespaces] is true, the builder will perform some
  /// namespace optimization.
  ///
  /// This means that
  ///  - namespaces that are defined in an element but are never used in this
  ///    element or its children will not be included in the document;
  ///  - namespaces that are defined in an element but are already defined in
  ///    one of the ancestors of the element will not be included again.
  final bool optimizeNamespaces;

  /// The current node stack of this builder.
  final List<XmlNodeBuilder> _stack = new List.from([new XmlDocumentBuilder()]);

  /// Construct a new [XmlBuilder].
  ///
  /// For the meaning of the [optimizeNamespaces] parameter, read the
  /// documentation of the [optimizeNamespaces] property.
  XmlBuilder({this.optimizeNamespaces: false});

  /// Adds a [XmlText] node with the provided [text].
  ///
  /// For example, to generate the text _Hello World_ one would write:
  ///
  ///     builder.text('Hello World');
  ///
  void text(Object text) {
    var children = _stack.last.children;
    if (children.isNotEmpty && children.last is XmlText) {
      // merge consecutive text nodes into one
      var previous = children.removeLast();
      children.add(new XmlText('${previous.text}${text.toString()}'));
    } else {
      children.add(new XmlText(text.toString()));
    }
  }

  /// Adds a [XmlCDATA] node with the provided [text].
  ///
  /// For example, to generate a CDATA element with the text _Hello World_
  /// one would write:
  ///
  ///     builder.cdata('Hello World');
  ///
  void cdata(Object text) {
    _stack.last.children.add(new XmlCDATA(text.toString()));
  }

  /// Adds a [XmlProcessing] node with the provided [target] and [text].
  ///
  /// For example, to generate a processing element with the _xml_ and the
  /// attribute _version="1.0"_ one would write:
  ///
  ///     builder.processing('xml', 'version="1.0"');
  ///
  void processing(String target, Object text) {
    _stack.last.children.add(new XmlProcessing(target, text.toString()));
  }

  /// Adds a [XmlComment] node with the provided [text].
  ///
  /// For example, to generate a comment with the text _Hello World_ one
  /// would write:
  ///
  ///     builder.comment('Hello World');
  ///
  void comment(Object text) {
    _stack.last.children.add(new XmlComment(text.toString()));
  }

  /// Adds a [XmlElement] node with the provided tag [name].
  ///
  /// If a [namespace] URI is provided, the prefix is looked up, verified and
  /// combined with the given tag [name].
  ///
  /// If a map of [namespaces] is provided the uri-prefix pairs are added to the
  /// element declaration, see also [XmlBuilder.namespace].
  ///
  /// If a map of [attributes] is provided the name-value pairs are added to the
  /// element declaration, see also [XmlBuilder.attribute].
  ///
  /// Finally, [nest] is used to further customize the element and to add its
  /// children. Typically this is a [Function] that defines elements using the
  /// same builder object. For convenience `nest` can also be a valid [XmlNode],
  /// a string or another common object that will be converted to a string and
  /// added as a text node.
  ///
  /// For example, to generate an element with the tag _message_ and the contained
  /// text _Hello World_ one would write:
  ///
  ///     builder.element('message', nest: 'Hello World');
  ///
  /// To add multiple child elements one would use:
  ///
  ///     builder.element('message', nest: () {
  ///       builder..text('Hello World')
  ///              ..element('break');
  ///     });
  ///
  void element(String name,
      {String namespace,
      Map<String, String> namespaces: const {},
      Map<String, String> attributes: const {},
      Object nest}) {
    var element = new XmlElementBuilder();
    _stack.add(element);
    namespaces.forEach(this.namespace);
    attributes.forEach(this.attribute);
    if (nest != null) {
      _insert(nest);
    }
    element.name = _buildName(name, namespace);
    if (optimizeNamespaces) {
      // Remove unused namespaces: The reason we first add them and then remove
      // them again is to keep the order in which they have been added.
      element.namespaces.forEach((uri, meta) {
        if (!meta.used) {
          var name = meta.name;
          var attribute = element.attributes.firstWhere((attribute) => attribute.name == name);
          element.attributes.remove(attribute);
        }
      });
    }
    _stack.removeLast();
    _stack.last.children.add(element.build());
  }

  /// Adds a [XmlAttribute] node with the provided [name] and [value].
  ///
  /// If a [namespace] URI is provided, the prefix is looked up, verified
  /// and combined with the given attribute [name].
  ///
  /// To generate an element with the tag _message_ and the attribute _lang="en"_
  /// one would write:
  ///
  ///     builder.element('message', nest: () {
  ///        builder.attribute('lang', 'en');
  ///     });
  ///
  void attribute(String name, Object value, {String namespace, XmlAttributeType attributeType}) {
    final attribute = new XmlAttribute(_buildName(name, namespace), value.toString(),
        attributeType ?? XmlAttributeType.DOUBLE_QUOTE);
    _stack.last.attributes.add(attribute);
  }

  /// Binds a namespace [prefix] to the provided [uri]. The [prefix] can be
  /// omitted to declare a default namespace. Throws an [ArgumentError] if
  /// the [prefix] is invalid or conflicts with an existing declaration.
  void namespace(String uri, [String prefix]) {
    if (prefix == xmlns || prefix == xml) {
      throw new ArgumentError('The "$prefix" prefix cannot be bound.');
    }
    if (optimizeNamespaces &&
        _stack.any((builder) =>
            builder.namespaces.containsKey(uri) && builder.namespaces[uri].prefix == prefix)) {
      // namespace prefix already correctly specified in an ancestor
      return;
    }
    if (_stack.last.namespaces.values.any((meta) => meta.prefix == prefix)) {
      throw new ArgumentError('The "$prefix" prefix conflicts with existing binding.');
    }
    var meta = new NamespaceData(prefix, false);
    _stack.last.attributes.add(new XmlAttribute(meta.name, uri, XmlAttributeType.DOUBLE_QUOTE));
    _stack.last.namespaces[uri] = meta;
  }

  /// Returns the resulting [XmlNode].
  XmlNode build() => _stack.last.build();

  // Internal method to build a name.
  XmlName _buildName(String name, String uri) {
    if (uri != null && uri.isNotEmpty) {
      var meta = _lookup(uri);
      meta.used = true;
      return new XmlName(name, meta.prefix);
    } else {
      return new XmlName.fromString(name);
    }
  }

  // Internal method to lookup an namespace prefix.
  NamespaceData _lookup(String uri) {
    var builder = _stack.lastWhere((builder) => builder.namespaces.containsKey(uri),
        orElse: () => throw new ArgumentError('Undefined namespace: $uri'));
    return builder.namespaces[uri];
  }

  // Internal method to add children to the current element.
  void _insert(Object value) {
    if (value is Function) {
      value();
    } else if (value is Iterable) {
      value.forEach(_insert);
    } else if (value is XmlNode) {
      if (value is XmlText) {
        // Text nodes need to be unwrapped for merging.
        text(value.text);
      } else if (value is XmlAttribute) {
        // Attributes must be copied and added to the attributes list.
        _stack.last.attributes.add(new XmlTransformer().visit(value));
      } else if (value is XmlDocumentFragment) {
        // Document fragments need to be unwrapped.
        value.children.forEach(_insert);
      } else if (value is XmlElement || value is XmlData) {
        // All other valid nodes must be copied and added to the children list.
        _stack.last.children.add(new XmlTransformer().visit(value));
      } else {
        throw new ArgumentError('Unable to add element of type ${value.nodeType}');
      }
    } else {
      text(value.toString());
    }
  }
}

class NamespaceData {
  final String prefix;
  bool used;

  NamespaceData(this.prefix, [this.used = false]);

  XmlName get name =>
      prefix == null || prefix.isEmpty ? new XmlName(xmlns) : new XmlName(prefix, xmlns);
}

abstract class XmlNodeBuilder {
  Map<String, NamespaceData> get namespaces;
  List<XmlAttribute> get attributes;
  List<XmlNode> get children;
  XmlNode build();
}

class XmlDocumentBuilder extends XmlNodeBuilder {
  @override
  final Map<String, NamespaceData> namespaces = {xmlUri: xmlData};

  @override
  List<XmlAttribute> get attributes {
    throw new ArgumentError('Unable to define attributes at the document level.');
  }

  @override
  final List<XmlNode> children = [];

  @override
  XmlNode build() => new XmlDocument(children);
}

class XmlElementBuilder extends XmlNodeBuilder {
  @override
  final Map<String, NamespaceData> namespaces = {};

  @override
  final List<XmlAttribute> attributes = [];

  @override
  final List<XmlNode> children = [];

  XmlName name;

  @override
  XmlNode build() => new XmlElement(name, attributes, children);
}
