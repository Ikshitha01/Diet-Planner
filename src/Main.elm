port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Data.Food as Food
import Data.Session as Session exposing (Session)
import Html exposing (Html, a, button, div, header, li, main_, nav, p, span, text, ul)
import Html.Attributes exposing (class, href, style)
import Html.Events exposing (onClick)
import Json.Decode as JD
import Page.Foods as Foods
import Page.Meals as Meals
import Svg.Attributes as SA
import Url exposing (Url)
import Url.Parser as UrlParser
import View.Helpers as VH
import Zondicons as Icons


port storeRatioNoteSeenStateLocally : String -> Cmd msg


main : Program JD.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChange
        }



-- MODEL


type Page
    = Meals Meals.Model
    | Foods Foods.Model
    | Recipes Session


isMealsPage : Page -> Bool
isMealsPage page =
    case page of
        Meals _ ->
            True

        _ ->
            False


isFoodsPage : Page -> Bool
isFoodsPage page =
    case page of
        Foods _ ->
            True

        _ ->
            False


isRecipesPage : Page -> Bool
isRecipesPage page =
    case page of
        Recipes _ ->
            True

        _ ->
            False


getSession : Page -> Session
getSession page =
    case page of
        Meals model ->
            model.session

        Foods model ->
            model.session

        Recipes session ->
            session


updateSession : (Session -> Session) -> Page -> Page
updateSession func page =
    case page of
        Meals pageModel ->
            Meals { pageModel | session = func pageModel.session }

        Foods pageModel ->
            Foods { pageModel | session = func pageModel.session }

        Recipes session ->
            Recipes (func session)


type alias Model =
    { page : Page
    , navKey : Nav.Key
    , ratioNoteOpen : Bool
    , ratioNoteSeen : Bool
    }


init : JD.Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init json url navKey =
    let
        decoder =
            JD.map2 Tuple.pair
                (JD.field "data" Food.decoder)
                (JD.field "ratioNoteSeen" JD.bool)

        result =
            JD.decodeValue decoder json
                |> Result.mapError (always "Could not decode food list")

        session =
            Session.init navKey
    in
    case result of
        Ok ( foods, ratioNoteSeen ) ->
            updateUrl url
                { page = Meals (Meals.init (Session.addFoods foods session))
                , navKey = navKey
                , ratioNoteOpen = True
                , ratioNoteSeen = ratioNoteSeen
                }

        Err err ->
            updateUrl url
                { page = Meals (Meals.init session)
                , navKey = navKey
                , ratioNoteOpen = False
                , ratioNoteSeen = True
                }



-- UPDATE


updatePage :
    (pageModel -> Page)
    -> (pageMsg -> Msg)
    -> Model
    -> ( pageModel, Cmd pageMsg )
    -> ( Model, Cmd Msg )
updatePage toPage toMsg model ( pageModel, pageCmd ) =
    ( { model | page = toPage pageModel }, Cmd.map toMsg pageCmd )


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChange Url.Url
    | NavToogle
    | SettingsToggle
    | MealsMsg Meals.Msg
    | FoodsMsg Foods.Msg
    | AcknowledgeRatioNote Bool
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.navKey (Url.toString url) )

                Browser.External url ->
                    ( model, Nav.load url )

        UrlChange url ->
            updateUrl url model

        NavToogle ->
            let
                newPage =
                    updateSession (\session -> { session | navOpen = not session.navOpen })
                        model.page
            in
            ( { model | page = newPage }, Cmd.none )

        SettingsToggle ->
            let
                newPage =
                    updateSession (\session -> { session | settingsOpen = not session.settingsOpen })
                        model.page
            in
            ( { model | page = newPage }, Cmd.none )

        MealsMsg pageMsg ->
            case model.page of
                Meals pageModel ->
                    updatePage Meals MealsMsg model (Meals.update pageMsg pageModel)

                _ ->
                    ( model, Cmd.none )

        FoodsMsg pageMsg ->
            case model.page of
                Foods pageModel ->
                    updatePage Foods FoodsMsg model (Foods.update pageMsg pageModel)

                _ ->
                    ( model, Cmd.none )

        AcknowledgeRatioNote remember ->
            ( { model | ratioNoteOpen = False }
            , if remember then
                storeRatioNoteSeenStateLocally "1"

              else
                Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )



