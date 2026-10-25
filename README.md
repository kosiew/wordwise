# WordWise

A Mastermind-style secret-word game for macOS. The on-device Apple Foundation Model hosts the game and answers your yes/no questions without giving the word away.

- Ask yes/no questions (−50 points each, up to 20).
- Guess the word (−75 points per wrong guess, up to 6). Each guess shows Mastermind pegs: ● for a right letter in the right spot, ○ for a right letter in the wrong spot.
- If you solve it on your first guess with no questions, you score 1000.

Requires macOS 26+ with Apple Intelligence enabled.

## Run

```sh
swift run WordWise            # quick launch
./scripts/make-app.sh         # builds build/WordWise.app
```

## Test

The Command Line Tools don't put the Swift Testing macro plugin on the default search path, so pass it explicitly:

```sh
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
WORDWISE_LIVE=1 swift test ...   # also queries the real on-device model
```
