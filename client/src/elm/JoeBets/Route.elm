module JoeBets.Route exposing
    ( Route(..)
    , a
    , fromUrl
    , pushUrl
    , replaceUrl
    , toUrl
    )

import Browser.Navigation as Navigation
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Bet.Model as Bet
import JoeBets.Game.Model as Game
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Model as Edit
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Url exposing (Url)
import Url.Builder
import Url.Parser as Parser exposing ((</>), (<?>))
import Util.Maybe as Maybe


type Route
    = About
    | Feed
    | Auth (Maybe Auth.CodeAndState)
    | User (Maybe User.Id)
    | Bets Bets.Subset Game.Id
    | Bet Game.Id Bet.Id
    | Games
    | Leaderboard
    | Edit Edit.Target
    | Problem String


toUrl : Route -> String
toUrl =
    toUrlWithGivenRoot Url.Builder.Absolute


toUrlWithGivenRoot : Url.Builder.Root -> Route -> String
toUrlWithGivenRoot root route =
    let
        ( parts, queries, fragment ) =
            case route of
                About ->
                    ( [], [], Nothing )

                Feed ->
                    ( [ "feed" ], [], Nothing )

                Auth _ ->
                    ( [ "auth" ], [], Nothing )

                User maybeId ->
                    ( "user" :: (maybeId |> Maybe.map User.idToString |> Maybe.toList), [], Nothing )

                Bets subset id ->
                    let
                        end =
                            case subset of
                                Bets.Active ->
                                    []

                                Bets.Suggestions ->
                                    [ "suggestions" ]
                    in
                    ( [ "games", id |> Game.idToString ] ++ end, [], Nothing )

                Bet gameId betId ->
                    ( [ "games", gameId |> Game.idToString, betId |> Bet.idToString ], [], Nothing )

                Games ->
                    ( [ "games" ], [], Nothing )

                Leaderboard ->
                    ( [ "leaderboard" ], [], Nothing )

                Edit target ->
                    case target of
                        Edit.Game maybeId ->
                            case maybeId of
                                Just id ->
                                    ( [ "games", id |> Game.idToString, "edit" ], [], Nothing )

                                Nothing ->
                                    ( [ "games", "new" ], [], Nothing )

                        Edit.Bet gameId editMode ->
                            case editMode of
                                Edit.New ->
                                    ( [ "games", gameId |> Game.idToString, "new" ], [], Nothing )

                                Edit.Suggest ->
                                    ( [ "games", gameId |> Game.idToString, "suggest" ], [], Nothing )

                                Edit.Edit betId ->
                                    ( [ "games", gameId |> Game.idToString, betId |> Bet.idToString, "edit" ], [], Nothing )

                Problem path ->
                    ( path |> String.split "/", [], Nothing )
    in
    Url.Builder.custom root parts queries fragment


fromUrl : Url -> Route
fromUrl url =
    let
        parser =
            Parser.oneOf
                [ Parser.s "user" </> User.idParser |> Parser.map (Just >> User)
                , Parser.s "user" |> Parser.map (Nothing |> User)
                , Parser.s "games" |> Parser.map Games
                , Parser.s "games" </> Parser.s "new" |> Parser.map (Nothing |> Edit.Game >> Edit)
                , Parser.s "games" </> Game.idParser |> Parser.map (Bets Bets.Active)
                , Parser.s "games" </> Game.idParser </> Parser.s "suggest" |> Parser.map (\g -> Edit.Bet g Edit.Suggest |> Edit)
                , Parser.s "games" </> Game.idParser </> Parser.s "suggestions" |> Parser.map (Bets Bets.Suggestions)
                , Parser.s "games" </> Game.idParser </> Parser.s "new" |> Parser.map (\g -> Edit.Bet g Edit.New |> Edit)
                , Parser.s "games" </> Game.idParser </> Parser.s "edit" |> Parser.map (Just >> Edit.Game >> Edit)
                , Parser.s "games" </> Game.idParser </> Bet.idParser |> Parser.map Bet
                , Parser.s "games" </> Game.idParser </> Bet.idParser </> Parser.s "edit" |> Parser.map (\g b -> Edit.Bet g (Edit.Edit b) |> Edit)
                , Parser.s "leaderboard" |> Parser.map Leaderboard
                , Parser.s "feed" |> Parser.map Feed
                , Parser.s "auth" <?> Auth.codeAndStateParser |> Parser.map Auth
                , Parser.top |> Parser.map About
                ]
    in
    url |> Parser.parse parser |> Maybe.withDefault (Problem url.path)


pushUrl : Navigation.Key -> Route -> Cmd msg
pushUrl navigationKey =
    toUrl >> Navigation.pushUrl navigationKey


replaceUrl : Navigation.Key -> Route -> Cmd msg
replaceUrl navigationKey =
    toUrl >> Navigation.replaceUrl navigationKey


a : Route -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
a route attrs =
    Html.a ((route |> toUrl |> HtmlA.href) :: attrs)
