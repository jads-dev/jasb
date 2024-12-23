module Jasb.Api.Path exposing
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
    , UserCardsPath(..)
    , UserPath(..)
    )

import Jasb.Bet.Model as Bets
import Jasb.Bet.Option as Option
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card
import Jasb.Gacha.CardType as CardType
import Jasb.Game.Id as Game
import Jasb.Page.Leaderboard.Route as Leaderboard
import Jasb.User.Model as User
import Jasb.User.Notifications.Model as Notifications


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
    | BannerCoverUpload
    | EditableBanners
    | SpecificBanner Banner.Id BannerPath


type CardPath
    = Card
    | RecycleValue
    | Highlight


type UserCardsPath
    = UserCardsOverview
    | UserCardsInBanner Banner.Id
    | AllUserCards


type CardsPath
    = UserCards UserCardsPath
    | ForgedCardTypes
    | ForgeCardType
    | RetireForged CardType.Id
    | SpecificCard Banner.Id Card.Id CardPath
    | Highlights


type GachaPath
    = Cards User.Id CardsPath
    | CardImageUpload
    | Balance
    | Banners BannersPath
    | Context


type Path
    = Auth AuthPath
    | Users
    | UserSearch String
    | SpecificUser User.Id UserPath
    | Games
    | GameSearch String
    | GameCoverUpload
    | BetOptionImageUpload
    | Game Game.Id GamePath
    | Leaderboard Leaderboard.Board
    | Feed
    | Gacha GachaPath
