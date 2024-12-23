module Jasb.Page.Gacha.Balance exposing
    ( load
    , update
    , view
    , viewValue
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Api as Api
import Jasb.Api.Data as Api
import Jasb.Api.Path as Api
import Jasb.Gacha.Balance exposing (..)
import Jasb.Gacha.Balance.Guarantees exposing (..)
import Jasb.Gacha.Balance.Rolls exposing (..)
import Jasb.Gacha.Balance.Scrap exposing (..)
import Jasb.Messages as Global
import Jasb.Page.Gacha.Balance.Model exposing (..)
import Jasb.Page.Gacha.Model as Gacha
import Jasb.Sentiment as Sentiment exposing (Sentiment)
import Jasb.User.Auth.Model as Auth
import Material.Button as Button
import Material.Dialog as Dialog
import Material.IconButton as IconButton


type alias Parent a =
    { a | origin : String, auth : Auth.Model, gacha : Gacha.Model }


viewInfo : List (Html msg)
viewInfo =
    let
        listItem icon name description =
            Html.li []
                [ Html.span [ HtmlA.class "icon" ] [ icon ]
                , Html.span [ HtmlA.class "name" ] [ Html.text name ]
                , Html.span [ HtmlA.class "description" ] [ Html.text description ]
                ]
    in
    [ Html.ul []
        [ listItem rollIcon rollName rollDescription
        , listItem guaranteeIcon guaranteeName guaranteeDescription
        , listItem scrapIcon scrapName scrapDescription
        ]
    ]


load : Parent a -> ( Parent a, Cmd Global.Msg )
load ({ origin, auth, gacha } as model) =
    if auth.localUser == Nothing then
        ( model, Cmd.none )

    else
        let
            ( balance, cmd ) =
                { path = Api.Gacha Api.Balance
                , wrap = Gacha.LoadBalance >> Global.GachaMsg
                , decoder = decoder
                }
                    |> Api.get origin
                    |> Api.getData gacha.balance
        in
        ( { model | gacha = { gacha | balance = balance } }, cmd )


update : Msg -> Parent a -> Parent a
update msg ({ gacha } as model) =
    case msg of
        ShowInfo ->
            { model | gacha = { gacha | balanceInfoShown = True } }

        HideInfo ->
            { model | gacha = { gacha | balanceInfoShown = False } }


view : (Msg -> msg) -> Parent a -> Balance -> List (Html msg)
view wrap { gacha } { rolls, guarantees, scrap } =
    let
        dialog =
            Dialog.dialog (wrap HideInfo)
                viewInfo
                [ Button.text "Close"
                    |> Button.icon [ Icon.times |> Icon.view ]
                    |> Button.button (HideInfo |> wrap |> Just)
                    |> Button.view
                ]
                gacha.balanceInfoShown
                |> Dialog.headline [ Html.text "About your balance." ]
                |> Dialog.attrs [ HtmlA.class "info-dialog" ]
                |> Dialog.view
    in
    [ [ dialog
      , viewRolls Sentiment.PositiveGood rolls
      , viewGuarantees Sentiment.PositiveGood guarantees
      , viewScrap Sentiment.PositiveGood scrap
      , Html.span [ HtmlA.class "info-button" ]
            [ IconButton.icon (Icon.infoCircle |> Icon.view)
                "About"
                |> IconButton.button (ShowInfo |> wrap |> Just)
                |> IconButton.view
            ]
      ]
        |> Html.div [ HtmlA.class "balance" ]
    ]


viewValue : Sentiment -> Value -> Html msg
viewValue sentiment { rolls, guarantees, scrap } =
    [ rolls |> Maybe.map (viewRolls sentiment)
    , guarantees |> Maybe.map (viewGuarantees sentiment)
    , scrap |> Maybe.map (viewScrap sentiment)
    ]
        |> List.filterMap identity
        |> Html.span [ HtmlA.class "gacha-value" ]
