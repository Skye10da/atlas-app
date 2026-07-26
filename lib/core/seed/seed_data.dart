import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:atlas_app/core/database/database.dart';

class SeedData {
  const SeedData(this._db);

  final AppDatabase _db;

  Future<bool> hasBooks() async {
    final rows = await _db.select(_db.books).get();
    return rows.isNotEmpty;
  }

  Future<void> seed() async {
    final dir = await getApplicationDocumentsDirectory();
    final contentDir = Directory(p.join(dir.path, 'content'));
    if (!await contentDir.exists()) {
      await contentDir.create(recursive: true);
    }

    for (final sample in _samples) {
      final bookId = _normalizeId(sample.title);

      for (var i = 0; i < sample.chapters.length; i++) {
        final ch = sample.chapters[i];
        final chapterId = '${bookId}_ch${i + 1}';

        final contentPath = p.join(contentDir.path, '$chapterId.txt');
        await File(contentPath).writeAsString(ch.content);

        await _db.into(_db.chapters).insert(ChaptersCompanion(
              id: Value(chapterId),
              bookId: Value(bookId),
              index: Value(i),
              title: Value(ch.title),
              contentPath: Value(contentPath),
              wordCount: Value(ch.content.split(RegExp(r'\s+')).length),
              pageCount: Value((ch.content.length / 2000).ceil()),
              createdAt: Value(DateTime.now()),
            ));
      }

      await _db.into(_db.books).insert(BooksCompanion(
            id: Value(bookId),
            title: Value(sample.title),
            author: Value(sample.author),
            format: const Value('sample'),
            filePath: Value(contentDir.path),
            totalChapters: Value(sample.chapters.length),
            description: Value(sample.description),
            language: const Value('en'),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ));
    }
  }

  String _normalizeId(String title) {
    return title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}

class _SampleBook {
  const _SampleBook({
    required this.title,
    required this.author,
    required this.description,
    required this.chapters,
  });

  final String title;
  final String author;
  final String description;
  final List<_SampleChapter> chapters;
}

class _SampleChapter {
  const _SampleChapter({required this.title, required this.content});

