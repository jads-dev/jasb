module JoeBets.Messages exposing (Msg(..))

import Browser
import Browser.Events as Browser
import JoeBets.Navigation.Messages as Navigation
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
import Time
import Time.Model as Time


type Msg
    = ChangeUrl Route
    | UrlChanged Route
    | SetTimeZone Time.Zone
    | SetTime Time.Posix
    | AuthMsg Auth.Msg
    | NotificationsMsg Notifications.Msg
    | FeedMsg Feed.Msg
    | UserMsg User.Msg
    | BetsMsg Bets.Msg
    | BetMsg Bet.Msg
    | GamesMsg Games.Msg
    | LeaderboardMsg Leaderboard.Msg
    | EditMsg Edit.Msg
    | SettingsMsg Settings.Msg
    | ChangeVisibility Browser.Visibility
    | NavigationMsg Navigation.Msg
    | NoOp
