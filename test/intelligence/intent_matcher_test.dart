import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_app/intelligence/application/query/intent_matcher.dart';
import 'package:atlas_app/intelligence/application/query/query_intent.dart';

void main() {
  const matcher = IntentMatcher();

  group('IntentMatcher', () {
    test('matches whoIs queries and extracts slot', () {
      final m1 = matcher.match('Who is Lin Dong?');
      expect(m1.intent, QueryIntentType.whoIs);
      expect(m1.primarySlot, 'Lin Dong');

      final m2 = matcher.match('tell me about Elder Mo');
      expect(m2.intent, QueryIntentType.whoIs);
      expect(m2.primarySlot, 'Elder Mo');

      final m3 = matcher.match('who was the Grand Elder?');
      expect(m3.intent, QueryIntentType.whoIs);
      expect(m3.primarySlot, 'Grand Elder');
    });

    test('matches relationship queries and extracts both slots', () {
      final m1 = matcher.match('How does Lin Dong know Mo?');
      expect(m1.intent, QueryIntentType.relationship);
      expect(m1.primarySlot, 'Lin Dong');
      expect(m1.secondarySlot, 'Mo');

      final m2 = matcher.match('What is the relationship between Lin Clan and Xiao Clan?');
      expect(m2.intent, QueryIntentType.relationship);
      expect(m2.primarySlot, 'Lin Clan');
      expect(m2.secondarySlot, 'Xiao Clan');
    });

    test('matches whereIs queries', () {
      final m1 = matcher.match('Where is Black Water City?');
      expect(m1.intent, QueryIntentType.whereIs);
      expect(m1.primarySlot, 'Black Water City');

      final m2 = matcher.match('Where does Lin Dong live?');
      expect(m2.intent, QueryIntentType.whereIs);
      expect(m2.primarySlot, 'Lin Dong');
    });

    test('matches recap queries', () {
      final m1 = matcher.match('Catch me up');
      expect(m1.intent, QueryIntentType.recap);

      final m2 = matcher.match('Recap up to chapter 10');
      expect(m2.intent, QueryIntentType.recap);
      expect(m2.chapterSlot, 10);
    });

    test('matches chapter specific whatHappened queries', () {
      final m1 = matcher.match('What happened in chapter 5?');
      expect(m1.intent, QueryIntentType.whatHappened);
      expect(m1.chapterSlot, 5);
    });
  });
}

