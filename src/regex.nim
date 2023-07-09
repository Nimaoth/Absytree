when defined(js):
  import std/jsre
  export jsre

  import custom_unicode, util

  type Regex* = object
    impl: RegExp

  proc findBoundsJs*(self: RegExp; pattern: cstring): seq[RuneIndex] {.importjs: "((#.exec(#)) || {indices: [[-1, 0]]}).indices[0]".}

  proc findBounds*(text: string, regex: Regex, start: int): tuple[first: int, last: int] =
    regex.impl.lastIndex = 0
    let bounds = regex.impl.findBoundsJs(text[start..^1].cstring)
    if bounds[0].int != -1:
      result.first = text.toOpenArray.runeOffset(bounds[0], start)
      result.last = text.toOpenArray.runeOffset(bounds[1] - 1.RuneCount, start)
    else:
      result = (-1, -1)

  proc matchLenJs*(self: RegExp; pattern: cstring): int {.importjs: "((#.exec(#)) || {index:-1}).index".}

  proc matchLen*(text: string, regex: Regex, start: int): int =
    regex.impl.lastIndex = 0
    result = regex.impl.matchLenJs(text[start..^1].cstring)
    if result != -1:
      result += start

  proc match*(text: string, regex: Regex, start: int): bool =
    return text.matchLen(regex, start) != -1

  proc re*(text: string): Regex =
    return Regex(impl: newRegExp(text.cstring, "dg"))

else:
  import std/re
  export re