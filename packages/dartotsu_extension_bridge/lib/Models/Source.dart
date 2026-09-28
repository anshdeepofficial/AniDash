import 'package:dartotsu_extension_bridge/ExtensionManager.dart'
    show ExtensionType;

class Source {
  String? id;

  String? name;

  String? baseUrl;

  String? lang;

  bool? isNsfw;

  String? iconUrl;

  String? version;

  String? versionLast;

  ItemType? itemType;

  bool? isObsolete;

  String? repo;

  bool? hasUpdate;

  String? apkUrl;

  String? apkName;

  String? apkSha256;

  ExtensionType? extensionType;

  Source({
    this.id = '',
    this.name = '',
    this.baseUrl = '',
    this.lang = '',
    this.iconUrl = '',
    this.isNsfw = false,
    this.version = "0.0.1",
    this.versionLast = "0.0.1",
    this.itemType = ItemType.manga,
    this.isObsolete = false,
    this.repo,
    this.hasUpdate = false,
    this.extensionType = ExtensionType.mangayomi,
    this.apkUrl = '',
    this.apkName = '',
    this.apkSha256,
  });

  Source.fromJson(Map<String, dynamic> json) {
    baseUrl = json['baseUrl'];
    iconUrl = json['iconUrl'];
    apkUrl = json['apkUrl'];
    apkName = json['apkName'];
    apkSha256 =
        (json['sha256'] ?? json['apkSha256'] ?? json['apkHash'])?.toString();
    id = json['id'].toString();
    itemType = ItemType.values[json['itemType'] ?? 0];
    isNsfw = json['isNsfw'];
    lang = json['lang'];
    name = json['name'];
    version = json['version'];
    versionLast = json['versionLast'];
    isObsolete = json['isObsolete'];
    repo = json['repo'];
    hasUpdate = json['hasUpdate'] ?? false;
    extensionType = ExtensionType.values[json['extensionType'] ?? 0];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'apkUrl': apkUrl,
    'apkName': apkName,
    'sha256': apkSha256,
    'lang': lang,
    'iconUrl': iconUrl,
    'isNsfw': isNsfw,
    'version': version,
    'versionLast': versionLast,
    'itemType': itemType?.index ?? 0,
    'isObsolete': isObsolete,
    'repo': repo,
    'hasUpdate': hasUpdate,
    'extensionType': extensionType?.index ?? 0,
  };
}

enum ItemType {
  manga,
  anime,
  novel;

  @override
  String toString() {
    switch (this) {
      case ItemType.manga:
        return 'Manga';
      case ItemType.anime:
        return 'Anime';
      case ItemType.novel:
        return 'Novel';
    }
  }
}
