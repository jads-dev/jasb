module JoeBets.Messages exposing (Msg(..))

import Browser.Events as Browser
import JoeBets.Feed.Model as Feed
import JoeBets.Navigation.Messages as Navigation
import JoeBets.Page.Bet.Model as Bet
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Msg as Edit
import JoeBets.Page.Gacha.Collection.Model as Collection
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Page.Games.Model as Games
import JoeBets.Page.Leaderboard.Model as Leaderboard
import JoeBets.Page.User.Model as User
import JoeBets.Route exposing (Route)
import JoeBets.Settings.Model as Settings
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Notifications.Model as Notifications
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
