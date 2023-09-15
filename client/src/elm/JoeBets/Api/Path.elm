module JoeBets.Api.Path exposing
    ( AuthPath(..)
    , BannerPath(..)
    , BannersPath(..)
    , BetPath(..)
    , CardPath(..)
    , CardsPath(..)
    , GachaPath(..)
    , GamePath(..)
    , OptionPath(..)
    , Path(..)
    , UserPath(..)
    )

import JoeBets.Bet.Model as Bets
import JoeBets.Bet.Option as Option
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card as Card
import JoeBets.Gacha.CardType as CardType
import JoeBets.Game.Id as Game
import JoeBets.Page.Leaderboard.Route as Leaderboard
import JoeBets.User.Model as User
import JoeBets.User.Notifications.Model as Notifications


type AuthPath
    = Login
    | Logout


type UserPath
    = User
    | Notifications (Maybe Notifications.Id)
    | UserBets
    | Bankrupt
    | Permissions


type BetPath
    = BetRoot
    | Edit
    | Complete
    | RevertComplete
    | Lock
    | Unlock
    | Cancel
    | RevertCancel
    | BetFeed
    | Option Option.Id OptionPath


type OptionPath
    = Stake


type GamePath
    = GameRoot
    | Bets
    | LockStatus
    | LockMoments
    | Bet Bets.Id BetPath
    | Suggestions


type BannerPath
    = Banner
    | Roll
    | EditableCardTypes
    | CardTypesWithCards
    | DetailedCardType CardType.Id
    | GiftCardType CardType.Id


type BannersPath
    = BannersRoot
    | EditableBanners
    | SpecificBanner Banner.Id BannerPath


type CardPath
    = Card
    | RecycleValue
    | Highlight


type CardsPath
    = UserCards (Maybe Banner.Id)
    | ForgedCardTypes
    | ForgeCardType
    | RetireForged CardType.Id
    | SpecificCard Banner.Id Card.Id CardPath
    | Highlights


type GachaPath
    = Cards User.Id CardsPath
    | Balance
    | Banners BannersPath
    | Rarities


type Path
    = Auth AuthPath
    | Users
    | UserSearch String
    | SpecificUser User.Id UserPath
    | Games
    | Game Game.Id GamePath
    | Leaderboard Leaderboard.Board
    | Feed
    | Gacha GachaPath
    | Upload
