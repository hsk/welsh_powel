:- use_module('../expand').
:- use_module('../memAlloc').
:- use_module('../emit').
:- begin_tests(expand).
  test(expand) :-
    expand([
      ('main',[],[
        mov(100,'a'),
        mov(20,'b'),
        mov(3,'c'),
        call('printInt',[call('add',['a','b','c'])]),
        mov(0,'e'),
        ret('e')
      ]),
      ('add',['a','b','c'],[
        ret(add('a',add('b','c')))
      ])
    ],P),
    format('p=~w\n',[P]),
    memAlloc(P,M),
    format('m=~w\n',[M]),
    emit('a.s',M),
    shell('gcc -static -o a a.s lib/lib.c'),
    shell('./a').
:- end_tests(expand).
:- run_tests,halt; halt(-1).
