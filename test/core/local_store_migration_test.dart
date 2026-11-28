import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/local_store.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/draft_models.dart';
import 'package:dastyar/domain/feedback.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  setUp(() {
    PrivacyService.persistenceAllowed = true;
    PrivacyService.resetEphemeralKeyForTesting();
    LocalStoreRegistry.reset();
  });

  tearDown(() {
    PrivacyService.persistenceAllowed = true;
    LocalStoreRegistry.reset();
  });

  test('HistoryStore و FeedbackStore و DraftCheckpointStore با MemoryKeyValueStore بی‌نیاز از SharedPreferences کار می‌کنند',
      () async {
    final mem = MemoryKeyValueStore();

    final history = HistoryStore(store: mem);
    await history.load();
    await history.upsert(ChatSession(
      id: 's1',
      title: 'چک برگشتی',
      updated: 100,
      messages: [StoredMsg('چکم برگشت خورده', true)],
      caseJson: <String, dynamic>{'topic': 'cheque'},
      dialogueJson: <String, dynamic>{'question': 'q1'},
    ));
    await history.flush();

    final reloaded = HistoryStore(store: mem);
    await reloaded.load();
    expect(reloaded.sessions, hasLength(1));
    expect(reloaded.sessions.single.caseJson?['topic'], 'cheque');
    expect(reloaded.sessions.single.dialogueJson?['question'], 'q1');

    expect(
      await FeedbackStore.add('پرسش آزمایشی', 'پاسخ آزمایشی', 1, store: mem),
      isTrue,
    );
    final fb = await FeedbackStore.all(store: mem);
    expect(fb, hasLength(1));
    expect(fb.single.q, 'پرسش آزمایشی');

    final tpl = LegalTemplate.fromJson(<String, dynamic>{
      'id': 'complaint',
      'title': 'شکوائیه',
      'body': 'متن',
      'fields': <dynamic>[],
    });
    final draft = DraftSession(tpl)..values['court_city'] = 'تهران';
    expect(await DraftCheckpointStore.save(draft, store: mem), isTrue);
    final loadedDraft = await DraftCheckpointStore.load([tpl], store: mem);
    expect(loadedDraft?.values['court_city'], 'تهران');
    expect(await DraftCheckpointStore.clear(store: mem), isTrue);
  });

  test('StorageMigration کلیدهای مجاز را یک‌باره و بدون تکرار منتقل و encf1 را رد می‌کند',
      () async {
    final legacy = MemoryKeyValueStore(<String, String>{
      'history_v1': 'enc1:index',
      'history_v1:m:s1': 'enc1:session1',
      'history_v1:m:stale': '${PrivacyService.fallbackPrefix}ephemeral',
      'active_draft_v1': 'enc1:draft',
      'feedback_v1': 'enc1:fb',
      'unrelated_setting': 'keep-in-source',
    });
    final target = MemoryKeyValueStore();

    final first = await StorageMigration.migrateOneShot(
      from: legacy,
      to: target,
      removeFromSource: true,
    );
    expect(first.ok, isTrue);
    expect(first.alreadyMigrated, isFalse);
    expect(first.copied, 4);
    expect(first.skippedEphemeral, 1);
    expect(first.removedFromSource, 5);

    expect(await target.getString('history_v1'), 'enc1:index');
    expect(await target.getString('history_v1:m:s1'), 'enc1:session1');
    expect(await target.getString('history_v1:m:stale'), isNull);
    expect(await target.getString('active_draft_v1'), 'enc1:draft');
    expect(await target.getString('feedback_v1'), 'enc1:fb');
    expect(await target.getString(StorageMigration.doneKey), '1');

    // کلید نامرتبط دست‌نخورده در مبدا می‌ماند و کلیدهای مهاجرت‌شده پاک شده‌اند.
    expect(await legacy.getString('unrelated_setting'), 'keep-in-source');
    expect(await legacy.getString('history_v1'), isNull);
    expect(await legacy.getString('history_v1:m:stale'), isNull);

    // اجرای دوم باید کاملاً بی‌اثر (idempotent) باشد.
    final second = await StorageMigration.migrateOneShot(
      from: legacy,
      to: target,
      removeFromSource: true,
    );
    expect(second.ok, isTrue);
    expect(second.alreadyMigrated, isTrue);
    expect(second.copied, 0);
  });
}
