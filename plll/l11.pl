:- dynamic(begin/2).
term_expansion(:-begin(M,E),:-true) :- assert(begin(M,E)).
term_expansion(:-end(M),:-true) :- retract(begin(M,E)),forall(retract(data(P)),M:assert(P)),
                                   forall(member(P1,E),(M:export(M:P1),user:import(M:P1))).
term_expansion(P,:-true) :- begin(_,_),assert(data(P)).
:- op(1200,xfx,::=).
:- op(650,xfx,∈).
:- op(250,yf,*).
:- begin(syntax,[syntax/2]).
  G∈{G}. G∈(G|_). G∈(_|G1):-G∈G1. G∈G.
  syntax(G,E):-G=..[O|Gs],E=..[O|Es],maplist(syntax,Gs,Es),!.
  syntax(G,E):-(G::=Gs),!,G1∈Gs,syntax(G1,E),!.
  syntax(i,I):-integer(I),!.
  syntax(id,I):- atom(I),!.
  syntax(E*,Ls) :- maplist(syntax(E),Ls).
  t ::= tv | ti(i) | tp(t) | tarr(t,i) | tstr((id:t)*) | tname(id).
  e ::= eint(ti(i),i) | eadd(e,e) | emul(e,e) | eprint(e) | eblock(e*)
      | evar(id,t) | eid(id) | eassign(e,e) | earray(e,e) | efield(e,id)
      | eref(e) | eptr(e) | etyp(t).
  r ::= rl(t,id) | rn(t,i).
  v ::= vprint(r) | vbin(r,id,r,r) | valloca(r) | vload(r,r) | vstore(r,r) | vfield(r,r,r,r)
      | vcomment(id).
:- end(syntax).
:- begin(env,[resetid/0,genid/2,genreg/2,t/2,cut_t/2,env/2,str/2]).
  t(rl(T,_),T).
  t(rn(T,_),T).
  resetid    :- retractall(id(_)),assert(id(0)),dynamic(env/2),dynamic(str/2).
  genid(S,A) :- retract(id(C)),C1 is C+1,assert(id(C1)),format(atom(A),'~w~w',[S,C]).
  genreg(T,rl(T,Id)) :- genid('..',Id).
  add(Id,T) :- assert(env(Id,T)),add_str(T,Id,false).
  add(Id,T,D) :- assert(env(Id,T)),add_str(T,Id,D).
  cut_t(tp(T),tp(T2)) :- cut_t(T,T2).
  cut_t(tname(T),T3) :- env(T,T2),cut_t(T2,T3).
  cut_t(T,T).
  add_str(tstr(Ls),Id,D) :- T=tstr(Ls),(str(T,_);D=true->assert(str(T,rl(T,Id)));genreg(T,R),assert(str(T,R))),
                         forall(member(_:T1,Ls),add_str(T1,Id,false)).
  add_str(tarr(T,_),Id,D) :- add_str(T,Id,D).
  add_str(_,_,_).
:- end(env).
:- begin(compile,[compile/2]).
  add(V) :- assert(v(V)).
  cut(T,T2) :- cut_t(T,T1),cut1(T1,T2).
  cut1(tp(tarr(T,_)),tp(T)).
  cut1(tp(T),T).
  arr(eid(Id),rl(tp(T),Id)) :- !,env(Id,T).
  arr(earray(Id,E),R4) :- !,e(E,R1),R2=rn(ti(64),0),arr(Id,R3),
                          t(R3,T3),cut_t(T3,T2),cut(T3,T4),genreg(T4,R4),
                          (T2=tp(tp(_)) -> genreg(T4,R5),add(vload(R5,R3)),add(vbin(R4,add,R5,R1))
                          ; add(vfield(R4,R3,R2,R1))).
  arr(eptr(Id),R1) :- arr(earray(Id,eint(ti(64),0)),R1).
  arr(efield(Id,Idx),R4) :- arr(Id,R3),t(R3,tp(T)),cut_t(T,T1),T1=tstr(M),member(Idx:T2,M),
                            index(T,Idx,N),R1=rn(ti(32),N),R2=rn(ti(64),0),genreg(tp(T2),R4),
                            add(vfield(R4,R3,R2,R1)).
  arr(E,_) :- findall(env(Id,T),env(Id,T),Vs),throw(error:arr(E);Vs).
  index(T,Id,N) :- cut_t(T,T1),index1(T1,Id,N).
  index1(tstr(Ls),Id,N) :- !,nth0(N,Ls,Id:_).
  index1(_,_,_) :- throw(error).
  e(eint(T,I),rn(T,I)).
  e(eadd(E1,E2),R3) :- e(E1,R1),e(E2,R2),t(R1,T1),genreg(T1,R3),add(vbin(R3,add,R1,R2)).
  e(emul(E1,E2),R3) :- e(E1,R1),e(E2,R2),t(R1,T1),genreg(T1,R3),add(vbin(R3,mul,R1,R2)).
  e(eblock(Es),R) :- foldl([E,R,R1]>>e(E,R1),Es,rn(tv,void),R).
  e(eprint(E1),rn(tv,void)) :- e(E1,R1),add(vprint(R1)).
  e(evar(Id,T),R1) :- R1=rl(T,Id),add(valloca(R1)),env:add(Id,T).
  e(eassign(eid(S),etyp(T)),rn(tv,void)) :- !,env:add(S,T,true).
  e(eassign(E1,E2),R1) :- e(E2,R1),arr(E1,R2),add(vstore(R1,R2)).
  e(E,R2) :- (E=eid(_);E=earray(_,_);E=efield(_,_);E=eptr(_)),!,
             arr(E,R1),t(R1,T1),cut(T1,T2),genreg(T2,R2),add(vload(R2,R1)).
  e(eref(E),R1) :- arr(E,R1).
  e(E,_) :- writeln(error(compile:e(E))),halt(-1).
  compile(E,Vs) :- syntax(e,E),resetid,e(E,_),findall(V,retract(v(V)),Vs).