-- ROUTING


updateUrl : Url -> Model -> ( Model, Cmd Msg )
updateUrl url model =
    let
        session =
            getSession model.page

        parser =
            UrlParser.oneOf
                [ UrlParser.map ( { model | page = Meals (Meals.init session) }, Cmd.none ) (UrlParser.s "meals")
                , UrlParser.map ( { model | page = Foods (Foods.init session) }, Cmd.none ) (UrlParser.s "foods")
                , UrlParser.map ( { model | page = Recipes session }, Cmd.none ) (UrlParser.s "recipes")
                ]
    in
    case UrlParser.parse parser url of
        Nothing ->
            -- redirect to meals page in case of failed url parsing
            ( model, Nav.replaceUrl model.navKey "meals" )

        Just pair ->
            pair



-- VIEW


viewNav : Model -> Html Msg
viewNav { page } =
    let
        session =
            getSession page

        viewItem active name link =
            li []
                [ a
                    [ href link
                    , class "block w-full px-4 py-1 my-2 font-bold tracking-wide"
                    , if active then
                        class "bg-indigo-500"

                      else
                        class ""
                    , onClick NavToogle
                    ]
                    [ text name ]
                ]
    in
    div
        [ class "fixed inset-0 z-50 w-full h-full mx-auto shadow-md app-width"
        , VH.attrIf (not session.navOpen) <|
            class "transition-transform transform -translate-x-full delay-200"
        ]
        [ div
            [ class "h-full bg-black"
            , class "transition-opacity duration-200 "
            , if session.navOpen then
                style "opacity" "0.25"

              else
                style "opacity" "0"
            , onClick NavToogle
            ]
            []
        , nav
            [ class "absolute inset-y-0 items-center justify-between w-2/3 pt-10 bg-white"
            , class "text-white bg-indigo-700"
            , class "shadow-md transition transition-transform duration-200"
            , if session.navOpen then
                style "transform" "none"

              else
                style "transform" "translateX(-100vw)"
            ]
            [ ul
                [ class "w-full"
                ]
                [ viewItem (isMealsPage page) "Meals" "/meals"
                , viewItem (isFoodsPage page) "Foods" "/foods"
                , viewItem (isRecipesPage page) "Recipes" "/recipes"
                ]
            ]
        ]


viewPageTitle : String -> Html Msg
viewPageTitle title =
    div [ class "relative tracking-widest text-bg-black" ]
        [ div
            [ class "flex items-center px-4 uppercase cursor-pointer"
            , Html.Attributes.tabindex 0
            , onClick NavToogle
            ]
            [ Icons.menu [ SA.class "w-6" ], span [ class "ml-2" ] [ text title ] ]
        ]


viewSkeleton : (a -> Msg) -> VH.Skeleton a -> Model -> Html Msg
viewSkeleton toMsg skeleton model =
    let
        session =
            getSession model.page

        { menuTitle, body, subHeader } =
            if Session.hasFoods session then
                skeleton

            else
                viewLoadingError skeleton
    in
    div [ class "w-full min-h-full mx-auto bg-gray-200 max-w-screen-sm" ] <|
        [ header [ class "sticky top-0 z-10 w-full" ]
            [ div [ class "relative z-10 flex items-center h-12 text-white bg-indigo-700 shadow-md" ]
                [ viewPageTitle menuTitle
                , viewSettings session
                ]
            , div [ class "relative" ] <| List.map (Html.map toMsg) subHeader
            ]
        , main_ [] <| List.map (Html.map toMsg) body
        , viewNav model
        ]


