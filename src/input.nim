import std/[json, jsonutils, strformat, bitops, strutils, tables, algorithm, math, unicode]
import os, osproc

const
  INPUT_COUNT* = 256 + 10
  INPUT_ENTER* = -1
  INPUT_ESCAPE* = -2
  INPUT_BACKSPACE* = -3
  INPUT_SPACE* = -4
  INPUT_DELETE* = -5

type
  Modifier* = enum
    Control
    Shift
    Alt
    Super
  Modifiers* = set[Modifier]
  DFAInput = object
    # length 8 because there are 3 modifiers and so 2^3 = 8 possible combinations
    next: array[8, int]
  InputKey = int64
  DFAState = object
    isTerminal: bool
    function: string
    inputs: Table[InputKey, DFAInput]
  CommandDFA = ref object
    states: seq[DFAState]

proc isAscii*(input: int64): bool =
  if input >= char.low.ord and input <= char.high.ord:
    return true
  return false

proc step*(dfa: CommandDFA, currentState: int, currentInput: int64, mods: Modifiers): int =
  if currentInput == 0:
    echo "Input 0 is invalid"
    return

  if not (currentInput in dfa.states[currentState].inputs):
    return 0

  return dfa.states[currentState].inputs[currentInput].next[cast[int](mods)]

proc isTerminal*(dfa: CommandDFA, state: int): bool =
  return dfa.states[state].isTerminal

proc getAction*(dfa: CommandDFA, state: int): string =
  return dfa.states[state].function

proc getInputCodeFromSpecialKey(specialKey: string): int64 =
  if specialKey.len == 1:
    result = ord(specialKey[0])
  else:
    result = case specialKey:
      of "ENTER": INPUT_ENTER
      of "ESCAPE": INPUT_ESCAPE
      of "BACKSPACE": INPUT_BACKSPACE
      of "SPACE": INPUT_SPACE
      of "DELETE": INPUT_DELETE
      else:
        echo "Invalid key '", specialKey, "'"
        0

proc linkState(dfa: var CommandDFA, currentState: int, nextState: int, inputCode: int64, mods: Modifiers) =
  let modsInt = cast[int](mods)

  if not (inputCode in dfa.states[currentState].inputs):
    dfa.states[currentState].inputs[inputCode] = DFAInput()
  dfa.states[currentState].inputs[inputCode].next[modsInt] = nextState

proc createOrUpdateState(dfa: var CommandDFA, currentState: int, inputCode: int64, mods: Modifiers): int =
  let modsInt = cast[int](mods)
  let nextState = if inputCode in dfa.states[currentState].inputs and dfa.states[currentState].inputs[inputCode].next[modsInt] != 0:
    dfa.states[currentState].inputs[inputCode].next[modsInt]
  else:
    dfa.states.add DFAState()
    dfa.states.len - 1
  linkState(dfa, currentState, nextState, inputCode, mods)
  return nextState

proc handleNextInput(dfa: var CommandDFA, input: seq[Rune], function: string, index: int, currentState: int) =
  type State = enum
    Normal
    Special

  var state = State.Normal
  var mods: Modifiers = {}
  var specialKey = ""

  var next: seq[tuple[index: int, state: int]] = @[]
  var lastIndex = 0
  
  if index >= input.len:
    # Mark last state as terminal state.
    dfa.states[currentState].isTerminal = true
    dfa.states[currentState].function = function
    return

  for i in index..<input.len:
    lastIndex = i
    # echo i, ": ", input[i]

    let rune = input[i]
    let ascii = if rune.int64.isAscii: rune.char else: '\0'
    let inputCode: int64 = case ascii:
      of '<':
        state = State.Special
        0.int64
      of '>':
        if state != State.Special:
          echo "Error: > without <"
          return
        let inputCode = getInputCodeFromSpecialKey(specialKey)
        state = State.Normal
        specialKey = ""
        inputCode

      else:
        if state == State.Special:
          if ascii == '-':
            # Parse stuff so far as mods
            mods = {}
            for m in specialKey:
              case m:
                of 'C': mods = mods + {Modifier.Control}
                of 'S': mods = mods + {Modifier.Shift}
                of 'A': mods = mods + {Modifier.Alt}
                else: echo "Invalid modifier '", m, "'"
            specialKey = ""
          else:
            specialKey.add rune
          0.int64
        else:
          mods = {}
          rune.int64

    # echo inputCode, ", ", mods
    if inputCode != 0:
      let nextState = createOrUpdateState(dfa, currentState, inputCode, mods)
      next.add((index: i + 1, state: nextState))

      let bIsLower = rune.isLower
      if not bIsLower:
        linkState(dfa, currentState, nextState, rune.toLower.int64, mods + {Modifier.Shift})
        linkState(dfa, currentState, nextState, inputCode, mods + {Modifier.Shift})

      if bIsLower and Modifier.Shift in mods:
        linkState(dfa, currentState, nextState, rune.toUpper.int64, mods - {Modifier.Shift})
      break

  for n in next:
    handleNextInput(dfa, input, function, n.index, n.state)

