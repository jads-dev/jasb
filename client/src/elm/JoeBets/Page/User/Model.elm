module JoeBets.Page.User.Model exposing
    ( BankruptcyDialog
    , BankruptcyStats
    , Change(..)
    , Model
    , Msg(..)
    , PermissionsDialog
    , apply
    , bankruptcyStatsDecoder
    , initBankruptcyDialog
    , initPermissionsDialog
    )

import AssocList
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User exposing (User)
import JoeBets.User.Permission exposing (Permission)
import JoeBets.User.Permission.Selector.Model as Permission
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


type alias BankruptcyStats =
    { amountLost : Int
    , stakesLost : Int
    , lockedAmountLost : Int
    , lockedStakesLost : Int
    , balanceAfter : Int
    }


bankruptcyStatsDecoder : JsonD.Decoder BankruptcyStats
bankruptcyStatsDecoder =
    JsonD.succeed BankruptcyStats
        |> JsonD.required "amountLost" JsonD.int
        |> JsonD.required "stakesLost" JsonD.int
        |> JsonD.required "lockedAmountLost" JsonD.int
        |> JsonD.required "lockedStakesLost" JsonD.int
        |> JsonD.required "balanceAfter" JsonD.int


type alias BankruptcyDialog =
    { open : Bool
    , sureToggle : Bool
    , stats : Api.Data BankruptcyStats
    , action : Api.ActionState
    }


initBankruptcyDialog : BankruptcyDialog
initBankruptcyDialog =
    { open = False
    , sureToggle = False
    , stats = Api.initData
    , action = Api.initAction
    }


type alias PermissionsDialog =
    { open : Bool
    , selector : Permission.Selector
    }


initPermissionsDialog : PermissionsDialog
initPermissionsDialog =
    { open = False
    , selector = Permission.initSelector
    }


type alias Model =
    { user : Api.IdData User.Id User
    , bets : Api.IdData User.Id (AssocList.Dict Game.Id Game.WithBets)
    , bankruptcyDialog : BankruptcyDialog
    , permissionsDialog : PermissionsDialog
    }


type Msg
    = Load User.Id (Api.Response User.WithId)
    | TryLoadBets User.Id
    | LoadBets User.Id (Api.Response (AssocList.Dict Game.Id Game.WithBets))
    | ToggleBankruptcyDialog User.Id Bool
    | SetBankruptcyToggle Bool
    | LoadBankruptcyStats User.Id (Api.Response BankruptcyStats)
    | GoBankrupt User.Id (Maybe (Api.Response User.WithId))
    | TogglePermissionsDialog User.Id Bool
    | LoadPermissions User.Id (Api.Response (List Permission))
    | SetPermissions User.Id Permission Bool
    | SelectPermission User.Id Permission.SelectorMsg


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
