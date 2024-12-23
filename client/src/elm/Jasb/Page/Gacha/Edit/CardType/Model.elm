module Jasb.Page.Gacha.Edit.CardType.Model exposing
    ( Editor
    , Msg(..)
    )

import Jasb.Api.Action as Api
import Jasb.Api.Model as Api
import Jasb.Editing.Uploader as Uploader exposing (Uploader)
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card.Layout as Card
import Jasb.Gacha.CardType as CardType
import Jasb.Gacha.Rarity as Rarity
import Jasb.Page.Gacha.Edit.CardType.CreditEditor as CreditEditor
import Time.DateTime as Time


type alias Editor =
    { open : Bool
    , banner : Banner.Id
    , cardType : CardType.EditableCardType
    , imageUploader : Uploader
    , creditEditor : CreditEditor.Model
    , save : Api.ActionState
    , id : Maybe CardType.Id
    }


type Msg
    = Load Banner.Id (Api.Response CardType.EditableCardTypes)
    | Add Banner.Id (Maybe Time.DateTime)
    | Edit Banner.Id CardType.Id
    | Cancel
    | Save Banner.Id (Api.Process ( CardType.Id, CardType.EditableCardType ))
    | SetName String
    | SetDescription String
    | SetImage Uploader.Msg
    | SetLayout (Maybe Card.Layout)
    | SetRarity (Maybe Rarity.Id)
    | SetRetired Bool
    | EditCredit CreditEditor.Msg
