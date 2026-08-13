/// Optional illustration mapping. The UI falls back to its accessible visual
/// placeholder until reviewed medical illustrations are packaged.
class AcupointImages {
  AcupointImages._();

  static const Map<String, String> _images = {};

  static String? getImage(String name) => _images[name];
}
