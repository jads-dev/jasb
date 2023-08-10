module JoeBets.Feed.Model exposing
    ( BetComplete
    , Event(..)
    , IdAndName
    , Model
    , Msg(..)
    , NewBet
    , NotableStake
    , decoder
    , relevantGame
    )

import JoeBets.Api.Data as Api
import JoeBets.Api.Model as Api
import JoeBets.Bet.Model as Bet
import JoeBets.Bet.Option as Option
import JoeBets.Game.Id as Game
import JoeBets.User.Model as User
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


type alias IdAndName id =
    { id : id
    , name : String
    }


idAndNameDecoder : JsonD.Decoder a -> JsonD.Decoder (IdAndName a)
idAndNameDecoder idDecoder =
    JsonD.map2 IdAndName
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 JsonD.string)


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
    { winners : List User.SummaryWithId
    , amount : Int
    }


highlightedDecoder : JsonD.Decoder Highlighted
highlightedDecoder =
    JsonD.succeed Highlighted
        |> JsonD.required "winners" (JsonD.list User.summaryWithIdDecoder)
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
    , user : User.SummaryWithId
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
        |> JsonD.required "user" User.summaryWithIdDecoder
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
    = Load (Api.Response (List Item))
    | RevealSpoilers Int
    | SetFavouritesOnly Bool


type alias Model =
    { items : Api.Data (List Item)
    , favouritesOnly : Bool
    }


decoder : JsonD.Decoder (List Item)
decoder =
    let
        toItem index event =
            Item index event False
    in
    JsonD.list eventDecoder |> JsonD.map (List.indexedMap toItem)
