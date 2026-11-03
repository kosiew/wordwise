# WordWise

A Mastermind-style secret-word game for macOS. The on-device Apple Foundation Model hosts the game and answers your yes/no questions without giving the word away.

- Ask yes/no questions (−50 points each, up to 20).
- Guess the word (−75 points per wrong guess, up to 6). Each guess shows Mastermind pegs: ● for a right letter in the right spot, ○ for a right letter in the wrong spot.
- Reveal a letter in its place (−100 points, ⌘R), up to half the word's letters.
- Reveal vowel positions (−75 points, ⇧⌘R): marks which boxes hold A, E, I, O or U, without saying which. Once per word.
- If you solve it on your first guess with no questions, you score 1000.

## Word lists

Choose a list from the **Word List** menu:

- **Built-in:** 1000 general words, from `Sources/WordWiseCore/Resources/words.txt`.
- **Themed lists:** every `.txt` file in `Sources/WordWiseCore/Resources/wordlists/`. Ten come with the game: Fantasy, Farm, Garden, Kitchen, Music, Ocean, Science, Space, Sports and Travel. Add a file there and rebuild, and it appears in the menu.
- **Your own lists:** every `.txt` file in `~/Library/Application Support/WordWise/Lists`. **Show My Word Lists Folder** opens it. New files appear the next time you switch back to the app, with no rebuild.
- **Open Other…** (⌘O) loads a list from anywhere else.

A file's name becomes its menu title, so `board-games.txt` shows as "Board Games". Each file has one word per line (letters only, at least 3), and lines starting with `#` are comments. The game remembers the list you picked across launches.

Requires macOS 26+ with Apple Intelligence enabled.

## Run

```sh
swift run WordWise            # quick launch
./scripts/make-app.sh         # builds build/WordWise.app and installs it to /Applications
```

## Test

The Command Line Tools don't put the Swift Testing macro plugin on the default search path, so pass it explicitly:

```sh
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
WORDWISE_LIVE=1 swift test ...   # also queries the real on-device model
```