  final String title;
  final String content;
}

final _samples = <_SampleBook>[
  const _SampleBook(
    title: 'A Study in Scarlet',
    author: 'Arthur Conan Doyle',
    description: 'The first Sherlock Holmes novel, introducing the detective and Dr. Watson.',
    chapters: <_SampleChapter>[
      _SampleChapter(
        title: 'Mr. Sherlock Holmes',
        content: "In the year 1878 I took my degree of Doctor of Medicine of the University of London, and proceeded to Netley to go through the course prescribed for surgeons in the army. Having completed my studies there, I was duly attached to the Fifth Northumberland Fusiliers as Assistant Surgeon. The regiment was stationed in India at the time, and before I could join it, the second Afghan war had broken out. On landing at Bombay, I learned that my corps had advanced through the passes, and was already deep in the enemy's country. I followed, however, with many other officers who were in the same situation as myself, and succeeded in reaching Candahar in safety, where I found my regiment, and at once entered upon my new duties.\n\nThe campaign brought honours and promotion to many, but for me it had nothing but misfortune and disaster. I was removed from my brigade and attached to the Berkshires, with whom I served at the fatal battle of Maiwand. There I was struck on the shoulder by a Jezail bullet, which shattered the bone and grazed the subclavian artery. I should have fallen into the hands of the murderous Ghazis had it not been for the devotion and courage shown by Murray, my orderly, who threw me across a pack-horse, and succeeded in bringing me safely to the British lines.\n\nWorn with pain, and weak from the prolonged hardships which I had undergone, I was removed, with a great train of wounded sufferers, to the base hospital at Peshawar. Here I rallied, and had already improved so far as to be able to walk about the wards, and even to take a short promenade in the verandah, when I was struck down by enteric fever, that curse of our Indian possessions. For months my life was despaired of, and when at last I came to myself and became convalescent, I was so weak and emaciated that a medical board determined that not a day should be lost in sending me back to England. I was dispatched, accordingly, in the troopship \"Orontes,\" and landed a month later on Portsmouth jetty, with my health irretrievably ruined, but with permission from a paternal government to spend the next nine months in attempting to improve it.\n\nI had neither kith nor kin in England, and was therefore as free as air—or as free as an income of eleven shillings and sixpence a day will permit a man to be. Under such circumstances, I naturally gravitated to London, that great cesspool into which all the loungers and idlers of the Empire are irresistibly drained. There I stayed for some time at a private hotel in the Strand, leading a comfortless, meaningless existence, and spending such money as I had, considerably more freely than I ought. So alarming did the state of my finances become, that I soon realized that I must either leave the metropolis and rusticate somewhere in the country, or that I must make a complete alteration in my style of living. Choosing the latter alternative, I began by making up my mind to leave the hotel, and take up my quarters in some less pretentious and less expensive domicile.",
      ),
      _SampleChapter(
        title: 'The Science of Deduction',
        content: 'We met next day as he had arranged, and inspected the rooms at No. 221B, Baker Street, of which he had spoken at our meeting. They consisted of a couple of comfortable bed-rooms and a single large airy sitting-room, cheerfully furnished, and illuminated by two broad windows. So desirable in every way were the apartments, and so moderate did the terms seem when divided between us, that the bargain was concluded upon the spot, and we at once entered into possession. That very evening I moved my things round from the hotel, and on the following morning Sherlock Holmes followed me with several boxes and portmanteaus. For a day or two we were busily employed in unpacking and laying out our property to the best advantage. That done, we gradually began to settle down and to accommodate ourselves to our new surroundings.\n\nHolmes was certainly not a difficult man to live with. He was quiet in his ways, and his habits were regular. It was rare for him to be up after ten at night, and he had invariably breakfasted and gone out before I rose in the morning. Sometimes he spent his day at the chemical laboratory, sometimes in the dissecting-rooms, and occasionally in long walks, which appeared to take him into the lowest portions of the City. Nothing could exceed his energy when the working fit was upon him; but now and again a reaction would seize him, and for days on end he would lie upon the sofa in the sitting-room, hardly uttering a word or moving a muscle from morning to night. On these occasions I have noticed such a dreamy, vacant expression in his eyes, that I might have suspected him of being addicted to the use of some narcotic, had not the temperance and cleanliness of his whole life forbidden such a notion.\n\nAs the weeks went by, my interest in him and my curiosity as to his aims in life, gradually deepened and increased. His very person and appearance were such as to strike the attention of the most casual observer. In height he was rather over six feet, and so excessively lean that he seemed to be considerably taller. His eyes were sharp and piercing, save during those intervals of torpor to which I have alluded; and his thin, hawk-like nose gave his whole expression an air of alertness and decision. His chin, too, had the prominence and squareness which mark the man of determination. His hands were invariably blotted with ink and stained with chemicals, yet he was possessed of extraordinary delicacy of touch, as I frequently had occasion to observe when I watched him manipulating his fragile philosophical instruments.',
      ),
      _SampleChapter(
        title: 'The Lauriston Garden Mystery',
        content: "I had rather a strange feeling when I first passed over the threshold of that dead man's house. It was not the first corpse I had seen, nor had I seen many less dreadful than that one. But I approached it with a certain sense of awe, for I could not but feel that the dark ending of that life was but a prelude to some still more terrible revelation. The body was that of a tall, well-made man, about forty years of age. He was dressed in a long, loose-fitting traveling coat, and had a heavy walking-stick lying beside him on the floor. His face was turned to the wall, and his hands were clenched as though in the grip of some final agony. The whole aspect of the room spoke of a desperate struggle having taken place.\n\nHolmes had already knelt down beside the body, and was examining it with the closest attention. \"You are certain that there is no wound?\" he asked, pointing to numerous splashes of blood upon the wall.\n\n\"Positive!\" cried the detective.\n\n\"Then, of course, the blood belongs to the murderer. That gives us a starting-point. Have you any reason to suspect that the dead man was robbed?\"\n\n\"No, sir. Nothing seems to have been taken.\"\n\n\"This is very interesting,\" said Holmes, in a low voice, as he continued his investigation. \"There is a small cut here, just above the right temple. It could have been made by a hard, sharp instrument. And here, on the left side, I see a similar mark, but less deep. The man was struck twice, then, and the second blow may have been enough to kill him.\"\n\nHe turned the body over, and his quick eye detected something which I had missed. \"Look at this,\" he said, pointing to a small, dark object lying near the dead man's hand. It was a woman's wedding-ring, set with a single gem of a peculiar green tint. I picked it up and examined it closely. It was of fine workmanship, and the stone was of considerable value. But what struck me most was the strange inscription on the inside of the ring: \"The dead are not dead but living.\"",
      ),
    ],
  ),
  const _SampleBook(
    title: 'The Adventures of Tom Sawyer',
    author: 'Mark Twain',
    description: 'The classic tale of childhood adventure along the Mississippi River.',
    chapters: <_SampleChapter>[
      _SampleChapter(
        title: 'Tom Plays, Fights, and Hides',
        content: "\"TOM!\"\n\nNo answer.\n\n\"TOM!\"\n\nNo answer.\n\n\"What's gone with that boy, I wonder? You TOM!\"\n\nNo answer.\n\nThe old lady pulled her spectacles down and looked over them about the room; then she put them up and looked out under them. She seldom or never looked through them for so small a thing as a boy; they were her state pair, the pride of her heart, and were built for \"style,\" not service—she could have seen through a pair of stove-lids just as well. She looked perplexed for a moment, and then said, not fiercely, but still loud enough for the furniture to hear:\n\n\"Well, I lay if I get hold of you I'll—\"\n\nShe did not finish, for by this time she was bending down and punching under the bed with the broom, and so she needed breath to punctuate the punches with. She resurrected nothing but the cat.\n\n\"I never did see the beat of that boy!\"\n\nShe went to the open door and stood in it and looked out among the tomato vines and \"jimpson\" weeds that constituted the garden. No Tom. So she lifted up her voice at an angle calculated for distance and shouted:\n\n\"Y-o-u-u TOM!\"\n\nThere was a slight noise behind her and she turned just in time to seize a small boy by the slack of his roundabout and arrest his flight.\n\n\"There! I might 'a' thought of that closet. What you been doing in there?\"\n\n\"Nothing.\"\n\n\"Nothing! Look at your hands. And look at your mouth. What is that truck?\"\n\n\"I don't know, aunt.\"\n\n\"Well, I know. It's jam—that's what it is. Forty times I've said if you didn't let that jam alone I'd skin you. Hand me that switch.\"\n\nThe switch hovered in the air—the peril was desperate—\n\n\"My! Look behind you, aunt!\"\n\nThe old lady whirled around, and snatched her skirts out of danger. The lad fled on the instant, scrambled up the high board-fence, and disappeared over it.\n\nHis aunt Polly stood surprised a moment, and then broke into a gentle laugh.",
      ),
      _SampleChapter(
        title: 'The Glorious Whitewasher',
        content: "Saturday morning was come, and all the summer world was bright and fresh, and brimming with life. There was a song in every heart; and if the heart was young the music issued at the lips. There was cheer in every face and a spring in every step. The locust-trees were in bloom and the fragrance of the blossoms filled the air. Cardiff Hill, beyond the village and above it, was green with vegetation and it lay just far enough away to seem a Delectable Land, dreamy, reposeful, and inviting.\n\nTom appeared on the sidewalk with a bucket of whitewash and a long-handled brush. He surveyed the fence, and all gladness left him and a deep melancholy settled down upon his spirit. Thirty yards of board fence nine feet high. Life to him seemed hollow, and existence but a burden. Sighing, he dipped his brush and passed it along the topmost plank; repeated the operation; did it again; compared the insignificant whitewashed streak with the far-reaching continent of unwhitewashed fence, and sat down on a tree-box discouraged.\n\nJim skipped by at the moment with a tin pail, singing \"Buffalo Gals.\" Bringing water from the town pump had always been hateful work in Tom's eyes, before, but now it did not strike him so. He remembered that there was company at the pump. White, mulatto, and negro boys and girls were always there waiting their turns, resting, trading playthings, quarrelling, fighting, skylarking. And he remembered that although the pump was only a hundred and fifty yards off, Jim never got back with a bucket of water under an hour—and even then somebody generally had to go after him. Tom said:\n\n\"Say, Jim, I'll fetch the water if you'll whitewash some.\"\n\nJim shook his head and said: \"Can't, Mars Tom. Ole missis, she tole me I got to go an' git dis water an' not stop foolin' roun' wid anybody. She say she spec' Mars Tom gwine to ax me to whitewash, an' so she tole me go 'long an' 'tend to my own business—she 'lowed she'd 'tend to de whitewashin'.\"\n\n\"Oh, never you mind what she said, Jim. That's the way she always talks. Gimme the bucket—I won't be gone only a a minute. SHE won't ever know.\"\n\n\"Oh, I dasn't, Mars Tom. Ole missis she'd take an' tar de head off'n me. 'Deed she would.\"",
      ),
    ],
  ),
];
