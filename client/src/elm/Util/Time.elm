module Util.Time exposing
    ( formatAsDate
    , formatAsRelative
    )

import DateFormat
import DateFormat.Relative as DateFormat
import Time


formatAsDate : Time.Zone -> Time.Posix -> String
formatAsDate =
    DateFormat.format
        [ DateFormat.yearNumber
        , DateFormat.text "-"
        , DateFormat.monthNumber
        , DateFormat.text "-"
        , DateFormat.dayOfMonthNumber
        ]


formatAsRelative : Time.Posix -> Time.Posix -> String
formatAsRelative =
    DateFormat.relativeTime
