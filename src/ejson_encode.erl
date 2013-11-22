
-module(ejson_encode).

-export([value/1]).

-include("ejson.hrl").

value({O}) when is_list(O) ->
    object(O, [<<?LC>>]);
value(L) when is_list(L) ->
    array(L, [<<?LB>>]);
value(true) ->
    <<"true">>;
value(false) ->
    <<"false">>;
value(null) ->
    <<"null">>;
value(S) when is_atom(S); is_binary(S) ->
    string(S);
value(I) when is_integer(I) ->
    list_to_binary(integer_to_list(I));
value(F) when is_float(F) ->
    list_to_binary(io_lib:format("~p", [F]));
value(B) ->
    throw({invalid_json, {badarg, B}}).

object([], Acc) ->
    list_to_binary(lists:reverse([<<?RC>> | Acc]));
object([{K, V} | Rest], Acc) when length(Acc) =:= 1 ->
    Acc2 = [value(V), <<?CL>>, string(K) | Acc],
    object(Rest, Acc2);
object([{K, V} | Rest], Acc) ->
    Acc2 = [value(V), <<?CL>>, string(K), <<?CM>> | Acc],
    object(Rest, Acc2).

array([], Acc) ->
    list_to_binary(lists:reverse([<<?RB>> | Acc]));
array([V | Rest], Acc) when length(Acc) =:= 1 ->
    array(Rest, [value(V) | Acc]);
array([V | Rest], Acc) ->
    array(Rest, [value(V), <<?CM>> | Acc]).

string(A) when is_atom(A) ->
    string(list_to_binary(atom_to_list(A)), [<<?DQ>>]);
string(B) when is_binary(B) ->
    string(B, [<<?DQ>>]);
string(Bad) ->
    ?EXIT({invalid_string, {bad_term, Bad}}).

string(Bin, Acc) ->
    case Bin of
        <<>> ->
            list_to_binary(lists:reverse([<<?DQ>> | Acc]));
        <<?DQ, Rest/binary>> ->
            string(Rest, [<<?ESDQ:16>> | Acc]);
        <<?RS, Rest/binary>> ->
            string(Rest, [<<?ESRS:16>> | Acc]);
        <<?FS, Rest/binary>> ->
            string(Rest, [<<?ESFS:16>> | Acc]);
        <<?BS, Rest/binary>> ->
            string(Rest, [<<?ESBS:16>> | Acc]);
        <<?FF, Rest/binary>> ->
            string(Rest, [<<?ESFF:16>> | Acc]);
        <<?NL, Rest/binary>> ->
            string(Rest, [<<?ESNL:16>> | Acc]);
        <<?CR, Rest/binary>> ->
            string(Rest, [<<?ESCR:16>> | Acc]);
        <<?TB, Rest/binary>> ->
            string(Rest, [<<?ESTB:16>> | Acc]);
        _ ->
            case fast_string(Bin, 0) of
                Pos when Pos > 0 ->
                    <<Fast:Pos/binary, Rest/binary>> = Bin,
                    string(Rest, [Fast | Acc]);
                _ ->
                    {Rest, Escaped} = unicode_escape(Bin),
                    string(Rest, [Escaped | Acc])
            end
    end.

fast_string(<<>>, Pos) ->
    Pos;
fast_string(<<C, _/binary>>, Pos) when
            C == ?DQ; C == ?RS; C == ?FS; C == ?BS;
            C == ?FF; C == ?NL; C == ?CR; C == ?TB ->
    Pos;
fast_string(<<C, Rest/binary>>, Pos) when C > 16#1F, C < 16#7F ->
    fast_string(Rest, Pos+1);
fast_string(_, Pos) ->
    Pos.

unicode_escape(Bin) ->
    case Bin of
        <<D, Rest/binary>> when D =< 16#1F; D =:= 16#7F ->
            {Rest, hex_escape(D)};
        <<6:3, C1:5/bits, 2:2, C2:6/bits, Rest/binary>> ->
            <<C:16>> = <<0:5, C1:5/bits, C2:6/bits>>,
            {Rest, hex_escape(C)};
        <<14:4, C1:4/bits, 2:2, C2:6/bits, 2:2, C3:6/bits, Rest/binary>> ->
            <<C:16>> = <<C1:4/bits, C2:6/bits, C3:6/bits>>,
            {Rest, hex_escape(C)};
        <<30:5, C1:3/bits, 2:2, C2:6/bits, 2:2, C3:6/bits, 2:2, C4:6/bits, Rest/binary>> ->
            <<C:32>> = <<0:11, C1:3/bits, C2:6/bits, C3:6/bits, C4:6/bits>>,
            {Rest, hex_escape(C)};
        _ ->
            ?EXIT(invalid_utf8)
    end.

hex_escape(C) when C =< 16#FFFF ->
    <<C1:4, C2:4, C3:4, C4:4>> = <<C:16>>,
    ["\\u"] ++ [hex_digit(C0) || C0 <- [C1, C2, C3, C4]];
hex_escape(C) ->
    BinCodePoint = list_to_binary(xmerl_ucs:to_utf16be(C)),
    <<D:16, E:16>> = BinCodePoint,
    [hex_escape(D), hex_escape(E)].

hex_digit(D) when D >= 0, D =< 9 ->
    $0 + D;
hex_digit(D) when D >= 10, D =< 15 ->
    $A + (D - 10).
