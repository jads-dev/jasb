module Jasb.Api exposing
    ( BodyRequest
    , Request
    , delete
    , get
    , post
    , postFile
    , put
    , relativeUrl
    , request
    )

import Http
import Jasb.Api.Error as Error
import Jasb.Api.Model exposing (..)
import Jasb.Api.Path exposing (..)
import Jasb.Bet.Model as Bets
import Jasb.Bet.Option as Option
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card
import Jasb.Gacha.CardType as CardType
import Jasb.Game.Id as Game
import Jasb.Page.Leaderboard.Route as Leaderboard
import Jasb.User.Model as User
import Jasb.User.Notifications.Model as Notifications
import Json.Decode as JsonD
import Json.Encode as JsonE
import Url.Builder
import Util.Maybe as Maybe


type alias GeneralRequest value msg =
    { method : String
    , path : Path
    , body : Http.Body
    , decoder : JsonD.Decoder value
    , wrap : Response value -> msg
    }


type alias Request value msg =
    { path : Path
    , decoder : JsonD.Decoder value
    , wrap : Response value -> msg
    }


type alias BodyRequest value msg =
    { path : Path
    , body : JsonE.Value
    , decoder : JsonD.Decoder value
    , wrap : Response value -> msg
    }


type alias FileBodyRequest value msg =
    { path : Path
    , body : List Http.Part
    , decoder : JsonD.Decoder value
    , wrap : Response value -> msg
    }


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
        User ->
            []

        Notifications maybeId ->
            "notifications"
                :: (maybeId
                        |> Maybe.map (Notifications.idToInt >> String.fromInt)
                        |> Maybe.toList
                   )

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

        LockMoments ->
            [ "lock" ]

        LockStatus ->
            [ "lock", "status" ]

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

        RevertComplete ->
            [ "complete", "revert" ]

        Lock ->
            [ "lock" ]

        Unlock ->
            [ "unlock" ]

        Cancel ->
            [ "cancel" ]

        RevertCancel ->
            [ "cancel", "revert" ]

        BetFeed ->
            [ "feed" ]

        Option id optionPath ->
            "options" :: Option.idToString id :: optionPathToStringList optionPath


optionPathToStringList : OptionPath -> List String
optionPathToStringList path =
    case path of
        Stake ->
            [ "stake" ]


bannerPathToStringList : BannerPath -> List String
bannerPathToStringList path =
    case path of
        Banner ->
            []

        Roll ->
            [ "roll" ]

        EditableCardTypes ->
            [ "card-types", "edit" ]

        CardTypesWithCards ->
            [ "card-types" ]

        DetailedCardType cardTypeId ->
            [ "card-types", cardTypeId |> CardType.idToInt |> String.fromInt ]

        GiftCardType cardTypeId ->
            [ "card-types", cardTypeId |> CardType.idToInt |> String.fromInt, "gift" ]


bannersPathToStringList : BannersPath -> List String
bannersPathToStringList path =
    case path of
        BannersRoot ->
            []

        BannerCoverUpload ->
            [ "cover" ]

        EditableBanners ->
            [ "edit" ]

        SpecificBanner bannerId bannerPath ->
            Banner.idToString bannerId :: bannerPathToStringList bannerPath


cardPathToStringList : CardPath -> List String
cardPathToStringList path =
    case path of
        Card ->
            []

        RecycleValue ->
            [ "value" ]

        Highlight ->
            [ "highlight" ]


userCardsPathToStringList : UserCardsPath -> List String
userCardsPathToStringList path =
    case path of
        UserCardsOverview ->
            []

        AllUserCards ->
            [ "all" ]

        UserCardsInBanner bannerId ->
            [ "banners", Banner.idToString bannerId ]