viewLoadingError : VH.Skeleton a -> VH.Skeleton a
viewLoadingError skeleton =
    { skeleton
        | subHeader = []
        , body =
            [ div
                [ class "px-4 pt-24 text-center"
                , class "text-4xl font-semibold text-gray-600"
                ]
                [ div [ class "w-16 mx-auto" ] [ Icons.exclamationSolid [] ]
                , div [ class "mt-8" ] [ text "Error when initializing data." ]
                ]
            ]
    }


viewSettings : Session -> Html Msg
viewSettings session =
    let
        linkItem text_ link =
            li []
                [ VH.externalLink
                    { href = link
                    , title = Nothing
                    , children = [ text text_ ]
                    , attr =
                        [ class "block px-4 py-2 hover:bg-gray-200"
                        , onClick SettingsToggle
                        ]
                    }
                ]
    in
    div [ class "relative px-1 ml-auto mr-2 cursor-pointer" ]
        [ Icons.dotsHorizontalTriple [ SA.class "w-8", onClick SettingsToggle ]
        , div
            [ class "fixed inset-0"
            , VH.attrIf (not session.settingsOpen) (class "hidden")
            , onClick SettingsToggle
            ]
            []
        , ul
            [ class "absolute top-0 right-0 w-48 bg-white shadow-md main-text-color"
            , class "v-gap-2"
            , VH.attrIf (not session.settingsOpen) (class "hidden")
            ]
            [ linkItem "Report a bug" "https://github.com/ChristophP/keto-meal-planner/issues/new"
            , linkItem "Request a feature" "https://github.com/ChristophP/keto-meal-planner/issues/new"
            , linkItem "Changelog" "https://github.com/ChristophP/keto-meal-planner/blob/master/CHANGELOG.md"
            ]
        ]


view : Model -> Browser.Document Msg
view model =
    Browser.Document "Keto Meal Planner"
        [ case model.page of
            Meals pageModel ->
                viewSkeleton MealsMsg (Meals.view pageModel) model

            Foods pageModel ->
                viewSkeleton identity { subHeader = [], body = [ div [ class "flex items-center justify-center h-64" ] [ text "Coming Soon" ] ], menuTitle = "Foods" } model

            --viewSkeleton FoodsMsg (Foods.view pageModel) model
            Recipes _ ->
                viewSkeleton identity { subHeader = [], body = [ div [ class "flex items-center justify-center h-64" ] [ text "Coming Soon" ] ], menuTitle = "Recipes" } model
        , VH.viewIf (not model.ratioNoteSeen && model.ratioNoteOpen) <|
            \_ ->
                div
                    [ class "fixed inset-0 z-50" ]
                    [ div [ class "w-full h-full bg-black opacity-75" ]
                        []
                    , div [ class "absolute inset-x-0 bottom-0 max-h-screen px-4 py-4 mx-auto overflow-y-auto leading-loose bg-white shadow-md app-width" ]
                        [ p [] [ text "Hi there! We just wanna inform you that the ratio has changed." ]
                        , p [ class "mt-4" ] [ text "It used to be (protein, fat, carbs) 9/79/12. Now it is 9/73/18 because our daughter needs a change in the ratio. Unfortunately, we currently don't support setting your own ratio, but we are planning to support it and are working on it. We're sorry for the inconvenience and please send us an email at keto@deedop.de if you want to reach out to us." ]
                        , button
                            [ class "block w-full p-4 mt-4 text-white bg-indigo-600 rounded shadow-md"
                            , class "font-semibold tracking-wider"
                            , onClick (AcknowledgeRatioNote True)
                            ]
                            [ text "Understood" ]
                        , button
                            [ class "block w-full p-4 mt-4 text-black bg-white rounded shadow-md"
                            , class "font-semibold tracking-wider"
                            , onClick (AcknowledgeRatioNote False)
                            ]
                            [ text "Remind me next time" ]
                        ]
                    ]
        ]
