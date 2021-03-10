module JoeBets.Bet.Editor.ProgressEditor exposing
    ( Model
    , Msg
    , State(..)
    , fromBet
    , init
    , toProgress
    , update
    , validator
    , view
    , viewMakeWinnerButton
    )

import AssocList
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Bet.Option as Option exposing (Option)
import JoeBets.Game.Model as Game
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Material.Switch as Switch
import Material.TextField as TextField
import Util.AssocList as AssocList
import Util.Maybe as Maybe


type Msg
    = ChangeState State
    | ChangeLocksWhen String
    | ChangeWinner Int
    | ChangeCancelReason String


type State
    = Suggestion
    | Voting
    | Locked
    | Complete
    | Cancelled


type alias Model =
    { state : State
    , by : Maybe User.Id
    , locksWhen : String
    , winner : Maybe Int
    , cancelReason : String
    }


init : Model
init =
    { state = Suggestion
    , by = Nothing
    , locksWhen = ""
    , winner = Nothing
    , cancelReason = ""
    }


locksWhenValidator : Validator Model
locksWhenValidator =
    Validator.fromPredicate "Lock moment must not be empty." (.locksWhen >> String.isEmpty)


winnerValidator : AssocList.Dict Option.Id Option -> Validator Model
winnerValidator options model =
    case model.winner of
        Just winner ->
            "The winner must be a valid option." |> Maybe.when ((options |> AssocList.size) < winner) |> Maybe.toList

        Nothing ->
            [ "Winner must be given." ]


cancelReasonValidator : Validator Model
cancelReasonValidator =
    Validator.fromPredicate "Cancel reason must not be empty." (.cancelReason >> String.isEmpty)


validator : AssocList.Dict Option.Id Option -> Validator Model
validator options model =
    case model.state of
        Suggestion ->
            []

        Voting ->
            locksWhenValidator model

        Locked ->
            []

        Complete ->
            winnerValidator options model

        Cancelled ->
            cancelReasonValidator model


fromBet : Bet -> Model
fromBet { progress, options } =
    let
        model =
            init
    in
    case progress of
        Bet.Suggestion { by } ->
            { model | state = Suggestion, by = Just by }

        Bet.Voting { locksWhen } ->
            { model | state = Voting, locksWhen = locksWhen }

        Bet.Locked _ ->
            { model | state = Locked }

        Bet.Complete { winner } ->
            { model | state = Complete, winner = options |> AssocList.findIndexOfKey winner }

        Bet.Cancelled { reason } ->
            { model | state = Cancelled, cancelReason = reason }


toProgress : User.Id -> AssocList.Dict Option.Id Option -> Model -> Bet.Progress
toProgress localUser options model =
    case model.state of
        Suggestion ->
            Bet.Suggestion { by = model.by |> Maybe.withDefault localUser }

        Voting ->
            Bet.Voting { locksWhen = model.locksWhen }

        Locked ->
            Bet.Locked {}

        Complete ->
            let
                maybeWinner =
                    model.winner
                        |> Maybe.andThen (\winningIndex -> AssocList.findKeyAtIndex winningIndex options)
                        |> Maybe.or (options |> AssocList.keys |> List.head)

                complete winner =
                    Bet.Complete { winner = winner }
            in
            maybeWinner |> Maybe.map complete |> Maybe.withDefault (Bet.Locked {})

        Cancelled ->
            Bet.Cancelled { reason = model.cancelReason }


update : Msg -> Model -> Model
update msg model =
    case msg of
        ChangeState state ->
            { model | state = state }

        ChangeLocksWhen locksWhen ->
            { model | locksWhen = locksWhen }

        ChangeWinner index ->
            { model | winner = Just index }

        ChangeCancelReason reason ->
            { model | cancelReason = reason }


viewMakeWinnerButton : (Msg -> msg) -> Int -> Model -> Maybe (Html msg)
viewMakeWinnerButton wrap index { state, winner } =
    if state == Complete then
        Switch.view
            (Html.span [ HtmlA.title "Winner" ] [ Icon.crown |> Icon.present |> Icon.view ])
            (Just index == winner)
            (index |> ChangeWinner |> wrap |> always |> Just)
            |> Just

    else
        Nothing


isEnabledFrom : State -> List (Maybe State)
isEnabledFrom state =
    case state of
        Suggestion ->
            [ Nothing
            , Just Suggestion
            ]

        Voting ->
            [ Nothing
            , Just Suggestion
            , Just Voting
            , Just Locked
            ]

        Locked ->
            [ Just Locked
            , Just Voting
            ]

        Complete ->
            [ Just Complete
            , Just Voting
            , Just Locked
            ]

        Cancelled ->
            [ Just Cancelled
            , Just Voting
            , Just Locked
            ]


view : (Msg -> msg) -> User.WithId -> Game.Id -> Maybe State -> AssocList.Dict Option.Id Option -> Model -> Html msg
view wrap localUser gameId sourceState options model =
    let
        stateSwitch icon name state =
            let
                enabled =
                    state |> isEnabledFrom |> List.member sourceState
            in
            Switch.view
                (Html.span [] [ icon |> Icon.present |> Icon.view, Html.text " ", Html.text name ])
                (model.state == state)
                (state |> ChangeState |> wrap |> always |> Maybe.when enabled)

        generalContent =
            if localUser |> Just |> Auth.isMod gameId then
                [ Html.div [ HtmlA.class "inline" ]
                    [ stateSwitch Icon.voteYea "Suggestion" Suggestion
                    , stateSwitch Icon.voteYea "Voting" Voting
                    , stateSwitch Icon.lock "Locked" Locked
                    , stateSwitch Icon.check "Complete" Complete
                    , stateSwitch Icon.check "Cancelled" Cancelled
                    ]
                ]

            else
                []

        specificContent =
            case model.state of
                Suggestion ->
                    [ TextField.viewWithAttrs "By"
                        TextField.Text
                        (model.by |> Maybe.withDefault localUser.id |> User.idToString)
                        Nothing
                        [ HtmlA.attribute "outlined" "" ]
                    ]

                Voting ->
                    [ TextField.viewWithAttrs "Lock Moment"
                        TextField.Text
                        model.locksWhen
                        (ChangeLocksWhen >> wrap |> Just)
                        [ HtmlA.attribute "outlined" "", HtmlA.required True ]
                    , Validator.view locksWhenValidator model
                    ]

                Locked ->
                    []

                Complete ->
                    [ Validator.view (winnerValidator options) model ]

                Cancelled ->
                    [ TextField.viewWithAttrs "Cancel Reason"
                        TextField.Text
                        model.cancelReason
                        (ChangeCancelReason >> wrap |> Just)
                        [ HtmlA.attribute "outlined" "", HtmlA.required True ]
                    , Validator.view cancelReasonValidator model
                    ]
    in
    Html.div [ HtmlA.class "progress-editor" ] (generalContent ++ specificContent)
