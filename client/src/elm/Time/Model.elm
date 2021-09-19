module Time.Model exposing
    ( Context
    , Display(..)
    )

import Time


{-| How to display a date/time, either absolutely or relatively.
Either way, the other will be provided as alt-text.
-}
type Display
    = Absolute
    | Relative


{-| The time context the user is in.
-}
type alias Context =
    { zone : Time.Zone
    , now : Time.Posix
    }
