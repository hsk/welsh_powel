:- module(memAlloc,[memAlloc/2]).
regp([\rdi,\rsi,\rdx,\rcx,\r8,\r9]).
adr(A,A) :- ($_=A;\_=A;ptr(_,_)=A),!.
adr(A,N) :- nb_getval(m,M),member(A:N,M),!.
adr(A,N) :- nb_getval(c,C),C1 is C+8,nb_setval(c,C1),
            N=ptr(\rbp,-C1),nb_getval(m,M),nb_setval(m,[A:N|M]).
adrs(A,A1) :- maplist(adr,A,A1).
prms(Ps,Ps_) :- regp(Regp),length(Regp,L),
                findall(P:R,(nth0(I,Ps,P),I>=L,C is (I-L+2)*8,R=ptr(\rbp,C)),M2),
                nb_setval(m,M2),findall(P:R,(nth0(I,Ps,P),nth0(I,Regp,R)),M),
                forall(member(A:_,M),adr(A,_)),append(M,M2,M3),
                nb_getval(m,M4),maplist(prms1(M4),M3,Ps_).
prms1(M4,A:R,mov(R,V)) :- member(A:V,M4).
code(mov(A,B),mov(A1,B1))           :- adr(A,A1),adr(B,B1).
code(bin(O,A,B,C),bin(O,A1,B1,C1))  :- adr(A,A1),adr(B,B1),adr(C,C1).
code(call(A,B,C),call(A,B1,C1,[]))  :- adrs(B,B1),adr(C,C1).
code(ret(A),ret(A1))                :- adr(A,A1).
code(bne(A,B,C),bne(A1,B,C))        :- adr(A,A1).
code(br(A),br(A)).
code(if(A,C,D),if(A1,C1,D1))        :- adr(A,A1),adrs(C,C1),adrs(D,D1).
code(C,_) :- throw(memAlloc(code(C))).
bb(L:BB,L:BB1) :- maplist(code,BB,BB1).
func(N:Ps=BBs,N:Ps_=[N1:[enter(Size,[])|Cs]|BBs1]) :-
  nb_setval(c,0),prms(Ps,Ps_),maplist(bb,BBs,[N1:Cs|BBs1]),nb_getval(c,Size).
memAlloc(Fs,Fs_) :- maplist(func,Fs,Fs_),!.
