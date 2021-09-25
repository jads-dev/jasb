module JoeBets.Api exposing
    ( AuthPath(..)
    , BetPath(..)
    , GamePath(..)
    , OptionPath(..)
    , Path(..)
    , UserPath(..)
    , delete
    , get
    , post
    , put
    , request
    )

import Http
import JoeBets.Bet.Model as Bets
import JoeBets.Bet.Option as Option
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User
import Url.Builder
import Util.Maybe as Maybe


type AuthPath
    = Login
    | Logout


type UserPath
    = UserRoot
    | Notifications (Maybe Int)
    | UserBets
    | Bankrupt
    | Permissions


type BetPath
    = BetRoot
    | Edit
    | Complete
    | Lock
    | Unlock
    | Cancel
    | BetFeed
    | Option Option.Id OptionPath


type OptionPath
    = Stake


type GamePath
    = GameRoot
    | Bets
    | Bet Bets.Id BetPath
    | Suggestions


type Path
    = Auth AuthPath
    | Users
    | User User.Id UserPath
    | Games
    | Game Game.Id GamePath
    | Leaderboard
    | Feed
    | Upload


get : String -> { path : Path, expect : Http.Expect msg } -> Cmd msg
get origin { path, expect } =
    request origin "GET" { path = path, body = Http.emptyBody, expect = expect }


post : String -> { path : Path, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
post origin =
    request origin "POST"


put : String -> { path : Path, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
put origin =
    request origin "PUT"


delete : String -> { path : Path, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
delete origin =
    request origin "DELETE"


request : String -> String -> { path : Path, body : Http.Body, expect : Http.Expect msg } -> Cmd msg
request origin method { path, body, expect } =
    Http.riskyRequest
        { method = method
        , headers = []
        , url = url origin path
        , body = body
        , expect = expect
        , timeout = Nothing
        , tracker = Nothing
        }


url : String -> Path -> String
url origin path =
    let
        stringPath =
            pathToStringList path
    in
    if origin |> String.startsWith "localhost" then
        Url.Builder.crossOrigin "http://localhost:8081" ("api" :: stringPath) []

    else
        Url.Builder.crossOrigin "https://jasb.900000000.xyz" ("api" :: stringPath) []


pathToStringList : Path -> List String
pathToStringList path =
    case path of
        Auth authPath ->
            "auth" :: authPathToStringList authPath

        Users ->
            [ "users" ]

        User id usersPath ->
            "users" :: User.idToString id :: userPathToStringList usersPath

        Games ->
            [ "games" ]

        Game id gamesPath ->
            "games" :: Game.idToString id :: gamePathToStringList gamesPath

        Leaderboard ->
            [ "leaderboard" ]

        Feed ->
            [ "feed" ]

        Upload ->
            [ "upload" ]


authPathToStringList : AuthPath -> List String
authPathToStringList path =
    case path of
        Login ->
            [ "login" ]

        Logout ->
            [ "logout" ]


userPathToStringList : UserPath -> List String
userPathToStringList path =
    case path of
        UserRoot ->
            []

        Notifications maybeInt ->
            "notifications" :: (maybeInt |> Maybe.map String.fromInt |> Maybe.toList)

        UserBets ->
            [ "bets" ]

        Bankrupt ->
            [ "bankrupt" ]

        Permissions ->
            [ "permissions" ]


gamePathToStringList : GamePath -> List String
gamePathToStringList path =
    case path of
        GameRoot ->
            []

        Bets ->
            [ "bets" ]

        Bet id betPath ->
            "bets" :: Bets.idToString id :: betPathToStringList betPath

        Suggestions ->
            [ "suggestions" ]


betPathToStringList : BetPath -> List String
betPathToStringList path =
    case path of
        BetRoot ->
            []

        Edit ->
            [ "edit" ]

        Complete ->
            [ "complete" ]

        Lock ->
            [ "lock" ]

        Unlock ->
            [ "unlock" ]

        Cancel ->
            [ "cancel" ]

        BetFeed ->
            [ "feed" ]

        Option id optionPath ->
            "options" :: Option.idToString id :: optionPathToStringList optionPath


optionPathToStringList : OptionPath -> List String
optionPathToStringList path =
    case path of
        Stake ->
            [ "stake" ]