proc buildDFA*(commands: seq[(string, string)]): CommandDFA =
  new(result)

  result.states.add DFAState()
  var currentState = 0

  for command in commands:
    # echo "Compiling '", command, "'"

    currentState = 0

    let input = command[0]
    let function = command[1]

    if input.len > 0:
      handleNextInput(result, input.toRunes, function, 0, 0)

proc inputAsString(input: int64): string =
  result = case input:
    of INPUT_ENTER: "ENTER"
    of INPUT_ESCAPE: "ESCAPE"
    of INPUT_BACKSPACE: "BACKSPACE"
    of INPUT_SPACE: "SPACE"
    of INPUT_DELETE: "DELETE"
    else: "<" & $input & ">"

proc inputToString*(input: int64, modifiers: Modifiers): string =
  if Control in modifiers: result.add "C"
  if Shift in modifiers: result.add "S"
  if Alt in modifiers: result.add "A"
  if result.len > 0: result.add "-"

  if input > 0 and input <= int32.high:
    let ch = Rune(input)
    result.add $ch
  else:
    result.add inputAsString(input)

proc dump*(dfa: CommandDFA, currentState: int, currentInput: int64, currentMods: Modifiers): void =
  stdout.write "        "
  for state in 0..<dfa.states.len:
    var stateStr = $state
    if state == currentState:
      stateStr = fmt"({stateStr})"
    stdout.write fmt"{stateStr:^7.7}|"
  echo ""

  stdout.write "        "
  for state in dfa.states:
    if state.isTerminal:
      stdout.write fmt"{state.function:^7.7}|"
    else:
      stdout.write fmt"       |"

  echo ""

  var allUsedInputs: seq[int64] = @[]
  for state in 0..<dfa.states.len:
    for key in dfa.states[state].inputs.keys:
      allUsedInputs.add key

  allUsedInputs.sort
  echo allUsedInputs

  for input in allUsedInputs:
    for modifiersNum in 0..0b111:
      let modifiers = cast[Modifiers](modifiersNum)

      var line = ""

      # Input
      var chStr = inputToString(input, modifiers)

      if currentInput != 0 and input == currentInput and modifiersNum == cast[int](currentMods):
        chStr = fmt"({chStr})"
      line.add fmt"{chStr:^7.7}|"

      # Next state
      var notEmpty = false
      for state in 0..<dfa.states.len:

        let nextState = if input in dfa.states[state].inputs:
          dfa.states[state].inputs[input].next[modifiersNum]
        else: 0

        if nextState == 0 and (state != currentState or input != currentInput or modifiersNum != cast[int](currentMods)):
          line.add "       |"
        else:
          var nextStateStr = $nextState
          if state == currentState and currentInput != 0 and input == currentInput and modifiersNum == cast[int](currentMods):
            nextStateStr = fmt"({nextStateStr})"
          line.add fmt"{nextStateStr:^7.7}|"
          notEmpty = true

      if notEmpty:
        echo line