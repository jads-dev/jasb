module Time.Format exposing
    ( asDate
    , asDateTime
    , asRelative
    )

import DateFormat
import DateFormat.Relative as DateFormat
import Time


asDate : Time.Zone -> Time.Posix -> String
asDate =
    DateFormat.format
        [ DateFormat.yearNumber
        , DateFormat.text "-"
        , DateFormat.monthFixed
        , DateFormat.text "-"
        , DateFormat.dayOfMonthFixed
        ]


asDateTime : Time.Zone -> Time.Posix -> String
asDateTime =
    DateFormat.format
        [ DateFormat.yearNumber
        , DateFormat.text "-"
        , DateFormat.monthFixed
        , DateFormat.text "-"
        , DateFormat.dayOfMonthFixed
        , DateFormat.text " "
        , DateFormat.hourFixed
        , DateFormat.text ":"
        , DateFormat.minuteFixed
        , DateFormat.text ":"
        , DateFormat.secondFixed
        ]


asRelative : Time.Posix -> Time.Posix -> String
asRelative =
    DateFormat.relativeTime
