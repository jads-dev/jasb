module JoeBets.Page.Problem.Model exposing
    ( Model(..)
    , Msg(..)
    )


type Model
    = Loading
    | UnknownPage { path : String }
    | MustBeLoggedIn { path : String }


type Msg
    = NoOp String
