module JoeBets.Page.Gacha.Balance exposing
    ( load
    , update
    , view
    , viewValue
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
import JoeBets.Gacha.Balance exposing (..)
import JoeBets.Gacha.Balance.Guarantees exposing (..)
import JoeBets.Gacha.Balance.Rolls exposing (..)
import JoeBets.Gacha.Balance.Scrap exposing (..)
import JoeBets.Messages as Global
import JoeBets.Overlay as Overlay
import JoeBets.Page.Gacha.Balance.Model exposing (..)
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.User.Auth.Model as Auth
import Material.IconButton as IconButton


type alias Parent a =
    { a | origin : String, auth : Auth.Model, gacha : Gacha.Model }


viewInfo : (Msg -> msg) -> List (Html msg)
viewInfo wrap =
    let
        listItem icon name description =
            Html.li []
                [ Html.span [ HtmlA.class "icon" ] [ icon ]
                , Html.span [ HtmlA.class "name" ] [ Html.text name ]
                , Html.span [ HtmlA.class "description" ] [ Html.text description ]
                ]
    in
    [ Html.div [ HtmlA.class "info-overlay" ]
        [ Html.div [ HtmlA.class "title" ]
            [ Html.h2 [] [ Html.text "About" ]
            , IconButton.icon (Icon.times |> Icon.view)
                "Close"
                |> IconButton.button (HideInfo |> wrap |> Just)
                |> IconButton.view
            ]
        , Html.ul []
            [ listItem rollIcon rollName rollDescription
            , listItem guaranteeIcon guaranteeName guaranteeDescription
            , listItem scrapIcon scrapName scrapDescription
            ]
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
        overlay =
            if gacha.balanceInfoShown then
                [ Overlay.view (wrap HideInfo) (viewInfo wrap) ]

            else
                []
    in
    [ [ Html.div [] overlay
      , viewRolls rolls
      , viewGuarantees guarantees
      , viewScrap scrap
      , Html.span [ HtmlA.class "info-button" ]
            [ IconButton.icon (Icon.infoCircle |> Icon.view)
                "About"
                |> IconButton.button (ShowInfo |> wrap |> Just)
                |> IconButton.view
            ]
      ]
        |> Html.div [ HtmlA.class "balance" ]
    ]


viewValue : Value -> Html msg
viewValue { rolls, guarantees, scrap } =
    [ rolls |> Maybe.map viewRolls
    , guarantees |> Maybe.map viewGuarantees
    , scrap |> Maybe.map viewScrap
    ]
        |> List.filterMap identity
        |> Html.span [ HtmlA.class "gacha-value" ]
