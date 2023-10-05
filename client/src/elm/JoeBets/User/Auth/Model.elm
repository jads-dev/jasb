module JoeBets.User.Auth.Model exposing
    ( LoggedIn
    , LoginProgress(..)
    , Model
    , Msg(..)
    , Progress(..)
    , Redirect
    , RedirectOrLoggedIn(..)
    , canManageBets
    , canManageGacha
    , canManageGames
    , canManagePermissions
    , redirectDecoder
    , redirectOrLoggedInDecoder
    )

import JoeBets.Api.Error as Api
import JoeBets.Game.Id as Game
import JoeBets.Route exposing (Route)
import JoeBets.User.Model as User exposing (User)
import JoeBets.User.Notifications.Model as Notifications exposing (Notification)
import JoeBets.User.Permission as Permission exposing (Permission)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


type Progress
    = LoggingIn
    | LoggingOut


type alias Model =
    { inProgress : Maybe Progress
    , error : Maybe Api.Error
    , localUser : Maybe User.WithId
    }


hasPermission : (List Permission -> Bool) -> Maybe { a | user : User } -> Bool
hasPermission getPerm =
    Maybe.map (.user >> .permissions >> getPerm) >> Maybe.withDefault False


canManageGames : Maybe { a | user : User } -> Bool
canManageGames =
    hasPermission Permission.canManageGames


canManagePermissions : Maybe { a | user : User } -> Bool
canManagePermissions =
    hasPermission Permission.canManagePermissions


canManageGacha : Maybe { a | user : User } -> Bool
canManageGacha =
    hasPermission Permission.canManageGacha


canManageBets : Game.Id -> Maybe { a | user : User } -> Bool
canManageBets game =
    hasPermission (Permission.canManageGameBets game)


type Msg
    = Login LoginProgress
    | SetLocalUser LoggedIn
    | RedirectAfterLogin (Maybe Route)
    | Logout
    | DismissError


type LoginProgress
    = Start
    | FinishNotLoggedIn
    | Continue Redirect
    | Failed Api.Error


type alias LoggedIn =
    { user : User.WithId
    , notifications : List Notification
    }


loggedInDecoder : JsonD.Decoder LoggedIn
loggedInDecoder =
    JsonD.succeed LoggedIn
        |> JsonD.required "user" User.withIdDecoder
        |> JsonD.required "notifications" (JsonD.list Notifications.decoder)


type alias Redirect =
    { redirect : String }


redirectDecoder : JsonD.Decoder Redirect
redirectDecoder =
    JsonD.succeed Redirect
        |> JsonD.required "redirect" JsonD.string


type RedirectOrLoggedIn
    = R Redirect
    | L LoggedIn


redirectOrLoggedInDecoder : JsonD.Decoder RedirectOrLoggedIn
redirectOrLoggedInDecoder =
    JsonD.oneOf
        [ redirectDecoder |> JsonD.map R
        , loggedInDecoder |> JsonD.map L
        ]
