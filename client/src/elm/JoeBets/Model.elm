module JoeBets.Model exposing
    ( Flags
    , Model
    )

import Browser
import Browser.Events as Browser
import Browser.Navigation as Navigation
import JoeBets.Navigation as Navigation
import JoeBets.Page.Bet as Bet
import JoeBets.Page.Bet.Model as Bet
import JoeBets.Page.Bets as Bets
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit as Edit
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Edit.Msg as Edit
import JoeBets.Page.Feed as Feed
import JoeBets.Page.Feed.Model as Feed
import JoeBets.Page.Games as Games
import JoeBets.Page.Games.Model as Games
import JoeBets.Page.Leaderboard as Leaderboard
import JoeBets.Page.Leaderboard.Model as Leaderboard
import JoeBets.Page.Leaderboard.Route as Leaderboard
import JoeBets.Page.Model exposing (Page)
import JoeBets.Page.Problem as Problem
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Page.User as User
import JoeBets.Page.User.Model as User
import JoeBets.Route exposing (Route)
import JoeBets.Settings as Settings
import JoeBets.Settings.Model as Settings
import JoeBets.User as User
import JoeBets.User.Auth as Auth
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications as Notifications
import JoeBets.User.Notifications.Model as Notifications
import Json.Decode as JsonD
import Time
import Time.Model as Time


type alias Flags =
    { store : List JsonD.Value
    }


type alias Model =
    { origin : String
    , navigationKey : Navigation.Key
    , time : Time.Context
    , route : Route
    , navigation : Navigation.Model
    , page : Page
    , auth : Auth.Model
    , notifications : Notifications.Model
    , feed : Feed.Model
    , user : User.Model
    , bets : Bets.Model
    , bet : Bet.Model
    , games : Games.Model
    , leaderboard : Leaderboard.Model
    , edit : Edit.Model
    , settings : Settings.Model
    , problem : Problem.Model
    , visibility : Browser.Visibility
    }
