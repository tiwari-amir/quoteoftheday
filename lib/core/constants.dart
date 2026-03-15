const String quotesAssetPath = 'assets/quotes.json';

const String prefDailyQuoteId = 'daily_quote_id';
const String prefDailyQuoteDate = 'last_date';
const String prefSavedQuoteIds = 'saved_quote_ids';
const String prefStreakCount = 'streak_count';
const String prefStreakLastDate = 'streak_last_date';
const String prefViewerShuffleEnabled = 'viewer_shuffle_enabled';
const String prefViewerScrolledCount = 'viewer_scrolled_count';
const String prefViewerLastMilestone = 'viewer_last_milestone';
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
  defaultValue: 'https://quoteflow.app',
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

const List<String> curatedCategoryTags = [
  'love',
  'happiness',
  'life',
  'wisdom',
  'success',
  'friendship',
  'inspiration',
  'hope',
  'courage',
  'freedom',
  'truth',
  'strength',
  'time',
  'purpose',
  'knowledge',
  'growth',
  'leadership',
  'motivation',
  'beauty',
  'creativity',
  'faith',
  'peace',
  'ambition',
  'failure',
  'resilience',
  'justice',
  'power',
  'nature',
  'death',
  'society',
  'identity',
  'self discovery',
  'forgiveness',
  'regret',
  'healing',
  'loss',
  'grief',
  'fear',
  'anxiety',
  'desire',
  'passion',
  'imagination',
  'gratitude',
  'discipline',
  'legacy',
  'doubt',
  'heartbreak',
  'pain',
  'mortality',
  'suffering',
];
