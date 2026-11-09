import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main(List<String> args) {
  bool update = args.contains('--update');
  String manifestPath = 'eval/test_manifest.sha256';
  String testDir = 'eval/scenarios_test';
  
  List<String> files = [];
  if (Directory(testDir).existsSync()) {
    files = Directory(testDir).listSync().map((e) => e.path).where((p) => p.endsWith('.json')).toList();
    files.sort();
  }

  // Deterministic name+size manifest (no crypto package)
  List<String> lines = [];
  int totalSize = 0;
  for (var f in files) {
    File file = File(f);
    int size = file.statSync().size;
    totalSize += size;
    String name = f.split('/').last;
    lines.add('$name:$size');
  }
  lines.add('TOTAL_SIZE:$totalSize');
  String currentManifest = lines.join('\n') + '\n';

  if (update) {
    File(manifestPath).writeAsStringSync(currentManifest);
    print('Manifest updated: $manifestPath');
    exit(0);
  }

  if (!File(manifestPath).existsSync()) {
    print('ERROR: Manifest $manifestPath not found. Run with --update to create.');
    exit(1);
  }

  String existingManifest = File(manifestPath).readAsStringSync();
  if (existingManifest == currentManifest) {
    print('Manifest matches.');
    exit(0);
  } else {
    print('ERROR: Manifest mismatch.');
    print('Expected:\n$existingManifest');
    print('Actual:\n$currentManifest');
    exit(1);
  }
}
