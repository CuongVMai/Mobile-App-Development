# local_storage_lab

| Item | Details |
|---|---|
| Student | Cuong Mai |
| Course | CSC 4360/6360 – Mobile App Development |
| Pathway | Undergraduate |
| Flutter | 3.47.2, stable |
| Dart | 3.13.2 |
| Android emulator | sdk gphone16k arm64 |
| Device ID | emulator-5554 |
| Android version | Android 17, API 37 |
1. I expected all saved guests, including earlier test records, to survive because SQLite stores them on the device instead of only in widget memory. For T4, I stopped Flutter with `q`, used Android’s Force stop, and reopened the app from its launcher; ID 1 was River, age 21, ID 2 was River, age 35, and the count stayed 2 (`evidence/T4_before.png` and `evidence/T4_after.png`). In `lib/main.dart`, `main()` awaits the helper’s `init()` to open the existing database, then the screen’s `initState()` calls `_load()`, which uses `_readRecords()` to query the rows/count and update the visible list with `setState()`. If the list reopened empty, showed different IDs or values, or needed me to add the guests again, that would contradict my claim that SQLite restored the same saved records.
2. Both guests were named River, but ID 1 was age 21 and ID 2 was age 34, so the name alone could not identify which guest to edit. In `lib/main.dart`, `_save()` calls `widget.helper.update()` with `DatabaseHelper.columnId: selectedId`, targeting the selected ID. Saving ID 2 as age 35 should return 1 affected row, leaving ID 1 at 21 and the count at 2. Hypothetically, if I selected the second row and then sorted the list, updating by its old position could change the other River because the rows switched places.
3. During my walkthrough, I checked that invalid input showed a message explaining the problem, such as needing a whole-number age or an age between 0 and 130, including both limits. For T6, the rejected attempts should leave the count at 1 with ID 2 unchanged, which would confirm that nothing was saved. One small improvement would be adding “Whole numbers from 0–130” below the age field so users know the rule before pressing Add. The trade-off is that this takes up a little more screen space.

- Schema/initialization: DatabaseHelper opens MyDatabase.db and creates
  my_table with _id INTEGER PRIMARY KEY, name TEXT NOT NULL, and
  age INTEGER NOT NULL. main() awaits init() before displaying the roster.
- Input/identity: Names are trimmed and required. Ages must be integers
  from 0–130. SQLite generates IDs, and updates/deletes target those IDs.

  ## Storage examples
- Memory state: selected guest ID and unsaved text-field input.
- Key-value preferences: a theme preference could use this storage;
  this app does not implement it.
- SQLite: saved guest records containing ID, name, and age.

## Source locations
- Database CRUD: lib/database_helper.dart
- Screen actions: lib/main.dart — _load(), _save(), _edit(),
  _cancelEdit(), and _delete()

## Evidence
- Before restart: evidence/T4_before.png
- After restart: evidence/T4_after.png
- Invalid input: evidence/T6_invalid.png
- Analyzer output: evidence/analysis_output.txt

## Known limitations
Data is stored locally. The app does not implement encryption,
backup, synchronization, or schema migrations.

