/// Stoplist of tokens and multi-word terms that should never be extracted as Character names.
class NegativeStoplist {
  const NegativeStoplist();

  static const Set<String> _singleWordStops = {
    // Discourse markers & conjunctions
    'however', 'meanwhile', 'suddenly', 'although', 'because', 'therefore',
    'furthermore', 'moreover', 'fortunately', 'unfortunately', 'finally',
    'eventually', 'afterwards', 'slowly', 'quickly', 'immediately', 'instantly',
    'naturally', 'obviously', 'apparently', 'certainly', 'actually', 'indeed',
    'perhaps', 'maybe', 'possibly', 'probably', 'instead', 'besides', 'otherwise',
    'anyway', 'regardless', 'nonetheless', 'nevertheless', 'somewhere', 'anywhere',
    'nowhere', 'everywhere', 'somehow', 'anyhow',

    // Pronouns & generic references
    'he', 'she', 'they', 'it', 'we', 'you', 'i', 'this', 'that', 'these', 'those',
    'someone', 'anyone', 'everyone', 'nobody', 'none', 'both', 'either', 'neither',
    'myself', 'himself', 'herself', 'themselves', 'itself', 'yourself', 'yourselves',
    'who', 'whom', 'whose', 'which', 'what', 'whatever', 'whoever',

    // Days & months
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august',
    'september', 'october', 'november', 'december', 'yesterday', 'today', 'tomorrow',

    // Common abstract concepts & elements frequently capitalized in MTL
    'heaven', 'earth', 'sun', 'moon', 'star', 'stars', 'world', 'universe',
    'space', 'time', 'life', 'death', 'light', 'darkness', 'fire', 'water',
    'wind', 'thunder', 'lightning', 'ice', 'metal', 'wood', 'spirit',
    'soul', 'body', 'mind', 'heart', 'dao', 'path', 'law', 'laws', 'rule', 'rules',
    'qi', 'mana', 'energy', 'force', 'power', 'aura', 'will', 'intent',
    'cultivation', 'stage', 'realm', 'peak', 'early', 'middle', 'late',
    'bloodline', 'physique', 'talent', 'potential', 'destiny', 'fate',
    'chapter', 'volume', 'prologue', 'epilogue', 'author', 'translator',
    'editor', 'note', 'index', 'summary',
  };

  static const Set<String> _multiWordStops = {
    // Cultivation realms & stages
    'golden core', 'nascent soul', 'foundation establishment', 'qi condensation',
    'spirit severing', 'soul formation', 'void refining', 'body integration',
    'mahayana stage', 'tribulation transcendence', 'true god', 'heavenly tribulation',
    'divine sea', 'divine transformation', 'immortal realm', 'mortal realm',
    'early stage', 'middle stage', 'late stage', 'peak stage', 'half-step',

    // Generic martial / story terms
    'martial arts', 'secret realm', 'ancient realm', 'storage ring',
    'heavenly dao', 'great dao', 'nine heavens', 'yellow springs',
    'clan gathering', 'auction house', 'pill pavilion', 'spirit herb',
    'beast core', 'monster core', 'demonic beast', 'spirit beast',
  };

  /// Returns true if [candidate] matches any negative stoplist rule.
  bool contains(String candidate) {
    final trimmed = candidate.trim().toLowerCase();
    if (trimmed.isEmpty) return true;

    if (_singleWordStops.contains(trimmed)) return true;
    if (_multiWordStops.contains(trimmed)) return true;

    // Reject single characters
    if (trimmed.length <= 1) return true;

    // Reject all-numeric or purely punctuation candidates
    if (RegExp(r'^[\d\s\-_.,!?;:]+$').hasMatch(trimmed)) return true;

    return false;
  }
}
