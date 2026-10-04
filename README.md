# GC1015 Learning Studio

A public, interactive companion to Professor Ken Ezekwem’s NYU SPS Quantitative Methods for Business Analysis course, Fall 2026. The instructor authorized the public release of the student resources in this repository.

**Website:** https://gc1015-learning-studio.kezekwem.chatgpt.site  
**Repository:** https://github.com/kezekwem/gc1015-learning-studio

Sessions **01–05** are released. Later sessions appear in gray, with no downloadable lesson files. Brightspace remains authoritative for assignment directions, dates, submission and grades.

## What students can use

- Five interactive experiments, fictional practice questions, an optional device-local XP passport, and session stamps. These never affect course grades.
- Full and concise study toolkits; student laboratory guides, packages, workbooks and SPSS support; full slide PDFs; mind maps; infographics; audio primers and transcripts.
- An independent Measurement Atlas for optional reference, including beyond the current course coverage.
- All 15 resources from the course’s Section 10 optional Career Toolkit. Excel/SPSS support the core course; Python/R are optional. LinkedIn Learning is free through NYU access.
- Professor Ken’s biography, official faculty-profile link and approved portrait, with the caption strip cropped out of its website display. The Career Toolkit also contains a discreet MAPS membership/contact section, verified social links, and a dated link to its official event calendar.
- English, Simplified Chinese/Mandarin, Spanish and Hindi reading choices, with language remembered on the device. Shared interface translations are bundled; digital toolkit/lab/Atlas text is translated on demand and cached. Equations, code, original PDFs, images and recorded primers retain their original content. AI translations should be checked against the English source when terminology matters.
- A source-grounded AI Study Tutor. It can navigate the **whole course**, while detailed revision is restricted to **one session before the latest released session: currently Session 04**. It offers hints rather than completing assignments, including ungraded activities. Replies can be narrated with clearly identified AI audio in the selected language.

## Run locally

Requires Node.js 22.13 or later (Node 24 recommended). No npm dependencies are needed for the preview.

```sh
npm run dev
```

Open http://127.0.0.1:8766/. Static pages and bundled interface translations work without an API key. Live tutoring, on-demand reader translations and speech need a server-only `OPENAI_API_KEY`.

For development, load credentials from a file **outside this repository**, for example:

```sh
node --env-file=/absolute/path/to/private/runtime.env server/dev.mjs
```

Never put credentials into client files, Git, screenshots or documentation. The local preview uses an in-memory SQLite adapter; production uses the Sites-managed D1 binding `DB`. Only public translation text and aggregate daily usage buckets are stored. The application does not store student conversations or connect to grades; recent messages are transmitted to the AI provider to answer a question.

## Build and verify

Use a Python virtual environment with `requirements.txt`:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
npm run build
npm run check
```

`npm run build` generates the studio pages, learning maps, translation annotations and Worker bundle. The curated teaching assets in `dist/client/assets/s01` through `s05` are intentionally versioned, as are the reference Atlas and its PDF. Do not replace them with instructor files or unreviewed source exports.

`server/worker.test.mjs` uses a fake provider, not paid API calls. It tests scope enforcement, whole-course navigation, ungraded assignment boundaries, source allowlists, missing credentials, failed generation, quotas, numeric translation invariants and signed audio requests. Browser checks should additionally exercise the controls and responsive layout.

## Architecture

- `content/course.json`: released session metadata, original fictional practice questions and the future-session outline.
- `content/career-resources.json`: curated optional links.
- `content/slide-text.json`: visible slide text from the matching student-facing Session 03 deck; no presenter notes. Session 04’s PDF text is extracted at build time. Toolkits/lab guides provide the additional revision evidence.
- `scripts/build.py`: original studio pages and maps.
- `scripts/build-services.py`: evidence retrieval corpus, public text IDs, HTML translation annotations and `dist/server/index.js`.
- `content/translations/`: reviewed-for-numeric-integrity shared interface dictionaries. `scripts/pretranslate.py` optionally refreshes them using credentials loaded at runtime from the external path in `COURSE_RUNTIME_ENV`.
- `dist/client/`: complete public site and all approved student resources.
- `server/worker.js`: moderation, structured question routing, bounded retrieval, grounded answers, a separate learning-support and arithmetic check, translation caching and signed text-to-speech.
- `server/dev.mjs`: local Worker-compatible preview.
- `drizzle/`: idempotent database schema; no student data.
- `.openai/hosting.json`: native Sites project identity and D1 binding.

Production uses OpenAI Responses (`gpt-5.6-luna`), input moderation (`omni-moderation-latest`) and speech (`gpt-4o-mini-tts`, coral voice). Model/API documentation: [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [moderation](https://developers.openai.com/api/docs/guides/moderation), [speech](https://developers.openai.com/api/docs/guides/text-to-speech). Jev is not required by this implementation. Provider models are configurable server-side; changing providers requires preserving the routing, grounding, assignment and numeric-integrity checks.

Default production capacity is 300 provider calls per day across the site and 180 per daily, salted visitor bucket; a chat uses multiple calls. `TUTOR_DAILY_CALL_LIMIT` can adjust the aggregate limit up to the application cap of 2,000. This is a request cap, not a guaranteed monetary spending cap. Static resources and experiments remain usable when capacity is exhausted.

## Claude Code UI/UX review

Start with the desktop home, mobile home (390 px), `/sessions/05/`, `/practice/`, `/tutor/`, `/career/`, `/about/` and `/reference/`. Inspect all four language choices, keyboard navigation, chart explanations and document readers.

Keep these requirements during revisions:

1. NYU violet `#57068c`, deep violet `#330662`, accessible teal `#006d68` and restrained gold; maintain contrast and reduced-motion behavior.
2. Future sessions stay gray and unreleased. The independent Atlas remains available as explicitly optional reference.
3. Do not expose answer keys, instructor notes, student records, credentials or private PRONOIA assets.
4. Preserve original math, sample sizes, units, denominators and statistical caveats when editing or translating.
5. Preserve the tutor’s Session 04 revision boundary, whole-course navigation and no-completion policy for graded **and ungraded** work.
6. Keep portrait proportions, responsive reader/table overflow, original PDFs and primer download links working.
7. XP remains optional, device-local and unrelated to grades.

## Content provenance

Student resource releases were checked against the current Fall 2026 materials and Brightspace inventory. Session 04 uses the corrected, approved 98-slide deck and corrected toolkit; the lab guide retains legacy slide references, with an on-page explanation directing students to slide titles. Session 05 contains the complete released materials. The Section 10 resource list was read directly from the course’s Brightspace module. The separate public repository deliberately excludes PRONOIA’s private operational files.

[Official faculty profile](https://www.sps.nyu.edu/faculty-directory/21052-kenechukwu-c-ezekwem.html) · [NYU visual identity](https://engineering.nyu.edu/marketing-and-communications/identity-guide/design-elements) · [Measurement Atlas](https://measurement-atlas-gc1015.kezekwem.chatgpt.site)

Third-party courses, documentation and readings are linked rather than republished. Original teaching files are included with the instructor’s approval for this course; this repository does not grant a blanket license to third-party material or NYU trademarks.
