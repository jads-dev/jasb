module JoeBets.Page.Feed.Model exposing
    ( BetComplete
    , Event(..)
    , IdAndName
    , Model
    , Msg(..)
    , NewBet
    , NotableStake
    , UserInfo
    , decoder
    , relevantGame
    )

import JoeBets.Bet.Model as Bet
import JoeBets.Bet.Option as Option
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD
import Util.RemoteData as RemoteData exposing (RemoteData)


type alias IdAndName id =
    { id : id
    , name : String
    }


idAndNameDecoder : JsonD.Decoder a -> JsonD.Decoder (IdAndName a)
idAndNameDecoder idDecoder =
    JsonD.succeed IdAndName
        |> JsonD.required "id" idDecoder
        |> JsonD.required "name" JsonD.string


type alias UserInfo =
    { id : User.Id
    , name : String
    , discriminator : Maybe String
    , avatar : Maybe String
    , avatarCache : Maybe String
    }


userInfoDecoder : JsonD.Decoder UserInfo
userInfoDecoder =
    JsonD.succeed UserInfo
        |> JsonD.required "id" User.idDecoder
        |> JsonD.required "name" JsonD.string
        |> JsonD.optionalAsMaybe "discriminator" JsonD.string
        |> JsonD.optionalAsMaybe "avatar" JsonD.string
        |> JsonD.optionalAsMaybe "avatarCache" JsonD.string


type alias NewBet =
    { game : IdAndName Game.Id
    , bet : IdAndName Bet.Id
    , spoiler : Bool
    }


newBetDecoder : JsonD.Decoder NewBet
newBetDecoder =
    JsonD.succeed NewBet
        |> JsonD.required "game" (idAndNameDecoder Game.idDecoder)
        |> JsonD.required "bet" (idAndNameDecoder Bet.idDecoder)
        |> JsonD.optional "spoiler" JsonD.bool False


type alias Highlighted =
    { winners : List UserInfo
    , amount : Int
    }


highlightedDecoder : JsonD.Decoder Highlighted
highlightedDecoder =
    JsonD.succeed Highlighted
        |> JsonD.required "winners" (JsonD.list userInfoDecoder)
        |> JsonD.required "amount" JsonD.int


type alias BetComplete =
    { game : IdAndName Game.Id
    , bet : IdAndName Bet.Id
    , spoiler : Bool
    , winners : List (IdAndName Option.Id)
    , highlighted : Highlighted
    , totalReturn : Int
    , winningBets : Int
    }


betCompleteDecoder : JsonD.Decoder BetComplete
betCompleteDecoder =
    JsonD.succeed BetComplete
        |> JsonD.required "game" (idAndNameDecoder Game.idDecoder)
        |> JsonD.required "bet" (idAndNameDecoder Bet.idDecoder)
        |> JsonD.optional "spoiler" JsonD.bool False
        |> JsonD.required "winners" (idAndNameDecoder Option.idDecoder |> JsonD.list)
        |> JsonD.required "highlighted" highlightedDecoder
        |> JsonD.required "totalReturn" JsonD.int
        |> JsonD.required "winningBets" JsonD.int


type alias NotableStake =
    { game : IdAndName Game.Id
    , bet : IdAndName Bet.Id
    , spoiler : Bool
    , option : IdAndName Option.Id
    , user : UserInfo
    , message : String
    , stake : Int
    }


notableStakeDecoder : JsonD.Decoder NotableStake
notableStakeDecoder =
    JsonD.succeed NotableStake
        |> JsonD.required "game" (idAndNameDecoder Game.idDecoder)
        |> JsonD.required "bet" (idAndNameDecoder Bet.idDecoder)
        |> JsonD.optional "spoiler" JsonD.bool False
        |> JsonD.required "option" (idAndNameDecoder Option.idDecoder)
        |> JsonD.required "user" userInfoDecoder
        |> JsonD.required "message" JsonD.string
        |> JsonD.required "stake" JsonD.int


type Event
    = NB NewBet
    | BC BetComplete
    | NS NotableStake


eventDecoder : JsonD.Decoder Event
eventDecoder =
    let
        byType type_ =
            case type_ of
                "NewBet" ->
                    newBetDecoder |> JsonD.map NB

                "BetComplete" ->
                    betCompleteDecoder |> JsonD.map BC

                "NotableStake" ->
                    notableStakeDecoder |> JsonD.map NS

                _ ->
                    JsonD.unknownValue "feed event" type_
    in
    JsonD.field "type" JsonD.string |> JsonD.andThen byType


relevantGame : Event -> Maybe Game.Id
relevantGame event =
    case event of
        NB { game } ->
            Just game.id

        BC { game } ->
            Just game.id

        NS { game } ->
            Just game.id


type alias Item =
    { index : Int
    , event : Event
    , spoilerRevealed : Bool
    }


type Msg
    = Load (RemoteData.Response (List Item))
    | RevealSpoilers Int
    | SetFavouritesOnly Bool


type alias Model =
    { items : RemoteData (List Item)
    , favouritesOnly : Bool
    }


decoder : JsonD.Decoder (List Item)
decoder =
    let
        toItem index event =
            Item index event False
    in
    JsonD.list eventDecoder |> JsonD.map (List.indexedMap toItem)
