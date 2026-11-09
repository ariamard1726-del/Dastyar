import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  bool fail = false;
  final dir = Directory('eval/scenarios_dev');
  if (!dir.existsSync()) {
    print('ERROR: eval/scenarios_dev directory not found');
    exit(1);
  }

  final files = dir.listSync();
  Set<String> ids = {};
  
  for (var file in files) {
    if (!file.path.endsWith('.json')) continue;
    try {
      String content = file.readAsStringSync();
      Map<String, dynamic> data = jsonDecode(content);
      
      // Required fields
      List<String> required = ['id', 'split', 'author', 'domain', 'needs_human_review', 'turns'];
      for (var r in required) {
        if (!data.containsKey(r)) {
          print('ERROR in ${file.path}: missing field $r');
          fail = true;
        }
      }

      // Enum values
      if (data['split'] != 'dev' && data['split'] != 'test') {
        print('ERROR in ${file.path}: invalid split ${data['split']}');
        fail = true;
      }

      // Unique ids
      String id = data['id'];
      if (ids.contains(id)) {
        print('ERROR: duplicate id $id');
        fail = true;
      }
      ids.add(id);

      // Turns
      List<dynamic> turns = data['turns'];
      for (var turn in turns) {
        List<String> turnReq = ['user_text', 'gold_speech_act', 'gold_relevance', 'expect_unanswerable'];
        for (var r in turnReq) {
          if (!turn.containsKey(r)) {
            print('ERROR in ${file.path}: turn missing field $r');
            fail = true;
          }
        }
        String act = turn['gold_speech_act'];
        List<String> acts = ['question', 'inform', 'confirm', 'deny', 'smallTalk', 'metaDialogue', 'outOfDomain'];
        if (!acts.contains(act)) {
          print('ERROR in ${file.path}: invalid gold_speech_act $act');
          fail = true;
        }
        String rel = turn['gold_relevance'];
        List<String> rels = ['continue', 'related_side', 'topic_switch', 'out_of_domain'];
        if (!rels.contains(rel)) {
          print('ERROR in ${file.path}: invalid gold_relevance $rel');
          fail = true;
        }
      }
    } catch (e) {
      print('ERROR parsing ${file.path}: $e');
      fail = true;
    }
  }

  if (fail) {
    print('VALIDATION FAILED');
    exit(1);
  } else {
    print('VALIDATION PASSED: $ids.length scenarios');
    exit(0);
  }
}
