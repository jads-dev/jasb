module JoeBets.User.Auth.Model exposing
    ( CodeAndState
    , Error(..)
    , LoggedIn
    , LoginProgress(..)
    , Model
    , Msg(..)
    , Redirect
    , RedirectOrLoggedIn(..)
    , canManageBets
    , canManageGames
    , canManagePermissions
    , codeAndStateParser
    , encodeCodeAndState
    , redirectDecoder
    , redirectOrLoggedInDecoder
    )

import EverySet
import Http
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User exposing (User)
import JoeBets.User.Notifications.Model as Notifications exposing (Notification)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Url.Parser.Query as Query


type Error
    = HttpError Http.Error
    | Unauthorized


type alias Model =
    { trying : Bool
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
    | SetLocalUser Bool LoggedIn
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


type alias CodeAndState =
    { code : String, state : String }


codeAndStateParser : Query.Parser (Maybe CodeAndState)
codeAndStateParser =
    Query.map2 (Maybe.map2 CodeAndState)
        (Query.string "code")
        (Query.string "state")


encodeCodeAndState : CodeAndState -> JsonE.Value
encodeCodeAndState { code, state } =
    JsonE.object
        [ ( "code", JsonE.string code )
        , ( "state", JsonE.string state )
        ]


type RedirectOrLoggedIn
    = R Redirect
    | L LoggedIn


redirectOrLoggedInDecoder : JsonD.Decoder RedirectOrLoggedIn
redirectOrLoggedInDecoder =
    JsonD.oneOf
        [ redirectDecoder |> JsonD.map R
        , loggedInDecoder |> JsonD.map L
        ]
