# An implementation of RFC-3339 for Nim.
# https://tools.ietf.org/html/rfc3339
# https://www.timeanddate.com/date/leapyear.html

when isMainModule:
  import unittest

const
  EpochMonth* = 1
  EpochDay* = 1
  EpochYear* = 1970

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
    myear: int16
    mmonth, mday: uint8
    mhour, mminute, msecond: uint8
    msecondfrac: uint8
    mhouroffset, mminuteoffset: int8
    components: Bitflags

proc is_leap_year*(year: int): bool =
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

proc days_in_month*(year, month: int): int =
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

proc days_in_year*(year: int): int =
  ## Calculates the number of days in a given year.
  assert year >= 0
  for i in 1..12:
    inc result, days_in_month(year, i)

template incl(self: var Bitflags; frag: DateTimeFragment) =
  self = (self.uint8 or (1 shl frag.ord).uint8).Bitflags

template excl(self: var Bitflags; frag: DateTimeFragment) =
  self = (self.uint8 and (not (1 shl frag.ord)).uint8).Bitflags

template `in`(frag: DateTimeFragment; flags: Bitflags): bool =
  ((flags.uint8 and (1 shl frag.ord.uint8)) != 0)

template `==`(x, y: Bitflags): bool =
  x.uint8 == y.uint8

proc `year=`*(self: var DateTime; year: int) =
  ## Sets the year to a given amount, which must be within [0, 9999].

  # RFC doesn't allow dates outside of these ranges
  assert year >= 0
  assert year <= 9999

  self.myear = year.int16
  self.components.incl(DateTimeFragment.Year)

proc year*(self: DateTime): int {.inline.} =
  result = self.myear.int

proc `month=`*(self: var DateTime; month: int) =
  ## Sets the month to a given amount, which must be within [1, 12]

  # RFC doesn't allow dates outside of these ranges
  assert month > 0
  assert month < 13

  self.mmonth = month.uint8
  self.components.incl(DateTimeFragment.Month)

proc month*(self: DateTime): int {.inline.} =
  result = self.mmonth.int

proc `day=`*(self: var DateTime; day: int) =
  assert day >= 1
  if (DateTimeFragment.Month in self.components) and (DateTimeFragment.Year in self.components):
    assert day <= days_in_month(self.year.int, self.month.int)
  else:
    assert day <= 31

  self.mday = day.uint8
  self.components.incl(DateTimeFragment.Day)

proc day*(self: DateTime): int {.inline.} =
  result = self.mday.int

proc `hour=`*(self: var DateTime; hour: int) =
  ## Sets the hour to a given amount, which must be within [0, 23]
  assert hour >= 0
  assert hour <= 23

  self.mhour = hour.uint8
  self.components.incl(DateTimeFragment.Hour)

proc hour*(self: DateTime): int {.inline.} =
  result = self.mhour.int

proc `minute=`*(self: var DateTime; minute: int) =
  ## Sets the minute to a given amount, which must be within [0, 59]
  assert minute >= 0
  assert minute <= 59

  self.mminute = minute.uint8
  self.components.incl(DateTimeFragment.Minute)

proc minute*(self: DateTime): int {.inline.} =
  result = self.mminute.int

proc `second=`*(self: var DateTime; second: int) =
  ## Sets the minute to a given amount, which must be within [0, 59].
  ## Note that leap seconds are not enforced here, but are allowed. As
  ## leap seconds cannot be predicted at the time of writing, trying to
  ## enforce them is liable to cause mysterious frustration with
  ## developers and end users who are forced to wait for on 
  ## updates their (suddenly, by committee order) broken code.
  assert second >= 0
  assert second <= 60

  self.msecond = second.uint8
  self.components.incl(DateTimeFragment.Second)

proc second*(self: DateTime): int =
  result = self.msecond.int

proc `second_fraction=`*(self: var DateTime; fraction: int) =
  assert fraction >= 0
  assert fraction <= 9

  self.msecondfrac = fraction.uint8
  self.components.incl(DateTimeFragment.SecondFraction)

proc second_fraction*(self: DateTime): int =
  result = self.msecondfrac.int

