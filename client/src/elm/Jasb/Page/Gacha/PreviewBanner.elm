module Jasb.Page.Gacha.PreviewBanner exposing
    ( load
    , view
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import Jasb.Api as Api
import Jasb.Api.Data as Api
import Jasb.Api.IdData as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Jasb.Gacha.Banner as Banner
import Jasb.Messages as Global
import Jasb.Page exposing (Page)
import Jasb.Page.Gacha.Banner as Banner
import Jasb.Page.Gacha.Card as Card
import Jasb.Page.Gacha.Collection.Route as Collection
import Jasb.Page.Gacha.Model as Gacha
import Jasb.Page.Gacha.PreviewBanner.Model exposing (..)
import Jasb.Page.Gacha.Route as Gacha
import Jasb.Route as Route
import Jasb.User.Auth.Model as Auth


wrap : Gacha.Msg -> Global.Msg
wrap =
    Global.GachaMsg


type alias Parent a =
    { a
        | origin : String
        , auth : Auth.Model
        , gacha : Gacha.Model
    }


load : Banner.Id -> Parent a -> ( Parent a, Cmd Global.Msg )
load bannerId ({ origin, gacha } as model) =
    let
        ( bannerPreviewData, cmd ) =
            { path = (Api.Banner |> Api.SpecificBanner bannerId |> Api.Banners) |> Api.Gacha
            , wrap = Gacha.LoadBannerPreview bannerId >> wrap
            , decoder = decoder
            }
                |> Api.get origin
                |> Api.getIdData bannerId gacha.bannerPreview
    in
    ( { model | gacha = { gacha | bannerPreview = bannerPreviewData } }
    , cmd
    )


view : Banner.Id -> Parent a -> Page Global.Msg
view desiredBannerId { auth, gacha } =
    let
        content bannerId { banner, cardTypes } =
            let
                viewDetailedCardType givenBannerId cardTypeId =
                    Api.Start
                        |> Gacha.ViewDetailedCardType
                            { bannerId = givenBannerId, cardTypeId = cardTypeId }
                        |> wrap

                loggedIn =
                    case auth.localUser of
                        Just localUser ->
                            [ Html.ul [ HtmlA.class "collection-links" ]
                                [ Html.li []
                                    [ Route.a (Collection.Banner bannerId |> Route.CardCollection localUser.id)
                                        []
                                        [ Icon.layerGroup |> Icon.view, Html.text "Your Cards For This Banner" ]
                                    ]
                                , Html.li []
                                    [ Route.a (Gacha.Roll |> Route.Gacha)
                                        []
                                        [ Icon.diceD20 |> Icon.view, Html.text "Get Cards For This Banner" ]
                                    ]
                                ]
                            ]

                        Nothing ->
                            []
            in
            [ [ Banner.viewPreviewBanner bannerId banner ]
            , loggedIn
            , [ cardTypes |> Card.viewCardTypes (Just viewDetailedCardType) bannerId
              , Card.viewDetailedCardTypeDialog gacha
              ]
            ]
                |> List.concat
    in
    { title = "Banner"
    , id = "preview-banner"
    , body = gacha.bannerPreview |> Api.viewSpecificIdData Api.viewOrError content desiredBannerId
    }
