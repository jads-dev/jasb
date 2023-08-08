module JoeBets.User.Auth.Model exposing
    ( Error(..)
    , LoggedIn
    , LoginProgress(..)
    , Model
    , Msg(..)
    , Progress(..)
    , Redirect
    , RedirectOrLoggedIn(..)
    , canManageBets
    , canManageGames
    , canManagePermissions
    , redirectDecoder
    , redirectOrLoggedInDecoder
    )

import EverySet
import Http
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.Route exposing (Route)
import JoeBets.User.Model as User exposing (User)
import JoeBets.User.Notifications.Model as Notifications exposing (Notification)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD


type Error
    = HttpError Http.Error
    | Unauthorized


type Progress
    = LoggingIn
    | LoggingOut


type alias Model =
    { inProgress : Maybe Progress
    , error : Maybe Error
    , localUser : Maybe User.WithId
    }


canManageGames : Maybe { a | user : User } -> Bool
canManageGames =
    Maybe.map (.user >> .permissions >> .manageGames) >> Maybe.withDefault False


canManagePermissions : Maybe { a | user : User } -> Bool
canManagePermissions =
    Maybe.map (.user >> .permissions >> .managePermissions) >> Maybe.withDefault False


canManageBets : Game.Id -> Maybe { a | user : User } -> Bool
canManageBets game =
    let
        modForGame { manageBets } =
            manageBets |> EverySet.member game
    in
    Maybe.map (.user >> .permissions >> modForGame) >> Maybe.withDefault False


type Msg
    = Login LoginProgress
    | SetLocalUser LoggedIn
    | RedirectAfterLogin (Maybe Route)
    | Logout


type LoginProgress
    = Start
    | Continue Redirect
    | Failed Error


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
