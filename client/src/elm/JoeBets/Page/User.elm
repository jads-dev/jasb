module JoeBets.Page.User exposing
    ( init
    , load
    , update
    , view
    )

import Browser.Navigation as Navigation
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Page exposing (Page)
import JoeBets.Page.User.Model exposing (Model, Msg(..))
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Material.Button as Button
import Material.Switch as Switch
import Util.Maybe as Maybe
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | user : Model
        , auth : Auth.Model
        , navigationKey : Navigation.Key
        , origin : String
    }


init : Model
init =
    { id = Nothing
    , user = RemoteData.Missing
    , bankruptcyToggle = False
    }


load : (Msg -> msg) -> Maybe User.Id -> Parent a -> ( Parent a, Cmd msg )
load wrap userId ({ user } as model) =
    let
        newModel =
            if user.id /= userId then
                { model | user = { user | id = userId, user = RemoteData.Missing } }

            else
                model
    in
    ( newModel
    , Api.get model.origin
        { path = "user" :: (userId |> Maybe.map User.idToString |> Maybe.toList)
        , expect = Http.expectJson (Load >> wrap) User.withIdDecoder
        }
    )


update : (Msg -> msg) -> Msg -> Parent a -> ( Parent a, Cmd msg )
update wrap msg ({ user, auth } as model) =
    case msg of
        Load result ->
            case result of
                Ok userData ->
                    let
                        newUser =
                            { user
                                | id = Just userData.id
                                , user = RemoteData.Loaded userData.user
                                , bankruptcyToggle = False
                            }

                        cmd =
                            if newUser.id /= user.id then
                                Route.pushUrl model.navigationKey (Route.User newUser.id)

                            else
                                Cmd.none

                        newAuth =
                            if Just userData.id == (auth.localUser |> Maybe.map .id) then
                                { auth | localUser = Just userData }

                            else
                                auth
                    in
                    ( { model | user = newUser, auth = newAuth }, cmd )

                Err error ->
                    ( { model | user = { user | user = RemoteData.Failed error } }, Cmd.none )

        SetBankruptcyToggle enabled ->
            ( { model | user = { user | bankruptcyToggle = enabled } }, Cmd.none )

        GoBankrupt ->
            case user.id of
                Just uid ->
                    ( model
                    , Api.post model.origin
                        { path = [ "user", uid |> User.idToString, "bankrupt" ]
                        , body = Http.emptyBody
                        , expect = Http.expectJson (Load >> wrap) User.withIdDecoder
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )


view : (Msg -> msg) -> Parent a -> Page msg
view wrap model =
    let
        { id, user, bankruptcyToggle } =
            model.user

        isLocal =
            id == (model.auth.localUser |> Maybe.map .id)

        body userData =
            let
                avatar =
                    case id of
                        Just givenId ->
                            User.viewAvatar givenId userData

                        Nothing ->
                            Html.text ""

                isYou =
                    if isLocal then
                        [ Html.text " (you)" ]

                    else
                        []

                identity =
                    [ [ avatar, User.viewName userData ], isYou ]

                controls =
                    if isLocal then
                        [ Html.div [ HtmlA.class "bankrupt" ]
                            [ Html.p [] [ Html.text "Going bankrupt will reset your balance to the starting amount, and cancel all your current bets." ]
                            , Switch.view (Html.text "I am sure I want to do this.") bankruptcyToggle (SetBankruptcyToggle >> wrap |> Just)
                            , Button.view Button.Raised
                                Button.Padded
                                "Go Bankrupt"
                                (Icon.recycle |> Icon.present |> Icon.view |> Just)
                                (GoBankrupt |> wrap |> Maybe.when bankruptcyToggle)
                            ]
                        ]

                    else
                        []

                userBets =
                    [--, Html.div [ HtmlA.class "bets" ]
                     --    [ bets "ongoing" "Ongoing", bets "won" "Won", bets "lost" "Lost" ]
                    ]

                netWorthEntry ( name, amount ) =
                    Html.li []
                        [ Html.span [ HtmlA.class "title" ] [ Html.text name ]
                        , User.viewBalance amount
                        ]

                netWorth =
                    [ ( "Balance", userData.balance )
                    , ( "Bets", userData.betValue )
                    ]

                contents =
                    [ [ identity |> List.concat |> Html.div [ HtmlA.class "identity" ]
                      , netWorth |> List.map netWorthEntry |> Html.ul [ HtmlA.class "net-worth" ]
                      ]
                    , controls
                    , userBets
                    ]
            in
            contents |> List.concat

        title =
            case user |> RemoteData.toMaybe of
                Just u ->
                    "“" ++ u.name ++ "”"

                Nothing ->
                    "Profile"
    in
    { title = "User " ++ title
    , id = "user"
    , body = user |> RemoteData.view body
    }


bets : String -> String -> Html msg
bets class title =
    Html.div [ HtmlA.class class ] [ Html.h2 [] [ Html.text title ], Html.ol [] [] ]
