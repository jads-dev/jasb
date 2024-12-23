module Jasb.Model exposing
    ( Flags
    , Model
    )

import Browser.Events as Browser
import Browser.Navigation as Navigation
import Jasb.Feed.Model as Feed
import Jasb.Navigation.Model as Navigation
import Jasb.Page.Bet.Model as Bet
import Jasb.Page.Bets.Model as Bets
import Jasb.Page.Edit.Model as Edit
import Jasb.Page.Gacha.Collection.Model as Collection
import Jasb.Page.Gacha.Forge.Model as Forge
import Jasb.Page.Gacha.Model as Gacha
import Jasb.Page.Games.Model as Games
import Jasb.Page.Leaderboard.Model as Leaderboard
import Jasb.Page.Problem.Model as Problem
import Jasb.Page.User.Model as User
import Jasb.Route exposing (Route)
import Jasb.Settings.Model as Settings
import Jasb.User.Auth.Model as Auth
import Jasb.User.Notifications.Model as Notifications
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
