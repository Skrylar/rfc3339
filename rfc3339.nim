# Written by Joshua "Skrylar" Cearley.
#
# Copyright 2017 Joshua Cearley
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# An implementation of RFC-3339 for Nim.
# https://tools.ietf.org/html/rfc3339
# https://www.timeanddate.com/date/leapyear.html

import parseutils

when isMainModule:
  import unittest

const
  EpochSeconds = 62135683200
  YearZeroSeconds = 31622400

type
  DateTimeFragment* {.pure.} = enum
    ## A fragment of a DateTime object. As not all fields are always
    ## available, this enum tracks the difference between "zero minutes"
    ## and "unspecified minutes."
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
    ## An RFC3339 date/time object.
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
  ## Sets the day of a year. If no month is set, the day must be less
  ## than 32. If a month is set, must be a valid day within that month.
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
  ## Sets the fraction of a second represented by this time object. Must
  ## be in the range of [0, 9]
  assert fraction >= 0
  assert fraction <= 9

  self.msecondfrac = fraction.uint8
  self.components.incl(DateTimeFragment.SecondFraction)

proc second_fraction*(self: DateTime): int =
  result = self.msecondfrac.int

proc set_offset*(self: var DateTime; hours, minutes: int) =
  ## Sets the offset (timezone) of this time object. Note that when
  ## converting to types with no timezone field, the offset is applied
  ## (and the metadata is lost.) A round-trip to epoch and back will
  ## represent the same moment in time, but will not know that it
  ## belongs to this timezone.
  assert hours <= 23
  assert hours >= -23
  assert minutes <= 59
  assert minutes >= -59

  if hours != 0:
    assert minutes >= 0

  self.mhouroffset = hours.int8
  self.mminuteoffset = minutes.int8
  self.components.incl(DateTimeFragment.Offset)

proc remove*(self: var DateTime; component: DateTimeFragment) =
  ## Removes a component from the date time; it is effectively set to
  ## zero.
  self.components.excl(component)

proc to_number*(self: DateTime): int64 =
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
    result += self.day.int64 * (60 * 60 * 24)
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

  result -= YearZeroSeconds

proc to_epoch*(self: DateTime): int64 =
  ## Returns the value of a given date time in reference to the Unix
  ## epoch (1/1/1970). Fractional seconds are lost due to the integer
  ## format.
  result = self.to_number - EpochSeconds

proc to_date*(self: int64): DateTime =
  ## Returns the value of a given time in reference to the start of the
  ## Gregorian calendar (1/1/0001)

  # I'm sure it's possible to compute time before Gregorian, although we
  # wouldn't have a means of legally representing it under the RFC.
  # There is no means to have a "negative year."
  assert self >= -YearZeroSeconds

  var accum = self + YearZeroSeconds

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
  var m = 0'i64
  block monthly:
    for i in 1..12:
      let x = days_in_month(y.int, i) * (24 * 60 * 60)
      if accum >= x:
        accum -= x
        m = m + 1
      else:
        break monthly
  m = min(m, 1)
  if m > 0:
    result.month = m.int

  var d = 0'i64
  block daily:
    for i in 1..60:
      let x = 24 * 60 * 60
      if accum >= x:
        accum -= x
        d += 1
      else:
        break daily
  d = min(d, 1)
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

proc to_epoch_date*(self: int64): DateTime =
  ## Returns the value of a given date time in reference to the Unix
  ## epoch (1/1/1970). Fractional seconds are lost due to the integer
  ## format.
  result = (self + EpochSeconds).to_date

proc to_fulldate_string*(self: DateTime): string =
  ## Emits a full-date from the date time, in the format YYYY-MM-DD.
  let y = if DateTimeFragment.Year in self.components: self.year else: 0
  let m = if DateTimeFragment.Month in self.components: self.month else: 1
  let d = if DateTimeFragment.Day in self.components: self.day else: 1

  # reserve space for all ten characters, then zero out so we can build
  # the string in pieces
  result = newString(10)
  setLen(result, 0)

  if y <= 9:
    result &= "000"
  elif y <= 99:
    result &= "00"
  elif y <= 999:
    result &= "0"
  result &= $y
  result &= "-"
  if m <= 9:
    result &= "0"
  result &= $m
  result &= "-"
  if d <= 9:
    result &= "0"
  result &= $d

