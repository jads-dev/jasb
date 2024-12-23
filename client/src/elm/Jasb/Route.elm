module Jasb.Route exposing
    ( Route(..)
    , a
    , decoder
    , encode
    , fromUrl
    , pushUrl
    , replaceUrl
    , toUrl
    )

import Browser.Navigation as Browser
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Bet.Model as Bet
import Jasb.Game.Id as Game
import Jasb.Page.Bets.Model as Bets
import Jasb.Page.Edit.Model as Edit
import Jasb.Page.Gacha.Collection.Route as Collection
import Jasb.Page.Gacha.Route as Gacha
import Jasb.Page.Leaderboard.Route as Leaderboard
import Jasb.User.Auth.Route as Auth
import Jasb.User.Model as User
import Json.Decode as JsonD
import Json.Encode as JsonE
import Url exposing (Url)
import Url.Builder
import Url.Parser as Parser exposing ((</>), (<?>))
import Util.Maybe as Maybe


type Route
    = About
    | Feed
    | Auth (Maybe Auth.CodeAndState)
    | User (Maybe User.Id)
    | CardCollection User.Id Collection.Route
    | Bets Bets.Subset Game.Id
    | Bet Game.Id Bet.Id
    | Games
    | Leaderboard Leaderboard.Board
    | Gacha Gacha.Route
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
                    ( "user"
                        :: (maybeId |> Maybe.map User.idToString |> Maybe.toList)
                    , []
                    , Nothing
                    )

                CardCollection userId collectionRoute ->
                    ( "user"
                        :: User.idToString userId
                        :: "cards"
                        :: Collection.routeToListOfStrings collectionRoute
                    , []
                    , Nothing
                    )

                Bets subset id ->
                    let
                        end =
                            case subset of
                                Bets.Active ->
                                    []

                                Bets.Suggestions ->
                                    [ "suggestions" ]
                    in
                    ( "games" :: Game.idToString id :: end, [], Nothing )

                Bet gameId betId ->
                    ( [ "games", gameId |> Game.idToString, betId |> Bet.idToString ], [], Nothing )

                Games ->
                    ( [ "games" ], [], Nothing )

                Leaderboard board ->
                    ( "leaderboard" :: Leaderboard.boardToListOfStrings board
                    , []
                    , Nothing
                    )

                Gacha gacha ->
                    ( "cards" :: Gacha.routeToListOfStrings gacha
                    , []
                    , Nothing
                    )

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
                    let
                        splitPath =
                            case path |> String.split "/" of
                                "" :: rest ->
                                    rest

                                otherwise ->
                                    otherwise
                    in
                    ( splitPath, [], Nothing )
    in
    Url.Builder.custom root parts queries fragment


fromUrl : Url -> Route
fromUrl url =
    let
        parser =
            Parser.oneOf
                [ Parser.s "user" </> User.idParser |> Parser.map (Just >> User)
                , Parser.s "user" </> User.idParser </> Parser.s "cards" </> Collection.routeParser |> Parser.map CardCollection
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
                , Parser.s "leaderboard" </> Leaderboard.boardParser |> Parser.map Leaderboard
                , Parser.s "feed" |> Parser.map Feed
                , Parser.s "cards" </> Gacha.routeParser |> Parser.map Gacha
                , Parser.s "auth" <?> Auth.codeAndStateParser |> Parser.map Auth
                , Parser.top |> Parser.map About
                ]
    in
    url |> Parser.parse parser |> Maybe.withDefault (Problem url.path)


pushUrl : Browser.Key -> Route -> Cmd msg
pushUrl navigationKey =
    toUrl >> Browser.pushUrl navigationKey


replaceUrl : Browser.Key -> Route -> Cmd msg
replaceUrl navigationKey =
    toUrl >> Browser.replaceUrl navigationKey


a : Route -> List (Html.Attribute msg) -> List (Html msg) -> Html msg
a route attrs =
    Html.a ((route |> toUrl |> HtmlA.href) :: attrs)


decoder : JsonD.Decoder Route
decoder =
    let
        addFakeOrigin absolute =
            "https://example.com" ++ absolute

        ifUrl maybeUrl =
            case maybeUrl of
                Just url ->
                    url |> fromUrl |> JsonD.succeed

                Nothing ->
                    JsonD.fail "Not a valid URL."
    in
    JsonD.string |> JsonD.andThen (addFakeOrigin >> Url.fromString >> ifUrl)


encode : Route -> JsonE.Value
encode =
    toUrl >> JsonE.string
