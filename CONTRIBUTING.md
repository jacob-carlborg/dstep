# Code Style for Contributors

* Use camelCase for functions and PascalCase for types.
* Do not use tabs, indent code with 4 spaces.
* If possible, a line of code should be at most 80 characters long.
* Put a space between foreach, if, while etc. and the opening parenthesis.
* Prefer to not include an empty set of parentheses in cases where there are only template parameters.

```d
auto good = foo.map!predicate;
auto bad = foo.map!predicate();
```

* Add spaces around operators.
```d
while (good && correct)
	perfect[1 .. $] = excellent[1 .. $];

while (bad&&wrong)
	poor[1..$] = inferior[1..$];
```

* Do not use braces for single-line statements.
```d
while (true)
	good();

while (true)
{
	wrong();
}
```

* Do not leave white-spaces at the end of line.
* Do not put extra newlines at the end of file.
* Use type inference, if possible.
* Prefer to use UFCS for algorithm functions.
* Do not use UFCS for `std.format.format`.
* Prefer `foreach` over plain old `for`:

```d
for (size_t bad = 0; bad < length; ++bad)
{
	...
}

foreach (good; 0 .. length)
{
	...
}
```

* Prefer using algorithms over `foreach`.
* Do not put spaces between `cast` and the opening parenthesis (`cast(Good)`).
* Do not put a newline between the documentation and the symbol it's attached to.
* For single-line ddocs use `///`.
* For multi-line ddocs use
```d
/**
 *
 */
```
