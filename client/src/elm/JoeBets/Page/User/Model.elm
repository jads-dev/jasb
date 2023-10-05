module JoeBets.Page.User.Model exposing
    ( BankruptcyOverlay
    , BankruptcyStats
    , Change(..)
    , Model
    , Msg(..)
    , PermissionsOverlay
    , apply
    , bankruptcyStatsDecoder
    )

import AssocList
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User exposing (User)
import JoeBets.User.Permission as Permission exposing (Permission)
import JoeBets.User.Permission.Selector.Model as Permission
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Util.Json.Decode as JsonD


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


type alias BankruptcyOverlay =
    { sureToggle : Bool
    , stats : Api.Data BankruptcyStats
    , action : Api.ActionState
    }


type alias PermissionsOverlay =
    { selector : Permission.Selector }


type alias Model =
    { user : Api.IdData User.Id User
    , bets : Api.IdData User.Id (AssocList.Dict Game.Id Game.WithBets)
    , bankruptcyOverlay : Maybe BankruptcyOverlay
    , permissionsOverlay : Maybe PermissionsOverlay
    }


type Msg
    = Load User.Id (Api.Response User.WithId)
    | TryLoadBets User.Id
    | LoadBets User.Id (Api.Response (AssocList.Dict Game.Id Game.WithBets))
    | ToggleBankruptcyOverlay User.Id Bool
    | SetBankruptcyToggle Bool
    | LoadBankruptcyStats User.Id (Api.Response BankruptcyStats)
    | GoBankrupt User.Id (Maybe (Api.Response User.WithId))
    | TogglePermissionsOverlay User.Id Bool
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
