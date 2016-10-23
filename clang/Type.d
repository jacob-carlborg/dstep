/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Type;

import std.bitmanip;

import clang.c.Index;
import clang.Cursor;
import clang.Util;

struct Type
{
    static assert(Type.init.kind == CXTypeKind.CXType_Invalid);

    mixin CX;

    private Type* pointee_;
    private Type* canonical_;

    mixin(bitfields!(
        bool, "isConst", 1,
        bool, "isVolatile", 1,
        bool, "isClang", 1,
        uint, "", 5));

    string spelling = "";

    this (CXType cx)
    {
        this.cx = cx;
        spelling = Cursor(clang_getTypeDeclaration(cx)).spelling;
        isConst = clang_isConstQualifiedType(cx) == 1;
        isClang = true;
    }

    this (CXTypeKind kind, string spelling)
    {
        cx.kind = kind;
        this.spelling = spelling;
    }

    static Type makePointer(Type pointee)
    {
        Type result = Type(CXTypeKind.CXType_Pointer, "");
        result.pointee_ = new Type();
        *result.pointee_ = pointee;
        return result;
    }

    static Type makeTypedef(string spelling, Type canonical)
    {
        Type result = Type(CXTypeKind.CXType_Typedef, spelling);
        result.canonical_ = new Type();
        *result.canonical_ = canonical;
        return result;
    }

    @property bool isAnonymous ()
    {
        return spelling == "";
    }

    @property Type underlying ()
    {
        return declaration.underlyingType;
    }

    @property bool isArray ()
    {
        return
            kind == CXTypeKind.CXType_ConstantArray ||
            kind == CXTypeKind.CXType_IncompleteArray ||
            kind == CXTypeKind.CXType_VariableArray ||
            kind == CXTypeKind.CXType_DependentSizedArray;
    }

    /**
     * Removes array and pointer modifiers from the type.
     */
    @property Type undecorated()
    {
        if (isArray)
            return array.elementType.undecorated;
        else if (kind == CXTypeKind.CXType_Pointer && !pointee.isFunctionType)
            return pointee.undecorated;
        else
            return this;
    }

    @property bool isDecorated()
    {
        return isArray || (kind == CXTypeKind.CXType_Pointer && !pointee.isFunctionType);
    }

    @property bool isEnum ()
    {
        return kind == CXTypeKind.CXType_Enum;
    }

    @property bool isExposed ()
    {
        return kind != CXTypeKind.CXType_Unexposed;
    }

    @property bool isFunctionType ()
    {
        return canonical.kind == CXTypeKind.CXType_FunctionProto;
    }

    @property bool isFunctionPointerType ()
    {
        return kind == CXTypeKind.CXType_Pointer && pointee.isFunctionType;
    }

    @property bool isObjCIdType ()
    {
        return isTypedef &&
            canonical.kind == CXTypeKind.CXType_ObjCObjectPointer &&
            spelling == "id";
    }

    @property bool isObjCClassType ()
    {
        return isTypedef &&
            canonical.kind == CXTypeKind.CXType_ObjCObjectPointer &&
            spelling == "Class";
    }

    @property bool isObjCSelType ()
    {
        with(CXTypeKind)
            if (isTypedef)
            {
                auto c = canonical;
                return c.kind == CXType_Pointer &&
                    c.pointee.kind == CXType_ObjCSel;
            }

            else
                return false;
    }

    @property bool isObjCBuiltinType ()
    {
        return isObjCIdType || isObjCClassType || isObjCSelType;
    }

    @property bool isPointer ()
    {
        return kind == CXTypeKind.CXType_Pointer;
    }

    @property bool isTypedef ()
    {
        return kind == CXTypeKind.CXType_Typedef;
    }

    @property bool isValid ()
    {
        return kind != CXTypeKind.CXType_Invalid;
    }

    @property bool isWideCharType ()
    {
        return kind == CXTypeKind.CXType_WChar;
    }

    @property Type canonical()
    {
        if (canonical_)
        {
            return *canonical_;
        }
        else
        {
            if (isClang)
                return Type(clang_getCanonicalType(cx));
            else
                return Type.init;
        }
    }

    @property Type pointee()
    {
        if (pointee_)
        {
            return *pointee_;
        }
        else
        {
            if (isClang)
                return Type(clang_getPointeeType(cx));
            else
                return Type.init;
        }
    }

    @property Type element()
    {
        return Type(clang_getElementType(cx));
    }

    @property Type named()
    {
        if (isClang)
            return Type(clang_Type_getNamedType(cx));
        else
            return Type.init;
    }

    @property Cursor declaration ()
    {
        if (isClang)
            return Cursor(clang_getTypeDeclaration(cx));
        else
            return Cursor.empty;
    }

    @property FuncType func ()
    {
        return FuncType(this);
    }

    @property ArrayType array ()
    {
        return ArrayType(this);
    }

    @property size_t sizeOf()
    {
        if (isClang)
        {
            auto result = clang_Type_getSizeOf(cx);

            if (result < 0)
                throwTypeLayoutError(cast(CXTypeLayoutError) result, spelling);

            return cast(size_t) result;
        }
        else
        {
            throw new TypeLayoutErrorUnknown(spelling);
        }
    }

