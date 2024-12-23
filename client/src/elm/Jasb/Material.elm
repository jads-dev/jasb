module Jasb.Material exposing
    ( buttonLink
    , externalMenuLink
    , iconButtonLink
    , listViewLink
    , menuLink
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Jasb.Route as Route exposing (Route)
import Material.Button as Button exposing (Button)
import Material.IconButton as IconButton exposing (IconButton)
import Material.ListView as ListView
import Material.Menu as Menu
import Url.Builder


externalMenuLink : String -> List String -> Menu.Item msg -> Menu.Item msg
externalMenuLink origin path =
    Menu.link (Url.Builder.crossOrigin origin path []) (Just "_blank")
        >> Menu.end [ Icon.externalLinkAlt |> Icon.view ]


buttonLink : (Route -> msg) -> Route -> (Button msg -> Button msg)
buttonLink changeUrl route =
    Button.replacedLink (\_ _ -> changeUrl route) (route |> Route.toUrl) Nothing


iconButtonLink : (Route -> msg) -> Route -> (IconButton msg -> IconButton msg)
iconButtonLink changeUrl route =
    IconButton.replacedLink (\_ _ -> changeUrl route) (route |> Route.toUrl) Nothing


menuLink : (Route -> msg) -> Route -> (Menu.Item msg -> Menu.Item msg)
menuLink changeUrl route =
    Menu.replacedLink (\_ _ -> changeUrl route) (route |> Route.toUrl) Nothing


listViewLink : (Route -> msg) -> Route -> (ListView.Item msg -> ListView.Item msg)
listViewLink changeUrl route =
    ListView.replacedLink (\_ _ -> changeUrl route) (route |> Route.toUrl) Nothing
