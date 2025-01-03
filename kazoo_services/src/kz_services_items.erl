%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2012-2025, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_services_items).

-export([empty/0]).
-export([create/2]).
-export([foldl/3]).

-export([public_json/1]).

-export([changes/1]).
-export([has_changes/1]).
-export([has_additions/1]).
-export([additions/1]).
-export([has_billable_additions/1]).
-export([billable_additions/1]).
-export([updates/1, has_updates/1]).

-export([reset/1]).

-export([annotate/3
        ,annotate/4
        ]).
-export([difference/2
        ,difference/3
        ,difference_simple/2
        ,difference_number/2
        ,difference_list/2
        ]).

-type items() :: [kz_services_item:item()].
-type fold_fun() :: fun((kz_services_item:item(), Acc) -> Acc).
-type difference_routine() :: {kz_json:get_key(), fun((any(), any()) -> any())}.
-type difference_routines() :: [difference_routine()].
-export_type([items/0
             ,fold_fun/0
             ]).

-include("services.hrl").

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec empty() -> items().
empty() ->
    [].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec create(kz_services:services(), kz_services_plan:plan()) -> items().
create(Services, Plan) ->
    lists:foldl(fun({CategoryName, ItemName}, Items) ->
                        ItemPlan = get_item_plan(Plan, CategoryName, ItemName),
                        [kz_services_item:create(Services, ItemPlan, CategoryName, ItemName)|Items]
                end
               ,[]
               ,get_plan_items(Services, Plan)
               ).

-spec get_item_plan(kz_services_plan:plan(), kz_term:ne_binary(), kz_term:ne_binary()) -> kzd_item_plan:doc().
get_item_plan(Plan, CategoryName, ItemName) ->
    PlanJObj = kz_services_plan:jobj(Plan),
    case kzd_service_plan:item(PlanJObj, CategoryName, ItemName) of
        'undefined' ->
            lager:info("unable to find item plan ~s/~s, using generic"
                      ,[CategoryName, ItemName]
                      ),
            get_generic_item_plan(PlanJObj, CategoryName);
        ItemPlan -> ItemPlan
    end.

-spec get_generic_item_plan(kzd_service_plan:doc(), kz_term:ne_binary()) -> kzd_item_plan:doc().
get_generic_item_plan(PlanJObj, CategoryName) ->
    case kzd_service_plan:item(PlanJObj, CategoryName, <<"_all">>) of
        'undefined' -> kz_json:new();
        ItemPlan -> ItemPlan
    end.

-spec get_plan_items(kz_services:services(), kz_services_plan:plan()) -> kz_term:proplist().
get_plan_items(_Services, Plan) ->
    PlanJObj = kz_services_plan:jobj(Plan),
    [{CategoryName, ItemName}
     || CategoryName <- kzd_service_plan:categories(PlanJObj),
        ItemName <- kzd_service_plan:items(PlanJObj, CategoryName)
    ].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec foldl(fold_fun(), Acc, items()) -> Acc.
foldl(FoldFun, Acc, Items) ->
    lists:foldl(FoldFun, Acc, Items).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec public_json(items()) -> kz_json:objects().
public_json(Items) ->
    [kz_services_item:public_json(Item) || Item <- Items].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec has_changes(items()) -> boolean().
has_changes(Items) ->
    changes(Items) =/= [].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec changes(items()) -> items().
changes(Items) ->
    [Item
     || Item <- Items,
        kz_services_item:has_changes(Item)
    ].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec has_additions(items()) -> boolean().
has_additions(Items) ->
    additions(Items) =/= [].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec additions(items()) -> items().
additions(Items) ->
    [Item
     || Item <- Items,
        kz_services_item:has_additions(Item)
    ].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec has_billable_additions(items()) -> boolean().
has_billable_additions(Items) ->
    billable_additions(Items) =/= [].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec billable_additions(items()) -> items().
billable_additions(Items) ->
    [Item
     || Item <- Items,
        kz_services_item:has_billable_additions(Item)
    ].

%%------------------------------------------------------------------------------
%% @doc Has any changed items as a result of direct update by a user?
%%
%% Direct updates can be any API requests or calls to ay kz_services:set_*_updates.
%% @end
%%------------------------------------------------------------------------------
-spec has_updates(items()) -> boolean().
has_updates(Items) ->
    updates(Items) =/= [].

%%------------------------------------------------------------------------------
%% @doc Returns items that have changed as a result of an update by a user.
%%
%% Direct updates can be any API requests or calls to ay kz_services:set_*_updates.
%% @end
%%------------------------------------------------------------------------------
-spec updates(items()) -> items().
updates(Items) ->
    [Item
     || Item <- Items,
        kz_services_item:has_updates(Item)
    ].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec reset(items()) -> items().
