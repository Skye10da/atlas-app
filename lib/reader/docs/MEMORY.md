# Reader Domain — Memory

> **Last Updated:** 2026-07-25

---

## Current Status

- Module structure scaffolded
- No implementation yet
- Waiting for Stage 5 (Reader Engine)

## Pending Tasks

- [ ] Import pipeline (EPUB, TXT, HTML)
- [ ] Content parser
- [ ] Chapter rendering with pagination
- [ ] Scroll and page-flip modes
- [ ] Reading progress tracking
- [ ] Bookmarks and annotations

## Known Issues

None yet — module is in scaffolding phase.

## Architecture Notes

- Repository pattern with drift for local storage
- Riverpod for state management
- Chapter preloading for performance
- Offline-first by design

## Performance Notes

- Chapter load target: < 100ms
- Page turn target: 60fps
- Cold open target: < 2s

## Future Improvements

- Custom renderer for EPUB content
- Variable font support
- Reading statistics

--- Last Updated: 2026-07-25
