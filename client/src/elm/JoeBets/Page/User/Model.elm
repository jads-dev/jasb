module JoeBets.Page.User.Model exposing
    ( BankruptcyOverlay
    , BankruptcyStats
    , Change(..)
    , GamePermissions
    , Model
    , Msg(..)
    , Permissions
    , PermissionsOverlay
    , UserModel
    , apply
    , decodeBankruptcyStats
    , decodeGamePermissions
    , decodePermissions
    )

import AssocList
import Http
import JoeBets.Game.Id as Game
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
    Maybe UserModel


type alias UserModel =
    { id : User.Id
    , user : RemoteData User
    , bets : RemoteData (AssocList.Dict Game.Id Game.WithBets)
    , bankruptcyOverlay : Maybe BankruptcyOverlay
    , permissionsOverlay : Maybe PermissionsOverlay
    }


type Msg
    = Load (Result Http.Error User.WithId)
    | TryLoadBets User.Id
    | LoadBets User.Id (Result Http.Error (AssocList.Dict Game.Id Game.WithBets))
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
