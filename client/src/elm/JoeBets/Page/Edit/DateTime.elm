module JoeBets.Page.Edit.DateTime exposing
    ( Change
    , DateTime
    , fromPosix
    , init
    , notEmptyValidator
    , toPosix
    , update
    , validIfGivenValidator
    , validator
    , viewEditor
    )

import DateFormat
import Html
import Html.Attributes as HtmlA
import Iso8601
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import Material.TextField as TextField
import Parser
import Time exposing (Posix)
import Util.Result as Result


type alias DateTime =
    { date : String
    , time : String
    }


type Change
    = ChangeDate String
    | ChangeTime String


init : DateTime
init =
    { date = "", time = "" }


update : Change -> DateTime -> DateTime
update change dateTime =
    case change of
        ChangeDate date ->
            { dateTime | date = date }

        ChangeTime time ->
            { dateTime | time = time }


toPosix : DateTime -> Result (List Parser.DeadEnd) Posix
toPosix { date, time } =
    (date ++ "T" ++ time ++ ":00.000Z") |> Iso8601.toTime


notEmptyValidator : Validator DateTime
notEmptyValidator =
    Validator.all
        [ Validator.fromPredicate "No date given." (.date >> String.isEmpty)
        , Validator.fromPredicate "No time given." (.time >> String.isEmpty)
        ]


validIfGivenValidator : Validator DateTime
validIfGivenValidator model =
    if (model.date |> String.isEmpty) && (model.time |> String.isEmpty) then
        []

    else
        validator model


validator : Validator DateTime
validator =
    Validator.fromPredicate "Invalid date/time." (toPosix >> Result.isOk >> not)


fromPosix : Time.Posix -> DateTime
fromPosix time =
    DateTime
        (time
            |> DateFormat.format
                [ DateFormat.yearNumber
                , DateFormat.text "-"
                , DateFormat.monthFixed
                , DateFormat.text "-"
                , DateFormat.dayOfMonthFixed
                ]
                Time.utc
        )
        (time |> DateFormat.format [ DateFormat.hourFixed, DateFormat.text ":", DateFormat.minuteFixed ] Time.utc)


viewEditor : String -> DateTime -> Maybe (Change -> msg) -> List (Html.Attribute msg) -> Html.Html msg
viewEditor name { date, time } action attrs =
    Html.div [ HtmlA.class "date-time" ]
        [ TextField.viewWithAttrs (name ++ " Date") TextField.Date date (action |> Maybe.map (\a -> ChangeDate >> a)) attrs
        , TextField.viewWithAttrs (name ++ " Time") TextField.Time time (action |> Maybe.map (\a -> ChangeTime >> a)) attrs
        ]
