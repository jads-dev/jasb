module Time.DateTime exposing
    ( DateTime
    , date
    , decoder
    , encode
    , fromDateAndTime
    , fromIso
    , fromPosix
    , getNow
    , time
    , toDateAndTime
    , toIso
    , toPosix
    , view
    , viewEditor
    , viewInTense
    )

import Html
import Html.Attributes as HtmlA
import Iso8601
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.TextField as TextField
import Task exposing (Task)
import Time
import Time.Format as Format
import Time.Model as Time


type DateTime
    = DateTime String


type alias DateTimeEditor =
    { date : String
    , time : String
    }


{-| Round a date/time down to just the date.
-}
date : DateTime -> String
date =
    toDateAndTime >> .date


{-| Round a date/time down to just the time.
-}
time : DateTime -> String
time =
    toDateAndTime >> .time


{-| Get a date/time from an ISO date string and an ISO time string.
-}
fromDateAndTime : { date : String, time : String } -> Maybe DateTime
fromDateAndTime dateTime =
    (dateTime.date ++ "T" ++ dateTime.time) |> fromIso


{-| Split a date/time to date and time ISO strings.
-}
toDateAndTime : DateTime -> { date : String, time : String }
toDateAndTime (DateTime dateTime) =
    case dateTime |> String.split "T" of
        [ dateString, timeString ] ->
            { date = dateString, time = timeString }

        _ ->
            -- We check the string at parse time so this shouldn't ever happen.
            { date = "", time = "" }


{-| Get an ISO string from a date.
-}
toIso : DateTime -> String
toIso (DateTime dateTime) =
    dateTime


{-| Get a date/time from an ISO string.
-}
fromIso : String -> Maybe DateTime
fromIso dateTime =
    case Iso8601.toTime dateTime of
        Ok _ ->
            dateTime |> DateTime |> Just

        Err _ ->
            Nothing


{-| Get a posix time from a date. This will be at 00:00.
-}
toPosix : DateTime -> Time.Posix
toPosix (DateTime dateTime) =
    case dateTime |> Iso8601.toTime of
        Ok posix ->
            posix

        Err _ ->
            -- We do this at parse time so this shouldn't ever happen.
            Time.millisToPosix 0


{-| Get a date from a posix time. This will be rounded down to the day before the given time.
-}
fromPosix : Time.Posix -> DateTime
fromPosix posix =
    posix |> Iso8601.fromTime |> DateTime


getNow : Task x DateTime
getNow =
    Time.now |> Task.map fromPosix


{-| Render as an HMTL editor.
-}
viewEditor : String -> DateTimeEditor -> Maybe (DateTimeEditor -> msg) -> List (Html.Attribute msg) -> Html.Html msg
viewEditor name value action attrs =
    let
        fromDate toMsg str =
            { value | date = str } |> toMsg

        fromTime toMsg str =
            { value | time = str } |> toMsg
    in
    Html.div [ HtmlA.class "date-time" ]
        [ TextField.viewWithAttrs
            (name ++ " Date")
            TextField.Date
            value.date
            (action |> Maybe.map fromDate)
            attrs
        , TextField.viewWithAttrs
            (name ++ " Time")
            TextField.Time
            value.time
            (action |> Maybe.map fromTime)
            attrs
        ]


{-| Render as HTML.
-}
view : Time.Context -> Time.Display -> DateTime -> Html.Html msg
view { zone, now } display value =
    let
        posixValue =
            value |> toPosix

        relative =
            posixValue |> Format.asRelative now

        absolute =
            posixValue |> Format.asDateTime zone

        ( primary, secondary ) =
            case display of
                Time.Absolute ->
                    ( absolute, relative )

                Time.Relative ->
                    ( relative, absolute )
    in
    Html.time
        [ value |> toIso |> HtmlA.datetime
        , secondary |> HtmlA.title
        ]
        [ primary |> Html.text ]


{-| Render as HTML with the correct tense relative to the current time.
-}
viewInTense : Time.Context -> Time.Display -> { past : String, future : String } -> DateTime -> List (Html.Html msg)
viewInTense ({ now } as timeContext) display { past, future } value =
    let
        describe =
            if Time.posixToMillis (value |> toPosix) < Time.posixToMillis now then
                past

            else
                future
    in
    [ describe |> Html.text
    , Html.text " "
    , view timeContext display value
    ]


{-| Encode a date/time to a JSON (ISO) string.
-}
encode : DateTime -> JsonE.Value
encode =
    toIso >> JsonE.string


{-| Decode a date/time from a JSON (ISO) string.
-}
decoder : JsonD.Decoder DateTime
decoder =
    let
        fromString iso =
            case fromIso iso of
                Just dateTime ->
                    JsonD.succeed dateTime

                Nothing ->
                    JsonD.fail "Not a valid date."
    in
    JsonD.string |> JsonD.andThen fromString
