module JoeBets.User.Auth.Route exposing
    ( CodeAndState
    , codeAndStateParser
    , encodeCodeAndState
    )

import Json.Encode as JsonE
import Url.Parser.Query as Query


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
