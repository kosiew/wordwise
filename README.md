# WordWise

A Mastermind-style secret-word game for macOS. The on-device Apple Foundation Model hosts the game and answers your yes/no questions without giving the word away.

- Ask yes/no questions (−50 points each, up to 20).
- Guess the word (−75 points per wrong guess, up to 6). Each guess shows Mastermind pegs: ● for a right letter in the right spot, ○ for a right letter in the wrong spot.
- If you solve it on your first guess with no questions, you score 1000.

## Word lists

Words live in secret GitHub gists, not in the app. Each new round picks one of 11 lists at random: a general list of 1000 words, plus 10 themed lists of 100 words each (Space, Ocean, Kitchen, Sports, Music, Fantasy & myth, Garden, Science, Travel, Farm). A themed list's name is shown as part of the hint, followed by a category the model writes for that word.

The gist URLs are in `GistWordSource.lists` in `Sources/WordWiseCore/WordSource.swift`. Edit a gist and the next round picks up the change without a rebuild. Each file has one word per line, `#` comments, and an optional `# theme: Name` line. Downloaded lists are cached in `~/Library/Application Support/WordWise/Lists`, so the game still works offline.

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
