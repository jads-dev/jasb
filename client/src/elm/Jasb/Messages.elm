module Jasb.Messages exposing (Msg(..))

import Browser.Events as Browser
import Jasb.Feed.Model as Feed
import Jasb.Navigation.Messages as Navigation
import Jasb.Page.Bet.Model as Bet
import Jasb.Page.Bets.Model as Bets
import Jasb.Page.Edit.Msg as Edit
import Jasb.Page.Gacha.Collection.Model as Collection
import Jasb.Page.Gacha.Model as Gacha
import Jasb.Page.Games.Model as Games
import Jasb.Page.Leaderboard.Model as Leaderboard
import Jasb.Page.User.Model as User
import Jasb.Route exposing (Route)
import Jasb.Settings.Model as Settings
import Jasb.User.Auth.Model as Auth
import Jasb.User.Notifications.Model as Notifications
import Time


type Msg
    = ChangeUrl Route
    | UrlChanged Route
    | SetTimeZone Time.Zone
    | SetTime Time.Posix
    | AuthMsg Auth.Msg
    | NotificationsMsg Notifications.Msg
    | FeedMsg Feed.Msg
    | UserMsg User.Msg
    | CollectionMsg Collection.Msg
    | BetsMsg Bets.Msg
    | BetMsg Bet.Msg
    | GamesMsg Games.Msg
    | LeaderboardMsg Leaderboard.Msg
    | GachaMsg Gacha.Msg
    | EditMsg Edit.Msg
    | SettingsMsg Settings.Msg
    | ChangeVisibility Browser.Visibility
    | NavigationMsg Navigation.Msg
    | NoOp String
