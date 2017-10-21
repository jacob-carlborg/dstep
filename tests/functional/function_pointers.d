extern (C):

extern __gshared void function () a;
extern __gshared int function () b;
extern __gshared void function (int) c;
extern __gshared int function (int, int) d;
extern __gshared int function (int a, int b) e;
extern __gshared int function (int a, int b, ...) f;
