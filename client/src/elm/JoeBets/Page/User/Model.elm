module JoeBets.Page.User.Model exposing
    ( BankruptcyOverlay
    , BankruptcyStats
    , Change(..)
    , GamePermissions
    , Model
    , Msg(..)
    , Permissions
    , PermissionsOverlay
    , SetPermission(..)
    , UserModel
    , apply
    , bankruptcyStatsDecoder
    , editablePermissionsDecoder
    , encodeSetPermissions
    , gamePermissionsDecoder
    , permissionsDecoder
    )

import AssocList
import Http
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User exposing (User)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Util.AssocList as AssocList
import Util.Json.Decode as JsonD
import Util.RemoteData exposing (RemoteData)


type alias Permissions =
    { canManageBets : Bool
    }


permissionsDecoder : JsonD.Decoder Permissions
permissionsDecoder =
    JsonD.succeed Permissions
        |> JsonD.required "canManageBets" JsonD.bool


type alias GamePermissions =
    { gameId : Game.Id
    , gameName : String
    , permissions : Permissions
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
    , stats : RemoteData BankruptcyStats
    }


type alias EditablePermissions =
    { manageGames : Bool
    , managePermissions : Bool
    , manageBets : Bool
    , gameSpecific : AssocList.Dict Game.Id GamePermissions
    }


editablePermissionsDecoder : JsonD.Decoder EditablePermissions
editablePermissionsDecoder =
    JsonD.succeed EditablePermissions
        |> JsonD.required "manageGames" JsonD.bool
        |> JsonD.required "managePermissions" JsonD.bool
        |> JsonD.required "manageBets" JsonD.bool
        |> JsonD.required "gameSpecific" (JsonD.assocListFromList (JsonD.field "gameId" Game.idDecoder) gamePermissionsDecoder)


type SetPermission
    = ManageGames Bool
    | ManagePermissions Bool
    | ManageBets (Maybe Game.Id) Bool


encodeSetPermissions : SetPermission -> JsonE.Value
encodeSetPermissions setPermissions =
    case setPermissions of
        ManageGames v ->
            JsonE.object [ ( "manageGames", JsonE.bool v ) ]

        ManagePermissions v ->
            JsonE.object [ ( "managePermissions", JsonE.bool v ) ]

        ManageBets Nothing v ->
            JsonE.object [ ( "manageBets", JsonE.bool v ) ]

        ManageBets (Just gameId) v ->
            JsonE.object
                [ ( "game", Game.encodeId gameId )
                , ( "manageBets", JsonE.bool v )
                ]


type alias PermissionsOverlay =
    { permissions : RemoteData EditablePermissions }


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
    | LoadPermissions User.Id (Result Http.Error EditablePermissions)
    | SetPermissions User.Id SetPermission
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
