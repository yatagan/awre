%% do with this code what ever you like
%% Bas Wegh

-module(crossbar_client).
-behaviour(gen_server).

-define(RPC_MUL2_URL,<<"com.example.mul2">>).
-define(RPC_ADD2_URL,<<"com.example.add2">>).
-define(EVENT_ONHELLO_URL,<<"com.example.onhello">>).
-define(EVENT_ONCOUNTER_URL,<<"com.example.oncounter">>).
-define(REALM,<<"realm1">>).
-define(HOST,"localhost"). % has to be a string
-define(PORT,5555).
-define(ENCODING,msgpack). %% msgpack or json

-export([start_link/0]).

%% gen_server
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-export([add2/4]).
-export([on_hello/4]).

-record(state,{
  con = undefined,
  session = undefined,
  counter = 0 }).


start_link() ->
  gen_server:start_link(?MODULE, [], []).

init(_) ->
  io:format("starting client ... "),
  {ok,Con} = awre:start_client(),
  io:format("done.~nconnecting to realm ~p at ~p:~p ... ",[?REALM,?HOST,?PORT]),
  {ok,SessionId,_RouterDetails} = awre:connect(Con,?HOST,?PORT,?REALM,?ENCODING),
  io:format("done (~p).~nsubscribe to ~p ... ",[SessionId,?EVENT_ONHELLO_URL]),
  {ok,SubId} = awre:subscribe(Con,[{}],?EVENT_ONHELLO_URL,{crossbar_client,on_hello,[]}),
  io:format("subscribed (~p).~nregister ~p ... ",[SubId,?RPC_ADD2_URL]),
  {ok,RegId} = awre:register(Con,[{}],?RPC_ADD2_URL,{crossbar_client,add2,[]}),
  io:format("registered (~p).~nstarting the timer ...",[RegId]),
  ok = timer:start(),
  {ok,_TRef} = timer:send_after(1000,on_timer),
  io:format("done~n"),
  io:format("client sucessfully initialized.~n"),
  {ok,#state{con=Con,session=SessionId}}.

on_hello(_Details,Arguments,ArgumentsKw,_) ->
  io:format("onhello(): ~p ~p~n",[Arguments,ArgumentsKw]),
  ok.

add2(_Details,[A,B],_ArgumentsKw,_) ->
  io:format("add2() called with ~p and ~p",[A,B]),
  {ok,[{}],[A+B],undefined}.


handle_call(_,_From,State) ->
  {noreply,State}.

handle_cast(_Msg,State) ->
  {noreply,State}.

handle_info(on_timer,#state{con=Con, counter=Counter}=State) ->
  io:format("tick~n"),
  ok = awre:publish(Con,[{}],?EVENT_ONCOUNTER_URL,[Counter]),
  case awre:call(Con,[{}],?RPC_MUL2_URL,[Counter,3]) of
    {ok,_Details,ResA,_ResAkw} ->
      io:format("mul2() result: ~p~n",ResA);
    {error,_Details,Error,_Arguments,_ArgumentsKw} ->
      io:format("mul2() error ~p~n",[Error])
    end,
  {ok,_TRef} = timer:send_after(1000,on_timer),
  {noreply,State#state{counter=Counter+1}};

handle_info(Msg,State) ->
  io:format("~nreceived unknown message: ~p~n",[Msg]),
  {noreply,State}.

terminate(_Reason,_State) ->
  ok.

code_change(_OldVsn,State,_Extra) ->
  {ok,State}.

