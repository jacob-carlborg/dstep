/**
 * Copyright: Copyright (c) 2010-2012 Jacob Carlborg.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 26, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.util.Traits;

version (Tango)
{
	static import tango.core.Traits;
	alias tango.core.Traits.BaseTypeTupleOf BaseTypeTupleOf;
	alias tango.core.Traits.ParameterTupleOf ParameterTupleOf;
	alias tango.core.Traits.ReturnTypeOf ReturnTypeOf;
}

else
{
	static import std.traits;
	alias std.traits.BaseTypeTuple BaseTypeTupleOf;
	alias std.traits.ParameterTypeTuple ParameterTupleOf;
	alias std.traits.ReturnType ReturnTypeOf;
}

import dstep.core.string;

template isPrimitive (T)
{
	const bool isPrimitive = is(T == bool) ||
						is(T == byte) ||
						is(T == cdouble) ||
						//is(T == cent) ||
						is(T == cfloat) ||
						is(T == char) ||
						is(T == creal) ||
						is(T == dchar) ||
						is(T == double) ||
						is(T == float) ||
						is(T == idouble) ||
						is(T == ifloat) ||
						is(T == int) ||
						is(T == ireal) ||
						is(T == long) ||
						is(T == real) ||
						is(T == short) ||
						is(T == ubyte) ||
						//is(T == ucent) ||
						is(T == uint) ||
						is(T == ulong) ||
						is(T == ushort) ||
						is(T == wchar);
}

template isChar (T)
{
	const bool isChar = is(T == char) || is(T == wchar) || is(T == dchar);
}

template isClass (T)
{
	const bool isClass = is(T == class);
}

template isInterface (T)
{
	const bool isInterface = is(T == interface);
}

template isObject (T)
{
	const bool isObject = isClass!(T) || isInterface!(T);
}

template isStruct (T)
{
	const bool isStruct = is(T == struct);
}

template isArray (T)
{
	static if (is(T U : U[]))
		const bool isArray = true;
	
	else
		const bool isArray = false;
}

template isString (T)
{
	const bool isString = is(T : string) || is(T : wstring) || is(T : dstring);
}

template isAssociativeArray (T)
{
	const bool isAssociativeArray = is(typeof(T.init.values[0])[typeof(T.init.keys[0])] == T);
}

template isPointer (T)
{
	static if (is(T U : U*))
		const bool isPointer = true;
	
	else
		const bool isPointer = false;
}

template isFunctionPointer (T)
{
	const bool isFunctionPointer = is(typeof(*T) == function);
}

template isEnum (T)
{
	const bool isEnum = is(T == enum);
}

template isReference (T)
{
	const bool isReference = isObject!(T) || isPointer!(T);
}

template isTypeDef (T)
{
	const bool isTypeDef = is(T == typedef);
}

template isVoid (T)
{
	const bool isVoid = is(T == void);
}

template BaseTypeOfArray (T)
{
	static if (is(T U : U[]))
		alias BaseTypeOfArray!(U) BaseTypeOfArray;
	
	else
		alias T BaseTypeOfArray;
}

template BaseTypeOfPointer (T)
{
	static if (is(T U : U*))
		alias BaseTypeOfPointer!(U) BaseTypeOfPointer;
	
	else
		alias T BaseTypeOfPointer;
}

template BaseTypeOfTypeDef (T)
{
	static if (is(T U == typedef))
		alias BaseTypeOfTypeDef!(U) BaseTypeOfTypeDef;
	
	else
		alias T BaseTypeOfTypeDef;
}

template KeyTypeOfAssociativeArray (T)
{
	static assert(isAssociativeArray!(T), "The type needs to be an associative array");
	alias typeof(T.init.keys[0]) KeyTypeOfAssociativeArray;
}

template ValueTypeOfAssociativeArray (T)
{
	static assert(isAssociativeArray!(T), "The type needs to be an associative array");
	alias typeof(T.init.values[0]) ValueTypeOfAssociativeArray;
}