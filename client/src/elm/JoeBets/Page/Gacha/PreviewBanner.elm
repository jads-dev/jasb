module JoeBets.Page.Gacha.PreviewBanner exposing
    ( load
    , view
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.IdData as Api
import JoeBets.Api.Model as Api
import JoeBets.Api.Path as Api
import JoeBets.Gacha.Banner as Banner
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Gacha.Banner as Banner
import JoeBets.Page.Gacha.Card as Card
import JoeBets.Page.Gacha.Collection.Route as Collection
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Page.Gacha.PreviewBanner.Model exposing (..)
import JoeBets.Page.Gacha.Route as Gacha
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth


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
            , [ cardTypes |> Card.viewCardTypes (Just viewDetailedCardType) bannerId ]
            , Card.viewDetailedCardTypeOverlay gacha
            ]
                |> List.concat
    in
    { title = "Banner"
    , id = "preview-banner"
    , body = gacha.bannerPreview |> Api.viewSpecificIdData Api.viewOrError content desiredBannerId
    }
