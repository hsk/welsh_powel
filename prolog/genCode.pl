:- module(genCode,[genCode/2,resetid/0,genid/2]).
resetid      :- nb_setval(id,0).
genid(S,A)  :- nb_getval(id,C),C1 is C+1,nb_setval(id,C1),format(atom(A),'.~w~w',[S,C]).
initBBs(Lbl) :- nb_setval(lbl,Lbl),nb_setval(cs,[]),nb_setval(bbs,(H1,H1)).
add(C)       :- nb_getval(cs,Cs),
                (Cs=[L|_],member(L,[br(_),bne(_,_,_),ret(_)]);nb_setval(cs,[C|Cs])).
label(Lbl)   :- nb_getval(lbl,Lb2),nb_getval(cs,Cs),reverse(Cs,Cs_),
                nb_getval(bbs,(BBs,[Lb2:Cs_|H1])),nb_setval(bbs,(BBs,H1)),
                nb_setval(lbl,Lbl),nb_setval(cs,[]).
bb(Lbl,F,B)  :- label(Lbl),call(F),add(B).
getBBs(BBs)  :- nb_getval(cs,Cs),reverse(Cs,Cs_),
                nb_getval(lbl,Lbl),nb_getval(bbs,(BBs,[Lbl:Cs_])).
expr(bin(Op,A,B),R) :-  genid(r,R),expr(A,A1),expr(B,B1),add(bin(Op,A1,B1,R)).
expr(mov(A,R),R) :-     expr(A,R1),add(mov(R1,R)).
expr(call(A,B),R) :-    genid(r,R),maplist(expr,B,Rs),add(call(A,Rs,R)).
expr(R,R) :-            atom(R),!.
expr(I,$I) :-           integer(I),!.
expr(E,_) :-            throw(genCode(expr(E))).
stmt(if(A,C,D)) :-      genid(then,Then),genid(else,Else),
                        expr(A,R1),add(bne(R1,Then,Else)),genid(cont,Cont),
                        bb(Then,forall(member(S,C),stmt(S)),br(Cont)),
                        bb(Else,forall(member(S,D),stmt(S)),br(Cont)),label(Cont).
stmt(while(A,B)) :-     genid(while,While),genid(then,Then),genid(cont,Cont),
                        bb(While,expr(A,R1),bne(R1,Then,Cont)),
                        bb(Then,forall(member(S,B),stmt(S)),br(While)),label(Cont).
stmt(ret(E)) :-         expr(E,R),add(ret(R)).
stmt(E) :-              expr(E,_).
func(N:A=B,N:A=BBs) :-  genid(enter,E),initBBs(E),forall(member(S,B),stmt(S)),getBBs(BBs).
genCode(P,R) :-         resetid,maplist(func,P,R),!.