reset(Items) ->
    [kz_services_item:reset(Item)
     || Item <- Items
    ].

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec annotate(kz_services:services(), items(), items()) -> items().
annotate(Services, CurrentItems, ProposedItems) ->
    annotate(Services, CurrentItems, ProposedItems, 'undefined').

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec annotate(kz_services:services(), items(), items(), kz_term:api_binary()) -> items().
annotate(Services, CurrentItems, ProposedItems, InvoiceReason) ->
    Dict =
        foldl(fun(Item, D) ->
                      Key = kz_services_item:hash(Item),
                      dict:store(Key, {Item, 'undefined'}, D)
              end
             ,dict:new()
             ,CurrentItems
             ),
    TentativeItems =
        dict:to_list(
          foldl(fun(Item, D) ->
                        Key = kz_services_item:hash(Item),
                        dict:update(Key
                                   ,fun({Current, _}) ->
                                            {Current, Item}
                                    end
                                   ,{'undefined', Item}
                                   ,D
                                   )
                end
               ,Dict
               ,ProposedItems
               )
         ),
    do_annotate(Services, [Items || {_ItemHash, Items} <- TentativeItems], InvoiceReason, []).

-type tentative_items() :: [{kz_services_item:item() | 'undefined', kz_services_item:item() | 'undefined'}].
-spec do_annotate(kz_services:services(), tentative_items(), kz_term:api_binary(), items()) -> items().
do_annotate(_Services, [], _InvoiceReason, Items) ->
    Items;
do_annotate(Services, [{CurrentItem, 'undefined'}|TentativeItems], InvoiceReason, Items) ->
    %% current item is removed, either due to:
    %% - there is no item of this kind left in account anymore (quantity was set null)
    %% - the item or its category got removed from plan (plan changed)
    %% - the item hash (maybe its masquerade_as/display_name part) is changed in plan
    ProposedItem = kz_services_item:reset(CurrentItem),
    Difference = difference(CurrentItem, ProposedItem),
    Item = maybe_annotate(Services, <<"removed">>, Difference, InvoiceReason, ProposedItem),
    do_annotate(Services, TentativeItems, InvoiceReason, [Item|Items]);
do_annotate(Services, [{'undefined', ProposedItem}|TentativeItems], InvoiceReason, Items) ->
    %% a new item is added, either by
    %% - new additions to the account
    %% - new additions to the plan? override?
    %% - the item hash (maybe its masquerade_as/display_name part) is changed in plan
    CurrentItem = kz_services_item:reset(ProposedItem),
    Difference = difference(CurrentItem, ProposedItem),
    Item = maybe_annotate(Services, <<"created">>, Difference, InvoiceReason, ProposedItem),
    do_annotate(Services, TentativeItems, InvoiceReason, [Item|Items]);
do_annotate(Services, [{CurrentItem, ProposedItem}|TentativeItems], InvoiceReason, Items) ->
    %% - nothing is changed
    %% - item is modified
    %% - plan was assigned / unassign
    Difference = difference(CurrentItem, ProposedItem),
    Item = maybe_annotate(Services, <<"modified">>, Difference, InvoiceReason, ProposedItem),
    do_annotate(Services, TentativeItems, InvoiceReason, [Item|Items]).

-spec maybe_annotate(kz_services:services(), kz_term:ne_binary(), kz_term:api_object(), kz_term:api_binary(), kz_services_item:item()) ->
          kz_services_item:item().
maybe_annotate(Services, Type, Difference, InvoiceReason, Item) ->
    case kz_json:is_empty(Difference) of
        'true' -> Item;
        'false' ->
            ProposedUpdates = annotate_updates(Services, Item),
            Reason = change_reason(InvoiceReason, ProposedUpdates),
            lager:debug("update ~s the item ~s/~s with reason ~s"
                       ,[Type
                        ,kz_services_item:category_name(Item)
                        ,kz_services_item:item_name(Item)
                        ,Reason
                        ]
                       ),
            %% Note: type removed/created and InvoiceReason =:= item_changed means that the item was added, removed or moved
            %% in plan WHILE also has its quantity changed
            Changes = props:filter_empty(
                        [{<<"type">>, Type}
                        ,{<<"reason">>, Reason}
                        ,{<<"difference">>, Difference}
                        ,{<<"updates">>, ProposedUpdates}
                        ]
                       ),
            kz_services_item:set_changes(Item, kz_json:from_list(Changes))
    end.

-spec change_reason(kz_term:api_ne_binary(), kz_json:object()) ->
          kz_term:ne_binary().
change_reason('undefined', Updates) ->
    %% If there is any account, cascade or manual updates that means this change
    %% is the result of direct updates by user or API or etc...
    UpdatesQuantity = kz_json:get_first_defined([<<"manual">>, <<"account">>, <<"cascade">>], Updates),
    case UpdatesQuantity =/= 'undefined' of
        'true' ->
            <<"service_change">>;
        'false' ->
            <<"reconcile">>
    end;
change_reason(Reason, _) ->
    Reason.

