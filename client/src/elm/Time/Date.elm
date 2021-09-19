module Time.Date exposing
    ( Date
    , decoder
    , encode
    , fromIso
    , fromPosix
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
import Time
import Time.Format as Format
import Time.Model as Time


type Date
    = Date String


{-| Get an ISO string from a date.
-}
toIso : Date -> String
toIso (Date value) =
    value


{-| Get a date from an ISO string.
-}
fromIso : String -> Maybe Date
fromIso value =
    case Iso8601.toTime value of
        Ok _ ->
            value |> String.split "T" |> List.head |> Maybe.map Date

        Err _ ->
            Nothing


{-| Get a posix time from a date. This will be at 00:00.
-}
toPosix : Date -> Time.Posix
toPosix (Date value) =
    case value |> Iso8601.toTime of
        Ok posix ->
            posix

        Err _ ->
            -- We do this at parse time so this shouldn't ever happen.
            Time.millisToPosix 0


{-| Get a date from a posix time. This will be rounded down to the day before the given time.
-}
fromPosix : Time.Posix -> Date
fromPosix posix =
    posix |> Iso8601.fromTime |> String.split "T" |> List.head |> Maybe.withDefault "" |> Date


{-| Render as an HMTL editor.
-}
viewEditor : String -> String -> Maybe (String -> msg) -> List (Html.Attribute msg) -> Html.Html msg
viewEditor name value action attrs =
    TextField.viewWithAttrs (name ++ " Date") TextField.Date value action attrs


{-| Render as HTML.
-}
view : Time.Context -> Time.Display -> Date -> Html.Html msg
view { zone, now } display value =
    let
        posixValue =
            value |> toPosix

        relative =
            posixValue |> Format.asRelative now

        absolute =
            posixValue |> Format.asDate zone

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
viewInTense : Time.Context -> Time.Display -> { past : String, future : String } -> Date -> List (Html.Html msg)
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


{-| Encode a date to a JSON (ISO) string.
-}
encode : Date -> JsonE.Value
encode =
    toIso >> JsonE.string


{-| Decode a date from a JSON (ISO) string.
-}
decoder : JsonD.Decoder Date
decoder =
    let
        fromString iso =
            case fromIso iso of
                Just date ->
                    JsonD.succeed date

                Nothing ->
                    JsonD.fail "Not a valid date."
    in
    JsonD.string |> JsonD.andThen fromString
