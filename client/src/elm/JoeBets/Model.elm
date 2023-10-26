module JoeBets.Model exposing
    ( Flags
    , Model
    )

import Browser.Events as Browser
import Browser.Navigation as Navigation
import JoeBets.Feed.Model as Feed
import JoeBets.Navigation.Model as Navigation
import JoeBets.Page.Bet.Model as Bet
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Page.Gacha.Collection.Model as Collection
import JoeBets.Page.Gacha.Forge.Model as Forge
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Page.Games.Model as Games
import JoeBets.Page.Leaderboard.Model as Leaderboard
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Page.User.Model as User
import JoeBets.Route exposing (Route)
import JoeBets.Settings.Model as Settings
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications.Model as Notifications
import Json.Decode as JsonD
import Time.Model as Time


type alias Flags =
    { base : String, store : List JsonD.Value }


type alias Model =
    { origin : String
    , navigationKey : Navigation.Key
    , time : Time.Context
    , route : Route
    , navigation : Navigation.Model
    , auth : Auth.Model
    , notifications : Notifications.Model
    , feed : Feed.Model
    , user : User.Model
    , bets : Bets.Model
    , bet : Bet.Model
    , games : Games.Model
    , leaderboard : Leaderboard.Model
    , gacha : Gacha.Model
    , forge : Forge.Model
    , collection : Collection.Model
    , edit : Edit.Model
    , settings : Settings.Model
    , problem : Problem.Model
    , visibility : Browser.Visibility
    }