cardsPathToStringList : CardsPath -> List String
cardsPathToStringList path =
    case path of
        UserCards userCardsPath ->
            userCardsPathToStringList userCardsPath

        ForgedCardTypes ->
            [ "forged" ]

        ForgeCardType ->
            [ "forge" ]

        RetireForged cardTypeId ->
            [ "forged"
            , cardTypeId |> CardType.idToInt |> String.fromInt
            , "retire"
            ]

        SpecificCard bannerId cardId cardPath ->
            "banners"
                :: Banner.idToString bannerId
                :: (cardId |> Card.idToInt |> String.fromInt)
                :: cardPathToStringList cardPath

        Highlights ->
            [ "highlights" ]


gachaPathToStringList : GachaPath -> List String
gachaPathToStringList path =
    case path of
        Cards userId cardPath ->
            "cards" :: User.idToString userId :: cardsPathToStringList cardPath

        CardImageUpload ->
            [ "cards", "image" ]

        Balance ->
            [ "balance" ]

        Banners bannersPath ->
            "banners" :: bannersPathToStringList bannersPath

        Context ->
            [ "context" ]


pathToStringList : Path -> List String
pathToStringList path =
    case path of
        Auth authPath ->
            "auth" :: authPathToStringList authPath

        Users ->
            [ "users" ]

        SpecificUser id usersPath ->
            "users" :: User.idToString id :: userPathToStringList usersPath

        UserSearch _ ->
            [ "users", "search" ]

        Games ->
            [ "games" ]

        GameSearch _ ->
            [ "games", "search" ]

        GameCoverUpload ->
            [ "games", "cover" ]

        BetOptionImageUpload ->
            [ "games", "options", "image" ]

        Game id gamesPath ->
            "games" :: Game.idToString id :: gamePathToStringList gamesPath

        Leaderboard board ->
            "leaderboard" :: Leaderboard.boardToListOfStrings board

        Feed ->
            [ "feed" ]

        Gacha gachaPath ->
            "gacha" :: gachaPathToStringList gachaPath


pathToQueryList : Path -> List Url.Builder.QueryParameter
pathToQueryList path =
    case path of
        UserSearch query ->
            [ Url.Builder.string "q" query ]

        GameSearch query ->
            [ Url.Builder.string "q" query ]

        _ ->
            []


url : String -> Path -> String
url base path =
    Url.Builder.crossOrigin
        base
        ("api" :: pathToStringList path)
        (pathToQueryList path)


relativeUrl : Path -> String
relativeUrl path =
    Url.Builder.relative
        ("api" :: pathToStringList path)
        (pathToQueryList path)


request : String -> GeneralRequest value msg -> Cmd msg
request base { method, path, body, wrap, decoder } =
    Http.riskyRequest
        { method = method
        , headers = []
        , url = url base path
        , body = body
        , expect = Error.expectJsonOrError method wrap decoder
        , timeout = Nothing
        , tracker = Nothing
        }


get : String -> Request value msg -> Cmd msg
get base { path, decoder, wrap } =
    request base
        { method = "GET"
        , path = path
        , body = Http.emptyBody
        , wrap = wrap
        , decoder = decoder
        }


post : String -> BodyRequest value msg -> Cmd msg
post base { path, body, decoder, wrap } =
    request base
        { method = "POST"
        , path = path
        , body = Http.jsonBody body
        , wrap = wrap
        , decoder = decoder
        }


put : String -> BodyRequest value msg -> Cmd msg
put base { path, body, decoder, wrap } =
    request base
        { method = "PUT"
        , path = path
        , body = Http.jsonBody body
        , wrap = wrap
        , decoder = decoder
        }


delete : String -> Request value msg -> Cmd msg
delete base { path, decoder, wrap } =
    request base
        { method = "DELETE"
        , path = path
        , body = Http.emptyBody
        , wrap = wrap
        , decoder = decoder
        }


postFile : String -> FileBodyRequest value msg -> Cmd msg
postFile base { path, body, decoder, wrap } =
    request base
        { method = "POST"
        , path = path
        , body = body |> Http.multipartBody
        , wrap = wrap
        , decoder = decoder
        }
