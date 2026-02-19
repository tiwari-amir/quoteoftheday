const String quotesAssetPath = 'assets/quotes.json';

const String prefDailyQuoteId = 'daily_quote_id';
const String prefDailyQuoteDate = 'last_date';
const String prefSavedQuoteIds = 'saved_quote_ids';
const String prefStreakCount = 'streak_count';
const String prefStreakLastDate = 'streak_last_date';
const String prefViewerShuffleEnabled = 'viewer_shuffle_enabled';

const String metaStoryAppId = String.fromEnvironment(
  'META_STORY_APP_ID',
  defaultValue: '',
);
const String facebookStoryAppId = String.fromEnvironment(
  'FACEBOOK_STORY_APP_ID',
  defaultValue: '',
);
const String storyAttributionUrl = String.fromEnvironment(
  'STORY_ATTRIBUTION_URL',
  defaultValue: 'https://quoteoftheday.app',
);

const List<String> moodAllowlist = [
  'happy',
  'sad',
  'motivated',
  'calm',
  'confident',
  'lonely',
  'angry',
  'grateful',
  'anxious',
  'romantic',
  'hopeful',
  'stressed',
];
