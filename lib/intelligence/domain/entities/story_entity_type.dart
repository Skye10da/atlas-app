/// The supported entity classifications within Atlas Story Memory.
enum StoryEntityType {
  character('character', 'Character'),
  location('location', 'Location'),
  faction('faction', 'Faction'),
  item('item', 'Item'),
  blockCard('block_card', 'BlockCard');

  const StoryEntityType(this.id, this.label);

  final String id;
  final String label;

  static StoryEntityType fromId(String id) {
    for (final type in values) {
      if (type.id.toLowerCase() == id.toLowerCase()) {
        return type;
      }
    }
    return StoryEntityType.character;
  }
}