proc to_fulltime_string*(self: DateTime): string =
  ## Returns a conversion of this date time object to a "full-time"
  ## string, which is HH:MM:SS.FZ+HH:MM.
  let h = if DateTimeFragment.Hour in self.components: self.hour else: 0
  let m = if DateTimeFragment.Minute in self.components: self.minute else: 0
  let s = if DateTimeFragment.Second in self.components: self.second else: 0

  result = newString(16)
  setLen(result, 0)

  if h <= 9:
    result &= "0"
  result &= $h
  result &= ":"
  if m <= 9:
    result &= "0"
  result &= $m
  result &= ":"
  if s <= 9:
    result &= "0"
  result &= $s

  if DateTimeFragment.SecondFraction in self.components:
    result &= "."
    result &= $self.second_fraction

  block offset:
    let ho = if DateTimeFragment.Offset in self.components: self.mhouroffset else: 0
    let mo = if DateTimeFragment.Offset in self.components: self.mminuteoffset else: 0

    if (ho == 0) and (mo == 0):
      result &= "Z"
    else:
      if ho == 0:
        if mo >= 0:
          result &= "+"
        else:
          result &= "-"
      else:
        if ho >= 0:
          result &= "+"
        else:
          result &= "-"

      if ho <= 9:
        result &= "0"
      result &= $abs(ho)
      result &= ":"

      let m = abs(mo)
      if m <= 9:
        result &= "0"
      result &= $m

proc `==`*(self, other: DateTime): bool =
  return self.to_number == other.to_number

proc `$`*(self: DateTime): string =
  ## Returns a full date and time pair in ISO specification,
  ## "YYYY-MM-DDTHH:MM:SS.FZ+HH:MM"
  result = newString(0)
  result &= self.to_fulldate_string
  result &= "T"
  result &= self.to_fulltime_string

proc to_date*(self: string): DateTime =
  ## Parses a string as an RFC3339 date, returning an object. Checking
  ## the components of the returned date time allows you to determine a
  ## failed parse, or when optional fields were not read.
  var i = 0

  # NB: while this is not unicode safe, rfc3339 dates consist solely of
  # 7-bit characters and thus we can do this without recourse
  template getch(): char =
    inc i
    if i > self.high:
      break
    self[i-1]

  template getdigit(): char =
    let x = getch
    if x < '0' or x > '9':
      break
    x

  var scratch = newString(4)
  var work = DateTime()

  block date:
    var x: int
    # load year
    scratch[0] = getdigit
    scratch[1] = getdigit
    scratch[2] = getdigit
    scratch[3] = getdigit
    discard parseint(scratch, x)
    work.myear = x.int16

    if getch != '-': break

    # load month
    setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.mmonth = x.uint8

    if getch != '-': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.mday = x.uint8

    if getch != 'T': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.mhour = x.uint8

    if getch != ':': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.mminute = x.uint8

    if getch != ':': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.msecond = x.uint8

    if getch == '.':
      setLen(scratch, 1)
      scratch[0] = getdigit
      discard parseint(scratch, x)
      work.msecondfrac = x.uint8

    if getch != 'Z': break

    let sign = getch
    if sign != '-' and sign != '+': break

    setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.mhouroffset = x.int8
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.mminuteoffset = x.int8

    if sign == '-':
      if work.mhouroffset > 0:
        work.mhouroffset *= -1
      else:
        work.mminuteoffset *= -1

    return work

  return

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

    check e == 0

    let d2 = e.to_epoch_date

    check d2 == date

  suite "Import":
    test "Epoch to Date":
      var date = 0.to_epoch_date()

      check date.to_fulldate_string() == "1970-01-01"
      check $date == "1970-01-01T00:00:00Z"

    test "String to Epoch":
      var date = "1970-01-01T00:00:00Z+00:00".to_date()

      check date.to_fulldate_string() == "1970-01-01"
      check $date == "1970-01-01T00:00:00Z"

    test "Gregorian Start to Date":
      var date = 0.to_date()

      check date.to_fulldate_string() == "0001-01-01"
      check $date == "0001-01-01T00:00:00Z"

    test "String to Gregorian Start":
      var date = "0001-01-01T00:00:00Z".to_date()

      check date.to_fulldate_string() == "0001-01-01"
      check $date == "0001-01-01T00:00:00Z"

  suite "Export":
    test "Epoch to Full Date (No Timezone)":
      var date = DateTime()
      date.year = 1970
      date.month = 1
      date.day = 1

      check date.to_fulldate_string() == "1970-01-01"
      check $date == "1970-01-01T00:00:00Z"

    test "Epoch to Full Date (With Timezone)":
      var date = DateTime()
      date.year = 1970
      date.month = 1
      date.day = 1
      date.set_offset(1, 30)

      check date.to_fulldate_string() == "1970-01-01"
      check $date == "1970-01-01T00:00:00+01:30"

    test "Epoch to Full Date (With Negative Hour Timezone)":
      var date = DateTime()
      date.year = 1970
      date.month = 1
      date.day = 1
      date.set_offset(-1, 30)

      check date.to_fulldate_string() == "1970-01-01"
      check $date == "1970-01-01T00:00:00-01:30"

    test "Epoch to Full Date (With Negative Minute Timezone)":
      var date = DateTime()
      date.year = 1970
      date.month = 1
      date.day = 1
      date.set_offset(0, -30)

      check date.to_fulldate_string() == "1970-01-01"
      check $date == "1970-01-01T00:00:00-00:30"