proc set_offset*(self: var DateTime; hours, minutes: int) =
  assert hours <= 23
  assert hours >= -23
  assert minutes <= 59
  assert minutes >= -59

  if hours != 0:
    assert minutes >= 0

  self.mhouroffset = hours.int8
  self.mminuteoffset = hours.int8
  self.components.incl(DateTimeFragment.Offset)

proc remove*(self: var DateTime; component: DateTimeFragment) =
  ## Removes a component from the date time; it is effectively set to
  ## zero.
  self.components.excl(component)

proc to_number(self: DateTime): int64 =
  ## Returns the value of a given date time in reference to the number
  ## of seconds since  the beginning of the Gregorian calendar
  ## (1/1/0001). Fractional seconds are lost due to the integer format.
  if DateTimeFragment.Second in self.components:
    result += self.second.int64
  if DateTimeFragment.Minute in self.components:
    if self.minute > 1:
      result += (self.minute.int64 - 1) * 60
  if DateTimeFragment.Hour in self.components:
    if self.hour > 1:
      result += (self.hour.int64 - 1) * (60 * 60)
  if DateTimeFragment.Day in self.components:
    result += (self.day.int64 - 1) * (60 * 60 * 24)
  if DateTimeFragment.Month in self.components:
    let y = if DateTimeFragment.Year in self.components: self.year else: 0
    if self.month > 1:
      for i in 1..(self.month-1):
        result += days_in_month(y, i) * (60 * 60 * 24)
  if DateTimeFragment.Year in self.components:
    for i in 0..(self.year-1):
      result += days_in_year(i) * (60 * 60 * 24)
  if DateTimeFragment.Offset in self.components:
    result += self.mhouroffset * (60 * 60)
    result += self.mminuteoffset * 60

proc to_epoch(self: DateTime): int64 =
  ## Returns the value of a given date time in reference to the Unix
  ## epoch (1/1/1970). Fractional seconds are lost due to the integer
  ## format.
  result = self.to_number - 62167219200

proc to_date(self: int64): DateTime =
  # I'm sure it's possible to compute time before Gregorian, although we
  # wouldn't have a means of legally representing it under the RFC.
  # There is no means to have a "negative year."
  assert self >= 0

  var accum = self

  # figure out how many years we are looking at
  var y = 0'i64
  block yearly:
    for i in 0..9999:
      let x = days_in_year(i) * (24 * 60 * 60)
      if accum >= x:
        accum -= x
        y += 1
      else:
        break yearly
  if y > 0:
    result.year = y.int

  # figure out how many months there are
  var m = 1'i64
  block monthly:
    for i in 1..12:
      let x = days_in_month(y.int, i) * (24 * 60 * 60)
      if accum >= x:
        accum -= x
        m = m + 1
      else:
        break monthly
  if m > 0:
    result.month = m.int

  var d = 1'i64
  block daily:
    for i in 1..60:
      let x = 24 * 60 * 60
      if accum >= x:
        accum -= x
        d += 1
      else:
        break daily
  if d > 0:
    result.day = d.int

  var h = 0'i64
  block hourly:
    for i in 0..23:
      let x = 60 * 60
      if accum >= x:
        accum -= x
        h += 1
      else:
        break hourly
  if h > 0:
    result.hour = h.int

  m = 0'i64
  block minutely:
    for i in 0..23:
      let x = 60
      if accum >= x:
        accum -= x
        h += 1
      else:
        break minutely
  if m > 0:
    result.minute = m.int
  if accum > 0:
    result.second = accum.int

proc to_epoch_date(self: int64): DateTime =
  result = (self + 62167219200).to_date

when isMainModule:
  test "Date to Epoch":
    var date = DateTime()
    date.year = 1970
    date.month = 1
    date.day = 1

    check DateTimeFragment.Year in date.components == true
    check DateTimeFragment.Month in date.components == true
    check DateTimeFragment.Day in date.components == true
    check DateTimeFragment.Hour in date.components == false

    check date.to_epoch == 0

  test "Date to Epoch Round Trip":
    var date = DateTime()
    date.year = 1970
    date.month = 1
    date.day = 1

    let e = date.to_epoch
    let d2 = e.to_epoch_date

    check d2 == date