:- end(compile).
:- begin(emit,[emit/2]).
  pt(R,X) :- t(R,T),!,cut_t(T,T1),pt1(T1,X).
  pt(T,X) :- cut_t(T,T1),pt1(T1,X).
  pt1(ti(I),X) :- format(atom(X),'i~w',[I]).
  pt1(tv,void).
  pt1(tp(T),X) :- pt(T,X1),format(atom(X),'~w*',[X1]).
  pt1(tarr(T,Size),X) :- pt(T,X1),format(atom(X),'[~w x ~w]',[Size,X1]).
  pt1(tstr(Ls),X) :- str(tstr(Ls),R),p(R,X).
  pt1(tname(N),X) :- format(atom(X),'%~w',[N]).
  p(A,A) :- atom(A),!.
  p(rl(_,Id),X) :- format(atom(X),'%~w',[Id]).
  p(rn(_,Id),Id).
  asm(S)              :- fp(FP),writeln(FP,S).
  asm(S,F)            :- fp(FP),maplist(call,F,F_),format(FP,S,F_),nl(FP).
  out(vbin(Id,add,A,B)) :- t(A,tp(T)),asm('\t~w = getelementptr inbounds ~w,~w ~w,~w ~w',[p(Id),pt(T),pt(A),p(A),pt(B),p(B)]),!.
  out(vbin(Id,Op,A,B)) :- asm('\t~w = ~w ~w ~w,~w',[p(Id),p(Op),pt(A),p(A),p(B)]).
  out(vprint(A)) :- asm('\tcall void @print_l(~w ~w)',[pt(A),p(A)]).
  out(valloca(R)) :- asm('\t~w = alloca ~w',[p(R),pt(R)]).
  out(vload(R1,R2)) :- t(R2,tp(tarr(T,N))),asm('\t~w = getelementptr inbounds ~w,~w ~w,i32 0,i32 0',[p(R1),pt(tarr(T,N)),pt(R2),p(R2)]).
  out(vload(R1,R2)) :- asm('\t~w = load ~w,~w ~w',[p(R1),pt(R1),pt(R2),p(R2)]).
  out(vstore(R1,R2)) :- asm('\tstore ~w ~w,~w ~w',[pt(R1),p(R1),pt(R2),p(R2)]).
  out(vfield(R1,Addr,Zero,A)) :- t(Addr,tp(T)),asm('\t~w = getelementptr inbounds ~w,~w ~w,~w ~w,~w ~w',
                                  [p(R1),pt(T),pt(Addr),p(Addr),pt(Zero),p(Zero),pt(A),p(A)]).
  out(vcomment(S)) :- asm('\t; ~w',[p(S)]).
  out(V) :- writeln(error:out(V)),halt.
  entry :-  asm('define i32 @main() {'),
            asm('entry:').
  leave :-  asm('\tret i32 0'),
            asm('}').
  printl :- asm('@.str = private constant [5 x i8] c"%ld\\0A\\00"'),
            asm('define void @print_l(i64 %a) {'),
            asm('entry:'),
            asm('\t%0 = call i32 (i8*,...) @printf(i8* ~w,i64 %a)',
                [p('getelementptr inbounds ([5 x i8],[5 x i8]* @.str,i32 0,i32 0)')]),
            asm('\tret void'),
            asm('}'),
            asm('declare i32 @printf(i8*,...)').
  strs :- forall(str(tstr(Ls),R),(
            maplist([_:T,A]>>pt(T,A),Ls,As),atomic_list_concat(As,',',A),
            asm('~w = type { ~w }',[p(R),p(A)])
          )).
  emit(File,Vs) :- setup_call_cleanup(
                    (open(File,write,FP),assert(fp(FP))),
                    (strs,entry,maplist(out,Vs),leave,printl),
                    (close(FP),retract(fp(_)))).
:- end(emit).
:-compile(eblock([
    eassign(eid(a),etyp(tstr([x:ti(64),y:tstr([a:ti(64)])]))),
    evar(b,tname(a)),
    eassign(efield(eid(b),x),eint(ti(64),3)),
    eassign(efield(efield(eid(b),y),a),emul(eint(ti(64),3),eint(ti(64),5))),
    eprint(efield(eid(b),x)),
    eprint(efield(efield(eid(b),y),a)),
    eprint(eadd(efield(eid(b),x),efield(efield(eid(b),y),a)))
  ]),Codes),!,
  syntax(v*,Codes),
  emit('l11.ll',Codes),!,
  shell('llc l11.ll -o l11.s'),
  shell('gcc -static l11.s -o l11.exe'),
  shell('./l11.exe').
:-halt.
