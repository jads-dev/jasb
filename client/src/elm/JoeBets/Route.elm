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
    | Auth (Maybe Auth.CodeAndState)
    | User (Maybe User.Id)
    | Bets Game.Id (Maybe Bets.Filters)
    | Bet Game.Id Bet.Id
    | Games
    | Leaderboard
    | Edit Edit.Target
    | UnknownPage String


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

                Auth _ ->
                    ( [ "auth" ], [], Nothing )

                User maybeId ->
                    ( "user" :: (maybeId |> Maybe.map User.idToString |> Maybe.toList), [], Nothing )

                Bets id filters ->
                    let
                        qs =
                            filters |> Maybe.withDefault Bets.initFilters |> Bets.filtersToQueries
                    in
                    ( [ "games", id |> Game.idToString ], qs, Nothing )

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

                        Edit.Bet gameId maybeBetId ->
                            case maybeBetId of
                                Just betId ->
                                    ( [ "games", gameId |> Game.idToString, betId |> Bet.idToString, "edit" ], [], Nothing )

                                Nothing ->
                                    ( [ "games", gameId |> Game.idToString, "new" ], [], Nothing )

                UnknownPage path ->
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
                , Parser.s "games" </> Game.idParser <?> Bets.filtersParser |> Parser.map Bets
                , Parser.s "games" </> Game.idParser </> Parser.s "new" |> Parser.map (\g -> Edit.Bet g Nothing |> Edit)
                , Parser.s "games" </> Game.idParser </> Parser.s "edit" |> Parser.map (Just >> Edit.Game >> Edit)
                , Parser.s "games" </> Game.idParser </> Bet.idParser |> Parser.map Bet
                , Parser.s "games" </> Game.idParser </> Bet.idParser </> Parser.s "edit" |> Parser.map (\g b -> Edit.Bet g (Just b) |> Edit)
                , Parser.s "leaderboard" |> Parser.map Leaderboard
                , Parser.s "auth" <?> Auth.codeAndStateParser |> Parser.map Auth
                , Parser.top |> Parser.map About
                ]
    in
    url |> Parser.parse parser |> Maybe.withDefault (UnknownPage url.path)


pushUrl : Navigation.Key -> Route -> Cmd msg
pushUrl navigationKey =
    toUrl >> Navigation.pushUrl navigationKey


replaceUrl : Navigation.Key -> Route -> Cmd msg
replaceUrl navigationKey =
    toUrl >> Navigation.replaceUrl navigationKey


a : Route -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
a route attrs =
    Html.a ((route |> toUrl |> HtmlA.href) :: attrs)
