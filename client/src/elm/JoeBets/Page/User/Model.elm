module JoeBets.Page.User.Model exposing
    ( BankruptcyOverlay
    , BankruptcyStats
    , Change(..)
    , GamePermissions
    , Model
    , Msg(..)
    , PerGamePermissions
    , PermissionsOverlay
    , SetPermission(..)
    , apply
    , bankruptcyStatsDecoder
    , editablePermissionsDecoder
    , encodeSetPermissions
    , gamePermissionsDecoder
    , permissionsDecoder
    )

import AssocList
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User exposing (User)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Util.Json.Decode as JsonD


type alias PerGamePermissions =
    { manageBets : Bool
    }


permissionsDecoder : JsonD.Decoder PerGamePermissions
permissionsDecoder =
    JsonD.succeed PerGamePermissions
        |> JsonD.required "manageBets" JsonD.bool


type alias GamePermissions =
    { gameId : Game.Id
    , gameName : String
    , permissions : PerGamePermissions
    }


gamePermissionsDecoder : JsonD.Decoder GamePermissions
gamePermissionsDecoder =
    JsonD.succeed GamePermissions
        |> JsonD.required "gameId" Game.idDecoder
        |> JsonD.required "gameName" JsonD.string
        |> JsonD.custom permissionsDecoder


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


type alias EditablePermissions =
    { manageGames : Bool
    , managePermissions : Bool
    , manageGacha : Bool
    , manageBets : Bool
    , gameSpecific : AssocList.Dict Game.Id GamePermissions
    }


editablePermissionsDecoder : JsonD.Decoder EditablePermissions
editablePermissionsDecoder =
    JsonD.succeed EditablePermissions
        |> JsonD.required "manageGames" JsonD.bool
        |> JsonD.required "managePermissions" JsonD.bool
        |> JsonD.required "manageGacha" JsonD.bool
        |> JsonD.required "manageBets" JsonD.bool
        |> JsonD.required "gameSpecific" (JsonD.assocListFromList (JsonD.field "gameId" Game.idDecoder) gamePermissionsDecoder)


type SetPermission
    = ManageGames Bool
    | ManagePermissions Bool
    | ManageGacha Bool
    | ManageBets (Maybe Game.Id) Bool


encodeSetPermissions : SetPermission -> JsonE.Value
encodeSetPermissions setPermissions =
    case setPermissions of
        ManageGames v ->
            JsonE.object [ ( "manageGames", JsonE.bool v ) ]

        ManagePermissions v ->
            JsonE.object [ ( "managePermissions", JsonE.bool v ) ]

        ManageGacha v ->
            JsonE.object [ ( "manageGacha", JsonE.bool v ) ]

        ManageBets Nothing v ->
            JsonE.object [ ( "manageBets", JsonE.bool v ) ]

        ManageBets (Just gameId) v ->
            JsonE.object
                [ ( "game", Game.encodeId gameId )
                , ( "manageBets", JsonE.bool v )
                ]


type alias PermissionsOverlay =
    { permissions : Api.Data EditablePermissions }


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
    | LoadPermissions User.Id (Api.Response EditablePermissions)
    | SetPermissions User.Id SetPermission
    | NoOp String


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
