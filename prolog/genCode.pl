:- module(genCode,[genCode/2,resetid/0,genid/1,genid/2]).
resetid :- nb_setval(idcounter,0).
genid(C) :- nb_getval(idcounter,C),C1 is C+1,nb_setval(idcounter,C1).
genid(S,S1) :- nb_getval(idcounter,C),C1 is C+1,nb_setval(idcounter,C1),atom_concat(S,C,S1).

init_bbs(Lbl)  :- nb_setval(lbl,Lbl),nb_setval(cs,[]),
                  nb_setval(bbs,(H1,H1)).
add(C)         :- nb_getval(cs,Cs),
                  (Cs=[L|_],member(L,[call(_,_),br(_),bne(_,_,_),ret(_)])
                  ;nb_setval(cs,[C|Cs])).
label(Lbl)     :- nb_getval(lbl,Lb2),nb_getval(cs,Cs),reverse(Cs,Cs_),
                  nb_getval(bbs,(BBs,[Lb2:Cs_|H1])),nb_setval(bbs,(BBs,H1)),
                  nb_setval(lbl,Lbl),nb_setval(cs,[]).
get_bbs(BBs)   :- nb_getval(lbl,Lbl),nb_getval(cs,Cs),reverse(Cs,Cs_),
                  nb_getval(bbs,(BBs,[Lbl:Cs_])).

code(bin(Op,A,B),R) :-  genid('.ex.',R),code(A,A1),code(B,B1),add(bin(Op,A1,B1,R)).
code(mov(A,R),R) :-     atom(A),!,add(mov(A,R)).
code(mov(A,R),R) :-     integer(A),!,format(atom(D),'$~w',[A]),add(mov(D,R)).
code(mov(A,R),R) :-     code(A,R1),add(mov(R1,R)).
code(call(A,B),R) :-    genid('.ex.',R),maplist(code,B,Rs),add(call(A,Rs,R)).
code(R,R) :-            atom(R),!.
code(I,R) :-            integer(I),!,format(atom(R),'$~w',I).
code(E,_) :-            writeln(error:E),halt.
stmt(if(A,C,D)) :-      genid('.else',Else),genid('.then',Then),
                        code(A,R1),add(bne(R1,Then,Else)),genid('.cont',Cont),
                        label(Then),maplist(stmt,C),add(br(Cont)),
                        label(Else),maplist(stmt,D),add(br(Cont)),
                        label(Cont).
stmt(ret(E)) :-         code(E,R),add(ret(R)).
stmt(E) :-              code(E,_).
func(N:A=B,N:A=BBs) :-  genid('.enter',Enter),init_bbs(Enter),
                        maplist(stmt,B),get_bbs(BBs).
genCode(P,R) :- resetid,maplist(func,P,R),!.
