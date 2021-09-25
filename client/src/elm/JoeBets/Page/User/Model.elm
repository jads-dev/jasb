module JoeBets.Page.User.Model exposing
    ( BankruptcyOverlay
    , BankruptcyStats
    , Change(..)
    , GamePermissions
    , Model
    , Msg(..)
    , Permissions
    , PermissionsOverlay
    , apply
    , decodeBankruptcyStats
    , decodeGamePermissions
    , decodePermissions
    , decodeUserBet
    )

import AssocList
import Http
import JoeBets.Bet.Model as Bet exposing (Bet)
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User exposing (User)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.RemoteData exposing (RemoteData)


type alias Permissions =
    { canManageBets : Bool
    }


decodePermissions : JsonD.Decoder Permissions
decodePermissions =
    JsonD.succeed Permissions
        |> JsonD.required "canManageBets" JsonD.bool


type alias GamePermissions =
    { gameId : Game.Id
    , gameName : String
    , permissions : Permissions
    }


decodeGamePermissions : JsonD.Decoder GamePermissions
decodeGamePermissions =
    JsonD.succeed GamePermissions
        |> JsonD.required "gameId" Game.idDecoder
        |> JsonD.required "gameName" JsonD.string
        |> JsonD.custom decodePermissions


type alias UserBet =
    { gameId : Game.Id
    , gameName : String
    , betId : Bet.Id
    , bet : Bet
    }


decodeUserBet : JsonD.Decoder UserBet
decodeUserBet =
    JsonD.succeed UserBet
        |> JsonD.required "gameId" Game.idDecoder
        |> JsonD.required "gameName" JsonD.string
        |> JsonD.required "id" Bet.idDecoder
        |> JsonD.required "bet" Bet.decoder


type alias BankruptcyStats =
    { amountLost : Int
    , stakesLost : Int
    , lockedAmountLost : Int
    , lockedStakesLost : Int
    , balanceAfter : Int
    }


decodeBankruptcyStats : JsonD.Decoder BankruptcyStats
decodeBankruptcyStats =
    JsonD.succeed BankruptcyStats
        |> JsonD.required "amountLost" JsonD.int
        |> JsonD.required "stakesLost" JsonD.int
        |> JsonD.required "lockedAmountLost" JsonD.int
        |> JsonD.required "lockedStakesLost" JsonD.int
        |> JsonD.required "balanceAfter" JsonD.int


type alias BankruptcyOverlay =
    { sureToggle : Bool
    , stats : RemoteData BankruptcyStats
    }


type alias PermissionsOverlay =
    { permissions : RemoteData (AssocList.Dict Game.Id GamePermissions) }


type alias Model =
    { id : Maybe User.Id
    , user : RemoteData User
    , bets : RemoteData (List UserBet)
    , bankruptcyOverlay : Maybe BankruptcyOverlay
    , permissionsOverlay : Maybe PermissionsOverlay
    }


type Msg
    = Load (Result Http.Error User.WithId)
    | LoadBets User.Id (Result Http.Error (List UserBet))
    | ToggleBankruptcyOverlay Bool
    | SetBankruptcyToggle Bool
    | LoadBankruptcyStats User.Id (Result Http.Error BankruptcyStats)
    | GoBankrupt
    | TogglePermissionsOverlay Bool
    | LoadPermissions User.Id (Result Http.Error (List GamePermissions))
    | SetPermissions User.Id Game.Id Permissions
    | NoOp


type Change
    = Replace User
    | ChangeBalance Int


apply : Change -> User -> User
apply change user =
    case change of
        Replace newUser ->
            newUser

        ChangeBalance newBalance ->
            { user | balance = newBalance }
