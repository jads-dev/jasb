module Jasb.Editing.Uploader exposing
    ( Model
    , Msg(..)
    , Uploader
    , fromUrl
    , init
    , setUrl
    , toUrl
    , update
    , view
    )

import File exposing (File)
import File.Select as Select
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import Jasb.Api as Api
import Jasb.Api.Action as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Material.IconButton as IconButton
import Material.TextField as TextField
import Maybe


type alias Parent a =
    { a
        | origin : String
    }


type Msg
    = ChangeUrl String
    | RequestFile
    | Upload File
    | Uploaded (Api.Response UploadedResponse)


type alias Model =
    { label : String
    , types : List String
    , path : Api.Path
    , extraParts : List Http.Part
    }


type alias Uploader =
    { url : String
    , upload : Api.ActionState
    }


type alias UploadedResponse =
    { url : String }


decoder : JsonD.Decoder UploadedResponse
decoder =
    JsonD.succeed UploadedResponse
        |> JsonD.required "url" JsonD.string


init : Uploader
init =
    { url = ""
    , upload = Api.initAction
    }


fromUrl : String -> Uploader
fromUrl url =
    { url = url
    , upload = Api.initAction
    }


toUrl : Uploader -> String
toUrl =
    .url


setUrl : String -> Uploader -> Uploader
setUrl url uploader =
    { uploader | url = url }


update : (Msg -> msg) -> Msg -> Parent a -> Model -> Uploader -> ( Uploader, Cmd msg )
update wrap msg { origin } { types, path, extraParts } uploader =
    case msg of
        ChangeUrl newUrl ->
            ( { uploader | url = newUrl }, Cmd.none )

        RequestFile ->
            ( uploader, Select.file types (Upload >> wrap) )

        Upload file ->
            let
                ( upload, cmd ) =
                    { path = path
                    , body = Http.filePart "file" file :: extraParts
                    , wrap = Uploaded >> wrap
                    , decoder = decoder
                    }
                        |> Api.postFile origin
                        |> Api.doAction uploader.upload
            in
            ( { uploader | upload = upload }, cmd )

        Uploaded result ->
            let
                ( response, upload ) =
                    uploader.upload |> Api.handleActionResult result
            in
            ( { uploader
                | url =
                    response
                        |> Maybe.map .url
                        |> Maybe.withDefault uploader.url
                , upload = upload
              }
            , Cmd.none
            )


view : Maybe (Msg -> msg) -> Model -> Uploader -> Html msg
view wrap { label } { url, upload } =
    let
        uploadIcon =
            Icon.upload
                |> Icon.view
                |> Api.orSpinner upload

        applyIfGiven maybeWrap value =
            maybeWrap |> Maybe.map (\w -> value >> w)

        ifGiven maybeWrap value =
            maybeWrap |> Maybe.map (\w -> value |> w)

        core =
            TextField.outlined label
                (ChangeUrl |> applyIfGiven wrap |> Api.ifNotWorking upload)
                url
                |> TextField.url
                |> TextField.trailingIcon
                    [ IconButton.icon uploadIcon
                        ("Upload " ++ label)
                        |> IconButton.button (RequestFile |> ifGiven wrap |> Api.ifNotWorking upload)
                        |> IconButton.view
                    ]
                |> TextField.supportingText "Please avoid hotlinking images, upload them."
                |> TextField.view

        action =
            Api.viewActionError [] upload
    in
    core :: action |> Html.div [ HtmlA.class "uploader" ]
