# An implementation of RFC-3339 for Nim.
# https://tools.ietf.org/html/rfc3339
# https://www.timeanddate.com/date/leapyear.html

when isMainModule:
  import unittest

type
  DateTimeFragment* {.pure.} = enum
    Year
    Month
    Day
    Hour
    Minute
    Second
    SecondFraction
    Offset

  Bitflags = distinct uint8

  DateTime* = object
    year: int16
    month, day: uint8
    hour, minute, second: uint8
    secondfrac: uint8
    houroffset, minuteoffset: int8
    components: Bitflags

proc is_leap_year(year: int): bool =
  ## Checks whether a given year is a leap year.
  let rule1 = (year %% 4) == 0
  let rule2 = (year %% 100) == 0
  let rule3 = (year %% 400) == 0

  if rule2 and (not rule3):
    return false
  return rule1

when isMainModule:
  test "Leap Years":
    check is_leap_year(2016) == true
    check is_leap_year(2017) == false
    check is_leap_year(2000) == true
    check is_leap_year(2001) == false
    check is_leap_year(2020) == true

proc days_in_month(year, month: int): int =
  ## Returns the number of days in a given month, [1, 12], from the
  ## Gregorian calendar.
  assert month >= 1
  assert month <= 12

  case month
  of 1, 3, 5, 7, 8, 10, 12:
    result = 31
  of 4, 6, 9, 11:
    result = 30
  of 2:
    if is_leap_year(year):
      result = 29
    else:
      result = 28
  else:
    assert(false, "Invalid month.")
    result = 0

template incl(self: var Bitflags; frag: DateTimeFragment) =
  self = (self.uint8 or (1 shl frag.ord)).Bitflags

template excl(self: var Bitflags; frag: DateTimeFragment) =
  self = (self.uint8 and (not (1 shl frag.ord))).Bitflags

template `in`(frag: DateTimeFragment; flags: Bitflags): bool =
  (flags.uint8 and (1 shl frag.ord)) != 0

proc `year=`*(self: var DateTime; year: int) =
  ## Sets the year to a given amount, which must be within [0, 9999].

  # RFC doesn't allow dates outside of these ranges
  assert year >= 0
  assert year <= 9999

  self.year = year.int16
  self.components.incl(DateTimeFragment.Year)

proc year*(self: DateTime): int {.inline.} =
  self.year.int

proc `month=`*(self: var DateTime; month: int) =
  ## Sets the month to a given amount, which must be within [1, 12]

  # RFC doesn't allow dates outside of these ranges
  assert month > 0
  assert month < 13

  self.month = month.uint8
  self.components.incl(DateTimeFragment.Month)

proc month*(self: DateTime): int {.inline.} =
  result = self.month.int

proc `day=`*(self: var DateTime; day: int) =
  assert day >= 1
  if (DateTimeFragment.Month in self.components) and (DateTimeFragment.Year in self.components):
    assert day <= days_in_month(self.year.int, self.month.int)
  else:
    assert day <= 31

  self.day = day.uint8
  self.components.incl(DateTimeFragment.Day)

proc day*(self: DateTime): int {.inline.} =
  result = self.day.int

proc `hour=`*(self: var DateTime; hour: int) =
  ## Sets the hour to a given amount, which must be within [0, 23]
  assert hour >= 0
  assert hour <= 23

  self.hour = hour.uint8
  self.components.incl(DateTimeFragment.Hour)

proc hour*(self: DateTime): int {.inline.} =
  result = self.hour.int

proc `minute=`*(self: var DateTime; minute: int) =
  ## Sets the minute to a given amount, which must be within [0, 59]
  assert minute >= 0
  assert minute <= 59

  self.minute = minute.uint8
  self.components.incl(DateTimeFragment.Minute)

proc minute*(self: DateTime): int {.inline.} =
  result = self.minute.int

proc `second=`*(self: var DateTime; second: int) =
  ## Sets the minute to a given amount, which must be within [0, 59].
  ## Note that leap seconds are not enforced here, but are allowed. As
  ## leap seconds cannot be predicted at the time of writing, trying to
  ## enforce them is liable to cause mysterious frustration with
  ## developers and end users who are forced to wait for on 
  ## updates their (suddenly, by committee order) broken code.
  assert second >= 0
  assert second <= 60

  self.second = second.uint8
  self.components.incl(DateTimeFragment.Second)

proc second*(self: DateTime): int =
  result = self.second.int