%% @doc Create an object of quantities of any types of updates.
-spec annotate_updates(kz_services:services(), kz_services_item:item()) -> kz_json:object().
annotate_updates(Services, Item) ->
    lists:foldl(fun (Kind, Acc) -> annotate_update_fold(Item, Kind, Acc) end
               ,kz_json:new()
               ,[{<<"manual">>, kz_services:manual_updates(Services)}
                ,{<<"account">>, kz_services:account_updates(Services)}
                ,{<<"cascade">>, kz_services:cascade_updates(Services)}
                ]
               ).

-spec annotate_update_fold(kz_services_item:item(), {kz_term:ne_binary(), kz_json:object()}, kz_json:object()) -> kz_json:object().
annotate_update_fold(Item, {Kind, Updates}, Acc) ->
    IsAllItemKeys = kzd_service_plan:all_items_key() =:= kz_services_item:item_name(Item),
    get_item_update(IsAllItemKeys, Kind, Item, Updates, Acc).

-spec get_item_update(boolean(), kz_term:ne_binary(), kz_services_item:item(), kz_json:object(), kz_json:object()) -> kz_json:object().
get_item_update('true', Kind, Item, Updates, Acc) ->
    CategoryName = kz_services_item:category_name(Item),
    case kz_json:get_value(CategoryName, Updates) of
        'undefined' -> Acc;
        Items ->
            CategorySum = kz_json:foldl(fun(_ItemName, ItemQuantity, Sum) -> ItemQuantity + Sum end, 0, Items),
            kz_json:set_value(Kind, CategorySum, Acc)
    end;
get_item_update('false', Kind, Item, Updates, Acc) ->
    CategoryName = kz_services_item:category_name(Item),
    ItemName = kz_services_item:item_name(Item),
    case kz_json:get_value([CategoryName, ItemName], Updates) of
        'undefined' -> Acc;
        ItemQuantity ->
            kz_json:set_value(Kind, ItemQuantity, Acc)
    end.

%%------------------------------------------------------------------------------
%% @doc Compares two service items, returning the difference
%% @end
%%------------------------------------------------------------------------------
-spec difference(kz_services_item:item(), kz_services_item:item()) -> kz_json:object().
difference(Item1, Item2) ->
    Routines = [{<<"activation_charge">>, fun difference_number/2}
               ,{<<"billable">>, fun difference_number/2}
               ,{<<"category">>, fun difference_simple/2}
               ,{[<<"discounts">>, <<"cumulative">>, <<"quantity">>], fun difference_number/2}
               ,{[<<"discounts">>, <<"cumulative">>, <<"rate">>], fun difference_number/2}
               ,{[<<"discounts">>, <<"single">>, <<"rate">>], fun difference_number/2}
               ,{<<"exceptions">>, fun difference_list/2}
               ,{<<"item">>, fun difference_simple/2}
               ,{<<"minimum">>, fun difference_number/2}
               ,{<<"name">>, fun difference_simple/2}
               ,{<<"quantity">>, fun difference_number/2}
               ,{<<"rate">>, fun difference_number/2}
               ],
    difference(Item1, Item2, Routines).

%%------------------------------------------------------------------------------
%% @doc
%% @end
%%------------------------------------------------------------------------------
-spec difference(kz_services_item:item(), kz_services_item:item(), difference_routines()) -> kz_json:object().
difference(Item1, Item2, Routines) ->
    JObj1 = kz_services_item:public_json(Item1),
    JObj2 = kz_services_item:public_json(Item2),
    lists:foldl(fun({Key, Fun}, JObj) ->
                        Value1 = kz_json:get_value(Key, JObj1),
                        Value2 = kz_json:get_value(Key, JObj2),
                        case Fun(Value1, Value2) of
                            'undefined' -> JObj;
                            Difference -> kz_json:set_value(Key, Difference, JObj)
                        end
                end
               ,kz_json:new()
               ,Routines
               ).

-spec difference_simple(any(), Value) -> 'undefined' | Value.
difference_simple(Value, Value) -> 'undefined';
difference_simple(_, Value) -> Value.

-spec difference_number(kz_term:api_float() | integer(), kz_term:api_float() | integer()) -> kz_term:api_float() | integer().
difference_number(Value, Value) -> 'undefined';
difference_number('undefined', Value) ->
    difference_number(0, Value);
difference_number(Value, 'undefined') ->
    difference_number(Value, 0);
difference_number(Value1, Value2) -> Value2 - Value1.

-spec difference_list(kz_term:api_ne_binaries(), kz_term:api_ne_binaries()) -> kz_term:proplist() | 'undefined'.
difference_list(List, List) -> 'undefined';
difference_list('undefined', List) ->
    difference_list([], List);
difference_list(List, 'undefined') ->
    difference_list(List, []);
difference_list(List1, List2) ->
    Set1 = sets:from_list(List1),
    Set2 = sets:from_list(List2),
    props:filter_empty(
      [{<<"removals">>, sets:to_list(sets:subtract(Set1, Set2))}
      ,{<<"additions">>, sets:to_list(sets:subtract(Set2, Set1))}
      ]
     ).
