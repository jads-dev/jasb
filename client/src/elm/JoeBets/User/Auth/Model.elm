module JoeBets.User.Auth.Model exposing
    ( CodeAndState
    , LoginProgress(..)
    , Model
    , Msg(..)
    , Redirect
    , RedirectOrUser(..)
    , codeAndStateParser
    , encodeCodeAndState
    , isAdmin
    , isMod
    , redirectDecoder
    , redirectOrUserDecoder
    )

import EverySet
import JoeBets.Game.Model as Game
import JoeBets.User.Model as User exposing (User)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Url.Parser.Query as Query


type alias Model =
    { trying : Bool
    , localUser : Maybe User.WithId
    }


isAdmin : Maybe { a | user : User } -> Bool
isAdmin =
    Maybe.map (.user >> .admin) >> Maybe.withDefault False


isMod : Game.Id -> Maybe { a | user : User } -> Bool
isMod game =
    let
        isAdminOrMod user =
            user.admin || (user.mod |> EverySet.member game)
    in
    Maybe.map (.user >> isAdminOrMod) >> Maybe.withDefault False


type Msg
    = Login LoginProgress
    | SetLocalUser Bool User.WithId
    | Logout


type LoginProgress
    = Start
    | Continue Redirect
    | Failed


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


type RedirectOrUser
    = R Redirect
    | U User.WithId


redirectOrUserDecoder : JsonD.Decoder RedirectOrUser
redirectOrUserDecoder =
    JsonD.oneOf
        [ redirectDecoder |> JsonD.map R
        , User.withIdDecoder |> JsonD.map U
        ]
