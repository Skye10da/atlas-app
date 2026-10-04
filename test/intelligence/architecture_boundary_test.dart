import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architectural Boundary Guard', () {
    test('Layers 1 and 2 have ZERO compile-time imports from Layer 3 (orchestrator)', () {
      final baseDir = Directory('lib/intelligence');
      expect(baseDir.existsSync(), isTrue, reason: 'lib/intelligence directory must exist');

      final forbiddenPatterns = [
        'intelligence/orchestrator',
        'orchestrator/',
      ];

      // Directories that belong to Layer 1 and Layer 2
      final nonAiDirectories = [
        'lib/intelligence/domain',
        'lib/intelligence/infrastructure',
        'lib/intelligence/application/extraction',
        'lib/intelligence/application/graph',
        'lib/intelligence/application/corrections',
        'lib/intelligence/application/query',
      ];

      final violations = <String>[];

      for (final dirPath in nonAiDirectories) {
        final dir = Directory(dirPath);
        if (!dir.existsSync()) continue;

        for (final file in dir.listSync(recursive: true)) {
          if (file is File && file.path.endsWith('.dart')) {
            final lines = file.readAsLinesSync();
            for (var i = 0; i < lines.length; i++) {
              final line = lines[i].trim();
              if (line.startsWith('import ') || line.startsWith('export ')) {
                for (final forbidden in forbiddenPatterns) {
                  if (line.contains(forbidden)) {
                    violations.add('${file.path}:${i + 1} -> $line');
                  }
                }
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Layer 1 & Layer 2 MUST NOT import Layer 3 (orchestrator). Found violations:\n${violations.join("\n")}',
      );
    });
  });
}

