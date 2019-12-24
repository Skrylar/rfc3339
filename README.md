# RFC3339

[RFC3339](https://www.ietf.org/rfc/rfc3339.txt) is a standard date/time
format used by many web protocols.

Lets you store dates and times. Also parse them from strings. Used by a
lot of web RFCs.

Originally created to parse dates in TOML files.

## Fractional Seconds

This module makes a best-effort attempt at supporting fractional time as
specified in the RFC. Conversion between formats may however result in
those fractional seconds being lost due to rounding or precision errors
in those interim types.

## Timezones

This module attempts to support timezones by preserving any timezone
information read or stored in its native type. Conversion between types
will however lose the timezone by applying the offset and converting the
time to UTC however.

## License

This module is made available under the BSD (2-clause) license.


