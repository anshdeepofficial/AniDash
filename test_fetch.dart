import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final req = await http.get(Uri.parse('https://raw.githubusercontent.com/kodjodevf/mangayomi-extensions/main/index.json'));
  final list = jsonDecode(req.body) as List;
  print("Total: ${list.length}");
  int anime = list.where((e) => e['itemType'] == 1).length;
  int manga = list.where((e) => e['itemType'] == 0).length;
  int novel = list.where((e) => e['itemType'] == 2).length;
  print("Anime: $anime, Manga: $manga, Novel: $novel");
}
