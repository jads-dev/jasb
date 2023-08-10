module JoeBets.Page.Feed exposing (init, load, update, view)

import JoeBets.Feed as Feed
import JoeBets.Feed.Model as Feed
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Settings.Model as Settings


wrap : Feed.Msg -> Global.Msg
wrap =
    Global.FeedMsg


type alias Parent a =
    { a
        | feed : Feed.Model
        , bets : Bets.Model
        , settings : Settings.Model
        , origin : String
    }


init : Feed.Model
init =
    Feed.init


load : Parent a -> ( Parent a, Cmd Global.Msg )
load model =
    let
        ( feed, cmd ) =
            Feed.load wrap Nothing model model.feed
    in
    ( { model | feed = feed }, cmd )


update : Feed.Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg model =
    let
        ( feed, cmd ) =
            Feed.update msg model.feed
    in
    ( { model | feed = feed }, cmd )


view : Parent a -> Page Global.Msg
view model =
    { title = "Feed"
    , id = "feed"
    , body = Feed.view wrap False model model.feed
    }
