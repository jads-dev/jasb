module JoeBets.Page.Gacha.Edit.CardType.Model exposing
    ( Editor
    , Msg(..)
    )

import JoeBets.Api.Action as Api
import JoeBets.Api.Model as Api
import JoeBets.Editing.Uploader as Uploader exposing (Uploader)
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.CardType as CardType
import JoeBets.Gacha.Rarity as Rarity
import JoeBets.Page.Gacha.Edit.CardType.CreditEditor as CreditEditor
import Time.DateTime as Time


type alias Editor =
    { banner : Banner.Id
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
    | SetRarity (Maybe Rarity.Id)
    | SetRetired Bool
    | EditCredit CreditEditor.Msg