    @property string toString() const
    {
        import std.format: format;
        return format("Type(kind = %s, spelling = %s, isConst = %s)", kind, spelling, isConst);
    }

    @property string toString()
    {
        import std.format : format;
        return format("Type(kind = %s, spelling = %s)", kind, spelling);
    }
}

struct FuncType
{
    Type type;
    alias type this;

    @property Type resultType ()
    {
        auto r = clang_getResultType(type.cx);
        return Type(r);
    }

    @property Arguments arguments ()
    {
        return Arguments(this);
    }

    @property bool isVariadic ()
    {
        return clang_isFunctionTypeVariadic(type.cx) == 1;
    }
}

struct ArrayType
{
    Type type;
    alias type this;

    this (Type type)
    {
        assert(type.isArray);
        this.type = type;
    }

    @property Type elementType ()
    {
        auto r = clang_getArrayElementType(cx);
        return Type(r);
    }

    @property long size ()
    {
        return clang_getArraySize(cx);
    }

    @property size_t numDimensions ()
    {
        size_t result = 1;
        auto subtype = elementType();

        while (subtype.isArray)
        {
            ++result;
            subtype = subtype.array.elementType();
        }

        return result;
    }
}

struct Arguments
{
    FuncType type;

    @property uint length ()
    {
        return clang_getNumArgTypes(type.type.cx);
    }

    Type opIndex (uint i)
    {
        auto r = clang_getArgType(type.type.cx, i);
        return Type(r);
    }

    int opApply (int delegate (ref Type) dg)
    {
        foreach (i ; 0 .. length)
        {
            auto type = this[i];

            if (auto result = dg(type))
                return result;
        }

        return 0;
    }
}

@property bool isIntegral (CXTypeKind kind)
{
    with (CXTypeKind)
        switch (kind)
        {
            case CXType_Bool:
            case CXType_Char_U:
            case CXType_UChar:
            case CXType_Char16:
            case CXType_Char32:
            case CXType_UShort:
            case CXType_UInt:
            case CXType_ULong:
            case CXType_ULongLong:
            case CXType_UInt128:
            case CXType_Char_S:
            case CXType_SChar:
            case CXType_WChar:
            case CXType_Short:
            case CXType_Int:
            case CXType_Long:
            case CXType_LongLong:
            case CXType_Int128:
                return true;

            default:
                return false;
        }
}

@property bool isUnsigned (CXTypeKind kind)
{
    with (CXTypeKind)
        switch (kind)
        {
            case CXType_Char_U: return true;
            case CXType_UChar: return true;
            case CXType_UShort: return true;
            case CXType_UInt: return true;
            case CXType_ULong: return true;
            case CXType_ULongLong: return true;
            case CXType_UInt128: return true;

            default: return false;
        }
}

class TypeLayoutError : object.Exception
{
    this (string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

class TypeLayoutErrorUnknown : TypeLayoutError
{
    this (string spelling, string file = __FILE__, size_t line = __LINE__)
    {
        super("The layout of the type is unknown: '" ~ spelling ~ "'.");
    }
}

class TypeLayoutErrorInvalid : TypeLayoutError
{
    this (string spelling, string file = __FILE__, size_t line = __LINE__)
    {
        super("The type is of invalid kind.");
    }
}

class TypeLayoutErrorIncomplete : TypeLayoutError
{
    this (string spelling, string file = __FILE__, size_t line = __LINE__)
    {
        super("The type '" ~ spelling ~ "' is an incomplete type.");
    }
}

class TypeLayoutErrorDependent : TypeLayoutError
{
    this (string spelling, string file = __FILE__, size_t line = __LINE__)
    {
        super("The type `" ~ spelling ~ "` is a dependent type.");
    }
}

class TypeLayoutErrorNotConstantSize : TypeLayoutError
{
    this (string spelling, string file = __FILE__, size_t line = __LINE__)
    {
        super("The type '" ~ spelling ~ "'is not a constant size type.");
    }
}

class TypeLayoutErrorInvalidFieldName : TypeLayoutError
{
    this (string spelling, string file = __FILE__, size_t line = __LINE__)
    {
        super("The field name '" ~ spelling ~ "' is not valid for this record.");
    }
}

void throwTypeLayoutError(
    CXTypeLayoutError layout,
    string spelling,
    string file = __FILE__,
    size_t line = __LINE__)
{
    final switch (layout)
    {
        case CXTypeLayoutError.CXTypeLayoutError_Invalid:
            throw new TypeLayoutErrorInvalid(spelling, file, line);
        case CXTypeLayoutError.CXTypeLayoutError_Incomplete:
            throw new TypeLayoutErrorIncomplete(spelling, file, line);
        case CXTypeLayoutError.CXTypeLayoutError_Dependent:
            throw new TypeLayoutErrorDependent(spelling, file, line);
        case CXTypeLayoutError.CXTypeLayoutError_NotConstantSize:
            throw new TypeLayoutErrorNotConstantSize(spelling, file, line);
        case CXTypeLayoutError.CXTypeLayoutError_InvalidFieldName:
            throw new TypeLayoutErrorInvalidFieldName(spelling, file, line);
    }
}
